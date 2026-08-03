const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

/**
 * Admin / Super Admin sets another user's password.
 * Client: FirebaseFunctions.instance.httpsCallable('changeUserPassword')
 */
exports.changeUserPassword = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const callerUid = request.auth.uid;
  const callerEmail = (request.auth.token.email || "").toLowerCase();
  const db = getFirestore();

  // Resolve caller role from users/{uid} or users/{email}
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

  // Legacy allow-list admin
  if (!roleId && callerEmail) {
    const allowed = await db.collection("allowed_users").doc(callerEmail).get();
    if (allowed.exists && allowed.data().isAdmin === true) {
      roleId = "admin";
    }
  }

  if (roleId !== "super_admin" && roleId !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only Admin or Super Admin can change user passwords."
    );
  }

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
    const msg = e?.message || "Failed to update password.";
    if (e?.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "Auth user not found for this account.");
    }
    throw new HttpsError("internal", msg);
  }

  return { success: true };
});
