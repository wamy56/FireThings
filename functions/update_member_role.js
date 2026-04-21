const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, defaultPermissionsForRole } = require("./shared");

exports.updateMemberRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  const { companyId, memberUid, newRole } = request.data;
  if (!companyId || !memberUid || !newRole) {
    throw new HttpsError("invalid-argument", "companyId, memberUid, and newRole required");
  }

  const validRoles = ["admin", "dispatcher", "engineer"];
  if (!validRoles.includes(newRole)) {
    throw new HttpsError("invalid-argument", `Invalid role: ${newRole}`);
  }

  const callerUid = request.auth.uid;

  const callerDoc = await db
    .doc(`companies/${companyId}/members/${callerUid}`)
    .get();
  if (!callerDoc.exists || !callerDoc.data().isActive) {
    throw new HttpsError("permission-denied", "Not an active member");
  }
  if (callerDoc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Only admins can change roles");
  }

  const targetDoc = await db
    .doc(`companies/${companyId}/members/${memberUid}`)
    .get();
  if (!targetDoc.exists || !targetDoc.data().isActive) {
    throw new HttpsError("not-found", "Member not found");
  }

  const currentRole = targetDoc.data().role;
  if (currentRole === "admin" && newRole !== "admin") {
    const adminsSnap = await db
      .collection(`companies/${companyId}/members`)
      .where("role", "==", "admin")
      .where("isActive", "==", true)
      .get();
    if (adminsSnap.docs.length <= 1) {
      throw new HttpsError(
        "failed-precondition",
        "Cannot demote the only admin"
      );
    }
  }

  await db.doc(`companies/${companyId}/members/${memberUid}`).update({
    role: newRole,
    permissions: defaultPermissionsForRole(newRole),
  });

  return { success: true };
});
