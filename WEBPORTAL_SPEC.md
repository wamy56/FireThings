# FireThings — Web Portal Specification

**Version:** 1.1  
**Date:** March 2026  
**Purpose:** Technical specification for building a web-based dispatcher portal within the existing FireThings Flutter codebase. Includes web push notifications for real-time status alerts. This document is intended to be read by both the developer and Claude Code during implementation.

**Prerequisite:** The dispatch feature (`DISPATCH_FEATURE_SPEC.md`) must be implemented before this web portal. The web portal is a presentation layer on top of the same Firestore data and services.

---

## Table of Contents

1. [Overview & Goals](#1-overview--goals)
2. [Architectural Approach](#2-architectural-approach)
3. [What to Include and Exclude](#3-what-to-include-and-exclude)
4. [Authentication on Web](#4-authentication-on-web)
5. [Navigation & Layout](#5-navigation--layout)
6. [Screens — Desktop Dispatcher Dashboard](#6-screens--desktop-dispatcher-dashboard)
7. [Screens — Company Management](#7-screens--company-management)
8. [Screens — Account & Settings](#8-screens--account--settings)
9. [Responsive Behaviour](#9-responsive-behaviour)
10. [Platform-Conditional Code](#10-platform-conditional-code)
11. [Web-Specific Technical Considerations](#11-web-specific-technical-considerations)
12. [Firebase Configuration for Web](#12-firebase-configuration-for-web)
13. [Hosting & Deployment](#13-hosting--deployment)
14. [Analytics Events (Web-Specific)](#14-analytics-events-web-specific)
15. [Existing Code Changes](#15-existing-code-changes)
16. [New Files to Create](#16-new-files-to-create)
17. [Implementation Order](#17-implementation-order)
18. [Testing Plan](#18-testing-plan)

---

## 1. Overview & Goals

### What This Is

A web-based version of FireThings focused entirely on the dispatcher/office workflow. Office workers open a browser on their laptop, log in, and can create jobs, assign them to engineers, monitor progress, and manage company data — all without needing to install the mobile app.

### What This Is Not

This is NOT a full port of the mobile app to web. Engineers will continue to use the mobile app for field work (camera, tools, jobsheets, signatures). The web portal is a focused, desktop-optimised dispatcher dashboard.

### Why Build It

- Office workers dispatching jobs need a large screen with keyboard/mouse — a phone is awkward for this workflow
- No installation required — just a URL in any browser
- Multiple browser tabs allow dispatchers to reference other systems while dispatching
- The same Firestore data is used, so changes appear in real-time on both web and mobile

### Key Principle

**One codebase.** The web portal is built within the existing Flutter project using conditional platform checks. It shares data models, services, and Firestore infrastructure with the mobile app. The UI layer is different — optimised for desktop widths — but the business logic is identical.

---

## 2. Architectural Approach

### Single Codebase with Platform Conditionals

```
lib/
  ├── models/              ← shared (no changes)
  ├── services/            ← shared (no changes)
  ├── screens/
  │     ├── home/          ← mobile only
  │     ├── jobs/          ← mobile only (engineer jobsheets)
  │     ├── invoices/      ← mobile only
  │     ├── settings/      ← shared (some screens mobile-only)
  │     ├── dispatch/      ← shared (used by both mobile and web)
  │     ├── company/       ← shared (used by both mobile and web)
  │     └── web/           ← NEW: web-only screens and layouts
  │           ├── web_shell.dart           ← top-level layout with sidebar nav
  │           ├── web_dashboard_screen.dart ← desktop dispatch dashboard
  │           ├── web_job_board_screen.dart ← calendar/board view of jobs
  │           └── web_login_screen.dart     ← web-styled login page
  └── main.dart            ← entry point routes to mobile or web shell
```

### How the Entry Point Works

In `main.dart`, check the platform and route accordingly:

```dart
import 'dart:foundation' show kIsWeb;

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthWrapper(
        // After auth, route to web shell or mobile shell
        authenticatedBuilder: (user) {
          if (kIsWeb) {
            return WebShell(user: user);
          }
          return MobileShell(user: user); // existing MainScreen / tab navigation
        },
      ),
    );
  }
}
```

### Shared Services — No Changes Needed

The following services work identically on web and mobile. No modifications required:

- `FirestoreSyncService` — Firestore SDK works on web
- `DispatchService` — all Firestore-based, works on web
- `CompanyService` — all Firestore-based, works on web
- `AnalyticsService` — Firebase Analytics supports web
- `RemoteConfigService` — Firebase Remote Config supports web
- `CompanyPdfConfigService` — Firestore-based, works on web

### Services That Won't Work on Web

- `DatabaseHelper` (SQLite) — SQLite doesn't work in browsers. The web portal doesn't need it because dispatchers don't create personal jobsheets or invoices. All dispatch data is Firestore-primary anyway.
- `NotificationService` (FCM push on mobile) — mobile FCM uses APNs/device tokens. Web push uses a different mechanism (browser Notification API via a service worker). See Section 11.5 for web push implementation.
- Camera/FFmpeg/Gallery services — not needed on web
- `EmailService` (feedback via native email client) — use `url_launcher` on web to open mailto: links instead

---

## 3. What to Include and Exclude

### Include on Web

| Feature | Notes |
|---------|-------|
| Login / Authentication | Firebase Auth email/password |
| Dispatch Dashboard | Full job overview with filters, real-time updates |
| Create Dispatched Job | Full form with all fields |
| Edit Dispatched Job | Full editing capability |
| Job Detail View | All details, status timeline, linked jobsheet info |
| Assign/Reassign Engineers | Dropdown of team members |
| Job Calendar/Board View | NEW web-only view — visual schedule |
| Team Management | View members, roles, invite code (admin) |
| Company Settings | Company details, branding, shared sites/customers (admin) |
| Company PDF Design | Header, footer, colour scheme setup (admin) |
| Shared Sites CRUD | Create/edit/delete company sites |
| Shared Customers CRUD | Create/edit/delete company customers |
| User Profile | Display name, email, password change |
| Privacy Policy | Link to public URL |
| Real-time Updates | Firestore snapshot listeners — see engineer status changes live |
| Web Push Notifications | Browser notifications via FCM web — alerts when engineers update status, accept/decline jobs, even when on a different tab |

### Exclude from Web

| Feature | Reason |
|---------|--------|
| Helpful Tools (all 6) | Field tools — no use case at a desk |
| Timestamp Camera | Requires device camera |
| Decibel Meter | Requires device microphone |
| Personal Jobsheets | Engineers create these on mobile with signatures |
| Personal Invoices | Engineers create these on mobile |
| PDF Certificate Forms | Field use — require signature capture |
| Custom Template Builder | Engineering workflow, not dispatch |
| PDF Generation/Preview | Keep on mobile — dispatchers view linked jobsheets via status |
| SQLite / Local Storage | All web data is Firestore-direct |
| Cloud Sync Settings | No SQLite on web, no sync needed |

---

## 4. Authentication on Web

### Firebase Auth on Web

Firebase Auth works on web with the same email/password flow. The web SDK handles sessions using browser storage (IndexedDB by default).

### Web Login Screen

Create a desktop-styled login screen (not the mobile login screen). This is the first thing a dispatcher sees:

**Layout:**
- Centred card on a branded background
- FireThings logo and "Dispatcher Portal" subtitle
- Email and password fields
- "Sign In" button
- "Forgot Password" link
- No "Create Account" option on web — accounts are created on the mobile app and dispatchers are promoted by admins

**After login:**
- Check the user's `companyId` and `companyRole` from `users/{uid}/profile`
- If the user is not in a company, show a message: "You need to join a company from the mobile app to use the web portal"
- If the user's role is "engineer" (not dispatcher or admin), show a message: "The web portal is for dispatchers and admins. Please use the mobile app."
- If the user is a dispatcher or admin, proceed to the dashboard

### Session Persistence

Firebase Auth on web persists the session by default (survives browser close). The user stays logged in until they explicitly sign out. This is the correct behaviour for a work tool — dispatchers shouldn't have to log in every morning.

### Role-Based Access on Web

The web portal should only be accessible to users with `companyRole` of "dispatcher" or "admin". Engineers should be directed to the mobile app. Enforce this in the UI layer (after auth, check role and show appropriate screen or redirect message).

---

## 5. Navigation & Layout

### Desktop Layout: Sidebar Navigation

The web portal uses a persistent left sidebar (not bottom tabs). This is the standard desktop web app pattern.

```
┌──────────────────────────────────────────────────────────┐
│  [Logo] FireThings           [User Avatar] ▾  [Sign Out] │
├──────────┬───────────────────────────────────────────────┤
│          │                                               │
│  📋 Jobs │  ┌─────────────────────────────────────────┐ │
│          │  │                                         │ │
│  📅 Board│  │          Main Content Area              │ │
│          │  │                                         │ │
│  👥 Team │  │    (Dashboard / Job Detail / etc.)      │ │
│          │  │                                         │ │
│  🏢 Sites│  │                                         │ │
│          │  │                                         │ │
│  👤 Custs│  │                                         │ │
│          │  │                                         │ │
│  ⚙ Setgs │  │                                         │ │
│          │  └─────────────────────────────────────────┘ │
│          │                                               │
├──────────┴───────────────────────────────────────────────┤
│  FireThings v1.x.x  |  © 2026                           │
└──────────────────────────────────────────────────────────┘
```

### Sidebar Items

| Icon | Label | Route | Role Required |
|------|-------|-------|---------------|
| 📋 | Jobs | `/web/jobs` | dispatcher, admin |
| 📅 | Schedule | `/web/schedule` | dispatcher, admin |
| 👥 | Team | `/web/team` | dispatcher (view), admin (manage) |
| 🏢 | Sites | `/web/sites` | dispatcher, admin |
| 👤 | Customers | `/web/customers` | dispatcher, admin |
| 🎨 | Branding | `/web/branding` | admin only |
| ⚙ | Settings | `/web/settings` | dispatcher, admin |

### Top Bar

- Left: FireThings logo + "Dispatcher Portal" text
- Right: user avatar/initial + display name + company name + sign out button
- Optional: notification bell showing count of status updates (not push — just a Firestore query for recently changed jobs)

### Web Shell Implementation

```dart
// lib/screens/web/web_shell.dart
class WebShell extends StatefulWidget {
  final User user;
  const WebShell({super.key, required this.user});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _selectedIndex = 0;

  final _pages = [
    WebDashboardScreen(),      // Jobs overview
    WebJobBoardScreen(),       // Calendar/board view
    TeamManagementScreen(),    // Reused from mobile
    CompanySitesScreen(),      // Shared sites CRUD
    CompanyCustomersScreen(),  // Shared customers CRUD
    CompanyPdfDesignScreen(),  // PDF branding (admin)
    WebSettingsScreen(),       // Profile, company settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            extended: true,  // always show labels on desktop
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            destinations: [
              NavigationRailDestination(icon: Icon(Icons.assignment), label: Text('Jobs')),
              NavigationRailDestination(icon: Icon(Icons.calendar_month), label: Text('Schedule')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Team')),
              NavigationRailDestination(icon: Icon(Icons.location_on), label: Text('Sites')),
              NavigationRailDestination(icon: Icon(Icons.person), label: Text('Customers')),
              NavigationRailDestination(icon: Icon(Icons.palette), label: Text('Branding')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          // Main content
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
```

**Note:** Your existing app already uses `NavigationRail` for medium/expanded breakpoints. The web shell follows the same pattern but is always in extended mode.

---

## 6. Screens — Desktop Dispatcher Dashboard

### 6.1 Jobs Overview (Main Dashboard)

This is the primary screen dispatchers will spend most of their time on. It needs to be information-dense but scannable.

**Layout — Desktop Optimised:**

```
┌─────────────────────────────────────────────────────────┐
│  Jobs Overview                        [+ Create Job]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐     │
│  │  12  │  │  3   │  │  5   │  │  2   │  │  2   │     │
│  │ Total│  │Unassd│  │Active│  │Today │  │Urgent│     │
│  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘     │
│                                                         │
│  Filter: [All ▾] [Any Engineer ▾] [Date Range] [Search] │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐│
│  │ Title          │ Site      │ Engineer │ Date  │Status││
│  ├─────────────────────────────────────────────────────┤│
│  │ Annual Inspect. │ 14 High St│ John S.  │ 15 Mar│ ✅  ││
│  │ Fault Call Out  │ Unit 7    │ —        │ 16 Mar│ 🟡  ││
│  │ Panel Commiss.  │ Retail Pk │ Sarah M. │ 17 Mar│ 🔵  ││
│  │ ...             │           │          │       │     ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

**Components:**

**Summary Cards (top):**
- Total jobs (this month or configurable range)
- Unassigned (needs attention — highlighted if > 0)
- Active (accepted + en_route + on_site)
- Completed Today
- Urgent/Emergency (highlighted in red if > 0)
- Each card is tappable — filters the job list to that category

**Filter Bar:**
- Status dropdown: All, Unassigned, Assigned, Accepted, En Route, On Site, Completed, Declined
- Engineer dropdown: All Engineers, or specific engineer name
- Date range picker: Today, This Week, This Month, Custom
- Search field: searches title, site name, site address, job number, contact name

**Job Table:**
- Column headers: Title, Site, Engineer, Scheduled Date, Priority, Status
- Sortable by clicking column headers
- Status shown as colour-coded badge
- Priority shown as icon/badge (🔴 Emergency, 🟠 Urgent, ⚪ Normal)
- Unassigned engineer column shows "—" with subtle highlight
- Click any row to open the job detail panel/page
- Hover state on rows for desktop feel

**Desktop-specific enhancements (not on mobile):**
- Bulk selection with checkboxes — assign multiple unassigned jobs at once
- Keyboard shortcut: `N` to create new job, `/` to focus search
- Right-click context menu on jobs: Edit, Reassign, View Details, Cancel
- Column resizing (nice to have, not essential)

### 6.2 Create Job Screen (Desktop Layout)

Same fields as the mobile Create Dispatched Job screen (Section 7.2 of `DISPATCH_FEATURE_SPEC.md`) but laid out for desktop width:

**Layout — Two or Three Column Form:**

```
┌─────────────────────────────────────────────────────────┐
│  Create New Job                          [Save] [Cancel]│
├──────────────────────┬──────────────────────────────────┤
│                      │                                  │
│  Job Details         │  Site Information                │
│  ─────────────       │  ─────────────────               │
│  Title: [________]   │  Site: [________] (autocomplete) │
│  Type:  [dropdown▾]  │  Address: [________]             │
│  Job #: [________]   │  Parking: [________________]     │
│  Priority: [○N ○U ○E]│  Access:  [________________]     │
│  System Cat: [▾]     │  Notes:   [________________]     │
│  Description:        │                                  │
│  [________________]  │  Contact                         │
│  [________________]  │  ─────────────                   │
│                      │  Name:  [________]               │
│  Scheduling          │  Phone: [________]               │
│  ─────────────       │  Email: [________]               │
│  Date: [📅 picker]   │                                  │
│  Time: [________]    │  Assignment                      │
│  Duration: [______]  │  ─────────────                   │
│                      │  Engineer: [dropdown ▾]          │
│                      │                                  │
└──────────────────────┴──────────────────────────────────┘
```

Side-by-side layout uses desktop width efficiently. On mobile, this same data is in a single scrolling column.

**Implementation approach:** Either reuse the existing `CreateJobScreen` with responsive layout breakpoints, or create a `WebCreateJobScreen` that uses the same form logic but with a different layout. The responsive approach is preferred — add a desktop layout variant to the existing screen.

### 6.3 Job Detail View (Desktop)

When clicking a job row in the table, show the full detail either as:
- **Option A: Side panel** — a panel slides in from the right covering ~40% of the screen while the job list stays visible on the left. This is the Jobber/ServiceM8 pattern and is excellent for quickly reviewing multiple jobs.
- **Option B: Full page** — navigates to a full-width detail page with a "Back to Jobs" link.

**Recommendation: Side panel (Option A).** It keeps the dispatcher in context and allows quick navigation between jobs.

**Panel content:** Same as dispatcher job detail from `DISPATCH_FEATURE_SPEC.md` Section 7.3 — all details, status timeline, assigned engineer, map embed, actions (edit, reassign, cancel).

**Desktop-specific additions:**
- Map embed (Google Maps iframe or Flutter `google_maps_flutter` web support) showing the site location
- Status timeline shown horizontally (enough space on desktop)
- Linked jobsheet: if completed, show a "View Jobsheet PDF" button that opens the PDF in a new browser tab

### 6.4 Schedule / Board View (Web-Only)

A visual calendar or board view of dispatched jobs — this is a web-only screen that doesn't exist on mobile.

**Option A: Calendar View**
- Weekly or monthly calendar grid
- Jobs shown as coloured blocks on their scheduled date
- Colour-coded by status or by assigned engineer
- Drag-and-drop to reschedule (nice to have)
- Click a job to open the side panel detail

**Option B: Kanban Board**
- Columns: Unassigned | Assigned | In Progress | Completed
- Job cards in each column
- Drag-and-drop between columns to update status (nice to have)

**Recommendation: Start with a simple calendar view.** A weekly view with job blocks colour-coded by engineer is the most useful for dispatch planning. Kanban can be added later.

**Implementation:** Use a Flutter calendar package that supports web (e.g., `table_calendar`, `syncfusion_flutter_calendar`, or build a simple custom grid). The data source is the same Firestore snapshot listener used by the job list.

---

## 7. Screens — Company Management

These screens are **shared between web and mobile** — they already exist from the dispatch feature implementation. On web, they simply render within the web shell's content area instead of inside mobile navigation.

### 7.1 Team Management

Reuse `TeamManagementScreen` from `DISPATCH_FEATURE_SPEC.md` Section 7.4. On desktop, the member list can show more columns (role, email, last active, assigned job count).

### 7.2 Company Sites

Reuse shared sites CRUD. On desktop, show as a table with inline editing rather than a list with tap-to-edit.

### 7.3 Company Customers

Same as sites — reuse shared customers CRUD with desktop table layout.

### 7.4 Company PDF Branding

Reuse `CompanyPdfDesignScreen`. The existing header/footer/colour scheme designers should work on web. The logo upload may need web-specific handling (file picker on web uses `html.FileUploadInputElement` or the `file_picker` package which supports web).

---

## 8. Screens — Account & Settings

### 8.1 Web Settings Screen

A simplified settings screen for the web portal:

- **Profile:** display name, email, password change
- **Company:** company name, details, invite code (admin)
- **Privacy Policy:** link to public GitHub URL
- **Sign Out** button
- **About:** app version

Do NOT include: saved customers/sites (personal), PDF design (personal), bank details, notifications (WorkManager), cloud sync settings, send feedback (use mailto: link instead).

### 8.2 Profile Editing

Reuse the existing profile editing logic. Firebase Auth profile updates (display name, email, password) work identically on web.

---

## 9. Responsive Behaviour

The web portal should handle different browser window sizes:

| Width | Behaviour |
|-------|-----------|
| 1200px+ | Full sidebar + spacious content area |
| 900–1200px | Collapsed sidebar (icons only) + full content |
| 600–900px | Hidden sidebar with hamburger menu + full content |
| < 600px | Show a message: "For the best experience, use the FireThings mobile app" with app store links |

**Implementation:** Use `MediaQuery` or `LayoutBuilder` to switch between layouts. The sidebar can use `NavigationRail` with `extended: true` for wide screens and `extended: false` for medium screens.

For very narrow windows (< 600px), rather than trying to make the dispatcher dashboard work on a phone-sized browser, redirect to the mobile app. The mobile app already has the dispatch screens.

---

## 10. Platform-Conditional Code

### Detecting Web

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Use throughout the codebase:
if (kIsWeb) {
  // Web-specific behaviour
} else {
  // Mobile/desktop behaviour
}
```

### Conditional Imports

For code that uses `dart:io` (which doesn't exist on web) or `dart:html` (which doesn't exist on mobile):

```dart
// Use conditional imports:
import 'mobile_implementation.dart'
    if (dart.library.html) 'web_implementation.dart';
```

### Features to Gate Behind `!kIsWeb`

These features should never load or render on web:

```dart
// In home_screen.dart, main navigation, etc:
if (!kIsWeb) ...[
  // Helpful tools grid
  // Timestamp camera
  // Decibel meter
  // Personal jobsheet creation (with signatures)
  // Personal invoice creation
  // PDF form certificates
  // Camera/gallery features
  // SQLite database initialisation
  // WorkManager background tasks
  // Mobile FCM setup (use WebNotificationService on web instead)
]
```

### SQLite on Web

SQLite (`sqflite`) does not work in browsers. You must ensure that `DatabaseHelper` is never initialised on web. Gate it:

```dart
// In main.dart or wherever DatabaseHelper is initialised:
if (!kIsWeb) {
  await DatabaseHelper.instance.database; // only on mobile/desktop
}
```

The web portal doesn't need SQLite because:
- Dispatched jobs are Firestore-primary (not SQLite)
- Company data is Firestore-primary
- The web portal doesn't create personal jobsheets or invoices

### Packages That Don't Work on Web

Verify these are not imported or initialised on web builds:

| Package | Reason | Solution |
|---------|--------|----------|
| `sqflite` | No SQLite in browsers | Gate behind `!kIsWeb` |
| `camera` | No native camera access this way | Exclude from web |
| `ffmpeg_kit_flutter` | No FFmpeg in browsers | Exclude from web |
| `workmanager` | No background tasks in browsers | Exclude from web |
| `flutter_email_sender` | Native email client | Use `url_launcher` with mailto: |
| `path_provider` | Limited on web | Use conditional import |
| `image_picker` | Works on web but not needed | Exclude unless needed for logo upload |

---

## 11. Web-Specific Technical Considerations

### URL Strategy

Use path-based URL strategy (not hash) for clean URLs:

```dart
// In main.dart:
void main() {
  usePathUrlStrategy(); // from package:flutter_web_plugins
  runApp(App());
}
```

This gives URLs like `firethings.web.app/jobs` instead of `firethings.web.app/#/jobs`.

### Browser Navigation

Support browser back/forward buttons and direct URL access:
- Use `GoRouter` or Flutter's built-in `Navigator 2.0` for declarative routing
- Each screen should have a distinct URL path
- Deep links should work — e.g., `/jobs/abc123` opens the detail for that specific job

```dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', redirect: (_, __) => '/jobs'),
    ShellRoute(
      builder: (context, state, child) => WebShell(child: child),
      routes: [
        GoRoute(path: '/jobs', builder: (_, __) => WebDashboardScreen()),
        GoRoute(path: '/jobs/:id', builder: (_, state) => WebJobDetailScreen(id: state.pathParameters['id']!)),
        GoRoute(path: '/jobs/create', builder: (_, __) => WebCreateJobScreen()),
        GoRoute(path: '/schedule', builder: (_, __) => WebJobBoardScreen()),
        GoRoute(path: '/team', builder: (_, __) => TeamManagementScreen()),
        GoRoute(path: '/sites', builder: (_, __) => CompanySitesScreen()),
        GoRoute(path: '/customers', builder: (_, __) => CompanyCustomersScreen()),
        GoRoute(path: '/branding', builder: (_, __) => CompanyPdfDesignScreen()),
        GoRoute(path: '/settings', builder: (_, __) => WebSettingsScreen()),
      ],
    ),
    GoRoute(path: '/login', builder: (_, __) => WebLoginScreen()),
  ],
);
```

### Page Title

Update the browser tab title based on the current page:

```dart
// In each screen or via GoRouter's pageBuilder:
Title(
  title: 'Jobs - FireThings',
  child: WebDashboardScreen(),
)
```

### Loading Performance

Flutter web can have slow initial load times. Mitigate this:
- Use `--web-renderer canvaskit` for better rendering (default in recent Flutter)
- Add a loading splash screen in `web/index.html` that shows while Flutter loads
- Consider deferred loading for heavy screens: `import 'screen.dart' deferred as screen;`
- Tree-shaking should exclude mobile-only code if properly gated behind `kIsWeb`

### Printing

Dispatchers may want to print job details. Web supports `window.print()`:

```dart
import 'dart:html' as html;

void printPage() {
  html.window.print();
}
```

Add a "Print" button on the job detail view. Use CSS `@media print` rules in `web/index.html` to control what prints cleanly.

### Copy to Clipboard

Useful for copying site addresses, job numbers, etc.:

```dart
import 'package:flutter/services.dart';

await Clipboard.setData(ClipboardData(text: siteAddress));
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Address copied')));
```

### 11.5 Web Push Notifications

Dispatchers won't be staring at the dashboard all day — they'll switch to emails, spreadsheets, and other tabs. Without notifications they'll miss engineer status updates entirely. Web push notifications solve this by showing native browser notifications even when the FireThings tab is in the background.

#### How Web Push Works (Different from Mobile)

Mobile push notifications use APNs (iOS) and FCM device tokens. Web push uses a completely different mechanism:

1. The browser asks the user for notification permission
2. If granted, the browser generates a **web push subscription** (not a device token)
3. A **service worker** runs in the background and receives messages even when the tab is closed
4. Firebase Cloud Messaging supports web push via this service worker

The end result is the same — a notification pops up on the dispatcher's screen — but the underlying technology is different.

#### Service Worker Setup

Create a Firebase Messaging service worker file. This runs in the browser background:

```javascript
// web/firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_AUTH_DOMAIN",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID",
});

const messaging = firebase.messaging();

// Handle background messages (when tab is not focused or closed)
messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'FireThings';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new update',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    tag: payload.data?.jobId || 'default', // prevents duplicate notifications for same job
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click — open the app to the relevant job
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const jobId = event.notification.data?.jobId;
  const url = jobId ? `/jobs/${jobId}` : '/jobs';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a FireThings tab is already open, focus it and navigate
      for (const client of clientList) {
        if (client.url.includes('firethings') && 'focus' in client) {
          client.focus();
          client.postMessage({ type: 'navigate', url: url });
          return;
        }
      }
      // Otherwise, open a new tab
      return clients.openWindow(url);
    })
  );
});
```

**Important:** Replace the Firebase config values with your actual project values. These are the same values from your `firebase_options.dart` web config.

#### Requesting Permission in Flutter

When a dispatcher logs in on web, request notification permission:

```dart
// lib/services/web_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebNotificationService {
  static final WebNotificationService instance = WebNotificationService._();
  WebNotificationService._();

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  /// Call this after login on web
  Future<void> initialize(String companyId, String uid) async {
    if (!kIsWeb) return;

    // Request permission — browser shows "Allow notifications?" prompt
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _permissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized;

    if (!_permissionGranted) {
      // User denied — show a subtle banner: "Enable notifications to get job updates"
      return;
    }

    // Get the web push token (different from mobile FCM token but stored the same way)
    // IMPORTANT: pass your VAPID key here — get this from Firebase Console → Cloud Messaging → Web Push certificates
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: 'YOUR_VAPID_KEY_FROM_FIREBASE_CONSOLE',
    );

    if (token != null) {
      // Store the token in the same place as mobile tokens
      // The Cloud Function from DISPATCH_FEATURE_SPEC.md sends to this token
      await FirebaseFirestore.instance
          .collection('companies').doc(companyId)
          .collection('members').doc(uid)
          .update({'fcmToken': token});

      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('profile').doc('main')
          .update({'fcmToken': token});
    }

    // Listen for token refresh (browsers can regenerate tokens)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection('companies').doc(companyId)
          .collection('members').doc(uid)
          .update({'fcmToken': newToken});
    });

    // Handle foreground messages (tab is active and focused)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showInAppNotification(message);
    });
  }

  void _showInAppNotification(RemoteMessage message) {
    // Show a toast/snackbar in the app UI
    // Don't show a browser notification if the tab is already focused —
    // the service worker handles background notifications
  }
}
```

#### VAPID Key Setup

You need a VAPID (Voluntary Application Server Identification) key for web push:

1. Firebase Console → Project Settings → Cloud Messaging tab
2. Scroll to "Web Push certificates"
3. Click "Generate key pair" if one doesn't exist
4. Copy the key pair string — this is your `vapidKey`
5. Paste it into the `getToken(vapidKey: '...')` call above

#### What the Cloud Functions Send

The Cloud Functions from `DISPATCH_FEATURE_SPEC.md` Section 9 (`onJobAssigned`, `onJobStatusChanged`) already send notifications to `fcmToken`. Because FCM handles both mobile and web tokens transparently, **no changes to the Cloud Functions are needed**. The same function that sends a mobile push to an engineer also sends a web push to a dispatcher — it just depends on what kind of token is stored.

This means:
- Engineer accepts a job on mobile → Cloud Function fires → looks up dispatcher's fcmToken → if it's a web push token, sends a web notification → browser shows notification even if dispatcher is in another tab
- Dispatcher creates a job and assigns on web → Cloud Function fires → sends mobile push to engineer

#### Notifications the Dispatcher Receives

| Trigger | Title | Body |
|---------|-------|------|
| Engineer accepts a job | "Job Accepted" | "{Engineer name} accepted — {Job title}" |
| Engineer declines a job | "Job Declined" | "{Engineer name} declined — {Job title}" |
| Engineer goes en route | "Engineer En Route" | "{Engineer name} is en route to — {Site name}" |
| Engineer arrives on site | "Engineer On Site" | "{Engineer name} is on site at — {Site name}" |
| Engineer completes a job | "Job Completed" | "{Engineer name} completed — {Job title}" |

#### Handling "Notification Denied"

If the user denies browser notification permission:
- Don't pester them with repeated prompts — browsers block repeated requests
- Show a subtle, dismissible banner at the top of the dashboard: "Notifications are off. You won't be notified when engineers update job status. Enable in browser settings."
- The dashboard still updates in real-time via Firestore listeners — they just won't see notifications when on another tab

#### In-App Notification Feed (Fallback)

As a complement to browser push notifications, add a notification bell icon in the top bar of the web shell. This shows a dropdown of recent status updates:

```
🔔 (3)
├─ John accepted "Annual Inspection" — 2 min ago
├─ Sarah is on site at "Unit 7 Retail Park" — 15 min ago
└─ John completed "Fault Call Out" — 1 hr ago
```

This is built from a Firestore query on recently updated dispatched jobs, ordered by `updatedAt` descending. It works regardless of browser notification permission and gives the dispatcher a quick catch-up when they return to the tab.

**Implementation:**
- Query `companies/{companyId}/dispatched_jobs/` where `updatedAt` is in the last 24 hours, ordered by `updatedAt` desc, limit 20
- Filter to only show status changes (compare `status` field)
- Show unread count as a badge on the bell icon
- Mark as read when the dropdown is opened
- Store "last seen" timestamp in `localStorage` (or just in memory — resets on page refresh, which is fine)

---

## 12. Firebase Configuration for Web

### Firebase Web SDK Setup

If not already configured, add the web app to your Firebase project:

1. Firebase Console → Project Settings → Your apps → Add app → Web
2. Register the app with a nickname (e.g., "FireThings Web")
3. Firebase provides a config object — this goes in `web/index.html` or your Flutter Firebase config

If you initialised Firebase via FlutterFire CLI (`flutterfire configure`), web should already be configured. Check for `lib/firebase_options.dart` — it should contain a `web` platform entry.

### Authentication Domain

For Firebase Auth on web, you may need to add your hosting domain to the authorised domains list:
- Firebase Console → Authentication → Settings → Authorized domains
- Add your hosting domain (e.g., `firethings.web.app` or your custom domain)

### Web Push Configuration

For web push notifications to work, two things must be set up in Firebase Console:

1. **VAPID Key:** Firebase Console → Project Settings → Cloud Messaging → Web Push certificates → Generate key pair (if not already present). Copy this key into your `WebNotificationService` code.

2. **Service Worker:** The `web/firebase-messaging-sw.js` file (see Section 11.5) must be deployed alongside your web build. Firebase Hosting serves it automatically from the `web/` directory.

### Firestore Security Rules

No changes needed. The existing rules from `DISPATCH_FEATURE_SPEC.md` Section 4 work for web clients exactly as they do for mobile clients. Security rules are enforced server-side regardless of the client platform.

### CORS (Cross-Origin Resource Sharing)

If your web app needs to fetch resources from Firebase Storage (e.g., company logos), you may need to configure CORS on your storage bucket. This is only needed if you're loading images directly from Firebase Storage URLs:

```json
// cors.json — deploy with: gsutil cors set cors.json gs://your-bucket-name
[
  {
    "origin": ["https://firethings.web.app", "http://localhost:5000"],
    "method": ["GET"],
    "maxAgeSeconds": 3600
  }
]
```

---

## 13. Hosting & Deployment

### Option A: Firebase Hosting (Recommended)

Free, fast, and integrates with your existing Firebase project.

**Setup:**
```bash
firebase init hosting
# Public directory: build/web
# Single-page app: Yes
# Automatic builds with GitHub: Optional
```

**Build and deploy:**
```bash
flutter build web --release --web-renderer canvaskit
firebase deploy --only hosting
```

**Custom domain:** Add your own domain (e.g., `portal.firethings.co.uk`) in Firebase Console → Hosting → Custom domains.

**Automatic deployments:** Add a Firebase Hosting deploy step to your Codemagic workflow so web builds deploy alongside mobile builds.

### Option B: Any Static Hosting

Flutter web builds produce static files (`build/web/`). These can be hosted on any static hosting service (Netlify, Vercel, GitHub Pages, Cloudflare Pages, etc.). Firebase Hosting is recommended because it's already part of your Firebase project.

### Separate Build Target

Add a web-specific build script or Codemagic workflow:

```yaml
# In codemagic.yaml, add a web workflow:
workflows:
  web-portal:
    name: Web Portal
    scripts:
      - name: Build web
        script: flutter build web --release --web-renderer canvaskit
      - name: Deploy to Firebase Hosting
        script: firebase deploy --only hosting
```

---

## 14. Analytics Events (Web-Specific)

Add these web-specific events to `AnalyticsService`:

| Event | Parameters | When |
|-------|-----------|------|
| `web_login` | company_id | User logs in on web portal |
| `web_dashboard_viewed` | company_id, filter_status | Dashboard loaded |
| `web_job_created` | company_id, job_type | Job created from web |
| `web_job_edited` | company_id, job_id | Job edited from web |
| `web_job_assigned` | company_id, job_id | Job assigned from web |
| `web_schedule_viewed` | company_id, view_type | Calendar/board viewed |
| `web_job_detail_viewed` | company_id, job_id | Job detail panel opened |
| `web_bulk_assign` | company_id, count | Multiple jobs assigned at once |
| `web_search_used` | company_id, query_length | Search field used |
| `web_print_used` | company_id, page | Print button clicked |

These are separate from the mobile dispatch analytics events so you can track which platform dispatchers prefer.

---

## 15. Existing Code Changes

### Files That Need Modification

**`lib/main.dart`**
- Add `kIsWeb` check to route to `WebShell` or `MobileShell` after auth
- Gate SQLite initialisation behind `!kIsWeb`
- Gate WorkManager initialisation behind `!kIsWeb`
- On web: initialise `WebNotificationService` after auth (requests browser permission, stores web push token)
- On mobile: initialise mobile FCM as before
- Add `usePathUrlStrategy()` for web URL handling
- Wrap with `GoRouter` for web navigation (or use conditionally)

**`lib/services/database_helper.dart`**
- Ensure this is never instantiated on web
- Add a `kIsWeb` guard at the top of `database` getter or factory constructor
- Alternative: wrap all `DatabaseHelper` calls in mobile-only code paths

**`lib/screens/dispatch/dispatch_dashboard_screen.dart`**
- Add responsive desktop layout variant for wide screens
- The core logic (Firestore listeners, job list, filters) stays the same

**`lib/screens/dispatch/create_job_screen.dart`**
- Add two-column form layout for desktop widths
- Same fields, same validation, same Firestore write — different layout

**`lib/screens/dispatch/dispatched_job_detail_screen.dart`**
- Can be reused on web inside the side panel
- Add map embed for desktop (Google Maps widget or iframe)

**`lib/screens/company/team_management_screen.dart`**
- Add desktop table layout variant with more columns

**`lib/services/analytics_service.dart`**
- Add web-specific events from Section 14

**`lib/services/remote_config_service.dart`**
- Add `webPortalEnabled` flag getter

### Files That Need Platform Guards

These files should NOT be imported or initialised on web:

- `lib/screens/home/home_screen.dart` (tools grid)
- `lib/screens/tools/*` (all tool screens)
- `lib/screens/jobs/*` (personal jobsheet screens — not dispatch)
- `lib/screens/invoices/*` (personal invoice screens)
- Any file that imports `dart:io`, `sqflite`, `camera`, `ffmpeg_kit_flutter`

---

## 16. New Files to Create

```
lib/screens/web/
  ├── web_shell.dart                  — sidebar navigation + content area layout
  ├── web_login_screen.dart           — desktop-styled login page
  ├── web_dashboard_screen.dart       — jobs overview with table, filters, summary cards
  ├── web_job_detail_panel.dart       — side panel for job detail (slides in from right)
  ├── web_create_job_screen.dart      — two-column job creation form (or responsive variant)
  ├── web_schedule_screen.dart        — calendar/board view of jobs
  ├── web_settings_screen.dart        — simplified settings for web
  ├── web_access_denied_screen.dart   — shown to engineers or users without a company
  └── web_notification_feed.dart      — bell icon dropdown showing recent status updates

lib/services/
  └── web_notification_service.dart   — web push permission, token management, foreground handling

web/
  ├── index.html                      — update with loading splash, favicon, page title
  ├── firebase-messaging-sw.js        — service worker for background web push notifications
  ├── favicon.png                     — FireThings icon
  └── manifest.json                   — PWA manifest (optional — makes it installable)
```

---

## 17. Implementation Order

### Phase 1: Web Build Foundation (2–3 days)

1. Verify Flutter web builds successfully (`flutter build web`)
2. Verify Firebase is configured for web (`flutterfire configure` includes web)
3. Add `kIsWeb` guards to `main.dart` — gate SQLite, WorkManager, FCM
4. Add `kIsWeb` guards to any file importing `dart:io` or mobile-only packages
5. Create `WebShell` with sidebar navigation (use `NavigationRail extended: true`)
6. Create `WebLoginScreen` with desktop-styled layout
7. Create `WebAccessDeniedScreen` for engineers / non-company users
8. Route to `WebShell` or `MobileShell` based on `kIsWeb` after auth
9. Test: `flutter run -d chrome` — verify login works, sidebar renders, no runtime errors

### Phase 2: Dashboard & Job Management (3–4 days)

1. Create `WebDashboardScreen` with summary cards, filter bar, and job table
2. Wire up Firestore snapshot listener (reuse from `DispatchService`)
3. Implement job table with sortable columns and status badges
4. Create `WebJobDetailPanel` — side panel that slides in when clicking a job row
5. Create `WebCreateJobScreen` (or add responsive desktop layout to existing screen)
6. Implement job editing from the detail panel
7. Implement assign/reassign from the dashboard
8. Test: create a job on web, verify it appears on mobile app, update status on mobile, verify web updates in real-time

### Phase 3: Schedule View & Polish (2–3 days)

1. Create `WebScheduleScreen` with a weekly calendar grid
2. Show jobs as coloured blocks on their scheduled dates
3. Click a job block to open the detail panel
4. Add bulk selection and bulk assignment to the job table
5. Add search functionality across all job fields
6. Add print button to job detail panel
7. Add keyboard shortcuts (N for new job, / for search)
8. Test across browsers: Chrome, Firefox, Safari, Edge

### Phase 4: Web Push Notifications (2–3 days)

1. Create `web/firebase-messaging-sw.js` with your Firebase config
2. Generate VAPID key in Firebase Console → Cloud Messaging → Web Push certificates
3. Create `WebNotificationService` — permission request, token storage, foreground handling
4. Initialise `WebNotificationService` after auth in `main.dart` (web only)
5. Test: assign a job on web → switch to another browser tab → verify notification appears
6. Test: engineer updates status on mobile → verify dispatcher gets a browser notification on web
7. Test notification click → verify it focuses the FireThings tab and navigates to the correct job
8. Handle "permission denied" gracefully — show dismissible banner
9. Build the notification bell/feed dropdown in the web shell top bar
10. Test: verify notification feed shows recent status updates from Firestore query

### Phase 5: Hosting & Deployment (1 day)

1. Set up Firebase Hosting (`firebase init hosting`)
2. Build and deploy (`flutter build web && firebase deploy --only hosting`)
3. Configure custom domain if desired
4. Add web build to Codemagic workflow
5. Add hosting domain to Firebase Auth authorized domains
6. Test: access the portal via the deployed URL, verify auth works, verify Firestore access

### Phase 6: Company Management Screens (1–2 days)

1. Verify team management, sites, and customers screens render on web
2. Add desktop table layouts where appropriate
3. Verify company PDF branding screens work on web (especially logo upload)
4. Create `WebSettingsScreen` with simplified settings
5. Add web-specific analytics events
6. Full end-to-end testing

---

## 18. Testing Plan

### Browser Testing

Test in all major browsers:
- Chrome (primary — Flutter web is best optimised for Chrome)
- Firefox
- Safari (important for Mac-using office workers)
- Edge

### Responsive Testing

Test at these widths:
- 1920px (full HD monitor)
- 1440px (common laptop)
- 1280px (smaller laptop)
- 1024px (iPad landscape)
- 768px (iPad portrait — should show collapsed sidebar)
- 375px (phone — should show "use mobile app" message)

### Web Push Notification Testing

1. Grant notification permission → verify token stored in Firestore member document
2. Deny notification permission → verify banner appears, no errors, dashboard still works
3. Engineer accepts job on mobile → dispatcher gets browser notification on web (even on another tab)
4. Engineer updates status through full lifecycle → dispatcher receives notification for each change
5. Click notification → FireThings tab focuses, navigates to correct job detail
6. Multiple rapid status updates → notifications don't pile up (tag-based deduplication)
7. Notification bell feed → shows recent updates, unread count, marks as read on open
8. Close browser, reopen → token still valid, notifications resume without re-granting permission
9. Test in Chrome, Firefox, Safari (Safari has limited web push support — may not work)
10. Revoke permission in browser settings → verify graceful handling, banner reappears

### Cross-Platform Real-Time Testing

This is the critical test — verify that web and mobile stay in sync:

1. Open web portal in browser, logged in as dispatcher
2. Open mobile app on phone, logged in as engineer
3. Dispatcher creates a job on web → verify it appears on mobile immediately
4. Dispatcher assigns job to engineer → verify mobile notification (if FCM is set up)
5. Engineer accepts job on mobile → verify web dashboard updates status in real-time
6. Engineer updates status through full lifecycle → verify each change reflects on web instantly
7. Engineer creates jobsheet from dispatched job → verify web shows "Completed" with linked jobsheet

### Authentication Testing

- Login on web → works
- Login on web + login on mobile simultaneously → both work (Firebase Auth supports multiple sessions)
- Logout on web → doesn't affect mobile session
- Engineer tries to access web portal → sees "use mobile app" message
- User with no company tries web portal → sees "join a company" message
- Session persistence → close browser, reopen → still logged in

### Performance Testing

- Dashboard load time with 50+ jobs
- Dashboard load time with 200+ jobs
- Real-time listener performance with frequent updates
- Initial Flutter web load time (target: < 5 seconds on decent connection)

---

## Notes for Claude Code

When implementing the web portal, keep these principles in mind:

1. **Never break the mobile app.** Every change must be gated behind `kIsWeb` or conditional imports. The mobile app must continue to work identically.

2. **Don't import `dart:io` on web.** This will crash the web build. Use conditional imports where needed.

3. **Don't initialise SQLite on web.** `DatabaseHelper` must be completely bypassed on web builds.

4. **Reuse existing services.** `DispatchService`, `CompanyService`, `AnalyticsService`, and all Firestore-based services work on web without modification.

5. **Reuse existing screens where possible.** Team management, company settings, and shared sites/customers screens should render on web with responsive layouts rather than being rebuilt from scratch.

6. **Follow the existing design language** — Deep Navy `#1E3A5F` primary, Coral `#F97316` accent, Google Fonts Inter. The web portal should feel like the same product.

7. **Test with `flutter run -d chrome`** throughout development. Don't wait until the end to test on web.

8. **The `FEATURES.md` and `CHANGELOG.md` files must be updated** to document the web portal, new screens, web-specific analytics events, and hosting configuration.

9. **GoRouter is recommended** for web navigation. It handles browser back/forward, deep links, and URL-based routing which are essential for a web app.

10. **The web portal is dispatcher/admin only.** Do not build engineer-facing features for web. Engineers use the mobile app.
