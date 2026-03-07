# FireThings — Feature Reference

FireThings is a Flutter app built for fire alarm engineers. It covers jobsheet creation, invoicing, PDF form certificates, and a suite of field tools — all backed by Firebase Auth and local SQLite storage. Targets Android, iOS, Windows, macOS, Linux, and web.

---

## Navigation

Four bottom tabs with swipe-gesture switching and animated transitions:

| Tab | Purpose |
|-----|---------|
| **Home** | Dashboard with stats and helpful tools grid |
| **Jobs** | Jobsheet management — creation, drafts, history |
| **Invoices** | Invoice management — creation, tracking, export |
| **Settings** | Profile, saved data, PDF design, app config |

Layout adapts by screen size:

- **Compact** (< 600 px) — bottom navigation bar
- **Medium** (600–840 px) — NavigationRail on the left
- **Expanded / Large** (840 px+) — extended NavigationRail with labels
- iOS / macOS uses CupertinoTabBar; Android uses Material NavigationBar

---

## Home Screen Dashboard

- **Greeting header** — time-based ("Good Morning / Afternoon / Evening") with the engineer's display name and an animated app icon.
- **Statistics cards** — tappable cards showing:
  - Completed jobsheets count
  - Job drafts count
  - Unpaid / outstanding invoices count
  - Invoice drafts count
- **Helpful Tools grid** — six tool tiles laid out in a responsive grid (see next section).

---

## Helpful Tools

### 1. BS 5839 Reference Guide

Searchable reference for the BS 5839-1 fire detection standard, organised into 11 categories:

1. System Categories (L1–L5, M, P1, P2)
2. Detectors (types and placement)
3. Detector Siting (specific guidance)
4. Sounders (output requirements)
5. Call Points (placement and function)
6. Cables & Wiring (specification)
7. Ancillary Equipment
8. Void Detection (ceiling / roof voids)
9. Testing & Maintenance (schedules)
10. Fire Detection Zones (layout)
11. False Alarm Management

Features: keyword search, category filter, expandable content cards.

### 2. DIP Switch Calculator

Visual 8-switch toggle interface for addressable device addressing.

- Real-time binary address calculation (0–255)
- Switch values: 1, 2, 4, 8, 16, 32, 64, 128
- Save / load favourite configurations by name
- Reset all switches

### 3. Timestamp Camera

Full camera app with live metadata overlay.

- **Photo capture** with watermarked timestamp, location, engineer name, and custom text
- **Video recording** with live overlay burned in via FFmpeg
- Pinch-to-zoom, tap-to-focus, flash control (auto / on / off), front / rear camera flip
- Multiple lens selection
- Configurable resolution in a settings panel
- Video processing screen with retry and "Save Without Overlay" fallback
- GPS location tracking (when available)
- Save to device gallery

### 4. Decibel Meter

Real-time sound level measurement.

- Current, minimum, maximum, and average dB readings
- Fast / slow refresh modes
- Calibration offset adjustment
- Start / stop / reset controls
- Visual gauge display
- Requires microphone permission

### 5. Detector Spacing Calculator

Calculates the number of detectors needed and their grid spacing for a room.

- Inputs: room length, width, height (metres); detector type; room type (open area or corridor)
- Detector types supported:
  - Point Smoke (radius 7.5 m, corridor 15 m, max ceiling 10.5 m)
  - Point Heat Grade 1 (radius 5.3 m, corridor 10.5 m, max ceiling 7.5 m)
  - Point Heat Grade 2 (radius 7.5 m, corridor 15 m, max ceiling 9 m)
- Outputs: detector count, X / Y grid spacing, wall offset distances, coverage per detector, design notes for ceiling height adjustments

### 6. Battery Load Tester

Calculates minimum battery capacity per BS 5839-1 Annex D / E.

- Inputs: battery capacity (Ah), standby current (A), alarm current (A)
- Formula: `Cmin = 1.25 × ((T1 × I1) + (D × I2 × T2))` where T1 = 24 h standby, D = 1.75 derating factor, T2 = 0.5 h alarm
- Colour-coded pass / fail result



## Jobsheets

### Creation

New jobsheets start from the Jobs hub. The engineer picks a **pre-built template**, a **custom template**, or a **PDF certificate form**.

Standard job form fields:

- Engineer name (pre-filled from account)
- Customer name
- Site address (with saved-sites picker)
- Job number
- System category (dropdown)
- Date
- Dynamic fields defined by the chosen template
- Notes section
- Defects list
- Engineer signature (touch capture)
- Customer signature (touch capture)

### Pre-built Templates

Six built-in templates covering common job types:

| Template | Fields |
|----------|--------|
| Battery Replacement | 13 — panel make, battery type, voltage testing, load test, charger test, next replacement, disposal method |
| Detector Replacement | 12 — location, zone, detector type, functional test, panel indication |
| Annual Inspection | 13 — zones, devices, visual inspection, battery condition, voltage, earth fault test, service due |
| Quarterly Test | 9 — call point tested, alarm activation, sounders / beacons, visual inspection, fault check |
| Panel Commissioning | 13 — panel serial, system category, zones, power / battery / charging tests, device testing, training |
| Fault Finding & Repair | 11 — fault reported, type, findings, cause, action taken, parts used, follow-up |

### Drafts

- Save any in-progress jobsheet as a draft
- Drafts screen lists all saved drafts with search / filter by customer or job number
- Resume editing, delete, or generate PDF from a draft

### History (Completed Jobsheets)

- Searchable list of all completed jobsheets
- Filter by customer name, job number, or site address
- View details, regenerate PDF, edit, or delete

### PDF Generation

- Generated via the `pdf` / Syncfusion PDF libraries
- Applies the user's PDF header, footer, and colour scheme settings
- Includes signatures, defects, and notes
- Share or email directly from the app

---

## Invoicing

### Creation

- Auto-incremented invoice number
- Customer name, address, and email (with saved-customers picker)
- Invoice date and due date (default 30 days)
- **Line items** — each with description, quantity, and unit price; calculated totals per item
- VAT toggle (adds 20 %)
- Notes section
- Payment details pulled from saved bank settings

### Statuses

| Status | Meaning |
|--------|---------|
| **Draft** | Work in progress, not yet sent |
| **Sent** | Delivered to customer, awaiting payment |
| **Paid** | Payment received |

### Invoice List

- Filter by status
- Edit draft or sent invoices
- Mark sent invoices as paid
- Delete drafts
- Generate and share PDF
- Bulk-export paid invoices

### Bank Details

Configured once in Settings and applied to every invoice:

- Bank name
- Account name
- Sort code
- Account number
- Payment terms text

---

## PDF Form Certificates

Access-controlled forms (whitelisted users only) that populate real PDF certificate templates.

### IQ Modification Certificate (1 page, 28 fields)

- Customer and job information (name, date, address, job number)
- Installer details and system category
- Extent of work and variations from standard
- Five compliance checkboxes (system tested per 46.4.2, as-fitted drawings updated, no false-alarm potential, third-party installation, subsequent visit required)
- Engineer certification (name, position, signature, date)
- Customer / representative certification (signature, name, position, date)

### IQ Minor Works & Call Out Certificate (1 page, 20 fields)

- Customer, date, job number, site address
- Call-out times (arrival, departure)
- Visit type checkboxes (remedial works, call out)
- System type checkboxes (fire alarm, emergency lighting, AOV / smoke vent, other)
- Description of work completed
- Parts used
- IQ representative and client representative signatures

### Form Interaction

- Fields are positioned on the PDF by percentage coordinates
- Signature capture via touch pad
- Date pickers and checkboxes
- Save as draft, preview PDF, email / share

---

## Custom Template Builder

Create reusable job templates from scratch.

- Set template name and description
- Add fields dynamically — supported types: text, number, multiline, dropdown, checkbox, date
- Configure each field: label, required / optional, default value, dropdown options
- **Section layout** — choose which PDF sections appear:
  - Job Information
  - Site Details
  - Work Carried Out (template-specific fields)
  - Notes
  - Defects
  - Compliance Statement
  - Signatures
- Saved templates appear alongside the pre-built templates when creating a new job
- Edit or delete saved templates at any time

---

## Saved Sites & Saved Customers

### Saved Customers

- Fields: customer name, address, email, notes
- Add, edit, delete
- Search / filter by name or address
- Quick-select dropdown in invoice creation
- Avatar badge showing the customer's initial

### Saved Sites

- Fields: site name, address, notes
- Add, edit, delete
- Search / filter by site name or address
- Quick-select in jobsheet creation for fast address entry

---

## PDF Design

Three design screens accessible from Settings — changes apply to both jobsheet and invoice PDFs.

### Header Designer

- **Logo** — zone (left, centre, none) and size (small 40 px, medium 60 px, large 80 px); upload a custom company logo
- **Left column** — company name (bold 18 pt), tagline (bold 10 pt), address (9 pt), phone (9 pt)
- **Centre column** — custom configurable text lines

### Footer Designer

- Left and centre column text lines
- Configurable font sizes and bold formatting
- Company details line

### Colour Scheme

- Primary, accent, text, and background colours
- Predefined themes or fully custom colour picker
- Applied consistently across all generated PDFs

---

## Settings & Account Management

### Profile

- Display name (editable)
- Email (editable)
- Password change (with verification)
- Logout

### Data Management

- Saved Customers
- Saved Sites
- Manage Permissions (grant / deny access to PDF certificates)

### PDF Design

- Header Designer
- Footer Designer
- Colour Scheme

### Invoice Configuration

- Bank Details (bank name, account name, sort code, account number, payment terms)
- Last invoice number tracking with auto-increment

### Notifications

- Draft jobsheet reminders (toggle)
- Overdue invoice reminders (toggle)
- Background checks via Workmanager at 12-hour intervals

### Cloud Sync

- **Firestore cloud backup** — SQLite remains the primary store; Firestore acts as a cloud backup synced automatically on every create/update/delete
- **"Sync Now" button** in Settings — triggers a full bidirectional sync on demand
- **Last sync timestamp** — displayed in Settings so the user knows when data was last synced
- **Offline-first** — app works fully offline; Firestore SDK queues writes and syncs when connectivity returns

### Send Feedback

- Opens the native email client with a pre-filled subject line, recipient, and device info footer (app version, OS, device model)
- Recipient: cscott93@hotmail.co.uk

### Privacy Policy

- In-app privacy policy screen accessible from Settings
- Covers: data collected, purpose, storage location, retention, access rights, user rights (access/export/deletion), third-party services (Firebase Auth, Firestore, Crashlytics, Analytics), and contact info

### Account Deletion

- GDPR-compliant full account deletion from Settings
- Deletes all Firestore cloud data (7 subcollections batch-deleted), local SQLite data, SharedPreferences, branding assets, and the Firebase Auth account
- Requires re-authentication before proceeding

### App Information

- Version and build number (dynamic via `PackageInfo`)

---

## Platform & Technical Notes

- **Multi-platform** — Android, iOS, Windows, macOS, Linux, web
- **Offline-first** — all data stored locally in SQLite with Firestore cloud sync backup; works fully offline
- **Dark mode** — full light / dark theme support following system preference
- **Responsive** — four breakpoints (compact, medium, expanded, large) with adaptive layouts
- **Adaptive UI** — Cupertino widgets on Apple platforms, Material on Android / desktop
- **State management** — StatefulWidget + setState throughout; ValueNotifier for isolated rebuilds (e.g. camera zoom)
- **Typography** — Google Fonts Inter; custom colour palette (Deep Navy `#1E3A5F` primary, Coral `#F97316` accent)
- **Animations** — Flutter Animate package; entrance animations, skeleton loaders, smooth transitions
- **PDF generation** — Syncfusion PDF + `pdf` package; custom watermarking, form-field population, signature overlay
- **Camera / media** — Camera package, FFmpeg video processing, image picker, gallery save
- **Location** — geocoding with throttled GPS tracking
- **Background tasks** — Workmanager for periodic notification checks
- **CI / CD** — Codemagic configuration for iOS TestFlight and Android APK workflows

---

## Backend & Infrastructure

### Firebase Crashlytics

- Crash and error reporting via Firebase Crashlytics
- `runZonedGuarded` wraps the entire app bootstrap to catch async errors
- `FlutterError.onError` captures Flutter framework errors
- `PlatformDispatcher.instance.onError` captures platform-level errors

### Firebase Analytics

- 22 custom events tracking feature usage across the app (jobsheet lifecycle, invoice lifecycle, tool opens, PDF forms, photo/video capture, auth)
- Automatic screen tracking via `FirebaseAnalyticsObserver` in `MaterialApp.navigatorObservers`

### Firebase Remote Config

- 10 server-side feature flags for toggling tools and features without an app update
- Flags: timestamp camera, decibel meter, DIP switch calculator, detector spacing, battery load tester, BS 5839 reference, invoicing, PDF forms, cloud sync, custom templates
- All flags default to enabled; controlled from the Firebase Console
- 12-hour fetch interval in release, 1-minute in debug

### Firestore Cloud Sync

- **Architecture** — SQLite primary, Firestore backup; offline-first with Firestore SDK handling offline queuing
- **Bidirectional merge** on login — pulls remote changes and pushes local changes
- **Fire-and-forget sync** on every CRUD operation for near-real-time backup
- **Conflict resolution** — last-write-wins via `lastModifiedAt` timestamps on all synced models
- **Synced data** — jobsheets, invoices, saved customers, saved sites, job templates, filled templates, and PDF config (header, footer, colour scheme)
- **Firestore persistence** enabled with unlimited cache size

### Firestore Security Rules

- Per-user data isolation: all data stored under `users/{uid}/` in Firestore
- Authentication required for all reads and writes
- Users can only access their own data (`request.auth.uid == userId`)
