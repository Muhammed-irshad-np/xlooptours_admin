const { onCall, HttpsError } = require("firebase-functions/v2/https");
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
