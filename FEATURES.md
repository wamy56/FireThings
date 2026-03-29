# FireThings — Complete Feature Reference

FireThings is a cross-platform Flutter application built specifically for fire alarm engineers. It combines jobsheet creation, invoicing, PDF certificate generation, asset register management, team job dispatch, and a suite of field tools into a single offline-first app. Backed by Firebase Auth with local SQLite storage (personal data) and Firestore (company/team data). Targets Android, iOS, Windows, macOS, Linux, and web.

This document is a comprehensive reference of every feature in the app as of March 2026. It is intended to be self-contained — suitable for handoff to another person or AI assistant to understand the full scope of the product.

---

## Table of Contents

1. [Navigation](#navigation)
2. [Home Screen Dashboard](#home-screen-dashboard)
3. [Helpful Tools](#helpful-tools)
4. [Jobsheets](#jobsheets)
5. [Invoicing](#invoicing)
6. [PDF Form Certificates](#pdf-form-certificates)
7. [Custom Template Builder](#custom-template-builder)
8. [Saved Sites & Customers (Personal)](#saved-sites--customers-personal)
9. [PDF Design & Branding](#pdf-design--branding)
10. [Dispatch System](#dispatch-system)
11. [Asset Register & Floor Plans](#asset-register--floor-plans)
12. [Web Portal](#web-portal)
13. [Settings & Account Management](#settings--account-management)
14. [Backend & Infrastructure](#backend--infrastructure)
15. [Platform & Technical Notes](#platform--technical-notes)
16. [Future Enhancements](#future-enhancements)

---

## Navigation

### Mobile (4 or 5 tabs)

| Tab | Purpose |
|-----|---------|
| **Home** | Dashboard with Sites & Assets card, dispatch card, and helpful tools grid |
| **Jobs** | Jobsheet management — creation, drafts, history |
| **Invoices** | Invoice management — creation, tracking, export |
| **Dispatch** | *(Conditional — only shown when `dispatch_enabled` flag is true AND user belongs to a company)* Job dispatch for dispatchers/admins or assigned jobs for engineers |
| **Settings** | Profile, saved data, PDF design, company management, app config |

Layout adapts by screen size:

- **Compact** (< 600 px) — bottom navigation bar
- **Medium** (600–840 px) — NavigationRail on the left
- **Expanded / Large** (840 px+) — extended NavigationRail with labels
- iOS / macOS uses CupertinoTabBar; Android uses Material NavigationBar
- Swipe-gesture switching between tabs with animated transitions

### Web

- GoRouter-based SPA routing with URL-based deep linking
- Sidebar navigation (Dashboard, Schedule, Team, Sites, Settings, Asset Register)
- Top bar with company name, user profile, and logout
- Auth redirect handling (login required, company/dispatcher role required)

---

## Home Screen Dashboard

- **Greeting header** — time-based ("Good Morning / Afternoon / Evening") with the engineer's display name and an animated app icon
- **Sites & Assets card** — full-width tappable card showing saved site count, navigates to Saved Sites screen. Shown when `asset_register_enabled` flag is true.
- **Dispatched Jobs card** — full-width tappable card showing pending dispatch job count, navigates to Dispatch tab. Shown when the user has pending dispatched jobs.
- **Helpful Tools grid** — up to six tool tiles in a responsive grid (2 columns on compact, 3 on wide screens). Each tool is individually controlled by a remote config feature flag.
- **Pull-to-refresh** — reloads dashboard data
- **Skeleton loader** — shimmer placeholder shown while data loads

---

## Helpful Tools

All tools are gated behind a disclaimer system (`ToolsDisclaimerGate`) for safety-critical tools (decibel meter, battery load test, BS 5839, detector spacing) that requires user acknowledgement before first use. All tools reference **BS 5839-1:2025**.

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
Remote config flag: `bs5839_reference_enabled`

### 2. DIP Switch Calculator

Visual 8-switch toggle interface for addressable device addressing.

- Real-time binary address calculation (0–255)
- Switch values: 1, 2, 4, 8, 16, 32, 64, 128
- Save / load favourite configurations by name
- Reset all switches

Remote config flag: `dip_switch_calculator_enabled`

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

Remote config flag: `timestamp_camera_enabled`

### 4. Decibel Meter

Real-time sound level measurement.

- Current, minimum, maximum, and average dB readings
- Fast / slow refresh modes
- Calibration offset adjustment
- Start / stop / reset controls
- Visual gauge display
- Requires microphone permission

Remote config flag: `decibel_meter_enabled`

### 5. Detector Spacing Calculator

Calculates the number of detectors needed and their grid spacing for a room.

- Inputs: room length, width, height (metres); detector type; room type (open area or corridor)
- Detector types supported:
  - Point Smoke (radius 7.5 m, corridor 15 m, max ceiling 10.5 m)
  - Point Heat Grade 1 (radius 5.3 m, corridor 10.5 m, max ceiling 7.5 m)
  - Point Heat Grade 2 (radius 7.5 m, corridor 15 m, max ceiling 9 m)
- Outputs: detector count, X / Y grid spacing, wall offset distances, coverage per detector, design notes for ceiling height adjustments

Remote config flag: `detector_spacing_enabled`

### 6. Battery Load Tester

Calculates minimum battery capacity per BS 5839-1 Annex D / E.

- Inputs: battery capacity (Ah), standby current (A), alarm current (A)
- Formula: `Cmin = 1.25 * ((T1 * I1) + (D * I2 * T2))` where T1 = 24 h standby, D = 1.75 derating factor, T2 = 0.5 h alarm
- Colour-coded pass / fail result

Remote config flag: `battery_load_tester_enabled`

---

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
- **Site Assets section** — "Test Assets" button opens the asset register for the linked site, allowing the engineer to run inspection checklists during the job. Test results are tagged with the jobsheet ID and auto-summarised in the generated PDF.

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
- Draft reminder notifications (12-hour background checks)

### History (Completed Jobsheets)

- Searchable list of all completed jobsheets
- Filter by customer name, job number, or site address
- View details, regenerate PDF, edit, or delete

### PDF Generation

- Generated via the `pdf` / Syncfusion PDF libraries
- Applies the user's PDF header, footer, and colour scheme settings
- Includes signatures, defects, and notes
- **Asset Inspection Summary** — auto-generated table with columns: Ref, Type, Location, Zone, Result, Defects. Summary line: "12 assets tested: 11 pass, 1 fail. 1 defect logged."
- Share or email directly from the app

### Dispatch Integration

When a jobsheet is created from a dispatched job, it pre-fills customer, site, job number, system category, and other fields from the dispatch data. The completed jobsheet is linked back to the dispatched job.

---

## Invoicing

### Creation

- Auto-incremented invoice number
- Customer name, address, and email (with saved-customers picker)
- Invoice date and due date (default 30 days)
- **Line items** — each with description, quantity, and unit price; calculated totals per item
- VAT toggle (adds 20%)
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
- Overdue invoice reminders (12-hour background checks)

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

Remote config flag: `pdf_forms_enabled`

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

Remote config flag: `custom_templates_enabled`

---

## Saved Sites & Customers (Personal)

These are the engineer's personal saved data, separate from company-level shared sites/customers (see Dispatch System).

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
- **Asset register integration** — tap a saved site to view its asset register and floor plans

---

## PDF Design & Branding

### Personal PDF Design

Three design screens accessible from Settings — changes apply to the engineer's own jobsheet and invoice PDFs.

#### Header Designer

- **Logo** — zone (left, centre, none) and size (small 40 px, medium 60 px, large 80 px); upload a custom company logo
- **Left column** — company name (bold 18 pt), tagline (bold 10 pt), address (9 pt), phone (9 pt)
- **Centre column** — custom configurable text lines

#### Footer Designer

- Left and centre column text lines
- Configurable font sizes and bold formatting
- Company details line

#### Colour Scheme

- Primary, accent, text, and background colours
- Predefined colour themes or fully custom colour picker
- Applied consistently across all generated PDFs

### Company-Level PDF Branding

When a user belongs to a company (dispatch system), company-level PDF designs override personal designs for dispatched job documents:

- Separate header, footer, and colour scheme stored per company in Firestore
- `CompanyPdfConfigService` provides `getEffectiveHeaderConfig` / `getEffectiveFooterConfig` / `getEffectiveColourScheme` with company-first, personal-fallback logic
- Company logo upload per document type (jobsheet / invoice)
- Managed from Settings → Company PDF Design (dispatchers/admins only)

---

## Dispatch System

**Status:** Feature complete, hidden behind `dispatch_enabled` remote config flag (default: false). Targeted to specific testers via Firebase Console conditions using the `dispatch_tester` analytics user property.

### Architecture & Roles

- **Data ownership:** Company data stored in Firestore under `companies/{companyId}/`
- **Three roles:** Admin (full access), Dispatcher (create/assign jobs, manage team), Engineer (view assigned jobs, update status)
- **Job lifecycle:** Created → Assigned → Accepted → En Route → On Site → Completed (or Declined)
- **Key principle:** The dispatch system is an addition to FireThings, not a replacement — all solo-engineer functionality continues to work independently

### Company Management

#### Create or Join a Company

- **Create:** Company name, address, phone, email — generates a unique invite code (format: FT-XXXXXX)
- **Join:** Enter an invite code to join an existing company
- Maximum members controlled by `dispatch_max_members` remote config flag (default: 25)

#### Team Management

- List all company members with role badges (colour-coded: Admin = orange, Dispatcher = blue, Engineer = green)
- Search members by name or email
- Change member roles (Admin can change any role)
- Remove members (with confirmation — they lose access to dispatched jobs)
- Regenerate invite codes

#### Shared Company Sites

- Company-level site database accessible to all team members
- Fields: name, address, notes
- Add, edit, delete (dispatchers/admins only)
- Search / filter
- Used for quick-select when creating dispatched jobs
- **Asset register integration** — each company site can have its own asset register and floor plans

#### Shared Company Customers

- Company-level customer database accessible to all team members
- Fields: name, address, email, phone, notes
- Add, edit, delete (dispatchers/admins only)
- Search / filter
- Used for quick-select when creating dispatched jobs

### Dispatcher Screens (Office)

#### Dispatch Dashboard

- Overview of all company jobs
- Filter by status, priority, engineer, date range
- Search by job number, site name, engineer name
- **Compliance snapshot** — asset register integration showing pass/fail/untested counts per job site
- Quick-view job cards with status badge, priority indicator, and assigned engineer
- FAB to create new job

#### Create Job Screen

- **Job details:** Title, description, job number, job type (dropdown matching pre-built templates)
- **Site:** Quick-select from company sites with address, parking notes, access notes, site notes
- **Contact:** Name, phone, email
- **Assignment:** Assign to specific engineer (dropdown from team members), scheduled date and time, estimated duration
- **System info:** System category (L1–L5, M, P1, P2), panel make and location, number of zones
- **Priority:** Normal, Urgent, Emergency
- **Compliance summary** — when a site is selected, shows asset counts, pass/fail/untested breakdown, and lifecycle warnings
- Save to create and assign, or save as unassigned

#### Dispatched Job Detail (Dispatcher View)

- Full job details with edit capability
- Assigned engineer info with call/email quick actions
- **Site Assets section** — total asset count, compliance summary, lifecycle warnings, "View Floor Plans" and "View Asset Register" buttons
- Job history and status updates
- Linked jobsheet view (if engineer has completed one)
- Asset inspection summary (auto-generated from jobsheet if assets were tested)

### Engineer Screens (Field)

#### Engineer Jobs Screen

- List of jobs assigned to the current engineer
- Filter by status (Assigned, Accepted, En Route, On Site, Completed)
- Search by job number or site name
- Quick actions: view details, get directions, accept/decline

#### Engineer Job Detail

- Full job information (read-only except for status)
- **Actions:**
  - Accept job (Assigned → Accepted)
  - Decline job (with reason: Can't get there, Hardware issue, Tool needed, Not trained, Other)
  - Get directions (opens device maps with coordinates)
  - Call contact (phone tap)
  - Create jobsheet from job (pre-fills with dispatch data)
  - Update status (Accepted → En Route → On Site → Completed)
- **Site Assets section** — asset count, compliance summary, "View Asset Register" and "View Floor Plans" buttons
- **Linked jobsheet** — view completed jobsheet PDF

### Push Notifications (FCM)

- **Cloud Functions** (`functions/index.js`, Node.js 20, us-central1):
  - `onJobAssigned` — when a job is assigned, the engineer receives a push notification ("New Job Assigned — [Title] — [Site Name]")
  - `onJobStatusChanged` — when an engineer updates job status, the dispatcher receives a push notification
- FCM token stored per company member in Firestore
- Notification data payload includes jobId, companyId, type
- Android notification channel: `firethings_dispatch`
- Foreground notification re-fire via `NotificationService.showDispatchNotification()`

### Remote Config Flags

- `dispatch_enabled` (default: false) — master toggle for entire dispatch system
- `dispatch_max_members` (default: 25) — maximum company members
- `dispatch_notifications_enabled` (default: true) — toggle push notifications

### Analytics Events (13 dispatch-specific)

`company_created`, `company_joined`, `dispatch_job_created`, `dispatch_job_assigned`, `dispatch_job_accepted`, `dispatch_job_declined`, `dispatch_job_status_changed`, `dispatch_job_completed`, `dispatch_jobsheet_created`, `dispatch_directions_opened`, `dispatch_contact_called`

---

## Asset Register & Floor Plans

**Status:** Feature complete (9 phases), hidden behind `asset_register_enabled` remote config flag (default: false).

### 12 Built-In Asset Types

| Type | Colour | Lifespan | Variants |
|------|--------|----------|----------|
| **Fire Alarm Panel** | Navy #1E3A5F | 15 years | Conventional, Addressable, Analogue Addressable, Wireless |
| **Smoke Detector** | Blue #3B82F6 | 10 years | Optical, Ionisation, Multi-sensor, Beam, Aspirating |
| **Heat Detector** | Red #EF4444 | 10 years | Fixed Temperature, Rate of Rise, Combined |
| **Call Point (Manual)** | Bright Red #DC2626 | 15 years | Conventional, Addressable, Resettable, Break Glass |
| **Sounder / Beacon** | Orange #F97316 | 15 years | Sounder, Beacon, Combined, Voice Alarm Speaker |
| **Fire Extinguisher** | Green #059669 | 5y discharge / 20y replace | CO2, Dry Powder, AFFF Foam, Water, Wet Chemical |
| **Emergency Lighting** | Yellow #FBBF24 | 10y luminaire / 4y battery | Maintained, Non-maintained, Sustained, Combined |
| **Fire Door** | Purple #8B5CF6 | Maintenance-based | FD30, FD60, FD90, FD120 |
| **AOV / Smoke Vent** | Cyan #06B6D4 | 15 years | Natural (AOV), Mechanical, Smoke Shaft |
| **Sprinkler Head** | Sky Blue #0EA5E9 | 50y standard / 20y fast response | Pendant, Upright, Sidewall, Concealed |
| **Fire Blanket** | Teal #14B8A6 | 7 years | Light Duty (kitchen), Heavy Duty (industrial) |
| **Other / Custom** | Configurable | User-defined | User-defined |

Each type ships with a default inspection checklist (e.g. smoke detector: visual inspection, functional test, panel indication, sounder/beacon activation, sensitivity check). Checklists are fully customisable per company or per user.

### Site Asset Register Screen

- **Header:** Site name, total assets, compliance summary (X pass, Y fail, Z untested)
- **Search:** By reference, barcode, make, model
- **Filter chips:** By asset type, compliance status, floor, zone
- **Asset cards:** Type icon coloured by compliance status, reference, type/variant, location, last service date/result, lifecycle warning badge
- **Action cards strip** — horizontally scrollable labeled cards:
  - Floor Plans (blue) — view/manage floor plans
  - Batch Test (green, mobile only) — sequential testing workflow
  - Scan Barcode (purple, mobile only) — barcode scanner
  - Report (orange) — generate compliance report PDF
  - Manage Types (grey) — asset type configuration
- FAB to add a new asset

### Asset Detail Screen

- **Identity section:** Type, variant, make, model, serial number, reference, barcode, photo
- **Location section:** Floor plan pin preview, zone, location description
- **Compliance section:** Status badge (pass/fail/untested/decommissioned), last service date and engineer, next due date, lifecycle progress bar, warranty status
- **Service History:** Chronological list of all inspections, tappable for full detail
- **Actions:** Test This Asset, Edit, Scan Barcode, View on Floor Plan, Decommission

### Add / Edit Asset Screen

- Asset type dropdown (with auto-suggested reference sequence, e.g. SD-001, SD-002)
- Variant dropdown (populated from selected type)
- Make (autocomplete from existing assets), Model, Serial number
- Reference (auto-fill updates when type changes, manual edits override)
- Barcode (text entry or scan)
- Zone, Location description
- Install date, Warranty expiry, Expected lifespan (pre-filled from type default)
- Photo upload (Firebase Storage)
- Notes
- After save: option to place on floor plan

### Floor Plans

#### Floor Plan List

- All floor plans for a site, ordered by sort order
- Each shows thumbnail, name, asset count, compliance dots (green/red/grey)
- Actions: tap to open, add new, reorder, edit name, delete

#### Upload Floor Plan

- Choose source: take photo, pick from gallery, upload file (JPG, PNG, GIF, WebP, PDF)
- **PDF support:** PDF files are rasterised to PNG via `Printing.raster()` for pin placement
- Enter floor plan name
- Image uploaded to Firebase Storage with compression (max 2048px longest edge, JPEG quality 80)

#### Interactive Floor Plan Viewer

- `InteractiveViewer` with pan and pinch-to-zoom
- Asset pins overlaid as BS 5839 schematic symbols, coloured by compliance:
  - Green = pass, Red = fail, Grey = untested, Faded = decommissioned
- **Pin labels** — optional reference text (e.g. "SD-001") displayed above each pin in a white pill. Toggle on/off via app bar icon. Persists per floor plan. Labels scale with pin size.
- **Pin size slider** — adjustable from 0.5x to 2.5x in 10% increments
- **Tap pin** — bottom sheet with asset summary + actions (View Details, Test Now, Log Defect, View History)
- **Placement mode** — enter to place new assets or reposition existing ones:
  - Mobile: long-press and drag
  - Web: click and drag with `GestureDetector` pan tracking (delta divided by zoom scale for correct movement at any zoom level)
- Pin positions stored as percentage coordinates (0.0–1.0) for responsive scaling across screen sizes

### Inspection & Testing

#### Inspection Checklist Screen

- Asset identity displayed at top
- Checklist items with configurable result types:
  - `pass_fail`: Pass / Fail buttons
  - `text`: Text field
  - `number`: Number field
  - `yes_no`: Yes / No buttons
  - Optional note per item
- **Overall result:** Auto-calculated (any required fail = overall fail)
- **Defect section** (on failure):
  - Severity: minor, major, critical
  - Defect note
  - Action: rectified on site, quote required, replacement needed
  - Defect photos (multiple, uploaded to Firebase Storage)

#### What Happens on Save

1. ServiceRecord created in service history (immutable audit trail)
2. Asset `complianceStatus` updated (pass/fail)
3. Asset `lastServiceDate` / `lastServiceBy` updated
4. `nextServiceDue` calculated
5. Defect photos uploaded to Firebase Storage
6. If during jobsheet: result added to job session for PDF summary
7. Floor plan pin colour updates immediately
8. Analytics event logged

#### Batch Testing

- "Test All on This Floor" workflow
- Sequential testing: shows first untested asset's checklist, moves to next on save
- Progress indicator (e.g. "3 of 12")
- Skip button for assets that can't be tested
- Summary at end

### Barcode / QR Scanning

- **Package:** `mobile_scanner` (supports QR codes, Code128, Code39, EAN)
- **Workflow:** Scan → search for matching barcode → if found, navigate to asset detail; if not found, prompt to create new asset with barcode pre-filled
- **Assign barcodes:** During asset creation (scan or type) or from asset detail
- **Web:** No camera scanning; barcodes entered via text field
- Remote config flag: `barcode_scanning_enabled`

### Lifecycle Tracking

- **Calculations:** Age from install date, remaining years from expected lifespan, end-of-life approaching when < 1 year remaining, warranty active/expired
- **Visual indicators:** Progress bar (green < 70%, amber 70–90%, red > 90%), warning text, warranty badge
- **Filters:** "Approaching end of life" filter in asset register
- **Dispatch integration:** Warning badge on dispatch dashboard when site has lifecycle alerts
- **Decommissioning:** Reason dropdown (End of Life, Replaced, Damaged, Removed, Other), date recorded, pin becomes faded, asset excluded from active compliance counts but retained for audit trail
- Remote config flag: `lifecycle_tracking_enabled`

### Compliance Report PDF

Auto-generated site compliance report with 7 sections:

1. **Cover page** — site name, address, date, company, engineer
2. **Compliance summary** — totals, pass/fail/untested breakdown
3. **Floor plan pages** — one per level, with asset pins and legend. When labels are enabled, reference text is drawn above each pin.
4. **Asset register table** — all assets with status, last service, lifecycle info
5. **Defect summary** — failed assets with severity, description, action
6. **Lifecycle alerts** — assets approaching or past end of life
7. **Service history summary** — recent service activity overview

Generated via gather-then-compute pattern (data gathered on main thread, PDF built in isolate for performance). Share / print / email.

Remote config flag: `compliance_report_enabled`

### Asset Type Configuration

- **Built-in types:** 12 types shipped with the app (read-only core fields, but checklists are editable)
- **Custom types:** Create entirely new asset types with custom icon, colour, variants, and checklist
- **Company-level overrides:** Stored in `companies/{companyId}/asset_type_config/{typeId}`
- **Solo user overrides:** Stored in `users/{uid}/asset_type_config/{typeId}`
- **Permissions:** Admins always have write access; engineers can edit if `canManageAssetTypes` permission is granted on their company member record

### Jobsheet Integration

- **During job:** "Site Assets" section in job form with "Test Assets" button
- Opens floor plan / asset list for the linked site
- Test results tagged with jobsheet ID
- In-memory session tracks tested assets
- **In PDF:** Auto-generated "Asset Inspection Summary" table (Ref, Type, Location, Zone, Result, Defects) with summary line

### Remote Config Flags

- `asset_register_enabled` (default: false) — master toggle
- `barcode_scanning_enabled` (default: false) — barcode scanner
- `lifecycle_tracking_enabled` (default: false) — lifecycle tracking and decommissioning
- `compliance_report_enabled` (default: false) — compliance report PDF generation

### Analytics Events (14 asset-specific)

`asset_created`, `asset_edited`, `asset_deleted`, `asset_tested`, `batch_testing_completed`, `asset_decommissioned`, `floor_plan_uploaded`, `floor_plan_viewed`, `floor_plan_pin_placed`, `barcode_scan`, `asset_register_viewed`, `dispatch_compliance_viewed`, `compliance_report_generated`, `asset_type_created`, `asset_type_checklist_modified`

---

## Web Portal

**Status:** Feature complete, deployed to Firebase Hosting. Designed as a dispatcher dashboard for office workers — engineers use mobile only.

### Architecture

- **Single Flutter codebase** with `kIsWeb` platform conditionals
- **Shared services** — same models, Firestore queries, analytics service
- **Separate UI layer** — desktop-optimised screens in `lib/screens/web/`
- **Routing:** GoRouter for proper URL-based SPA navigation (mobile uses `AuthWrapper` navigator)
- **Entry point:** `main.dart` routes to `WebShell` (web) or `MainNavigationScreen` (mobile)

### Web Shell Layout

- **Sidebar navigation:** Dashboard (Jobs), Schedule, Team Management, Sites, Settings, Asset Register (conditional)
- **Top bar:** Company name, user profile, logout
- **Main content area:** Dynamic per route
- **Wide-screen layout:** List and form screens constrained to 750px max width using `Center` + `ConstrainedBox(maxWidth: 750)` pattern

### Authentication

- Web-specific styled login page
- Email / password entry
- Redirects to `/jobs` on success
- Redirects to `/access-denied` if user has no company or is not a dispatcher/admin

### Dispatcher Dashboard

- Overview cards: total jobs, in progress, completed, pending assignments
- Filterable and searchable job list/table
- Job detail panel with side-by-side viewing and editing
- Compliance integration: asset register summary per job
- Search / filter by status, priority, engineer, date
- Full-text search (job number, site name, contact)
- Bulk actions: select multiple jobs to assign to an engineer
- Print job details or entire schedule

### Job Creation & Editing (Web)

- Same form as mobile with desktop-optimised layout
- Larger input fields, inline validation
- Compliance summary for selected site

### Schedule / Calendar View

- Calendar/board view of scheduled jobs
- Colour-coded by engineer or priority
- Click to open job detail panel

### Company Management (Web)

- Team Management: invite, manage roles, remove members
- Sites: add / edit / delete company sites
- Customers: manage customer database
- PDF Design: company branding settings
- Same screens as mobile, desktop-width layout with max-width constraints

### Asset Register & Floor Plans (Web)

- Full asset register functionality on web
- Add / edit / delete assets from desktop
- Upload floor plans (including PDF files)
- **Place and move pins with mouse** — ideal for office-based setup with printed drawings. `GestureDetector` pan tracking replaces `Draggable` to avoid `InteractiveViewer` gesture conflicts. Pan delta divided by zoom scale for correct movement at any zoom level.
- Click pins for details, create assets directly from floor plan
- `Image.network` with `webHtmlElementStrategy: WebHtmlElementStrategy.prefer` bypasses CORS for Firebase Storage images. Mobile keeps `CachedNetworkImage` for offline caching.

### Web Push Notifications

- Real-time job status updates via `WebNotificationService`
- Notification feed in top bar with badge count for unread
- Click notification to navigate to job

### Web Routes

| Route | Screen |
|-------|--------|
| `/login` | Web login |
| `/jobs` | Dispatcher dashboard |
| `/jobs/create` | Create job |
| `/jobs/:id` | Job detail |
| `/schedule` | Calendar/board view |
| `/team` | Team management |
| `/sites` | Company sites |
| `/sites/:siteId/assets` | Asset register for site |
| `/sites/:siteId/floor-plans` | Floor plans for site |
| `/access-denied` | Access denied |

### Analytics Events (12 web-specific)

`web_login`, `web_dashboard_viewed`, `web_job_created`, `web_job_edited`, `web_job_assigned`, `web_job_detail_viewed`, `web_schedule_viewed`, `web_bulk_assign`, `web_search_used`, `web_print_used`, `web_asset_register_viewed`, `web_floor_plan_viewed`

---

## Settings & Account Management

### Profile

- Display name (editable)
- Email (editable)
- Password change (with re-authentication)
- Logout

### Data Management

- Saved Customers
- Saved Sites
- Manage Permissions (grant / deny access to PDF certificates)

### PDF Design

- Header Designer
- Footer Designer
- Colour Scheme
- Company Logo upload (per document type: jobsheet / invoice)

### Company Management (when user belongs to a company)

- Team Management
- Shared Sites
- Shared Customers
- Company PDF Design

### Invoice Configuration

- Bank Details (bank name, account name, sort code, account number, payment terms)
- Last invoice number tracking with auto-increment

### Notifications

- Draft jobsheet reminders (toggle)
- Overdue invoice reminders (toggle)
- Background checks via Workmanager at 12-hour intervals
- Dispatch push notifications (via FCM when in a company)

### Cloud Sync

- **Firestore cloud backup** — SQLite remains the primary store; Firestore acts as a cloud backup synced automatically on every create/update/delete
- **"Sync Now" button** — triggers a full bidirectional sync on demand
- **Last sync timestamp** — displayed in Settings
- **Offline-first** — app works fully offline; Firestore SDK queues writes and syncs when connectivity returns

Remote config flag: `cloud_sync_enabled`

### Send Feedback

- Opens native email client with pre-filled subject line, recipient (cscott93@hotmail.co.uk), and device info footer (app version, OS, device model)

### Privacy Policy

- In-app privacy policy screen accessible from Settings
- 8 sections: data collected, purpose, storage location, retention, access rights, user rights (access/export/deletion), third-party services (Firebase Auth, Firestore, Crashlytics, Analytics), contact info
- ICO registration number included

### Account Deletion

- GDPR-compliant full account deletion from Settings
- Deletes all Firestore cloud data (7 subcollections batch-deleted), local SQLite data, SharedPreferences, branding assets, and the Firebase Auth account
- Requires re-authentication before proceeding

### App Information

- Version and build number (dynamic via `PackageInfo`)

---

## Backend & Infrastructure

### Firebase Crashlytics

- Crash and error reporting via Firebase Crashlytics
- `runZonedGuarded` wraps the entire app bootstrap to catch async errors
- `FlutterError.onError` captures Flutter framework errors
- `PlatformDispatcher.instance.onError` captures platform-level errors

### Firebase Analytics (61 events)

- 61 custom events across all features:
  - **Templates:** 2 events (template_selected, template_started)
  - **Tools:** 1 event (tool_opened)
  - **Jobsheets:** 5 events (started, saved_draft, completed, pdf_generated, pdf_shared)
  - **Invoices:** 4 events (created, saved_draft, sent, marked_paid)
  - **Customers & Sites:** 4 events (customer_saved, customer_selected, site_saved, site_selected)
  - **PDF Forms:** 3 events (opened, saved_draft, previewed)
  - **Camera:** 3 events (photo_captured, video_recording_started, video_recording_completed)
  - **Auth:** 2 events (login, signup)
  - **Dispatch:** 13 events (company_created, company_joined, job lifecycle, directions, contact)
  - **Web:** 12 events (login, dashboard, job CRUD, schedule, bulk assign, search, print, assets, floor plans)
  - **Asset Register:** 14 events (asset CRUD, testing, batch, decommission, floor plans, barcode, compliance report, type config)
- Automatic screen tracking via `FirebaseAnalyticsObserver`

### Firebase Remote Config (18 flags)

| Flag | Default | Purpose |
|------|---------|---------|
| `timestamp_camera_enabled` | true | Timestamp Camera tool |
| `decibel_meter_enabled` | true | Decibel Meter tool |
| `dip_switch_calculator_enabled` | true | DIP Switch Calculator tool |
| `detector_spacing_enabled` | true | Detector Spacing Calculator tool |
| `battery_load_tester_enabled` | true | Battery Load Tester tool |
| `bs5839_reference_enabled` | true | BS 5839 Reference Guide |
| `invoicing_enabled` | true | Invoicing feature |
| `pdf_forms_enabled` | true | PDF Form Certificates |
| `cloud_sync_enabled` | true | Firestore cloud sync |
| `custom_templates_enabled` | true | Custom Template Builder |
| `standards_data_version` | '08/03/2026' | BS 5839 data version string |
| `dispatch_enabled` | false | Entire dispatch system |
| `dispatch_max_members` | 25 | Maximum company members |
| `dispatch_notifications_enabled` | true | Dispatch push notifications |
| `asset_register_enabled` | false | Entire asset register |
| `barcode_scanning_enabled` | false | Barcode/QR scanning |
| `lifecycle_tracking_enabled` | false | Asset lifecycle tracking |
| `compliance_report_enabled` | false | Compliance report PDF |

12-hour fetch interval in release, 1-minute in debug. Controlled from Firebase Console. Tester targeting via `dispatch_tester` analytics user property.

### Firestore Cloud Sync

- **Architecture:** SQLite primary (solo engineers), Firestore backup — offline-first with Firestore SDK handling offline queuing
- **Bidirectional merge** on login — pulls remote changes and pushes local changes
- **Fire-and-forget sync** on every CRUD operation for near-real-time backup
- **Conflict resolution:** Last-write-wins via `lastModifiedAt` timestamps on all synced models
- **Synced data:** Jobsheets, invoices, saved customers, saved sites, job templates, filled templates, PDF config (header, footer, colour scheme per document type)
- **Firestore persistence** enabled with unlimited cache size

### Firestore Security Rules

- **Personal data:** `users/{userId}/**` only accessible when `request.auth.uid == userId`
- **Company data:** `companies/{companyId}/**` accessible to authenticated company members
- **Service history:** Immutable (no updates/deletes) for audit trail integrity
- Authentication required for all reads and writes
- Deployed via `firebase deploy --only firestore:rules`

### Cloud Functions (2 functions)

Located in `functions/index.js` (Node.js 20, us-central1). Require Firebase Blaze plan.

1. **onJobAssigned** — triggered when a dispatched job is created or assigned. Sends FCM push notification to the assigned engineer.
2. **onJobStatusChanged** — triggered when a job status is updated. Sends FCM push notification to the job creator (dispatcher).

### Firestore Data Structure

```
users/{uid}/
  ├── profile/main/                    # User profile (companyId, role, fcmToken)
  ├── jobsheets/{jobsheetId}
  ├── invoices/{invoiceId}
  ├── saved_customers/{customerId}
  ├── saved_sites/{siteId}
  ├── job_templates/{templateId}
  ├── filled_templates/{filledTemplateId}
  ├── pdf_config/
  │   ├── header_jobsheet, header_invoice
  │   ├── footer_jobsheet, footer_invoice
  │   └── colour_scheme_jobsheet, colour_scheme_invoice
  └── asset_type_config/{typeId}

companies/{companyId}/
  ├── profile/main/                    # Company details, invite code
  ├── members/{uid}/                   # Role, FCM token, permissions
  ├── dispatched_jobs/{jobId}
  ├── sites/{siteId}/
  │   ├── profile/main/
  │   ├── assets/{assetId}
  │   ├── floor_plans/{planId}
  │   └── asset_service_history/{recordId}
  ├── customers/{customerId}
  ├── pdf_config/                      # Company-level PDF branding
  │   ├── header, footer, colour_scheme
  └── asset_type_config/{typeId}
```

### Firebase Storage Structure

```
{basePath}/
  └── sites/{siteId}/
      ├── floor_plans/{planId}.{ext}           # Floor plan images
      └── assets/{assetId}/
          ├── photo.jpg                         # Asset photo
          └── defects/{recordId}_{index}.jpg    # Defect photos
```

Where `{basePath}` is `users/{uid}` (solo engineer) or `companies/{companyId}` (company team).

---

## Platform & Technical Notes

- **Multi-platform** — Android, iOS, Windows, macOS, Linux, web
- **Offline-first** — all personal data stored locally in SQLite with Firestore cloud sync backup; company/dispatch data is Firestore-primary with offline persistence
- **Dark mode** — full light / dark theme support following system preference
- **Responsive** — four breakpoints (compact < 600, medium 600–840, expanded 840–1200, large 1200+) with adaptive layouts
- **Adaptive UI** — Cupertino widgets on Apple platforms, Material on Android / desktop / web
- **State management** — StatefulWidget + setState throughout; ValueNotifier for isolated rebuilds (e.g. camera zoom)
- **Typography** — Google Fonts Inter; custom colour palette (Deep Navy `#1E3A5F` primary, Coral `#F97316` accent, Success Green `#4CAF50`, Error Red `#D32F2F`)
- **Animations** — Flutter Animate package; entrance animations, skeleton loaders, smooth transitions
- **PDF generation** — Syncfusion PDF + `pdf` package; custom watermarking, form-field population, signature overlay, compliance report generation
- **Camera / media** — Camera package, FFmpeg video processing, image picker, gallery save
- **Location** — geocoding with throttled GPS tracking
- **Background tasks** — Workmanager for periodic notification checks (12-hour intervals)
- **CI / CD** — Codemagic configuration for iOS TestFlight and Android APK workflows
- **Firebase services** — Auth, Firestore, Crashlytics, Analytics, Remote Config, Storage, Cloud Functions, Cloud Messaging (FCM)
- **Web hosting** — Firebase Hosting for the web portal

---

## Future Enhancements

This section is reserved for features requested by testers or identified during beta testing. Items will be added here as they are identified and prioritised.

### Potential Areas (Not Yet Committed)

- Photo attachment to jobsheets from timestamp camera
- Recurring job scheduling
- Customer portal or email notifications for invoice tracking
- Export to accounting software (Xero, QuickBooks, FreeAgent)
- Multi-device sync for solo engineers
- End-to-end encryption for sensitive data
- Additional PDF certificate templates
- Expanded BS 5839 reference data
- Integration with third-party fire safety systems
- Advanced reporting and analytics dashboards
- Team performance metrics for dispatchers

*(This list will evolve based on tester feedback and usage data.)*
