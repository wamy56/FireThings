const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getStorage } = require("firebase-admin/storage");
const { db } = require("./shared");

const GRACE_PERIOD_DAYS = 7;

exports.storageJanitor = onSchedule("every 24 hours", async () => {
  const bucket = getStorage().bucket();
  const [files] = await bucket.getFiles();

  let deleted = 0;
  let checked = 0;

  for (const file of files) {
    checked++;
    const path = file.name;

    const referenced = await isReferenced(path);
    if (referenced) continue;

    const [metadata] = await file.getMetadata();
    const ageDays =
      (Date.now() - new Date(metadata.timeCreated).getTime()) / 86400000;
    if (ageDays <= GRACE_PERIOD_DAYS) continue;

    try {
      await file.delete();
      deleted++;
    } catch (e) {
      console.error(`Failed to delete orphan ${path}: ${e.message}`);
    }
  }

  console.log(
    `Storage janitor: checked ${checked} files, deleted ${deleted} orphans`
  );
});

async function isReferenced(storagePath) {
  // Asset photos: {basePath}/sites/{siteId}/assets/{assetId}/photos/{file}
  const assetPhotoMatch = storagePath.match(
    /^(.+)\/sites\/([^/]+)\/assets\/([^/]+)\/photos\//
  );
  if (assetPhotoMatch) {
    const [, basePath, siteId, assetId] = assetPhotoMatch;
    const doc = await db
      .doc(`${basePath}/sites/${siteId}/assets/${assetId}`)
      .get();
    if (!doc.exists) return false;
    const urls = doc.data().photoUrls || [];
    return urls.some((url) => url.includes(encodeURIComponent(storagePath)));
  }

  // Floor plans: {basePath}/sites/{siteId}/floor_plans/{planId}.{ext}
  const floorPlanMatch = storagePath.match(
    /^(.+)\/sites\/([^/]+)\/floor_plans\/([^.]+)\./
  );
  if (floorPlanMatch) {
    const [, basePath, siteId, planId] = floorPlanMatch;
    const doc = await db
      .doc(`${basePath}/sites/${siteId}/floor_plans/${planId}`)
      .get();
    return doc.exists;
  }

  // Unknown path pattern — assume referenced to be safe
  return true;
}
