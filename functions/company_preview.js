const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db } = require("./shared");

exports.previewCompanyByCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  const { inviteCode } = request.data;
  if (!inviteCode || typeof inviteCode !== "string") {
    throw new HttpsError("invalid-argument", "Invite code required");
  }

  const code = inviteCode.trim().toUpperCase();
  const query = await db
    .collection("companies")
    .where("inviteCode", "==", code)
    .limit(1)
    .get();

  if (query.empty) {
    throw new HttpsError("not-found", "Invalid invite code");
  }

  const company = query.docs[0].data();

  if (
    company.inviteCodeExpiresAt &&
    company.inviteCodeExpiresAt.toMillis() < Date.now()
  ) {
    throw new HttpsError("failed-precondition", "Invite code has expired");
  }

  return { name: company.name };
});
