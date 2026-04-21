const { onDocumentWritten, onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { db, messaging } = require("./shared");

// Callable functions
const { joinCompany } = require("./company_join");
const { createCompany } = require("./company_create");
const { previewCompanyByCode } = require("./company_preview");
const { updateMemberRole } = require("./update_member_role");
const { updateMemberPermissions } = require("./update_member_permissions");
const { storageJanitor } = require("./storage_janitor");

exports.joinCompany = joinCompany;
exports.createCompany = createCompany;
exports.previewCompanyByCode = previewCompanyByCode;
exports.updateMemberRole = updateMemberRole;
exports.updateMemberPermissions = updateMemberPermissions;
exports.storageJanitor = storageJanitor;

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

    // Don't notify if assigning to self
    const lastUpdatedBy = afterData.lastUpdatedBy;
    if (lastUpdatedBy && lastUpdatedBy === newAssignee) return;

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

    // Don't notify if the person who changed the status is the creator
    const lastUpdatedBy = afterData.lastUpdatedBy;
    if (lastUpdatedBy && lastUpdatedBy === creatorUid) return;
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

/**
 * Triggered when a dispatched job is rescheduled (scheduledDate or scheduledTime changed).
 * Sends a push notification to the assigned engineer.
 */
exports.onJobRescheduled = onDocumentUpdated(
  "companies/{companyId}/dispatched_jobs/{jobId}",
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // Only fire if scheduledDate or scheduledTime changed
    if (
      beforeData.scheduledDate === afterData.scheduledDate &&
      beforeData.scheduledTime === afterData.scheduledTime
    ) {
      return;
    }

    const assignee = afterData.assignedTo;
    if (!assignee) return; // No one to notify

    // Don't notify if the person who rescheduled is the assigned engineer
    const lastUpdatedBy = afterData.lastUpdatedBy;
    if (lastUpdatedBy && lastUpdatedBy === assignee) return;

    const memberDoc = await db
      .collection("companies")
      .doc(event.params.companyId)
      .collection("members")
      .doc(assignee)
      .get();

    if (!memberDoc.exists) return;
    const fcmToken = memberDoc.data().fcmToken;
    if (!fcmToken) return;

    const jobTitle = afterData.title || "Untitled job";
    let dateText = "a new date";
    if (afterData.scheduledDate) {
      const d = new Date(afterData.scheduledDate);
      dateText = d.toLocaleDateString("en-GB", {
        weekday: "short",
        day: "numeric",
        month: "short",
      });
      if (afterData.scheduledTime) {
        dateText += ` at ${afterData.scheduledTime}`;
      }
    }

    const message = {
      token: fcmToken,
      notification: {
        title: "Job Rescheduled",
        body: `"${jobTitle}" has been rescheduled to ${dateText}`,
      },
      data: {
        type: "job_rescheduled",
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
      console.log(`Reschedule notification sent to engineer ${assignee} for job ${event.params.jobId}`);
    } catch (error) {
      console.error("Error sending reschedule notification:", error);
    }
  }
);

/**
 * BS 5839: Notify dispatchers when a visit is declared unsatisfactory.
 */
exports.onVisitDeclarationUnsatisfactory = onDocumentUpdated(
  "companies/{companyId}/sites/{siteId}/inspection_visits/{visitId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after || after.declaration !== "unsatisfactory") return;
    if (before && before.declaration === "unsatisfactory") return;

    const { companyId, siteId } = event.params;

    const membersSnap = await db
      .collection("companies").doc(companyId)
      .collection("members")
      .get();

    const tokens = [];
    membersSnap.docs.forEach((doc) => {
      const data = doc.data();
      const perms = data.permissions || {};
      if (
        data.fcmToken &&
        (data.role === "admin" || data.role === "dispatcher" || perms.dispatch_view_all)
      ) {
        tokens.push(data.fcmToken);
      }
    });

    if (tokens.length === 0) return;

    const siteName = after.siteId || siteId;
    const engineer = after.engineerName || "An engineer";

    for (const token of tokens) {
      try {
        await messaging.send({
          token,
          notification: {
            title: "Unsatisfactory Declaration",
            body: `${engineer} declared site ${siteName} unsatisfactory under BS 5839-1:2025`,
          },
          data: { type: "bs5839_unsatisfactory", companyId, siteId },
          android: { priority: "high", notification: { channelId: "firethings_dispatch", sound: "default" } },
        });
      } catch (_) {}
    }
  }
);

/**
 * BS 5839: Notify dispatchers when a prohibited variation is logged.
 */
exports.onProhibitedVariationDetected = onDocumentCreated(
  "companies/{companyId}/sites/{siteId}/variations/{variationId}",
  async (event) => {
    const data = event.data.data();
    if (!data || !data.isProhibited) return;

    const { companyId, siteId } = event.params;

    const membersSnap = await db
      .collection("companies").doc(companyId)
      .collection("members")
      .get();

    const tokens = [];
    membersSnap.docs.forEach((doc) => {
      const d = doc.data();
      if (d.fcmToken && (d.role === "admin" || d.role === "dispatcher")) {
        tokens.push(d.fcmToken);
      }
    });

    if (tokens.length === 0) return;

    const clause = data.clauseReference || "unknown clause";
    for (const token of tokens) {
      try {
        await messaging.send({
          token,
          notification: {
            title: "Prohibited Variation Detected",
            body: `A prohibited variation (cl. ${clause}) was logged at a BS 5839 site`,
          },
          data: { type: "bs5839_prohibited_variation", companyId, siteId },
          android: { priority: "high", notification: { channelId: "firethings_dispatch", sound: "default" } },
        });
      } catch (_) {}
    }
  }
);

/**
 * BS 5839: Check daily for approaching service windows and notify dispatchers.
 * Runs at 08:00 UTC every day.
 */
exports.onServiceWindowApproaching = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Europe/London" },
  async () => {
    const companiesSnap = await db.collection("companies").get();

    for (const companyDoc of companiesSnap.docs) {
      const companyId = companyDoc.id;
      const sitesSnap = await db
        .collection("companies").doc(companyId)
        .collection("sites")
        .where("isBs5839Site", "==", true)
        .get();

      const approaching = [];
      const now = new Date();
      const warningDays = 30;
      const warningDate = new Date(now.getTime() + warningDays * 24 * 60 * 60 * 1000);

      for (const siteDoc of sitesSnap.docs) {
        const site = siteDoc.data();
        if (!site.nextServiceDueDate) continue;
        const dueDate = new Date(site.nextServiceDueDate);
        if (dueDate <= warningDate && dueDate >= now) {
          approaching.push({ name: site.name || siteDoc.id, dueDate: site.nextServiceDueDate });
        }
      }

      if (approaching.length === 0) continue;

      const membersSnap = await db
        .collection("companies").doc(companyId)
        .collection("members")
        .get();

      const tokens = [];
      membersSnap.docs.forEach((doc) => {
        const d = doc.data();
        if (d.fcmToken && (d.role === "admin" || d.role === "dispatcher")) {
          tokens.push(d.fcmToken);
        }
      });

      for (const token of tokens) {
        try {
          await messaging.send({
            token,
            notification: {
              title: "BS 5839 Services Due",
              body: `${approaching.length} site(s) have services due within ${warningDays} days`,
            },
            data: { type: "bs5839_service_approaching", companyId },
            android: { priority: "normal", notification: { channelId: "firethings_dispatch" } },
          });
        } catch (_) {}
      }
    }
  }
);
