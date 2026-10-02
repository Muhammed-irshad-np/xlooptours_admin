const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

async function assertCallerIsAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const callerUid = request.auth.uid;
  const callerEmail = (request.auth.token.email || "").toLowerCase();
  const db = getFirestore();

  let roleId = "";
  const byUid = await db.collection("users").doc(callerUid).get();
  if (byUid.exists) {
    roleId = (byUid.data().roleId || "").toString().toLowerCase();
  } else if (callerEmail) {
    const byEmail = await db.collection("users").doc(callerEmail).get();
    if (byEmail.exists) {
      roleId = (byEmail.data().roleId || "").toString().toLowerCase();
    } else {
      const q = await db
        .collection("users")
        .where("email", "==", callerEmail)
        .limit(1)
        .get();
      if (!q.empty) {
        roleId = (q.docs[0].data().roleId || "").toString().toLowerCase();
      }
    }
  }

  if (!roleId && callerEmail) {
    const allowed = await db.collection("allowed_users").doc(callerEmail).get();
    if (allowed.exists && allowed.data().isAdmin === true) {
      roleId = "admin";
    }
  }

  if (roleId !== "super_admin" && roleId !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only Admin or Super Admin can perform this action."
    );
  }

  return { callerUid, callerEmail, roleId };
}

/**
 * Admin / Super Admin sets another user's password.
 */
exports.changeUserPassword = onCall(async (request) => {
  await assertCallerIsAdmin(request);

  const uid = (request.data?.uid || "").toString().trim();
  const newPassword = (request.data?.newPassword || "").toString();

  if (!uid) {
    throw new HttpsError("invalid-argument", "User id is required.");
  }
  if (!newPassword || newPassword.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters."
    );
  }

  try {
    await getAuth().updateUser(uid, { password: newPassword });
  } catch (e) {
    if (e?.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Auth user not found for this account.");
    }
    throw new HttpsError("internal", e?.message || "Failed to update password.");
  }

  return { success: true };
});

/**
 * Admin / Super Admin changes another user's login email (username).
 * Updates Firebase Auth + users/{uid} + allowed_users + linked employee.
 */
exports.changeUserEmail = onCall(async (request) => {
  await assertCallerIsAdmin(request);

  const uid = (request.data?.uid || "").toString().trim();
  const newEmail = (request.data?.newEmail || "").toString().trim().toLowerCase();

  if (!uid) {
    throw new HttpsError("invalid-argument", "User id is required.");
  }
  if (!newEmail || !newEmail.includes("@")) {
    throw new HttpsError("invalid-argument", "A valid new email is required.");
  }

  const db = getFirestore();
  const auth = getAuth();

  // Ensure target exists
  let oldEmail = "";
  try {
    const authUser = await auth.getUser(uid);
    oldEmail = (authUser.email || "").toLowerCase();
  } catch (e) {
    if (e?.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Auth user not found for this account.");
    }
    throw new HttpsError("internal", e?.message || "Failed to load auth user.");
  }

  if (oldEmail === newEmail) {
    return { success: true, email: newEmail, unchanged: true };
  }

  // Auth: set new login email
  try {
    await auth.updateUser(uid, {
      email: newEmail,
      emailVerified: false,
    });
  } catch (e) {
    if (e?.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "That email is already used by another account."
      );
    }
    if (e?.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "Invalid email address.");
    }
    throw new HttpsError("internal", e?.message || "Failed to update email.");
  }

  // Profile doc
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const roleId = userSnap.exists
    ? userSnap.data().roleId || "office_staff"
    : "office_staff";
  const isActive = userSnap.exists
    ? userSnap.data().isActive !== false
    : true;
  const employeeId = userSnap.exists ? userSnap.data().employeeId : null;

  await userRef.set(
    {
      email: newEmail,
      uid,
    },
    { merge: true }
  );

  // Remove legacy email-keyed user doc if it pointed at this user
  if (oldEmail && oldEmail !== newEmail) {
    const legacy = db.collection("users").doc(oldEmail);
    const legacySnap = await legacy.get();
    if (legacySnap.exists) {
      const legacyUid = legacySnap.data().uid;
      if (!legacyUid || legacyUid === uid) {
        await legacy.delete();
      }
    }
    await db.collection("allowed_users").doc(oldEmail).set(
      { active: false },
      { merge: true }
    );
  }

  await db.collection("allowed_users").doc(newEmail).set(
    {
      active: isActive,
      isAdmin: roleId === "super_admin" || roleId === "admin",
      roleId,
    },
    { merge: true }
  );

  if (employeeId) {
    await db.collection("employees").doc(employeeId).set(
      {
        linkedUserUid: uid,
        linkedUserEmail: newEmail,
      },
      { merge: true }
    );
  }

  return { success: true, email: newEmail, previousEmail: oldEmail };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Odometer integrity
//
//  The client runs a history-aware plausibility engine before writing a
//  reading. These functions are the parts that must not live on the client:
//  a server-side guard that re-derives the vehicle's odometer from the log
//  after any write, and a one-shot audit that seeds and inspects data written
//  before the log existed.
//
//  Thresholds mirror OdometerPolicy in
//  lib/features/vehicle/domain/entities/odometer_policy.dart. Keep the two in
//  step: the Dart side decides what a user sees, this side decides what the
//  database will tolerate.
// ─────────────────────────────────────────────────────────────────────────────


const ODOMETER_POLICY = {
  lifetimeMaxKm: 2000000,
  hardMaxFirstDayKm: 1500,
  hardMaxSustainedDailyKm: 900,
};

function hardMaxDelta(days) {
  const d = Math.max(1, days);
  return (
    ODOMETER_POLICY.hardMaxFirstDayKm +
    ODOMETER_POLICY.hardMaxSustainedDailyKm * (d - 1)
  );
}

function toDate(raw) {
  if (!raw) return null;
  if (typeof raw === "string") {
    const d = new Date(raw);
    return isNaN(d.getTime()) ? null : d;
  }
  if (typeof raw.toDate === "function") return raw.toDate();
  return null;
}

/** Accepted readings for a vehicle, oldest first. */
async function acceptedReadings(db, vehicleId) {
  const snap = await db
    .collection("vehicles")
    .doc(vehicleId)
    .collection("odometerReadings")
    .where("status", "==", "accepted")
    .get();

  return snap.docs
    .map((d) => ({ id: d.id, ...d.data(), _at: toDate(d.data().readingAt) }))
    .filter((r) => r._at !== null)
    .sort((a, b) => a._at - b._at);
}

/**
 * Keeps `vehicles/{id}.currentOdometer` honest.
 *
 * currentOdometer is a derived cache of the latest accepted reading, not a
 * field anyone should be setting. Recomputing it here means that however a
 * reading arrives — the app, a script, a console edit — the vehicle cannot end
 * up disagreeing with its own log, and a quarantined reading can never move it.
 */
exports.syncVehicleOdometer = onDocumentWritten(
  "vehicles/{vehicleId}/odometerReadings/{readingId}",
  async (event) => {
    const { vehicleId } = event.params;
    const db = getFirestore();

    const accepted = await acceptedReadings(db, vehicleId);
    if (accepted.length === 0) return;

    const latest = accepted[accepted.length - 1];
    const vehicleRef = db.collection("vehicles").doc(vehicleId);
    const vehicle = await vehicleRef.get();
    if (!vehicle.exists) return;

    const current = vehicle.data().currentOdometer;
    if (current === latest.value) return;

    await vehicleRef.update({
      currentOdometer: latest.value,
      lastOdometerUpdateDate: latest.readingAt,
    });
  }
);

/**
 * Flags a reading the client wrote as accepted but which the server considers
 * physically impossible.
 *
 * This only catches the hard limits — backwards travel and impossible daily
 * distances — because those are the ones decidable without the learned
 * per-vehicle baseline. It quarantines rather than deletes, so the reading
 * stays visible in the review queue with its full provenance.
 */
exports.guardOdometerReading = onDocumentWritten(
  "vehicles/{vehicleId}/odometerReadings/{readingId}",
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return;

    const reading = after.data();
    if (reading.status !== "accepted") return;
    if (reading.source === "correction" || reading.source === "initial") return;

    const { vehicleId } = event.params;
    const db = getFirestore();
    const at = toDate(reading.readingAt);
    if (!at) return;

    const flags = [];

    if (
      typeof reading.value !== "number" ||
      reading.value < 0 ||
      reading.value > ODOMETER_POLICY.lifetimeMaxKm
    ) {
      flags.push("aboveLifetimeMax");
    }

    const accepted = await acceptedReadings(db, vehicleId);
    const previous = accepted
      .filter((r) => r.id !== after.id && r._at <= at)
      .pop();

    if (previous) {
      const delta = reading.value - previous.value;
      const days = Math.max(
        1,
        Math.round((at - previous._at) / (1000 * 60 * 60 * 24))
      );

      if (delta < 0) flags.push("belowPrevious");
      else if (delta > hardMaxDelta(days)) flags.push("aboveHardCeiling");
    }

    if (flags.length === 0) return;

    const existing = Array.isArray(reading.flags) ? reading.flags : [];
    await after.ref.update({
      status: "quarantined",
      flags: Array.from(new Set([...existing, ...flags])),
      reviewNote:
        "Quarantined by the server: the reading breaches a hard odometer limit.",
    });
  }
);

/**
 * One-shot audit of odometer data written before the reading log existed.
 *
 * Two jobs. It seeds every vehicle that has a stored odometer but no readings,
 * so the first validated entry has an anchor instead of sailing through as
 * "no history". And it reports vehicles whose existing maintenance records
 * already contain impossible jumps, which is worth knowing before trusting any
 * of the alert maths built on top of them.
 *
 * Call with { dryRun: true } to get the report without writing anything.
 */
exports.auditOdometerHistory = onCall(async (request) => {
  await assertCallerIsAdmin(request);

  const dryRun = request.data?.dryRun !== false;
  const db = getFirestore();
  const vehicles = await db.collection("vehicles").get();

  const report = { seeded: [], suspicious: [], skipped: 0, dryRun };

  for (const doc of vehicles.docs) {
    const v = doc.data();
    const readings = await doc.ref.collection("odometerReadings").limit(1).get();

    if (readings.empty) {
      const seedValue = v.currentOdometer ?? v.purchaseOdometer;
      if (typeof seedValue === "number" && seedValue > 0) {
        const readingAt =
          v.lastOdometerUpdateDate || v.purchaseDate || new Date().toISOString();

        if (!dryRun) {
          const ref = doc.ref.collection("odometerReadings").doc();
          await ref.set({
            id: ref.id,
            vehicleId: doc.id,
            value: Math.round(seedValue),
            readingAt:
              typeof readingAt === "string"
                ? readingAt
                : toDate(readingAt)?.toISOString() ||
                  new Date().toISOString(),
            recordedAt: new Date().toISOString(),
            source: "initial",
            status: "accepted",
            flags: [],
            userConfirmed: false,
            note: "Seeded from the vehicle record by auditOdometerHistory.",
          });
        }
        report.seeded.push({
          vehicleId: doc.id,
          plate: v.plateNumber || null,
          value: Math.round(seedValue),
        });
      } else {
        report.skipped += 1;
      }
    }

    // Look for impossible jumps already sitting in the maintenance history.
    const history = Array.isArray(v.maintenanceHistory)
      ? [...v.maintenanceHistory]
      : [];
    const points = history
      .map((r) => ({ mileage: r.mileage, at: toDate(r.date) }))
      .filter((p) => typeof p.mileage === "number" && p.at)
      .sort((a, b) => a.at - b.at);

    for (let i = 1; i < points.length; i++) {
      const delta = points[i].mileage - points[i - 1].mileage;
      const days = Math.max(
        1,
        Math.round((points[i].at - points[i - 1].at) / (1000 * 60 * 60 * 24))
      );
      if (delta < 0 || delta > hardMaxDelta(days)) {
        report.suspicious.push({
          vehicleId: doc.id,
          plate: v.plateNumber || null,
          from: points[i - 1].mileage,
          to: points[i].mileage,
          days,
          impliedKmPerDay: Math.round(delta / days),
        });
      }
    }
  }

  return report;
});
