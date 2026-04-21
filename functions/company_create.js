const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, auth, defaultPermissionsForRole } = require("./shared");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

const INVITE_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const INVITE_CODE_EXPIRY_DAYS = 90;

function generateRandomCode() {
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += INVITE_CODE_CHARS.charAt(
      Math.floor(Math.random() * INVITE_CODE_CHARS.length)
    );
  }
  return `FT-${code}`;
}

async function generateUniqueInviteCode() {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateRandomCode();
    const existing = await db
      .collection("companies")
      .where("inviteCode", "==", code)
      .limit(1)
      .get();
    if (existing.empty) return code;
  }
  throw new Error("Could not generate unique invite code after 5 attempts");
}

exports.createCompany = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  const { name, address, phone, email } = request.data;
  if (!name || typeof name !== "string" || !name.trim()) {
    throw new HttpsError("invalid-argument", "Company name required");
  }

  const uid = request.auth.uid;

  const existingProfile = await db.doc(`users/${uid}/profile/main`).get();
  if (existingProfile.exists && existingProfile.data().companyId) {
    throw new HttpsError("failed-precondition", "Already in a company");
  }

  const companyRef = db.collection("companies").doc();
  const inviteCode = await generateUniqueInviteCode();
  const userRecord = await auth.getUser(uid);
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.set(companyRef, {
    id: companyRef.id,
    name: name.trim(),
    address: address || null,
    phone: phone || null,
    email: email || null,
    createdBy: uid,
    createdAt: now,
    inviteCode,
    inviteCodeExpiresAt: Timestamp.fromMillis(
      Date.now() + INVITE_CODE_EXPIRY_DAYS * 24 * 60 * 60 * 1000
    ),
  });
  batch.set(companyRef.collection("members").doc(uid), {
    uid,
    displayName: userRecord.displayName || "Admin",
    email: userRecord.email || "",
    role: "admin",
    joinedAt: now,
    isActive: true,
    permissions: defaultPermissionsForRole("admin"),
  });
  batch.set(
    db.doc(`users/${uid}/profile/main`),
    { uid, companyId: companyRef.id, companyRole: "admin" },
    { merge: true }
  );
  await batch.commit();

  return { companyId: companyRef.id };
});
