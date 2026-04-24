# FireThings — Complete Feature Reference

FireThings is a cross-platform Flutter application built specifically for fire alarm engineers. It combines jobsheet creation, invoicing, quoting, PDF document generation, asset register management, BS 5839-1:2025 compliance, team job dispatch, and a suite of field tools into a single offline-first app. Backed by Firebase Auth with local SQLite storage (personal data) and Firestore (company/team data). Targets Android, iOS, Windows, macOS, Linux, and web.

This document is a comprehensive reference of every feature in the app as of April 2026. It is intended to be self-contained — suitable for handoff to another person or AI assistant to understand the full scope of the product.

---

## Table of Contents

1. [Navigation](#navigation)
2. [Home Screen Dashboard](#home-screen-dashboard)
3. [Helpful Tools](#helpful-tools)
4. [Jobsheets](#jobsheets)
5. [Invoicing](#invoicing)
6. [Quoting](#quoting)
7. [Custom Template Builder](#custom-template-builder)
8. [Saved Sites & Customers (Personal)](#saved-sites--customers-personal)
9. [Granular Permission System](#granular-permission-system)
10. [PDF Design & Branding](#pdf-design--branding)
11. [PDF Architecture Rebuild](#pdf-architecture-rebuild)
12. [Dispatch System](#dispatch-system)
13. [Asset Register & Floor Plans](#asset-register--floor-plans)
14. [BS 5839-1:2025 Compliance System](#bs-5839-12025-compliance-system)
15. [Web Portal](#web-portal)
16. [Theme System](#theme-system)
17. [Settings & Account Management](#settings--account-management)
18. [Backend & Infrastructure](#backend--infrastructure)
19. [Platform & Technical Notes](#platform--technical-notes)
20. [Future Enhancements](#future-enhancements)

---

## Navigation

### Mobile (5 tabs)

| Tab | Purpose |
|-----|---------|
| **Home** | Dashboard with Sites & Assets card, dispatch card, and helpful tools grid |
| **Jobs** | Jobsheet management — creation, drafts, history |
| **Invoices** | Invoice management — creation, tracking, export |
| **Quotes** | Quote management — creation, status tracking, PDF generation |
| **Dispatch** | Job dispatch for dispatchers/admins or assigned jobs for engineers |

Layout adapts by screen size:

- **Compact** (< 600 px) — bottom navigation bar
- **Medium** (600–840 px) — NavigationRail on the left
- **Expanded / Large** (840 px+) — extended NavigationRail with labels
- iOS / macOS uses CupertinoTabBar; Android uses Material NavigationBar
- Swipe-gesture switching between tabs with animated transitions
- Dispatch tab: users with any dispatch permission see the dispatch dashboard (stream scoped by `dispatchViewAll`); users without dispatch permissions see the engineer jobs view

### Web

- GoRouter-based SPA routing with URL-based deep linking
- Sidebar navigation grouped into sections:
  - **Top:** Jobs (Dashboard), Schedule
  - **Workspace:** Team, Sites, Customers
  - **Finance:** Quotes (conditional on `quoting_enabled`), Invoices
  - **Bottom:** Branding (conditional on `pdfBranding` permission), Settings
- Top bar with company name, user profile, and logout
- Auth redirect handling (login required, company membership required, web portal permission required)

---

## Home Screen Dashboard

- **Greeting header** — time-based ("Good Morning / Afternoon / Evening") with the engineer's display name and an animated app icon
- **Sites & Assets card** — full-width tappable card showing saved site count, navigates to Saved Sites screen. Shown when `asset_register_enabled` flag is true.
- **Dispatched Jobs card** — full-width tappable card showing pending dispatch job count, navigates to Dispatch tab. Shown when the user has pending dispatched jobs.
- **Helpful Tools grid** — up to seven tool tiles in a responsive grid (2 columns on compact, 3 on wide screens). Each tool is individually controlled by a remote config feature flag.
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

### 7. Symptom Troubleshooter

Interactive diagnostic tool for fire alarm fault finding. Guides engineers through systematic troubleshooting based on observed symptoms.

- **Five symptom categories:**
  - Loop / Wiring Faults (7 symptoms) — intermittent loop fault, night-only faults, wet-weather faults, post-building-work faults, random device faults, short circuit, open circuit
  - Earth / Electrical Issues (6 symptoms) — night earth faults, wet-weather earth faults, intermittent earth faults, mains failure trips, PSU overheating, battery not charging
  - Device Issues (6 symptoms) — unwanted alarms at night, detector faults, multiple faults same zone, device not responding, new device not working, detector drift / contamination
  - System Behavior (6 symptoms) — panel resetting, slow loop polling, network communication fault, sounder circuit fault, panel buzzer, display fault with no details
  - Environmental (5 symptoms) — cold-weather faults, hot-weather faults, post-cleaning faults, kitchen-area faults, bathroom / shower area faults

- **For each symptom provides:**
  - Description of the problem
  - Likely causes (ranked by probability)
  - Step-by-step isolation procedure
  - Testing tips
  - Preventive measures

---

## Jobsheets

### Creation

New jobsheets start from the Jobs hub. The engineer picks a **pre-built template** or a **custom template**.

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
- Applies the user's PDF branding settings (cover, header, footer, colour scheme)
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

## Quoting

**Status:** Feature complete, hidden behind `quoting_enabled` remote config flag (default: false).

### Creation

- Auto-incremented quote number (Q-0001 format)
- Customer name, address, email, and phone (with saved-customers picker)
- Site selection (with saved-sites picker)
- **Line items** — each with description, quantity, unit price, and optional category (labour, parts, materials); calculated totals per item
- VAT toggle (adds 20%)
- Notes section
- Validity period (`validUntil` date)

### Defect-to-Quote Workflow

Quotes can be created directly from asset defects discovered during inspections:

- Pre-fills defect description, severity, and clause reference from the source defect
- Tracks whether the defect triggered a prohibited variation rule
- Links quote back to the source defect ID (`defectId`)
- Bidirectional link — defect stores `linkedQuoteId`, quote stores `defectId`
- Deleting a quote clears the bidirectional defect link

### Statuses

| Status | Meaning |
|--------|---------|
| **Draft** | Work in progress, not yet sent |
| **Sent** | Delivered to customer, awaiting response |
| **Approved** | Customer accepted the quote |
| **Declined** | Customer rejected the quote |
| **Converted** | Approved quote converted to a dispatched job |

### Quote Conversion

- Approved quotes can be converted into dispatched jobs
- Converted quote stores the linked job ID (`convertedJobId`)
- Dispatched job stores the source quote ID (`sourceQuoteId`)
- `ConvertedQuoteDeletionException` prevents deleting converted quotes to avoid data loss

### Mobile Screens

- **Quoting Hub** (`quoting_hub_screen.dart`) — entry point with overview and quick actions
- **Quote Screen** (`quote_screen.dart`) — create and edit quotes
- **Quote List** (`quote_list_screen.dart`) — browse, search, and filter quotes by status

### PDF Generation

- Quote PDF generated via `quote_pdf_service.dart`
- Applies the user's PDF branding (cover, header, footer, colour scheme)
- Share or email directly from the app

### Permissions (company context)

| Permission | Label |
|------------|-------|
| `quotesCreate` | Create Quotes |
| `quotesEdit` | Edit Quotes |
| `quotesSend` | Send Quotes |
| `quotesApprove` | Approve / Decline Quotes |
| `quotesConvert` | Convert Quote to Job |

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
- Quick-select dropdown in invoice and quote creation
- Avatar badge showing the customer's initial

### Saved Sites

- Fields: site name, address, notes
- Add, edit, delete
- Search / filter by site name or address
- Quick-select in jobsheet creation for fast address entry
- **Asset register integration** — tap a saved site to view its asset register and floor plans

---

## Granular Permission System

45 individual permissions across 14 categories, assigned per-user by company admins. Permissions control access to features in both the mobile app and the web portal.

### Permission Categories

| Category | Permissions | Count |
|----------|-------------|-------|
| **Web Portal** | Web Portal Access | 1 |
| **Dispatch** | Create Jobs, Edit Jobs, Delete Jobs, View All Jobs | 4 |
| **Sites** | Add Sites, Edit Sites, Delete Sites | 3 |
| **Customers** | Add Customers, Edit Customers, Delete Customers | 3 |
| **Assets** | Add Assets, Edit Assets, Delete Assets, Add Asset Photos, Delete Asset Photos, Test / Inspect Assets | 6 |
| **Floor Plans** | Upload Floor Plans, Edit Floor Plans, Delete Floor Plans | 3 |
| **Asset Types** | Manage Asset Types | 1 |
| **Branding** | PDF Branding | 1 |
| **Quoting** | Create Quotes, Edit Quotes, Send Quotes, Approve / Decline Quotes, Convert Quote to Job | 5 |
| **Invoicing** | Create Invoices, Edit Invoices, Delete Invoices, Send Invoices | 4 |
| **Jobsheets** | Edit Completed Jobsheets, Delete Completed Jobsheets | 2 |
| **Defects** | Log Defects, Mark Defects Rectified, Delete Defects | 3 |
| **Company** | Edit Company, Delete Company, Manage Team, Regenerate Invite Code | 4 |
| **BS 5839** | Edit BS 5839 Config, Approve Variations, Issue Reports, Record CPD, View Team Competency | 5 |

### Role Defaults

Roles serve as default permission templates when a member joins a company:

| Role | Default Permissions |
|------|-------------------|
| **Admin** | All 45 permissions enabled (also enforced at code level — admin always has access) |
| **Dispatcher** | Operational permissions enabled (dispatch, sites, customers, assets, floor plans, quoting, invoicing). Company management restricted. |
| **Engineer** | Field-work permissions only (test assets, log defects, create jobsheets). Cannot create dispatch jobs, manage team, or access web portal. |

### Enforcement

- **Client-side:** `UserProfileService.hasPermission(AppPermission.xxx)` — reactive via `ChangeNotifier`, UI elements hide/show immediately when permissions change
- **Server-side:** Firestore security rules use `hasPermission(companyId, 'key')` helper function
- **Cloud Functions:** Role and permission changes are Cloud Functions only (not direct writes)
- **Last-admin protection:** `LastAdminException` prevents demotion or removal of the sole admin

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
- Company logo upload per document type (jobsheet / invoice / quote)
- Managed from Settings → Company PDF Design (dispatchers/admins only)

### PDF Branding v2 (Web Customiser)

Full branding customisation via the web portal (`web_branding_screen.dart`) with live preview across all document types.

- **Cover Styles:** Bold (navy background, amber radial glow, large display typography), Minimal (white background, amber divider, clean layout), Bordered (white background, thick navy bars top and bottom)
- **Header Styles:** Solid (navy background, white text), Minimal (white background, amber border-bottom), Bordered (white background, grey border-bottom)
- **Footer Styles:** Light, Minimal, Coloured — with optional page numbers toggle
- **Typography:** Outfit (display / titles), Inter (body text), JetBrains Mono (technical / mono text)
- **Per-document-type cover text overrides:** Eyebrow, title, and subtitle customisable per doc type (jobsheet, invoice, quote, compliance report)
- **Logo upload** with live preview and delete
- **Primary and accent colour selection** via colour picker
- **Toggle controls:** Show company name in header, show document number in header
- **Autosave** with 500 ms debounce and save-status pill indicator
- **Branding resolution:** Company branding overrides personal for company members; solo engineers use personal branding

Branding stored in Firestore:
- Company: `companies/{companyId}/branding/main`
- Personal: `users/{userId}/branding/main`

Model: `lib/models/pdf_branding.dart` — `PdfBranding` + `BrandingCoverText` + enums (`CoverStyle`, `HeaderStyle`, `FooterStyle`, `BrandingDocType`)
Service: `lib/services/pdf_branding_service.dart`

---

## PDF Architecture Rebuild

**Status:** Phase 1 in progress. Approved spec at `docs/specs/PDF_ARCHITECTURE_REBUILD_SPEC.md`.

Five-phase rebuild to align actual PDF output with the web preview and support subscription tiers. The core problem: the web customiser's live preview looks correct, but the generated PDF doesn't match it — the PDF still uses the old mobile-era visual language.

### Phase 1 — Rendering Rebuild (in progress)

Making PDF output visually faithful to the web preview for all three cover styles and typography throughout.

- **Font registry** (`lib/services/pdf_widgets/pdf_font_registry.dart`) — loads and registers Outfit (weights 600/700/800), Inter (weights 400/500/600/700), and JetBrains Mono (500) for use in PDFs. Fonts loaded once at app startup, cached for subsequent PDF generations.
- **Brand tokens** (`lib/services/pdf_widgets/pdf_brand_tokens.dart`) — PDF-side parallel of `web_theme.dart`. Provides reusable text styles, spacing, and colours as PDF types derived from `PdfBranding`.
- **Cover builder rewrite** (`lib/services/pdf_widgets/pdf_cover_builder.dart`) — three cover style implementations:
  - **Bold** — navy background, amber radial gradient glow, white text, amber logo mark, Outfit display title, Inter meta grid
  - **Minimal** — white background, amber horizontal divider, logo on left, clean layout
  - **Bordered** — white background, thick navy bars at top and bottom
- **Page header rebuild** (`lib/services/pdf_widgets/pdf_modern_header.dart`) — Solid / Minimal / Bordered header variants with optional company name and document number toggles
- **Footer rebuild** (`lib/services/pdf_footer_builder.dart`) — Light / Minimal / Coloured footer variants with page numbers
- **Wiring to five PDF services:** compliance report, quote, invoice, jobsheet template, BS 5839 report — each calls `PdfFontRegistry.instance.ensureLoaded()` and uses new builders when `PdfBranding` is present
- **Font assets** committed to `assets/fonts/` (Outfit, Inter, JetBrains Mono TTF files)

### Phase 2 — Branding Source Split (planned)

- Company vs personal branding storage with automatic resolution
- `resolveBrandingForCurrentUser()` — returns company branding for company users, personal branding for solo users
- User-level branding at `users/{userId}/branding/main`

### Phase 3 — Simplified Mobile Customiser (planned)

- Five preset brand kits: FireThings (navy + amber), Graphite (black + red), Forest (deep green + copper), Slate (cool grey + cyan), Heritage (burgundy + gold)
- Logo upload, cover style picker (Bold / Minimal / Bordered), primary colour hue tweaker
- Mini live preview on mobile
- Personal branding for solo engineers — accessible from Settings when not in a company

### Phase 4 — Tier Gating (planned)

- Free / Pro / Premium subscription tiers
- RevenueCat integration (StoreKit on iOS, Play Billing on Android, Stripe on web)
- `EntitlementService` and `TierCapabilities` for capability checks
- Server-side enforcement via Firestore rules
- Subscription screen with tier comparison and upgrade flow

### Phase 5 — Deprecate Old Editors (planned)

- Migration of legacy `pdf_config` Firestore data to `PdfBranding` model
- Removal of old editor screens (`UnifiedPdfEditorScreen`, `CompanyPdfDesignScreen`, `PdfDesignScreen`)
- Removal of old config services (`pdf_header_config_service`, `pdf_footer_config_service`, `pdf_colour_scheme_service`, etc.)
- Single code path for PDF generation (branding-based only)

Feature flags: `pdf_renderer_v2_enabled`, `personal_branding_enabled`, `mobile_customiser_v2_enabled`, `tier_gating_enabled`

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

## BS 5839-1:2025 Compliance System

**Status:** Feature complete, hidden behind `bs5839_mode_enabled` remote config flag (default: false). Per-site compliance management system aligned with the BS 5839-1:2025 standard (fire detection and fire alarm systems for buildings).

### System Configuration

Per-site fire alarm system configuration stored in Firestore.

- System category declaration (L1–L5, M, P1, P2) per site
- Responsible person details per site
- Alarm Receiving Centre (ARC) details
- Transmission time requirements (new in 2025 edition)

Screen: `bs5839_system_config_screen.dart`
Model: `bs5839_system_config.dart`
Service: `bs5839_config_service.dart`

### Inspection Visit System

Structured inspection workflow that groups asset tests, cause-and-effect tests, and documentation reviews into a formal visit record.

- **Dashboard** (`inspection_visit_dashboard_screen.dart`) — overview of visit status per site
- **Start Visit** (`start_inspection_visit_screen.dart`) — initiate a new inspection with visit type selection
- **Complete Visit** (`complete_visit_screen.dart`) — finalise, review results, and sign off
- **Visit Detail** (`visit_detail_screen.dart`) — full record of a specific visit
- **Visit History** (`visit_history_screen.dart`) — chronological list of all visits for a site
- **Visit types:** Commissioning, Routine Service, Modification, Re-inspection
- Engineer and customer signatures with competency evidence
- Immutable audit trail

Model: `inspection_visit.dart`
Service: `inspection_visit_service.dart`

### Variations Register

Record and track departures from the BS 5839-1 standard per site.

- Add and edit variations with justification
- **Prohibited variation detection** — rule database (`lib/data/prohibited_variation_rules.dart`) automatically identifies variations that violate Clause 6.6
- Hard-stop: system refuses to issue a "satisfactory" declaration if any prohibited variation is present — must be marked "unsatisfactory" with remediation required
- Alert widget (`prohibited_variations_alert.dart`) surfaced in relevant screens

Screens: `variations_register_screen.dart`, `add_edit_variation_screen.dart`
Model: `bs5839_variation.dart`
Service: `variation_service.dart`

### Cause-and-Effect Testing

Record trigger-to-effect verification tests required at handover per the 2025 edition.

- Define trigger devices and expected effects (e.g. MCP → AOV opens, sounders activate, door releases, ARC signal)
- Record test results as structured data (not free-text)
- Required at commissioning handover

Screens: `cause_effect_test_list_screen.dart`, `cause_effect_test_screen.dart`
Model: `cause_effect_test.dart`
Service: `cause_effect_service.dart`

### Engineer Competency Tracking

Qualifications and continuing professional development records per engineer, as required by Clause 3.13 (competent person definition).

- Record qualifications and CPD activities
- Minimum CPD hours configurable via remote config (`bs5839_min_cpd_hours_per_year`, default: 5)
- Competency evidence surfaced on every inspection report

Screen: `competency_screen.dart`
Model: `engineer_competency.dart`
Service: `competency_service.dart`

### Logbook System

Structured site logbook replacing free-text records.

- Add logbook entries per site with structured fields
- Logbook review confirmation per visit (must be evidenced)

Screens: `logbook_screen.dart`, `add_logbook_entry_screen.dart`
Model: `logbook_entry.dart`
Service: `logbook_service.dart`

### BS 5839 Report PDF

Standards-compliant inspection report.

- Declaration: satisfactory / satisfactory-with-variations / unsatisfactory
- Clause-level traceability (2025 numbering)
- Structured report with inspection visit details, variations, competency evidence
- Responsible person countersignature

Screen: `bs5839_report_screen.dart`
Service: `bs5839_report_service.dart`

### Overall Compliance

Aggregation service that brings together all compliance subsystems for a site.

- Validation logic for system categories
- Clause 6.6 prohibited variation detection
- Satisfactory / unsatisfactory determination

Service: `bs5839_compliance_service.dart`

### Permissions (company context)

| Permission | Label |
|------------|-------|
| `bs5839ConfigEdit` | Edit BS 5839 Config |
| `bs5839ApproveVariations` | Approve Variations |
| `bs5839IssueReports` | Issue Reports |
| `bs5839RecordCpd` | Record CPD |
| `bs5839ViewTeamCompetency` | View Team Competency |

### Remote Config Flags (10 BS 5839-specific)

| Flag | Default | Purpose |
|------|---------|---------|
| `bs5839_mode_enabled` | false | Master toggle for BS 5839 compliance system |
| `bs5839_visits_enabled` | false | Inspection visit functionality |
| `bs5839_variations_register_enabled` | false | Variations register |
| `bs5839_cause_effect_enabled` | false | Cause-and-effect testing |
| `bs5839_competency_tracking_enabled` | false | Engineer competency tracking |
| `bs5839_report_enabled` | false | BS 5839 report PDF generation |
| `bs5839_logbook_structured_enabled` | false | Structured logbook |
| `bs5839_min_cpd_hours_per_year` | 5.0 | Minimum CPD hours per year |
| `bs5839_service_window_warning_days` | 30 | Days before service window warning |
| `bs5839_reference_data_version` | '2025-04-30' | BS 5839 reference data version |

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

- **Sidebar navigation** grouped into sections:
  - **Top:** Jobs (Dashboard), Schedule
  - **Workspace:** Team, Sites, Customers
  - **Finance:** Quotes (conditional on `quoting_enabled`), Invoices
  - **Bottom:** Branding (conditional on `pdfBranding` permission), Settings
- **Top bar:** Company name, user profile, logout
- **Main content area:** Dynamic per route
- **Wide-screen layout:** List and form screens constrained to 750px max width using `Center` + `ConstrainedBox(maxWidth: 750)` pattern

### Authentication

- Web-specific styled login page
- Email / password entry
- Redirects to `/jobs` on success
- Redirects to `/access-denied` if user has no company or lacks web portal access permission

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
- Month, week, and day views
- Colour-coded by engineer or priority
- Click to open job detail panel
- Unscheduled jobs strip

### Company Management (Web)

- Team Management: invite, manage roles and permissions, remove members
- Sites: add / edit / delete company sites
- Customers: manage customer database
- Same screens as mobile, desktop-width layout with max-width constraints

### Quotes (Web)

- Quote list with filtering by status (`web_quotes_screen.dart`)
- Create and edit quotes from web (`web_create_quote_screen.dart`)
- Quote detail panel with side-by-side viewing (`web_quote_detail_panel.dart`)
- PDF preview
- Gated behind `quoting_enabled` remote config flag

### Invoices (Web)

- Invoice list with filtering by status (`web_invoices_screen.dart`)
- Create and edit invoices from web (`web_create_invoice_screen.dart`)
- Invoice detail panel (`web_invoice_detail_panel.dart`)

### Branding (Web)

- Full PDF branding customiser with live preview (`web_branding_screen.dart`)
- Cover style, header style, footer style selection
- Logo upload, colour selection, per-doc-type text overrides
- Preview builders for all document types (jobsheet, invoice, quote, compliance report)
- Gated behind `pdfBranding` permission

### Asset Register & Floor Plans (Web)

- Full asset register functionality on web
- Add / edit / delete assets from desktop
- Upload floor plans (including PDF files)
- **Place and move pins with mouse** — ideal for office-based setup with printed drawings. `GestureDetector` pan tracking replaces `Draggable` to avoid `InteractiveViewer` gesture conflicts. Pan delta divided by zoom scale for correct movement at any zoom level.
- Click pins for details, create assets directly from floor plan
- `Image.network` with `webHtmlElementStrategy: WebHtmlElementStrategy.prefer` bypasses CORS for Firebase Storage images. Mobile keeps `CachedNetworkImage` for offline caching.

### BS 5839 Compliance (Web)

- System configuration per site
- Inspection visit history and detail
- Variations register
- Logbook entries
- Engineer competency tracking (via `/team/competency` route)

### Web Push Notifications

- Real-time job status updates via `WebNotificationService`
- Notification feed in top bar with badge count for unread
- Click notification to navigate to job

### Web Routes

| Route | Screen |
|-------|--------|
| `/login` | Web login |
| `/jobs` | Dispatcher dashboard |
| `/jobs/create` | Create / edit job |
| `/jobs/:id` | Job detail |
| `/schedule` | Calendar / board view |
| `/team` | Team management |
| `/team/competency` | Engineer competency (BS 5839) |
| `/sites` | Company sites |
| `/sites/:siteId/assets` | Asset register for site |
| `/sites/:siteId/assets/add` | Add new asset |
| `/sites/:siteId/assets/types` | Asset type configuration |
| `/sites/:siteId/assets/report` | Compliance report |
| `/sites/:siteId/assets/bs5839-config` | BS 5839 system config |
| `/sites/:siteId/assets/bs5839-visits` | BS 5839 visit history |
| `/sites/:siteId/assets/bs5839-visits/:visitId` | Visit detail |
| `/sites/:siteId/assets/bs5839-variations` | Variations register |
| `/sites/:siteId/assets/bs5839-logbook` | Logbook |
| `/sites/:siteId/assets/:assetId` | Asset detail |
| `/sites/:siteId/assets/:assetId/edit` | Edit asset |
| `/sites/:siteId/floor-plans` | Floor plans for site |
| `/sites/:siteId/floor-plans/upload` | Upload floor plan |
| `/sites/:siteId/floor-plans/:planId` | Interactive floor plan |
| `/quotes` | Quote list |
| `/quotes/create` | Create / edit quote |
| `/quotes/:id` | Quote detail |
| `/invoices` | Invoice list |
| `/invoices/create` | Create / edit invoice |
| `/invoices/:id` | Invoice detail |
| `/customers` | Company customers |
| `/branding` | PDF branding customiser |
| `/settings` | Web settings |
| `/access-denied` | Access denied |

### Analytics Events (12 web-specific)

`web_login`, `web_dashboard_viewed`, `web_job_created`, `web_job_edited`, `web_job_assigned`, `web_job_detail_viewed`, `web_schedule_viewed`, `web_bulk_assign`, `web_search_used`, `web_print_used`, `web_asset_register_viewed`, `web_floor_plan_viewed`

---

## Theme System

Two visual themes selectable from Settings → Appearance.

| Theme | Description |
|-------|-------------|
| **Classic** | Default FireThings theme. Light and dark mode follows system preference. Deep Navy `#1E3A5F` primary, Coral `#F97316` accent. |
| **SiteOps** | Dark industrial theme. Forces dark mode regardless of system preference. Background `#0B0D10`, surface `#14171C`, accent amber `#FFB020`. |

Implementation:

- `ThemeStyle` enum (`classic`, `siteOps`) in `lib/utils/theme_style.dart`
- `themeStyleNotifier` — global `ValueNotifier<ThemeStyle>` for reactive theme switching across the app
- Preference persisted via SharedPreferences (`theme_style` key)
- SiteOps forces `ThemeMode.dark` at the `MaterialApp` level
- `AppTheme` colour constants are `static Color get` that dispatch by `themeStyleNotifier.value` — e.g. `AppTheme.primaryBlue` returns amber when SiteOps is active (colour names are semantic roles, not literal colours)
- Theme loaded on app startup via `loadThemeStylePreference()`

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

### Appearance

- Theme style selection (Classic / SiteOps)

### PDF Design

- Header Designer
- Footer Designer
- Colour Scheme
- Company Logo upload (per document type: jobsheet / invoice / quote)
- Personal Branding (solo users only — company branding is managed via the web portal)

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

### Firebase Analytics (62 events)

- 62 custom events across all features:
  - **Templates:** 2 events (template_selected, template_started)
  - **Tools:** 1 event (tool_opened)
  - **Jobsheets:** 5 events (started, saved_draft, completed, pdf_generated, pdf_shared)
  - **Invoices:** 4 events (created, saved_draft, sent, marked_paid)
  - **Quoting:** 4 events (quote_created, quote_sent, quote_status_changed, quote_converted)
  - **Customers & Sites:** 4 events (customer_saved, customer_selected, site_saved, site_selected)
  - **Camera:** 3 events (photo_captured, video_recording_started, video_recording_completed)
  - **Auth:** 2 events (login, signup)
  - **Dispatch:** 13 events (company_created, company_joined, job lifecycle, directions, contact)
  - **Web:** 12 events (login, dashboard, job CRUD, schedule, bulk assign, search, print, assets, floor plans)
  - **Asset Register:** 14 events (asset CRUD, testing, batch, decommission, floor plans, barcode, compliance report, type config)
- Automatic screen tracking via `FirebaseAnalyticsObserver`

### Firebase Remote Config (29 flags)

| Flag | Default | Purpose |
|------|---------|---------|
| `timestamp_camera_enabled` | true | Timestamp Camera tool |
| `decibel_meter_enabled` | true | Decibel Meter tool |
| `dip_switch_calculator_enabled` | true | DIP Switch Calculator tool |
| `detector_spacing_enabled` | true | Detector Spacing Calculator tool |
| `battery_load_tester_enabled` | true | Battery Load Tester tool |
| `bs5839_reference_enabled` | true | BS 5839 Reference Guide |
| `invoicing_enabled` | true | Invoicing feature |
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
| `quoting_enabled` | false | Quoting feature |
| `bs5839_mode_enabled` | false | Master toggle for BS 5839 compliance system |
| `bs5839_visits_enabled` | false | Inspection visit functionality |
| `bs5839_variations_register_enabled` | false | Variations register |
| `bs5839_cause_effect_enabled` | false | Cause-and-effect testing |
| `bs5839_competency_tracking_enabled` | false | Engineer competency tracking |
| `bs5839_report_enabled` | false | BS 5839 report PDF generation |
| `bs5839_logbook_structured_enabled` | false | Structured logbook |
| `bs5839_min_cpd_hours_per_year` | 5.0 | Minimum CPD hours per year |
| `bs5839_service_window_warning_days` | 30 | Days before service window warning |
| `bs5839_reference_data_version` | '2025-04-30' | BS 5839 reference data version |

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
- **Permission enforcement:** `hasPermission(companyId, 'key')` helper function
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
  ├── quotes/{quoteId}
  ├── saved_customers/{customerId}
  ├── saved_sites/{siteId}
  ├── job_templates/{templateId}
  ├── filled_templates/{filledTemplateId}
  ├── branding/main/                   # Personal PDF branding (solo users)
  ├── pdf_config/
  │   ├── header_jobsheet, header_invoice
  │   ├── footer_jobsheet, footer_invoice
  │   └── colour_scheme_jobsheet, colour_scheme_invoice
  └── asset_type_config/{typeId}

companies/{companyId}/
  ├── profile/main/                    # Company details, invite code
  ├── members/{uid}/                   # Role, FCM token, permissions
  ├── dispatched_jobs/{jobId}
  ├── quotes/{quoteId}
  ├── customers/{customerId}
  ├── branding/main/                   # Company-level PDF branding (v2)
  ├── pdf_config/                      # Legacy PDF config (being deprecated)
  │   ├── header, footer, colour_scheme
  ├── sites/{siteId}/
  │   ├── profile/main/
  │   ├── assets/{assetId}
  │   ├── floor_plans/{planId}
  │   ├── asset_service_history/{recordId}
  │   ├── bs5839_config/main/          # BS 5839 system configuration
  │   ├── inspection_visits/{visitId}   # Inspection visit records
  │   ├── variations/{variationId}      # Variations register
  │   ├── cause_effect_tests/{testId}   # Cause-and-effect tests
  │   ├── defects/{defectId}
  │   └── logbook_entries/{entryId}     # Logbook entries
  ├── competency/{uid}/                 # Engineer competency records
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
- **Dark mode** — full light / dark theme support following system preference (Classic theme), or forced dark mode (SiteOps theme)
- **Responsive** — four breakpoints (compact < 600, medium 600–840, expanded 840–1200, large 1200+) with adaptive layouts
- **Adaptive UI** — Cupertino widgets on Apple platforms, Material on Android / desktop / web
- **State management** — StatefulWidget + setState throughout; ValueNotifier for isolated rebuilds (e.g. camera zoom, theme style)
- **Typography** — Google Fonts Inter throughout; Outfit and JetBrains Mono for PDF generation
- **Colour palette** — Classic: Deep Navy `#1E3A5F` primary, Coral `#F97316` accent, Success Green `#4CAF50`, Error Red `#D32F2F`. SiteOps: amber `#FFB020` on near-black `#0B0D10`.
- **Animations** — Flutter Animate package; entrance animations, skeleton loaders, smooth transitions
- **PDF generation** — `pdf` package + Syncfusion PDF; custom typography (Outfit/Inter/JetBrains Mono), branded covers, signature overlay, compliance report generation
- **Camera / media** — Camera package, FFmpeg video processing, image picker, gallery save
- **Location** — geocoding with throttled GPS tracking
- **Background tasks** — Workmanager for periodic notification checks (12-hour intervals)
- **CI / CD** — Codemagic configuration for iOS TestFlight and Android APK workflows
- **Firebase services** — Auth, Firestore, Crashlytics, Analytics, Remote Config, Storage, Cloud Functions, Cloud Messaging (FCM)
- **Web hosting** — Firebase Hosting for the web portal

---

## Future Enhancements

This section lists confirmed future build items only.

### Customer Portal

Customer-facing portal for viewing quotes, invoices, and job status. Allows customers to review and respond to documents without requiring a FireThings account. Scope and timeline to be determined.

### PDF Architecture Rebuild — Phases 2–5

The rendering rebuild (Phase 1) is currently in progress. The remaining phases are approved and planned:

- **Phase 2 — Branding source split:** Company vs personal branding resolution with automatic fallback logic
- **Phase 3 — Simplified mobile customiser:** Five preset brand kits for solo engineers with logo upload and colour tweaking
- **Phase 4 — Tier gating:** Free / Pro / Premium subscription tiers via RevenueCat (StoreKit, Play Billing, Stripe)
- **Phase 5 — Deprecate old editors:** Migration of legacy PDF config data and removal of old editor screens

Full spec: `docs/specs/PDF_ARCHITECTURE_REBUILD_SPEC.md`
