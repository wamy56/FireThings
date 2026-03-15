# FireThings — Job Dispatch Feature Specification

**Version:** 1.1  
**Date:** March 2026  
**Purpose:** Complete technical specification for implementing a job dispatch system into FireThings. This document is intended to be read by both the developer and Claude Code during implementation. Includes company PDF branding system.

---

> **Implementation Progress (updated 2026-03-15, Session 37):**
> - [x] Phase 1: Data Models & Company Setup *(items 8-9 deferred to Phase 4)*
> - [x] Phase 2: Dispatch CRUD — Dispatcher Side
> - [x] Phase 3: Engineer Job Views & Status Flow *(item 5 — Home screen card — not yet done)*
> - [ ] Phase 4: Jobsheet Integration & Company PDF Branding
> - [ ] Phase 5: Push Notifications (FCM)
> - [ ] Phase 6: Team Management & Polish
>
> **Remaining from Phases 1-3:**
> - Home screen "Dispatched Jobs" card (Phase 3, item 5)
> - Company PDF config structure + design screen (Phase 1, items 8-9 — actually Phase 4 work)
> - Site/customer autocomplete in Create Job screen (data sources not yet created)

---

## Table of Contents

1. [Feature Overview](#1-feature-overview)
2. [Architecture Changes](#2-architecture-changes)
3. [Data Models](#3-data-models)
4. [Firestore Structure & Security Rules](#4-firestore-structure--security-rules)
5. [Firebase Console Setup](#5-firebase-console-setup)
6. [User Roles & Authentication](#6-user-roles--authentication)
7. [Screens — Dispatcher (Office)](#7-screens--dispatcher-office)
8. [Screens — Engineer](#8-screens--engineer)
9. [Push Notifications (FCM)](#9-push-notifications-fcm)
10. [Jobsheet Integration](#10-jobsheet-integration)
11. [Company PDF Branding](#11-company-pdf-branding)
12. [SQLite Schema Changes](#12-sqlite-schema-changes)
13. [Existing Code Changes](#13-existing-code-changes)
14. [Analytics Events](#14-analytics-events)
15. [Remote Config Flags](#15-remote-config-flags)
16. [App Store & Privacy Changes](#16-app-store--privacy-changes)
17. [Implementation Order](#17-implementation-order)
18. [Testing Plan](#18-testing-plan)

---

## 1. Feature Overview

### What It Does

An office worker (dispatcher) creates job assignments with full details (address, contact, notes, parking, job type, etc.) and assigns them to a specific engineer. The engineer receives a push notification, sees the job in their app, can view details, get directions, update the status, and then create a jobsheet directly from the dispatched job with pre-filled data.

### User Roles

- **Dispatcher (Office)** — creates jobs, assigns to engineers, monitors job progress, sees all company jobs
- **Engineer** — receives assigned jobs, updates status, creates jobsheets from dispatched jobs
- **Admin** — manages company settings, invites/removes team members, has dispatcher + engineer access

### Job Lifecycle

```
Created → Assigned → Accepted → En Route → On Site → Completed
                 ↘ Declined (returns to unassigned)
```

### Key Principle

The dispatch system is an **addition** to FireThings, not a replacement. All existing solo-engineer functionality (personal jobsheets, invoices, tools, etc.) continues to work exactly as before. The dispatch feature is activated when a user joins or creates a company.

---

## 2. Architecture Changes

### Current Architecture

```
Firebase Auth (user identity)
    └── users/{uid}/
            ├── jobsheets/
            ├── invoices/
            ├── saved_customers/
            ├── saved_sites/
            ├── job_templates/
            ├── filled_templates/
            └── pdf_config/
```

All data is per-user, completely siloed. SQLite is primary, Firestore is backup.

### New Architecture

```
Firebase Auth (user identity)
    ├── users/{uid}/                     ← existing, unchanged
    │       ├── jobsheets/
    │       ├── invoices/
    │       ├── ... (all existing collections)
    │       └── profile                  ← NEW: role, companyId, fcmToken
    │
    └── companies/{companyId}/           ← NEW: shared company data
            ├── members/                 ← user roles within company
            ├── dispatched_jobs/         ← job assignments
            ├── sites/                   ← shared company sites
            └── customers/              ← shared company customers
```

### Key Architectural Decisions

1. **Existing personal data stays under `users/{uid}/`** — personal jobsheets, invoices, saved customers/sites, templates, and PDF config are unchanged. No migration needed.

2. **Dispatched jobs are company-level data** stored under `companies/{companyId}/dispatched_jobs/`. This is separate from the engineer's personal jobsheets.

3. **When an engineer creates a jobsheet from a dispatched job**, the jobsheet is created in their personal `users/{uid}/jobsheets/` collection as normal, but includes a `dispatchedJobId` reference back to the dispatched job. The dispatched job's status is updated to "completed".

4. **SQLite stays primary for personal data.** Dispatched jobs should use **Firestore as the primary store with local caching** (not SQLite-primary) because they are shared data that needs real-time updates from the dispatcher. Use Firestore's offline persistence for this.

5. **Push notifications via Firebase Cloud Messaging (FCM)** for job assignments. This requires storing each user's FCM device token and using Cloud Functions to trigger notifications.

---

## 3. Data Models

### Company

```dart
class Company {
  final String id;                    // Firestore document ID
  final String name;                  // e.g. "IQ Fire Solutions"
  final String? address;
  final String? phone;
  final String? email;
  final String createdBy;             // uid of the admin who created it
  final DateTime createdAt;
  final String? logoUrl;              // optional company logo (Firebase Storage)
  final String? inviteCode;           // for engineers to join the company
}
```

### CompanyMember

```dart
class CompanyMember {
  final String uid;                   // Firebase Auth UID
  final String displayName;
  final String email;
  final String role;                  // "admin", "dispatcher", "engineer"
  final String? fcmToken;             // for push notifications
  final DateTime joinedAt;
  final bool isActive;
}
```

### DispatchedJob

```dart
class DispatchedJob {
  final String id;                    // Firestore document ID
  final String companyId;

  // Job details
  final String title;                 // short description, e.g. "Annual Inspection"
  final String? description;          // detailed notes about the job
  final String? jobNumber;            // optional reference number
  final String? jobType;              // e.g. "Annual Inspection", "Fault Call Out", "Installation"

  // Site information
  final String siteName;
  final String siteAddress;
  final double? latitude;
  final double? longitude;
  final String? parkingNotes;         // e.g. "Park in rear car park, code 1234"
  final String? accessNotes;          // e.g. "Report to reception, ask for John"
  final String? siteNotes;            // general site notes

  // Contact
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;

  // Assignment
  final String? assignedTo;           // engineer uid (null = unassigned)
  final String? assignedToName;       // denormalised for display
  final String createdBy;             // dispatcher uid
  final String createdByName;         // denormalised for display

  // Scheduling
  final DateTime? scheduledDate;
  final String? scheduledTime;        // e.g. "09:00" or "AM" or "Morning"
  final String? estimatedDuration;    // e.g. "2 hours", "Half day"

  // Status
  final String status;                // created, assigned, accepted, en_route, on_site, completed, declined
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  // Linked jobsheet
  final String? linkedJobsheetId;     // populated when engineer creates a jobsheet from this job
  final String? declineReason;        // if engineer declines

  // Priority
  final String priority;              // normal, urgent, emergency

  // System info (fire alarm specific)
  final String? systemCategory;       // L1-L5, M, P1, P2
  final String? panelMake;
  final String? panelLocation;
  final int? numberOfZones;
}
```

### UserProfile (addition to existing user data)

```dart
class UserProfile {
  final String uid;
  final String? companyId;            // null if solo user (no company)
  final String? companyRole;          // admin, dispatcher, engineer
  final String? fcmToken;             // device token for push notifications
}
```

---

## 4. Firestore Structure & Security Rules

### Firestore Collections

```
companies/{companyId}
    ├── name: string
    ├── address: string
    ├── createdBy: string (uid)
    ├── inviteCode: string
    ├── createdAt: timestamp
    │
    ├── members/{uid}
    │       ├── displayName: string
    │       ├── email: string
    │       ├── role: string
    │       ├── fcmToken: string
    │       ├── joinedAt: timestamp
    │       └── isActive: bool
    │
    ├── dispatched_jobs/{jobId}
    │       ├── title: string
    │       ├── siteAddress: string
    │       ├── assignedTo: string (uid)
    │       ├── status: string
    │       ├── ... (all DispatchedJob fields)
    │       └── updatedAt: timestamp
    │
    ├── sites/{siteId}                  ← shared company sites
    │       ├── name: string
    │       ├── address: string
    │       └── notes: string
    │
    └── customers/{customerId}          ← shared company customers
            ├── name: string
            ├── address: string
            ├── email: string
            └── notes: string

users/{uid}
    ├── ... (all existing collections unchanged)
    └── profile
            ├── companyId: string
            ├── companyRole: string
            └── fcmToken: string
```

### Security Rules

Replace the existing `firestore.rules` with rules that support both personal data and company data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── Existing: personal user data (unchanged) ──
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // ── NEW: Company data ──
    match /companies/{companyId} {

      // Company document: readable by members, writable by admins
      allow read: if isCompanyMember(companyId);
      allow write: if isCompanyAdmin(companyId);

      // Members subcollection
      match /members/{memberId} {
        // Members can read all members (to see team list)
        allow read: if isCompanyMember(companyId);
        // Only admins can add/remove members
        allow write: if isCompanyAdmin(companyId);
        // Members can update their own fcmToken
        allow update: if request.auth.uid == memberId
                      && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmToken']);
      }

      // Dispatched jobs
      match /dispatched_jobs/{jobId} {
        // All company members can read all jobs
        allow read: if isCompanyMember(companyId);
        // Dispatchers and admins can create and fully update jobs
        allow create: if isCompanyDispatcherOrAdmin(companyId);
        allow update: if isCompanyDispatcherOrAdmin(companyId)
                      // Engineers can update status and linked fields on jobs assigned to them
                      || (isCompanyMember(companyId)
                          && resource.data.assignedTo == request.auth.uid
                          && request.resource.data.diff(resource.data).affectedKeys()
                             .hasOnly(['status', 'updatedAt', 'completedAt', 'linkedJobsheetId', 'declineReason']));
        allow delete: if isCompanyAdmin(companyId);
      }

      // Shared company sites
      match /sites/{siteId} {
        allow read: if isCompanyMember(companyId);
        allow write: if isCompanyDispatcherOrAdmin(companyId);
      }

      // Shared company customers
      match /customers/{customerId} {
        allow read: if isCompanyMember(companyId);
        allow write: if isCompanyDispatcherOrAdmin(companyId);
      }
    }

    // ── Helper functions ──
    function isCompanyMember(companyId) {
      return request.auth != null
             && exists(/databases/$(database)/documents/companies/$(companyId)/members/$(request.auth.uid))
             && get(/databases/$(database)/documents/companies/$(companyId)/members/$(request.auth.uid)).data.isActive == true;
    }

    function isCompanyAdmin(companyId) {
      return isCompanyMember(companyId)
             && get(/databases/$(database)/documents/companies/$(companyId)/members/$(request.auth.uid)).data.role == "admin";
    }

    function isCompanyDispatcherOrAdmin(companyId) {
      return isCompanyMember(companyId)
             && get(/databases/$(database)/documents/companies/$(companyId)/members/$(request.auth.uid)).data.role in ["admin", "dispatcher"];
    }
  }
}
```

**Important:** These rules use `get()` and `exists()` calls which count towards Firestore read quotas. Each rule evaluation that checks membership costs 1 read. For a small company (15–20 users) this is negligible, but be aware of it for future scaling.

---

## 5. Firebase Console Setup

### Required before implementation

1. **Firebase Cloud Messaging (FCM)** — should already be available in your Firebase project. Navigate to Firebase Console → Engage → Messaging to verify. For iOS, you need an APNs key or certificate uploaded:
   - Go to Firebase Console → Project Settings → Cloud Messaging tab
   - Under "Apple app configuration", upload your APNs Authentication Key (.p8 file)
   - You get this from Apple Developer → Certificates, Identifiers & Profiles → Keys → create a key with Apple Push Notifications service (APNs) enabled
   - This is a one-time setup — the same key works for all your iOS apps

2. **Firebase Cloud Functions** — needed to trigger push notifications when a job is assigned. This requires the Blaze (pay-as-you-go) plan on Firebase. If you're on the free Spark plan, you'll need to upgrade. For 15–20 users the cost will be negligible (pennies per month).

3. **New Remote Config flags:**
   - `dispatch_enabled` (boolean, default: false) — master toggle for the dispatch feature
   - `dispatch_max_members` (number, default: 25) — max company size

### Required before deployment

4. **Deploy updated Firestore security rules** — the new rules from Section 4 must be deployed via `firebase deploy --only firestore:rules`

5. **Deploy Cloud Functions** — `firebase deploy --only functions`

6. **Firestore indexes** — you'll likely need composite indexes for querying dispatched jobs. Firebase will prompt you with a link to create them when queries fail in development. Common indexes needed:
   - `dispatched_jobs`: companyId + assignedTo + status (for engineer's job list)
   - `dispatched_jobs`: companyId + status + scheduledDate (for dispatcher's overview)
   - `dispatched_jobs`: companyId + createdAt (for chronological listing)

---

## 6. User Roles & Authentication

### How Users Join a Company

**Option A: Invite Code (recommended for simplicity)**
1. Admin creates a company → system generates a unique invite code (e.g. "FT-ABC123")
2. Admin shares the code with team members (verbally, text, email)
3. Engineer opens FireThings → Settings → "Join Company" → enters invite code
4. System looks up the company by invite code, adds the user as a member with "engineer" role
5. Admin can promote members to "dispatcher" or "admin" role

**Option B: Email Invitation**
1. Admin enters an engineer's email address
2. If the engineer already has a FireThings account, they get a push notification / in-app prompt
3. If not, they get an email invitation to download the app and create an account
4. More complex to implement — recommend starting with Option A

### Role Capabilities

| Capability | Engineer | Dispatcher | Admin |
|-----------|----------|------------|-------|
| View own assigned jobs | ✓ | ✓ | ✓ |
| Update job status | ✓ (own jobs) | ✓ (all) | ✓ (all) |
| Create jobsheet from dispatched job | ✓ | ✓ | ✓ |
| View all company jobs | ✗ | ✓ | ✓ |
| Create/assign dispatched jobs | ✗ | ✓ | ✓ |
| Manage company sites/customers | ✗ | ✓ | ✓ |
| Invite/remove members | ✗ | ✗ | ✓ |
| Change member roles | ✗ | ✗ | ✓ |
| Delete company | ✗ | ✗ | ✓ |
| Personal jobsheets/invoices/tools | ✓ | ✓ | ✓ |

### Storing the Role

The user's `companyId` and `companyRole` are stored in two places:
1. `users/{uid}/profile` — so the app can check on startup whether the user is in a company
2. `companies/{companyId}/members/{uid}` — so security rules can verify membership

Both must be kept in sync. When a user's role changes, update both documents.

---

## 7. Screens — Dispatcher (Office)

### 7.1 Dispatch Dashboard (New Tab or Home Section)

**Route:** `/dispatch` or section within the Home tab

**Layout:** Shows an overview of all company jobs, filterable by status, date, and engineer.

**Components:**
- **Summary cards** at the top: Unassigned (count), In Progress (count), Completed Today (count), Urgent (count)
- **Job list** below, each card showing: title, site name, assigned engineer (or "Unassigned"), scheduled date/time, status badge (colour-coded), priority indicator
- **Filter bar:** status filter (all / unassigned / assigned / in progress / completed), date range, engineer filter
- **Sort options:** by date (default), by priority, by status
- **FAB (floating action button):** "Create Job" → opens job creation form

**Real-time updates:** Use a Firestore snapshot listener on `companies/{companyId}/dispatched_jobs/` so the dispatcher sees status changes from engineers in real time without refreshing.

### 7.2 Create Dispatched Job Screen

**Route:** `/dispatch/create`

**Form sections:**

**Job Details:**
- Title (required) — text field, e.g. "Annual Inspection"
- Job type (required) — dropdown: Annual Inspection, Quarterly Test, Fault Call Out, Installation, Commissioning, Remedial Works, Other
- Job number — text field (optional)
- Description — multiline text
- Priority — segmented control: Normal (default), Urgent, Emergency
- System category — dropdown (same as existing: L1–L5, M, P1, P2)
- Panel make — text field
- Panel location — text field
- Number of zones — number field

**Site Information:**
- Site name (required) — text field with autocomplete from company saved sites
- Site address (required) — text field with autocomplete from company saved sites
- Latitude / Longitude — auto-filled if site is from saved sites, or manual entry
- Parking notes — multiline text, e.g. "Code for barrier: 4521, park in bay 3"
- Access notes — multiline text, e.g. "Report to main reception, ask for Jane"
- Site notes — multiline text

**Contact:**
- Contact name — text field with autocomplete from company saved customers
- Contact phone — text field
- Contact email — text field

**Scheduling:**
- Scheduled date — date picker (required)
- Scheduled time — text field or time picker, e.g. "09:00" or "Morning"
- Estimated duration — text field, e.g. "2 hours"

**Assignment:**
- Assign to — dropdown of company engineers (from members collection where role == "engineer" or "admin"), or leave unassigned
- If assigned, trigger push notification on save

**Actions:**
- "Save" — creates the job, sends notification if assigned
- "Save as Draft" — creates with status "created" (unassigned)

### 7.3 Dispatched Job Detail Screen (Dispatcher View)

**Route:** `/dispatch/job/{jobId}`

**Shows:** all job details, current status with timeline, assigned engineer, map preview of site location, linked jobsheet (if completed)

**Actions:**
- Edit job details
- Reassign to different engineer
- Cancel job
- View linked jobsheet / PDF (if completed)
- Call contact (tap to dial)
- Open location in maps

### 7.4 Team Management Screen

**Route:** `/dispatch/team` or in Settings

**Shows:** list of all company members with their role, active status, and last seen

**Actions (admin only):**
- Invite new member (show invite code, or enter email)
- Change member role (engineer / dispatcher / admin)
- Deactivate / remove member
- View member's assigned jobs

### 7.5 Company Settings Screen

**Route:** `/dispatch/settings` or in Settings

**Shows:** company name, address, invite code, member count

**Actions (admin only):**
- Edit company details
- Regenerate invite code
- Manage shared sites (CRUD)
- Manage shared customers (CRUD)
- Delete company (with confirmation — must reassign or delete all jobs first)

---

## 8. Screens — Engineer

### 8.1 Dispatched Jobs List (Engineer View)

**Route:** `/dispatch/my-jobs` or new tab/section on Home screen

**Layout:** List of jobs assigned to this engineer, grouped or filterable by status.

**Sections:**
- **Active Jobs** (accepted, en_route, on_site) — shown first, highlighted
- **Upcoming Jobs** (assigned, not yet accepted) — with accept/decline actions
- **Completed Jobs** — collapsed by default, expandable

**Each job card shows:**
- Title and job type
- Site name and address
- Scheduled date and time
- Priority badge (if urgent/emergency)
- Status badge
- Tap to open detail

**Real-time updates:** Snapshot listener on dispatched_jobs where assignedTo == currentUser.uid

### 8.2 Dispatched Job Detail Screen (Engineer View)

**Route:** `/dispatch/my-jobs/{jobId}`

**Shows all job information in a clear, field-friendly layout:**

**Header section:**
- Job title, type, and priority
- Status badge with update button

**Site section:**
- Site name and full address
- Map preview (static map image or embedded map widget)
- "Get Directions" button → opens Google Maps / Apple Maps with the address
- Parking notes (highlighted if present — this is high-value info for engineers)
- Access notes
- Site notes

**Contact section:**
- Contact name
- Phone number (tap to call)
- Email (tap to email)

**Job details section:**
- Description / notes from dispatcher
- System category, panel make, panel location, zones
- Estimated duration

**Status actions (bottom of screen or FAB):**

| Current Status | Available Actions |
|---------------|-------------------|
| Assigned | Accept Job, Decline Job |
| Accepted | En Route |
| En Route | On Site |
| On Site | Complete Job, Create Jobsheet |
| Completed | View Linked Jobsheet |

**"Create Jobsheet" button:** This is the critical integration point — see Section 10.

### 8.3 Decline Job Dialog

When an engineer declines a job:
- Show a dialog asking for a reason (optional text field)
- Common quick-select reasons: "Unavailable on this date", "Too far", "Need more information", "Other"
- Job status changes to "declined", dispatcher is notified
- Job returns to the dispatcher's unassigned queue

---

## 9. Push Notifications (FCM)

### Overview

When a dispatcher assigns a job to an engineer, the engineer receives a push notification on their device even if the app is closed.

### Dependencies

Add to `pubspec.yaml`:
```yaml
firebase_messaging: ^15.x.x   # check latest version compatible with your firebase_core
```

### Device Token Management

On app startup (after Firebase Auth login), get the FCM token and store it:

```dart
// In main.dart or auth wrapper, after successful login:
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null && user.companyId != null) {
  // Update token in both places
  await FirebaseFirestore.instance
      .collection('users').doc(uid).collection('profile').doc('main')
      .update({'fcmToken': fcmToken});
  await FirebaseFirestore.instance
      .collection('companies').doc(user.companyId)
      .collection('members').doc(uid)
      .update({'fcmToken': fcmToken});
}

// Listen for token refresh
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  // Update both locations
});
```

### iOS-Specific Setup

1. Enable Push Notifications capability in Xcode:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target → Signing & Capabilities → + Capability → Push Notifications
   - Also add Background Modes → Remote notifications

2. Request notification permission in the app:
```dart
final settings = await FirebaseMessaging.instance.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
```

3. Upload APNs key to Firebase Console (covered in Section 5)

### Cloud Function for Sending Notifications

Create a Cloud Function that triggers when a dispatched job is created or updated with a new assignedTo value:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onJobAssigned = functions.firestore
  .document('companies/{companyId}/dispatched_jobs/{jobId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    if (!after) return; // job was deleted

    const newAssignee = after.assignedTo;
    const oldAssignee = before ? before.assignedTo : null;

    // Only send notification if assignee changed and new assignee exists
    if (!newAssignee || newAssignee === oldAssignee) return;

    // Get the engineer's FCM token
    const memberDoc = await admin.firestore()
      .collection('companies').doc(context.params.companyId)
      .collection('members').doc(newAssignee)
      .get();

    if (!memberDoc.exists) return;
    const fcmToken = memberDoc.data().fcmToken;
    if (!fcmToken) return;

    // Send the notification
    const message = {
      token: fcmToken,
      notification: {
        title: 'New Job Assigned',
        body: `${after.title} — ${after.siteName}`,
      },
      data: {
        type: 'job_assigned',
        jobId: context.params.jobId,
        companyId: context.params.companyId,
      },
      apns: {
        payload: {
          aps: { badge: 1, sound: 'default' },
        },
      },
    };

    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
  });

// Optional: notify dispatcher when engineer updates job status
exports.onJobStatusChanged = functions.firestore
  .document('companies/{companyId}/dispatched_jobs/{jobId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;

    // Notify the job creator (dispatcher)
    const creatorUid = after.createdBy;
    const memberDoc = await admin.firestore()
      .collection('companies').doc(context.params.companyId)
      .collection('members').doc(creatorUid)
      .get();

    if (!memberDoc.exists) return;
    const fcmToken = memberDoc.data().fcmToken;
    if (!fcmToken) return;

    const statusLabels = {
      accepted: 'accepted',
      en_route: 'is en route to',
      on_site: 'is on site at',
      completed: 'completed',
      declined: 'declined',
    };

    const statusText = statusLabels[after.status] || 'updated';

    const message = {
      token: fcmToken,
      notification: {
        title: 'Job Status Update',
        body: `${after.assignedToName} ${statusText} — ${after.title}`,
      },
      data: {
        type: 'job_status_update',
        jobId: context.params.jobId,
        companyId: context.params.companyId,
        newStatus: after.status,
      },
    };

    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error('Error sending status notification:', error);
    }
  });
```

### Notification Handling in the App

Handle notifications in three states:

1. **Foreground** — show an in-app banner/snackbar when a notification arrives while the app is open
2. **Background** — notification appears in the system tray; tapping it opens the app
3. **Terminated** — notification appears in the system tray; tapping it cold-starts the app

```dart
// Foreground
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Show in-app notification banner
  // Navigate to dispatched job detail if tapped
});

// Background/Terminated — tapping the notification
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  // Navigate to the dispatched job detail screen
  final jobId = message.data['jobId'];
  final companyId = message.data['companyId'];
  // Navigator.push to job detail
});

// Check if app was opened from a terminated state via notification
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
if (initialMessage != null) {
  // Navigate to job detail
}
```

---

## 10. Jobsheet Integration

### Creating a Jobsheet from a Dispatched Job

This is the core workflow connection. When an engineer taps "Create Jobsheet" on a dispatched job, the app should:

1. Navigate to the existing job creation flow (new_job_screen.dart)
2. Pre-fill the following fields from the dispatched job data:
   - Customer name → from dispatched job contactName or siteName
   - Site address → from dispatched job siteAddress
   - Job number → from dispatched job jobNumber
   - System category → from dispatched job systemCategory
   - Date → current date (or scheduledDate)
   - Engineer name → from current user's display name (already auto-filled)
3. Let the engineer select a template as normal
4. When the jobsheet is saved/completed, update the dispatched job:
   - Set `linkedJobsheetId` to the new jobsheet's ID
   - Set `status` to "completed"
   - Set `completedAt` to current timestamp
5. The dispatcher can then see the linked jobsheet from their job detail view

### Implementation Approach

Add an optional `dispatchedJob` parameter to the job creation flow:

```dart
// In the dispatched job detail screen:
ElevatedButton(
  onPressed: () {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => NewJobScreen(dispatchedJob: job),
    ));
  },
  child: Text('Create Jobsheet'),
)

// In new_job_screen.dart, accept the parameter:
class NewJobScreen extends StatefulWidget {
  final DispatchedJob? dispatchedJob;
  const NewJobScreen({super.key, this.dispatchedJob});
  // ...
}

// In job_form_screen.dart, pre-fill fields if dispatchedJob is provided:
if (widget.dispatchedJob != null) {
  customerNameController.text = widget.dispatchedJob!.contactName ?? widget.dispatchedJob!.siteName;
  siteAddressController.text = widget.dispatchedJob!.siteAddress;
  jobNumberController.text = widget.dispatchedJob!.jobNumber ?? '';
  // etc.
}
```

### After Jobsheet Completion

In `signature_screen.dart` or wherever the jobsheet is finalised, add logic to update the dispatched job:

```dart
// After saving the jobsheet:
if (dispatchedJob != null) {
  await FirebaseFirestore.instance
    .collection('companies').doc(dispatchedJob.companyId)
    .collection('dispatched_jobs').doc(dispatchedJob.id)
    .update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'linkedJobsheetId': newJobsheetId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
}
```

---

## 11. Company PDF Branding

### The Problem

Without company-level PDF config, every engineer's jobsheets and invoices look different — different logos, colours, footers. For a company with 15–20 engineers, this looks unprofessional. When a customer receives documents from two different engineers at the same company, the documents should be visually consistent.

### The Solution

Company-level PDF configuration (header, footer, colour scheme) that automatically applies to any document created from a dispatched job. Personal PDF config continues to apply to personal (non-dispatched) jobsheets and invoices.

### How It Works

**Decision logic in PDF generation:**

```
When generating a PDF for a jobsheet:
    if jobsheet.dispatchedJobId != null AND user.companyId != null:
        → load PDF config from companies/{companyId}/pdf_config/
    else:
        → load PDF config from users/{uid}/pdf_config/ (existing behaviour)

When generating a PDF for an invoice:
    if invoice.useCompanyBranding == true AND user.companyId != null:
        → load PDF config from companies/{companyId}/pdf_config/
    else:
        → load PDF config from users/{uid}/pdf_config/ (existing behaviour)
```

This means:
- **Dispatched job → jobsheet → PDF** automatically uses company branding. No toggle needed — if it came from a dispatch, it gets company branding.
- **Personal jobsheet → PDF** uses the engineer's personal branding as it does today.
- **Invoice → PDF** uses personal branding by default, but the engineer can toggle "Use company branding" when creating an invoice. This gives flexibility for engineers who invoice on behalf of the company vs engineers who invoice personally.

### Firestore Structure

Company PDF config mirrors the existing personal PDF config structure exactly:

```
companies/{companyId}/
    └── pdf_config/
            ├── header          ← same fields as users/{uid}/pdf_config/header
            │       ├── logoPosition: string
            │       ├── logoSize: string
            │       ├── logoBytes: string (base64)
            │       ├── companyName: string
            │       ├── tagline: string
            │       ├── address: string
            │       ├── phone: string
            │       └── centreLines: list<string>
            │
            ├── footer          ← same fields as users/{uid}/pdf_config/footer
            │       ├── leftLines: list<string>
            │       ├── centreLines: list<string>
            │       └── companyDetailsLine: string
            │
            └── colour_scheme   ← same fields as users/{uid}/pdf_config/colour_scheme
                    ├── primary: string (hex)
                    ├── accent: string (hex)
                    ├── text: string (hex)
                    └── background: string (hex)
```

### Security Rules

Add to the company security rules (Section 4):

```javascript
// Company PDF config — readable by all members, writable by admins
match /pdf_config/{configDoc} {
  allow read: if isCompanyMember(companyId);
  allow write: if isCompanyAdmin(companyId);
}
```

### Who Sets Up Company Branding

The company **admin** configures the PDF branding from Company Settings. The screens are identical to the existing Header Designer, Footer Designer, and Colour Scheme screens — they just read from and write to the company Firestore path instead of the personal one.

Dispatchers and engineers cannot edit the company PDF config. They can view a preview of it.

### Screens

**Company PDF Design (in Company Settings, admin only):**
- "Company Header" → opens Header Designer reading/writing `companies/{companyId}/pdf_config/header`
- "Company Footer" → opens Footer Designer reading/writing `companies/{companyId}/pdf_config/footer`
- "Company Colour Scheme" → opens Colour Scheme screen reading/writing `companies/{companyId}/pdf_config/colour_scheme`
- "Preview" → generates a sample PDF with the company config so the admin can see how it looks

**Implementation approach:** Reuse the existing designer screens by passing a `configPath` parameter:

```dart
// Current usage (personal):
HeaderDesignerScreen(configPath: 'users/$uid/pdf_config')

// New usage (company):
HeaderDesignerScreen(configPath: 'companies/$companyId/pdf_config')
```

If the existing designer screens are tightly coupled to the personal Firestore path, refactor them to accept a configurable path. The UI, form fields, and logic stay identical — only the read/write path changes.

### Changes to PDF Generation Code

The existing PDF generation code (using Syncfusion PDF and the `pdf` package) loads header, footer, and colour scheme from the user's config services. Add a wrapper that selects the correct source:

```dart
// New helper method — add to the PDF generation flow:
Future<PdfConfig> getEffectivePdfConfig({
  required String uid,
  String? companyId,
  String? dispatchedJobId,
  bool useCompanyBranding = false,
}) async {
  // Use company config if this is a dispatched job or company branding is explicitly requested
  final useCompany = companyId != null && (dispatchedJobId != null || useCompanyBranding);

  if (useCompany) {
    // Load from companies/{companyId}/pdf_config/
    final header = await _loadCompanyHeader(companyId);
    final footer = await _loadCompanyFooter(companyId);
    final colourScheme = await _loadCompanyColourScheme(companyId);

    // Fall back to personal config if company config hasn't been set up yet
    if (header == null && footer == null && colourScheme == null) {
      return _loadPersonalPdfConfig(uid);
    }

    return PdfConfig(
      header: header ?? await _loadPersonalHeader(uid),      // fallback per component
      footer: footer ?? await _loadPersonalFooter(uid),
      colourScheme: colourScheme ?? await _loadPersonalColourScheme(uid),
    );
  }

  return _loadPersonalPdfConfig(uid);
}
```

**Key detail:** If the company admin hasn't set up company PDF config yet, fall back to the engineer's personal config gracefully. This prevents blank headers/footers on company documents before the admin has configured branding. The fallback is per-component — if the admin has set a header and colour scheme but not a footer, the company header and colour scheme are used with the engineer's personal footer.

### Changes to Invoice Model

Add one field to the Invoice model:

```dart
class Invoice {
  // ... existing fields ...
  final bool useCompanyBranding;    // NEW — defaults to false
}
```

In the invoice creation screen, if the user is a company member, show a toggle:

```dart
if (userProfile.companyId != null)
  SwitchListTile(
    title: Text('Use company branding'),
    subtitle: Text('Apply company logo, colours, and footer to this invoice'),
    value: useCompanyBranding,
    onChanged: (val) => setState(() => useCompanyBranding = val),
  ),
```

### SQLite Changes for Invoice

```sql
ALTER TABLE invoices ADD COLUMN use_company_branding INTEGER DEFAULT 0;
```

### Caching Company PDF Config

Since multiple dispatched jobs will use the same company PDF config, cache it locally to avoid repeated Firestore reads:

- On app startup (if user has a companyId), fetch and cache the company PDF config in memory
- Listen for changes with a Firestore snapshot listener so the cache updates if the admin changes branding
- The cache is just in-memory (a service singleton holding the loaded config) — no need to persist to SQLite since this is shared data that should stay fresh from Firestore

### What Engineers See

When an engineer creates a jobsheet from a dispatched job, the PDF preview and generated PDF automatically use company branding. The engineer doesn't need to do anything — it just works. They don't see a toggle or choice for dispatched jobs; the company branding is applied automatically.

For personal jobsheets and invoices, everything works exactly as before with their personal PDF design settings.

If an engineer wants to see what the company branding looks like, they can view a preview from Settings → Company → Company Branding (read-only view for non-admins).

---

## 12. SQLite Schema Changes

### Minimal Changes

Since dispatched jobs are primarily Firestore-based (shared data), you do **not** need to add a dispatched_jobs table to SQLite. Firestore's offline persistence handles caching.

However, you do need to add the company/role reference to the local user profile. Add a column to the existing user preferences or create a small local cache:

```sql
-- Option: add to existing preferences/SharedPreferences
-- Store: companyId, companyRole as SharedPreferences strings
-- These are read on app startup to determine which UI to show
```

The existing SQLite tables (jobsheets, invoices, etc.) need small additions:

```sql
ALTER TABLE jobsheets ADD COLUMN dispatched_job_id TEXT;
ALTER TABLE invoices ADD COLUMN use_company_branding INTEGER DEFAULT 0;
```

The first links a personal jobsheet back to the dispatched job it was created from. The second allows invoices to optionally use company PDF branding (see Section 11).

---

## 13. Existing Code Changes

### Files That Need Modification

**`lib/main.dart`**
- Add FCM initialization after Firebase init
- Add FCM token management after auth
- Add notification handlers (foreground, background, terminated)

**`lib/screens/home/home_screen.dart`**
- Add a "Dispatched Jobs" section or card showing pending job count
- Conditionally show dispatch-related UI only if user has a companyId

**`lib/screens/settings/settings_screen.dart`**
- Add "Company" section with: Join Company / Create Company / Company Settings
- Add "Team" option (for dispatchers/admins)

**`lib/screens/jobs/new_job_screen.dart`**
- Accept optional `DispatchedJob` parameter
- Pass it through to job_form_screen

**`lib/screens/jobs/job_form_screen.dart`**
- Pre-fill fields from DispatchedJob if provided
- Store dispatchedJobId on the resulting jobsheet

**`lib/screens/jobs/signature_screen.dart`**
- After jobsheet completion, update the dispatched job status if linked

**`lib/services/firestore_sync_service.dart`**
- No changes needed for personal sync — dispatched jobs use their own Firestore path
- Add company PDF config sync/cache methods

**`lib/services/pdf_header_config_service.dart`** (and footer/colour scheme equivalents)
- Refactor to accept a configurable Firestore path, or create a wrapper that selects between personal and company paths based on context

**PDF generation code (jobsheet and invoice PDF builders)**
- Add the `getEffectivePdfConfig()` helper (see Section 11)
- Pass `dispatchedJobId` and `useCompanyBranding` through to determine which config to load

**`lib/services/remote_config_service.dart`**
- Add `dispatchEnabled` getter for the new feature flag

**`lib/services/analytics_service.dart`**
- Add new dispatch-related events (see Section 13)

**`lib/models/jobsheet.dart`**
- Add optional `dispatchedJobId` field

**`lib/services/database_helper.dart`**
- Add dispatchedJobId to jobsheet CRUD operations
- SQLite migration to add the column

**Navigation (main tab structure)**
- For dispatchers/admins: consider adding a 5th tab "Dispatch" or replacing "Home" with a dispatch-aware dashboard
- For engineers: add a section on the Home screen showing assigned jobs count/list

### New Files to Create

```
lib/models/
  ├── company.dart
  ├── company_member.dart
  └── dispatched_job.dart

lib/services/
  ├── dispatch_service.dart          — CRUD for dispatched jobs, real-time listeners
  ├── company_service.dart           — company management, invites, members
  └── notification_service.dart      — FCM token management, notification handling

lib/screens/dispatch/
  ├── dispatch_dashboard_screen.dart — dispatcher's main view
  ├── create_job_screen.dart         — job creation form
  ├── dispatched_job_detail_screen.dart — full job detail (dispatcher view)
  ├── engineer_jobs_screen.dart      — engineer's assigned jobs list
  ├── engineer_job_detail_screen.dart — job detail (engineer view)
  └── job_status_timeline.dart       — reusable status timeline widget

lib/screens/company/
  ├── create_company_screen.dart
  ├── join_company_screen.dart
  ├── company_settings_screen.dart
  ├── company_pdf_design_screen.dart   — links to header/footer/colour designers with company path
  ├── team_management_screen.dart
  └── member_detail_screen.dart

lib/services/
  ├── company_pdf_config_service.dart  — loads/caches company PDF config from Firestore

functions/
  └── index.js                       — Cloud Functions for notifications
```

---

## 14. Analytics Events

Add these events to `AnalyticsService`:

| Event | Parameters | When |
|-------|-----------|------|
| `company_created` | company_id | Admin creates a company |
| `company_joined` | company_id, role | User joins via invite code |
| `dispatch_job_created` | company_id, job_type, has_assignment | Dispatcher creates a job |
| `dispatch_job_assigned` | company_id, job_type | Job is assigned to an engineer |
| `dispatch_job_accepted` | company_id, job_id | Engineer accepts a job |
| `dispatch_job_declined` | company_id, reason | Engineer declines a job |
| `dispatch_job_status_changed` | company_id, old_status, new_status | Any status change |
| `dispatch_job_completed` | company_id, job_id, has_jobsheet | Job is completed |
| `dispatch_jobsheet_created` | company_id, job_id, template_type | Jobsheet created from dispatched job |
| `dispatch_directions_opened` | company_id | Engineer opens directions to site |
| `dispatch_contact_called` | company_id | Engineer taps to call contact |

---

## 15. Remote Config Flags

Add to Firebase Console Remote Config and to `RemoteConfigService`:

| Key | Default | Purpose |
|-----|---------|---------|
| `dispatch_enabled` | `false` | Master toggle — hides all dispatch UI when false |
| `dispatch_max_members` | `25` | Maximum team members per company |
| `dispatch_notifications_enabled` | `true` | Toggle push notifications |

---

## 16. App Store & Privacy Changes

### App Store Connect — App Privacy

Update the App Privacy declaration to add:

- **Contact Info** — you're already declaring this, but note that you now also collect contact info for job site contacts (name, phone, email) as company-shared data, not just personal saved customers
- No new categories needed — the existing declarations cover the data types

### Info.plist

Add the push notification usage description (iOS requires this):

```xml
<key>NSUserNotificationUsageDescription</key>
<string>FireThings sends notifications when new jobs are assigned to you.</string>
```

Ensure the Push Notifications entitlement is added in Xcode (Signing & Capabilities).

### Privacy Policy Update

Update the in-app privacy policy and the public markdown version to add:

**In Section 1 (Data We Collect), add:**
- Company data — if you join a company, your display name, email, and role are visible to other company members.
- Dispatched job data — job assignments including site addresses, contact details, and job notes are shared between company members.
- Push notification tokens — a device identifier used to deliver push notifications about job assignments.

**In Section 3 (Where Your Data Is Stored), add:**
- Company and dispatched job data is stored in Google Cloud Firestore and is accessible to all members of your company.

**In Section 5 (Who Can Access Your Data), add:**
- If you are a member of a company, dispatched job data is shared with other company members. Your display name and role are visible to other members. Your personal jobsheets, invoices, and other data remain private and are not shared.

### Google Play Data Safety

When you set up the Play Store listing, declare the additional push notification token collection.

---

## 17. Implementation Order

Build in this order. Each phase produces a working, testable increment.

### Phase 1: Data Model & Company Setup (Week 1)

1. ✅ Create the data models: `Company`, `CompanyMember`, `DispatchedJob`
2. ✅ Create `CompanyService` — create company, join company via invite code, manage members
3. ✅ Create the Firestore security rules (don't deploy yet — test locally first)
4. ✅ Add company-related screens: Create Company, Join Company, Company Settings
5. ✅ Add the "Company" section in Settings
6. ✅ Add `companyId` and `companyRole` to SharedPreferences
7. ✅ Add `dispatch_enabled` to Remote Config service
8. Add company PDF config structure to Firestore (`companies/{companyId}/pdf_config/`) *(deferred to Phase 4)*
9. Build Company PDF Design screen (reuse existing designer screens with company config path) *(deferred to Phase 4)*
10. Test: create a company, generate invite code, join from a second test account, verify members appear, set up company branding *(partially done — not yet fully tested)*

### Phase 2: Dispatch CRUD — Dispatcher Side (Week 2)

1. ✅ Create `DispatchService` — CRUD operations for dispatched jobs, Firestore listeners
2. ✅ Build the Create Dispatched Job screen with all form fields
3. ✅ Build the Dispatch Dashboard screen with job listing and filters
4. ✅ Build the Dispatched Job Detail screen (dispatcher view)
5. ✅ Add real-time Firestore snapshot listeners for the job list
6. Test: create jobs as dispatcher, verify they appear in Firestore, verify real-time updates *(not yet tested)*

### Phase 3: Engineer Job Views (Week 3)

1. ✅ Build the Engineer Jobs List screen (assigned jobs only)
2. ✅ Build the Engineer Job Detail screen with all site info, contact, map, directions
3. ✅ Implement status update flow (accept → en route → on site → complete)
4. ✅ Implement job decline flow with reason
5. Add the "Dispatched Jobs" section to the Home screen (conditional on companyId) *(not yet done)*
6. Test with two accounts: dispatcher creates and assigns, engineer accepts and updates status, dispatcher sees status change in real time *(not yet tested)*

### Phase 4: Jobsheet Integration & Company Branding (Week 3–4)

1. Add `dispatchedJobId` to the Jobsheet model and SQLite schema
2. Add `useCompanyBranding` to the Invoice model and SQLite schema
3. Modify `NewJobScreen` and `JobFormScreen` to accept and pre-fill from a DispatchedJob
4. Modify `SignatureScreen` to update dispatched job status on completion
5. Implement `getEffectivePdfConfig()` — the decision logic that selects company vs personal PDF config
6. Refactor PDF header/footer/colour scheme services to accept a configurable Firestore path
7. Create `CompanyPdfConfigService` to load and cache company PDF config
8. Add the "Use company branding" toggle to the invoice creation screen
9. Add "View Linked Jobsheet" action on dispatcher's job detail for completed jobs
10. Test full workflow: dispatch → assign → accept → create jobsheet → verify company branding on PDF → complete → dispatcher sees linked jobsheet
11. Test invoice with company branding toggle on/off
12. Test fallback: company with no PDF config set up → should fall back to personal config gracefully

### Phase 5: Push Notifications (Week 4–5)

1. Add `firebase_messaging` dependency
2. Implement FCM token management (get, store, refresh)
3. Set up APNs key in Firebase Console
4. Create and deploy Cloud Functions (`onJobAssigned`, `onJobStatusChanged`)
5. Implement notification handling in the app (foreground, background, terminated)
6. Implement deep linking from notification tap to job detail screen
7. Test: assign a job, verify push notification arrives, tap notification, verify correct screen opens

### Phase 6: Team Management & Polish (Week 5–6)

1. Build Team Management screen (admin role)
2. Implement role changes (promote/demote members)
3. Implement member deactivation/removal
4. Add shared company sites and customers (CRUD screens)
5. Add all analytics events
6. Deploy updated security rules
7. Update privacy policy
8. Update App Store Connect privacy declaration
9. Full end-to-end testing with multiple users

---

## 18. Testing Plan

### Unit Testing

- `DispatchedJob` model serialisation/deserialisation
- Status transition validation (only valid transitions allowed)
- Security rules (use Firebase emulator to test read/write permissions for each role)

### Integration Testing

- Create company → join company → verify member appears
- Create dispatched job → verify in Firestore
- Assign job → verify engineer can read it
- Engineer updates status → verify dispatcher sees update
- Create jobsheet from dispatched job → verify pre-fill → verify link back
- Decline job → verify returns to unassigned
- Push notification delivery (requires real devices)
- **PDF branding: dispatched job → jobsheet → PDF uses company branding (not personal)**
- **PDF branding: personal jobsheet → PDF uses personal branding (not company)**
- **PDF branding: invoice with company branding toggle ON → PDF uses company branding**
- **PDF branding: invoice with company branding toggle OFF → PDF uses personal branding**
- **PDF branding: company with no PDF config → falls back to personal config per component**
- **PDF branding: admin updates company branding → next generated PDF reflects the change**

### Multi-User Testing

This feature requires testing with at least 3 accounts simultaneously:
1. Admin/Dispatcher account (on one device or browser)
2. Engineer account 1 (on a phone)
3. Engineer account 2 (on another phone)

Test scenarios:
- Dispatcher creates job, assigns to Engineer 1 → Engineer 1 gets notification
- Engineer 1 accepts, updates status through full lifecycle → Dispatcher sees all updates
- Dispatcher reassigns a job from Engineer 1 to Engineer 2 → Both get appropriate notifications
- Engineer declines → job returns to dispatcher's queue
- Two engineers have different assigned jobs simultaneously
- Offline: engineer goes offline, updates status, comes back online → changes sync

### Security Testing

Use the Firebase Emulator Suite to test that:
- Engineers cannot read jobs assigned to other engineers? **Note: current rules allow all members to read all jobs.** This is intentional for transparency, but you could restrict it if needed.
- Engineers cannot create or delete jobs
- Engineers can only update status fields on their own assigned jobs
- Non-members cannot access any company data
- Members of Company A cannot access Company B's data

---

## Notes for Claude Code

When implementing this feature, keep these principles in mind:

1. **Don't break existing functionality.** All solo-engineer features must continue working identically for users who are not in a company.

2. **Conditionally show dispatch UI.** Check `companyId != null` before showing any dispatch-related screens, cards, or navigation items. Use the `dispatch_enabled` Remote Config flag as a master toggle.

3. **Follow existing patterns.** The app uses StatefulWidget + setState for state management. Follow this pattern for dispatch screens. Use the same widget patterns (ResponsiveListView, responsive grid, skeleton loaders, Flutter Animate transitions) used throughout the app.

4. **Match existing design language.** Use the same colour palette (Deep Navy `#1E3A5F` primary, Coral `#F97316` accent), Google Fonts Inter typography, and adaptive UI (Cupertino on Apple, Material on Android).

5. **Firestore-primary for shared data.** Unlike personal data (SQLite-primary, Firestore-backup), dispatched jobs should use Firestore as the primary data store with snapshot listeners for real-time updates. Firestore's offline persistence handles caching.

6. **Test with the Firebase Emulator Suite** before deploying security rules to production. The emulator lets you test rules without affecting live data.

7. **Keep the Cloud Functions simple.** The notification functions are the only backend code needed. Don't add unnecessary server-side logic — keep business logic in the client app where possible.

8. **The `FEATURES.md` and `CHANGELOG.md` files must be updated** after implementation to reflect the new dispatch feature, new screens, new models, and new Firebase services.
