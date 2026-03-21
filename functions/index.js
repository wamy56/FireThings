const { onDocumentWritten, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Triggered when a dispatched job is created or updated.
 * Sends a push notification to the newly assigned engineer.
 */
exports.onJobAssigned = onDocumentWritten(
  "companies/{companyId}/dispatched_jobs/{jobId}",
  async (event) => {
    const beforeData = event.data.before.exists ? event.data.before.data() : null;
    const afterData = event.data.after.exists ? event.data.after.data() : null;

    if (!afterData) return; // Job was deleted

    const newAssignee = afterData.assignedTo;
    const oldAssignee = beforeData ? beforeData.assignedTo : null;

    // Only send notification if assignee changed and new assignee exists
    if (!newAssignee || newAssignee === oldAssignee) return;

    // Get the engineer's FCM token from the company members subcollection
    const memberDoc = await db
      .collection("companies")
      .doc(event.params.companyId)
      .collection("members")
      .doc(newAssignee)
      .get();

    if (!memberDoc.exists) return;
    const fcmToken = memberDoc.data().fcmToken;
    if (!fcmToken) return;

    const message = {
      token: fcmToken,
      notification: {
        title: "New Job Assigned",
        body: `${afterData.title || "Untitled job"} — ${afterData.siteName || "No site"}`,
      },
      data: {
        type: "job_assigned",
        jobId: event.params.jobId,
        companyId: event.params.companyId,
      },
      apns: {
        payload: {
          aps: { badge: 1, sound: "default" },
        },
      },
      android: {
        priority: "high",
        notification: {
          channelId: "firethings_dispatch",
          sound: "default",
        },
      },
    };

    try {
      await messaging.send(message);
      console.log(`Notification sent to engineer ${newAssignee} for job ${event.params.jobId}`);
    } catch (error) {
      console.error("Error sending job assigned notification:", error);
    }
  }
);

/**
 * Triggered when a dispatched job is updated.
 * Sends a push notification to the dispatcher (job creator) when status changes.
 */
exports.onJobStatusChanged = onDocumentUpdated(
  "companies/{companyId}/dispatched_jobs/{jobId}",
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    if (beforeData.status === afterData.status) return;

    // Notify the job creator (dispatcher)
    const creatorUid = afterData.createdBy;
    if (!creatorUid) return;

    const memberDoc = await db
      .collection("companies")
      .doc(event.params.companyId)
      .collection("members")
      .doc(creatorUid)
      .get();

    if (!memberDoc.exists) return;
    const fcmToken = memberDoc.data().fcmToken;
    if (!fcmToken) return;

    const statusLabels = {
      accepted: "accepted",
      en_route: "is en route to",
      on_site: "is on site at",
      completed: "completed",
      declined: "declined",
    };

    const statusText = statusLabels[afterData.status] || "updated";
    const engineerName = afterData.assignedToName || "Engineer";
    const jobTitle = afterData.title || "Untitled job";

    const message = {
      token: fcmToken,
      notification: {
        title: "Job Status Update",
        body: `${engineerName} ${statusText} — ${jobTitle}`,
      },
      data: {
        type: "job_status_update",
        jobId: event.params.jobId,
        companyId: event.params.companyId,
        newStatus: afterData.status || "",
      },
      apns: {
        payload: {
          aps: { badge: 1, sound: "default" },
        },
      },
      android: {
        priority: "high",
        notification: {
          channelId: "firethings_dispatch",
          sound: "default",
        },
      },
    };

    try {
      await messaging.send(message);
      console.log(`Status notification sent to dispatcher ${creatorUid} for job ${event.params.jobId}`);
    } catch (error) {
      console.error("Error sending status notification:", error);
    }
  }
);
