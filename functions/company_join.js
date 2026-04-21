const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, auth, defaultPermissionsForRole } = require("./shared");
const { FieldValue } = require("firebase-admin/firestore");

exports.joinCompany = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  const { inviteCode } = request.data;
  if (!inviteCode || typeof inviteCode !== "string") {
    throw new HttpsError("invalid-argument", "Invite code required");
  }

  const code = inviteCode.trim().toUpperCase();
  const uid = request.auth.uid;

  const query = await db
    .collection("companies")
    .where("inviteCode", "==", code)
    .limit(1)
    .get();

  if (query.empty) {
    throw new HttpsError("not-found", "Invalid invite code");
  }

  const companyDoc = query.docs[0];
  const companyId = companyDoc.id;
  const company = companyDoc.data();

  if (
    company.inviteCodeExpiresAt &&
    company.inviteCodeExpiresAt.toMillis() < Date.now()
  ) {
    throw new HttpsError("failed-precondition", "Invite code has expired");
  }

  const memberRef = companyDoc.ref.collection("members").doc(uid);
  const existing = await memberRef.get();
  if (existing.exists && existing.data().isActive === true) {
    throw new HttpsError("already-exists", "Already a member of this company");
  }

  const userRecord = await auth.getUser(uid);
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.set(memberRef, {
    uid,
    displayName:
      userRecord.displayName || userRecord.email?.split("@")[0] || "Engineer",
    email: userRecord.email || "",
    role: "engineer",
    joinedAt: now,
    isActive: true,
    permissions: defaultPermissionsForRole("engineer"),
  });
  batch.set(
    db.doc(`users/${uid}/profile/main`),
    { uid, companyId, companyRole: "engineer" },
    { merge: true }
  );
  await batch.commit();

  return { companyId, companyName: company.name };
});
