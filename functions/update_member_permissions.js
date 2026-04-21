const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db } = require("./shared");

exports.updateMemberPermissions = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  const { companyId, memberUid, permissions } = request.data;
  if (!companyId || !memberUid || !permissions) {
    throw new HttpsError(
      "invalid-argument",
      "companyId, memberUid, and permissions required"
    );
  }
  if (typeof permissions !== "object" || Array.isArray(permissions)) {
    throw new HttpsError("invalid-argument", "permissions must be an object");
  }

  const callerUid = request.auth.uid;

  const callerDoc = await db
    .doc(`companies/${companyId}/members/${callerUid}`)
    .get();
  if (!callerDoc.exists || !callerDoc.data().isActive) {
    throw new HttpsError("permission-denied", "Not an active member");
  }
  if (callerDoc.data().role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Only admins can change permissions"
    );
  }

  const targetDoc = await db
    .doc(`companies/${companyId}/members/${memberUid}`)
    .get();
  if (!targetDoc.exists || !targetDoc.data().isActive) {
    throw new HttpsError("not-found", "Member not found");
  }

  await db.doc(`companies/${companyId}/members/${memberUid}`).update({
    permissions,
  });

  return { success: true };
});
