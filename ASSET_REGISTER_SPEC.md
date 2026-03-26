# FireThings — Asset Register & Floor Plans Feature Specification

**Version:** 1.0  
**Date:** March 2026  
**Purpose:** Complete technical specification for implementing an asset register, interactive floor plans, QR/barcode scanning, asset lifecycle tracking, configurable inspection checklists, and site compliance reporting into FireThings. This document is intended to be read by both the developer and Claude Code during implementation.

**Prerequisites:**
- The dispatch feature (`DISPATCH_FEATURE_SPEC.md`) should be implemented first, as asset compliance data surfaces in the dispatch system.
- The web portal (`WEBPORTAL_SPEC.md`) should be implemented or in progress, as floor plans and asset editing are available on both mobile and web.
- Firebase Storage must be enabled in the Firebase project for floor plan images and defect photos.

---

## Table of Contents

1. [Overview & Goals](#1-overview--goals)
2. [Architecture](#2-architecture)
3. [Data Models](#3-data-models)
4. [Firestore Structure & Security Rules](#4-firestore-structure--security-rules)
5. [Pre-Built Asset Types & Default Checklists](#5-pre-built-asset-types--default-checklists)
6. [Asset Register — Screens & Workflow](#6-asset-register--screens--workflow)
7. [Floor Plans — Screens & Interaction](#7-floor-plans--screens--interaction)
8. [Asset Testing & Inspection Workflow](#8-asset-testing--inspection-workflow)
9. [QR / Barcode Scanning](#9-qr--barcode-scanning)
10. [Asset Lifecycle Tracking](#10-asset-lifecycle-tracking)
11. [Jobsheet Integration — Auto-Generated Asset Summary](#11-jobsheet-integration--auto-generated-asset-summary)
12. [Site Compliance Report PDF](#12-site-compliance-report-pdf)
13. [Dispatch System Integration](#13-dispatch-system-integration)
14. [Web Portal Integration](#14-web-portal-integration)
15. [Firebase Storage — Images & Photos](#15-firebase-storage--images--photos)
16. [Permissions & Role-Based Access](#16-permissions--role-based-access)
17. [SQLite Schema Changes](#17-sqlite-schema-changes)
18. [Existing Code Changes](#18-existing-code-changes)
19. [New Files to Create](#19-new-files-to-create)
20. [Analytics Events](#20-analytics-events)
21. [Remote Config Flags](#21-remote-config-flags)
22. [Implementation Order](#22-implementation-order)
23. [Testing Plan](#23-testing-plan)

---

## 1. Overview & Goals

### What This Feature Does

Engineers can build and maintain a complete digital asset register for every site they service. Each site has one or more floor plans (uploaded images) with interactive pins showing the exact location of every fire safety device. Engineers tap pins to view device details, run inspection checklists, log pass/fail results, and record defects with photos — all of which automatically feed into jobsheet PDFs and build a permanent audit trail.

### Who Uses It

- **Solo engineers** — track assets for sites they personally service, stored under their own account
- **Company engineers** — track assets for company sites, shared with the whole team
- **Dispatchers/admins (web portal)** — view asset registers and floor plans, set up site plans from the office using printed drawings, see compliance warnings when dispatching jobs
- **Customers (future)** — view their site's compliance status, floor plans, and asset history via a customer portal

### Key Principles

1. **Available to all users, not just companies.** Solo engineers can use the asset register on their personal saved sites. Company users share the register across the team. Same screens, same logic, different Firestore paths.

2. **Floor plans are interactive, not static.** Pins are tappable, show real-time compliance status, and support full CRUD from both mobile and web.

3. **Testing feeds into jobsheets automatically.** When an engineer tests assets during a job, those results appear as a summary table in the generated PDF — no double entry.

4. **Full audit trail.** Every test result is permanently logged with date, engineer, checklist outcomes, and notes. This data builds over time and becomes the site's compliance history.

5. **BS 5839 defaults out of the box.** Pre-built asset types with sensible default checklists mean engineers can start using the feature immediately without configuration. Admins can extend and customise.

---

## 2. Architecture

### Data Ownership

Solo engineer (no company): `users/{uid}/sites/{siteId}/` contains assets/, floor_plans/, and asset_service_history/.

Company user: `companies/{companyId}/sites/{siteId}/` contains the same subcollections, shared across the team.

The app determines which path to use based on whether the user has a `companyId`. All screens and services accept a `basePath` parameter (either `users/{uid}` or `companies/{companyId}`) so the same code works for both.

### Storage

- **Asset data, floor plan metadata, service history** — Firestore
- **Floor plan images, defect photos** — Firebase Storage
- **Local caching for company data** — Firestore offline persistence
- **Local caching for solo data** — SQLite (mirrors Firestore, same pattern as existing jobsheets)

### Asset Type Configuration

Global (read-only, shipped with app): Built-in asset types and default checklists (hardcoded in `default_asset_types.dart`).

Company-level overrides: `companies/{companyId}/asset_type_config/{typeId}` — custom types, modified checklists, additional checks.

Solo user overrides: `users/{uid}/asset_type_config/{typeId}` — same structure for solo engineers.

---

## 3. Data Models

### Asset

```dart
class Asset {
  final String id;
  final String siteId;
  final String assetTypeId;           // e.g. "smoke_detector"
  final String? variant;              // e.g. "Optical", "Multi-sensor"
  final String? make;                 // manufacturer
  final String? model;
  final String? serialNumber;
  final String? reference;            // site-specific ref, e.g. "SD-001"
  final String? barcode;              // QR/barcode value
  final String? floorPlanId;          // which floor plan this asset is on
  final double? xPercent;             // X position (0.0-1.0)
  final double? yPercent;             // Y position (0.0-1.0)
  final String? locationDescription;
  final String? zone;
  final DateTime? installDate;
  final DateTime? warrantyExpiry;
  final int? expectedLifespanYears;
  final DateTime? decommissionDate;
  final String? decommissionReason;
  final String complianceStatus;      // "pass", "fail", "untested", "decommissioned"
  final DateTime? lastServiceDate;
  final String? lastServiceBy;
  final String? lastServiceByName;
  final DateTime? nextServiceDue;
  final String? photoUrl;             // Firebase Storage URL
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
}
```

### AssetType

```dart
class AssetType {
  final String id;                    // e.g. "smoke_detector"
  final String name;                  // e.g. "Smoke Detector"
  final String? category;             // e.g. "Detection", "Notification"
  final String iconName;
  final String defaultColor;          // hex colour for pins
  final List<String> variants;
  final int? defaultLifespanYears;
  final List<ChecklistItem> defaultChecklist;
  final bool isBuiltIn;
}
```

### ChecklistItem

```dart
class ChecklistItem {
  final String id;
  final String label;                 // e.g. "Visual inspection"
  final String? description;
  final bool isRequired;
  final String resultType;            // "pass_fail", "text", "number", "yes_no"
}
```

### ServiceRecord

```dart
class ServiceRecord {
  final String id;
  final String assetId;
  final String siteId;
  final String? jobsheetId;
  final String? dispatchedJobId;
  final String engineerId;
  final String engineerName;
  final DateTime serviceDate;
  final String overallResult;         // "pass", "fail"
  final List<ChecklistResult> checklistResults;
  final String? defectNote;
  final List<String> defectPhotoUrls;
  final String? defectSeverity;       // "minor", "major", "critical"
  final String? defectAction;         // "rectified_on_site", "quote_required", "replacement_needed"
  final String? notes;
  final DateTime createdAt;
}
```

### ChecklistResult

```dart
class ChecklistResult {
  final String checklistItemId;
  final String label;
  final String result;                // "pass", "fail", "n/a" or text/number
  final String? note;
}
```

### FloorPlan

```dart
class FloorPlan {
  final String id;
  final String siteId;
  final String name;                  // e.g. "Ground Floor"
  final int sortOrder;
  final String imageUrl;              // Firebase Storage URL
  final double imageWidth;
  final double imageHeight;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Pin positions are stored directly on the Asset model (floorPlanId, xPercent, yPercent). No separate pin model needed.

---

## 4. Firestore Structure & Security Rules

### Collections

Under `{basePath}/sites/{siteId}/`:
- `assets/{assetId}` — all Asset fields
- `floor_plans/{planId}` — all FloorPlan fields
- `asset_service_history/{recordId}` — all ServiceRecord fields

Under `{basePath}/`:
- `asset_type_config/{typeId}` — custom/modified asset types

Where `{basePath}` is either `users/{uid}` (solo) or `companies/{companyId}` (team).

### Security Rules Additions

Solo user asset data follows existing pattern — user can read/write under their own UID.

Company asset data rules (add inside existing companies match block):

- `sites/{siteId}/assets/{assetId}` — all members can read and create/update; only dispatchers/admins can delete
- `sites/{siteId}/floor_plans/{planId}` — all members can read and create/update; only dispatchers/admins can delete
- `sites/{siteId}/asset_service_history/{recordId}` — all members can read and create; **nobody can update or delete** (audit trail is immutable)
- `asset_type_config/{typeId}` — all members can read; admins always write; other members write only if `canManageAssetTypes` permission is set on their member document

### Firestore Indexes Needed

- assets: siteId + assetTypeId + complianceStatus
- assets: siteId + floorPlanId (for loading pins per floor plan)
- assets: barcode (for QR scanning lookup)
- asset_service_history: assetId + serviceDate desc (for history view)
- asset_service_history: siteId + serviceDate desc (for site report)

---

## 5. Pre-Built Asset Types & Default Checklists

The app ships with 12 built-in asset types. Each has a default checklist based on BS 5839 and common industry practice. Admins (or permitted engineers) can modify these and add custom checks on top.

### Fire Alarm Panel
- **Icon:** rectangle with grid lines | **Colour:** #1E3A5F (navy) | **Lifespan:** 15 years
- **Variants:** Conventional, Addressable, Analogue Addressable, Wireless
- **Checklist:** Visual inspection, check zone indicators/LEDs, battery voltage (number), charger output, check logged faults, earth fault test, sounder/beacon activation, check zone isolations removed

### Smoke Detector
- **Icon:** circle | **Colour:** #3B82F6 (blue) | **Lifespan:** 10 years
- **Variants:** Optical, Ionisation, Multi-sensor, Beam, Aspirating
- **Checklist:** Visual inspection (damage/dust/paint), functional test, panel indication, sounder/beacon activation, sensitivity check

### Heat Detector
- **Icon:** circle with H | **Colour:** #EF4444 (red) | **Lifespan:** 10 years
- **Variants:** Fixed Temperature, Rate of Rise, Combined
- **Checklist:** Visual inspection, functional test, panel indication, sounder/beacon activation

### Call Point (Manual)
- **Icon:** square with arrow | **Colour:** #DC2626 (bright red) | **Lifespan:** 15 years
- **Variants:** Conventional, Addressable, Resettable, Break Glass
- **Checklist:** Visual inspection (damage/obstruction/signage), functional test, panel indication, reset correctly, frangible element intact (if break glass)

### Sounder / Beacon / Visual Alarm
- **Icon:** speaker/bell | **Colour:** #F97316 (orange) | **Lifespan:** 15 years
- **Variants:** Sounder, Beacon, Combined Sounder/Beacon, Voice Alarm Speaker
- **Checklist:** Visual inspection, functional test, sound level adequate, dB reading at 1m (number)

### Fire Extinguisher
- **Icon:** extinguisher shape | **Colour:** #059669 (green) | **Lifespan:** 5yr discharge test, 20yr replacement
- **Variants:** CO2, Dry Powder, AFFF Foam, Water, Wet Chemical
- **Checklist:** Visual inspection (condition/corrosion), pressure gauge green, safety pin/tamper seal, instructions legible, signage, accessible, weight check (number kg), last discharge test date (text)

### Emergency Lighting
- **Icon:** lightbulb | **Colour:** #FBBF24 (yellow) | **Lifespan:** 10yr luminaire, 4yr battery
- **Variants:** Maintained, Non-maintained, Sustained, Combined
- **Checklist:** Visual inspection, functional test (simulate mains failure), 3-hour duration test (annual), light output adequate, charging indicator active

### Fire Door
- **Icon:** door shape | **Colour:** #8B5CF6 (purple) | **Lifespan:** N/A (maintenance-based)
- **Variants:** FD30, FD60, FD90, FD120
- **Checklist:** Door leaf condition, intumescent seals, smoke seals, self-closer operation, hinges secure, gaps within tolerance, signage correct, hold-open device (if fitted)

### AOV / Smoke Vent
- **Icon:** vent/fan | **Colour:** #06B6D4 (cyan) | **Lifespan:** 15 years
- **Variants:** Natural (AOV), Mechanical, Smoke Shaft
- **Checklist:** Visual inspection, open/close cycle, activation from local control, activation from fire panel, full open achieved, re-close correctly

### Sprinkler Head
- **Icon:** droplet | **Colour:** #0EA5E9 (sky blue) | **Lifespan:** 50yr standard, 20yr fast response
- **Variants:** Pendant, Upright, Sidewall, Concealed
- **Checklist:** Visual inspection (corrosion/paint/loading), correct orientation, clearance below (min 500mm), correct temperature rating, escutcheon/cover plate intact

### Fire Blanket
- **Icon:** blanket/cloth | **Colour:** #14B8A6 (teal) | **Lifespan:** 7 years
- **Variants:** Light Duty (kitchen), Heavy Duty (industrial)
- **Checklist:** Container condition, accessible/unobstructed, blanket undamaged/clean, signage visible, wall fixings secure

### Other / Custom Type
- **Icon:** configurable | **Colour:** configurable | **Lifespan:** user-defined
- **Variants:** user-defined
- **Checklist:** user-defined

---

## 6. Asset Register — Screens & Workflow

### 6.1 Site Asset Register Screen

Accessed from site detail, dispatched job detail, or floor plan view.

**Layout:** Header with site name, total assets, compliance summary (X pass, Y fail, Z untested). Filter bar (by type, status, floor, zone). Search (reference, barcode, make, model). Scrollable asset list.

**Each asset card:** Type icon (coloured by status), reference, type/variant, location, last service date/result, lifecycle warning badge.

**Actions:** Tap asset for detail, FAB to add asset, "View Floor Plans" button, "Generate Report" button.

### 6.2 Asset Detail Screen

Shows all asset information in sections: Identity (type, variant, make, model, serial, reference, barcode, photo), Location (floor plan pin preview, zone, description), Compliance (status badge, last service, next due, lifecycle progress bar, warranty status), Service History (chronological list, tappable for full detail).

**Actions:** Test This Asset, Edit, Scan Barcode, View on Floor Plan, Decommission.

### 6.3 Add/Edit Asset Screen

Form: asset type dropdown, variant dropdown (from type), make (autocomplete), model, serial number, reference (auto-suggested sequence), barcode (text or scan), zone, location description, install date, warranty expiry, expected lifespan (pre-filled from type default), photo, notes. After saving, option to place on floor plan.

---

## 7. Floor Plans — Screens & Interaction

### 7.1 Floor Plan List Screen

List of all floor plans for a site, ordered by sortOrder. Each shows thumbnail, name, asset count, compliance summary dots. Actions: tap to open, add new, reorder, edit name, delete.

### 7.2 Upload Floor Plan

Process: choose source (take photo, gallery, upload file/PDF), if PDF convert first page to image, enter name, image uploads to Firebase Storage, Firestore document created.

### 7.3 Interactive Floor Plan View

Displays floor plan image with asset pins overlaid using InteractiveViewer with a Stack.

**Pin appearance:** Small circle icon per asset type, coloured by compliance (green=pass, red=fail, grey=untested, faded=decommissioned).

**Tap a pin:** Bottom sheet with asset summary and actions (View Details, Test Now, Log Defect, View History).

**Long-press a pin:** Drag mode to reposition.

**Filter bar:** Filter visible pins by asset type or compliance status.

**Level switcher:** Tabs or dropdown to switch between floor plan levels.

### 7.4 Pin Placement Mode

Floor plan enters placement mode with a crosshair following finger/cursor. Tap to place. If creating new asset, Add Asset form opens with position pre-filled. If placing existing asset, position is updated. On web: mouse clicks for placement — ideal for office-based setup with printed drawings.

### 7.5 Floor Plan on Web Portal

Full interactivity on web: view, upload, place/move/remove pins with mouse, click pins for details, create assets directly from floor plan. Large site setup (e.g. hospital with 500 devices) is much more practical at a desk.

---

## 8. Asset Testing & Inspection Workflow

### 8.1 Starting a Test

Entry points: tap pin on floor plan, tap asset in register, scan QR/barcode, from jobsheet asset section.

### 8.2 Inspection Checklist Screen

Shows asset identity, then the checklist for this asset type. Each item has the label, description, and input by resultType (pass_fail buttons, number field, text field, yes_no buttons). Optional note per item. Overall result auto-calculated (any required fail = overall fail). Defect section appears on failure: severity (minor/major/critical), note, action (rectified/quote/replacement), photos.

### 8.3 What Happens on Save

1. ServiceRecord created in asset_service_history
2. Asset complianceStatus updated
3. Asset lastServiceDate/lastServiceBy updated
4. nextServiceDue calculated
5. Defect photos uploaded to Firebase Storage
6. If during a jobsheet, result added to job session for PDF summary
7. Floor plan pin colour updates immediately
8. Analytics event logged

### 8.4 Batch Testing

"Test All on This Floor" — sequential testing flow: shows first untested asset checklist, after save moves to next, progress indicator, skip button, summary at end.

---

## 9. QR / Barcode Scanning

### Package

`mobile_scanner` Flutter package — QR codes, barcodes (Code128, Code39, EAN), iOS and Android.

### Workflow

Tap "Scan" button, camera opens, code detected, search assets for matching barcode. If found: navigate to asset detail. If not found: prompt to create new asset with barcode pre-filled.

### Assigning Barcodes

During asset creation (scan or type), or from asset detail ("Scan Barcode" to assign/update).

### Web Portal

No camera scanning on web. Barcodes entered via text field. Web can display barcode value and generate QR code image for printing.

---

## 10. Asset Lifecycle Tracking

### Calculations

Age = today - installDate. Remaining = expectedLifespanYears - age. End of life approaching = remaining < 1 year. Warranty active = today < warrantyExpiry.

### Alerts

Asset detail: progress bar (green <70%, amber 70-90%, red >90%), warning text, warranty badge. Site register: "Approaching end of life" filter. Dispatch dashboard: warning when site has lifecycle alerts.

### Decommissioning

Reason dropdown (End of Life, Replaced, Damaged, Removed, Other), decommissionDate set, status to "decommissioned", pin becomes faded. Asset stays in register for audit trail, excluded from active compliance counts.

---

## 11. Jobsheet Integration — Auto-Generated Asset Summary

### During the Job

Jobsheet form includes "Site Assets" section with "Test Assets" button. Opens floor plan/asset list for linked site. Test results tagged with jobsheet ID. In-memory session tracks tested assets.

### In the PDF

New section "Asset Inspection Summary" — table with columns: Ref, Type, Location, Zone, Result, Defects. Summary line: "12 assets tested: 11 pass, 1 fail. 1 defect logged."

PDF generation queries asset_service_history for records with current jobsheetId.

---

## 12. Site Compliance Report PDF

### Contents

1. Cover page (site name, address, date, company, engineer)
2. Compliance summary (totals, pie/bar chart)
3. Floor plan pages (one per level, with pins and legend)
4. Asset register table (all assets with status, last service, lifecycle)
5. Defect summary (failed assets with severity, description, photos, action)
6. Lifecycle alerts (assets approaching/past end of life)
7. Service history summary (optional period overview)

Generated from site asset register via "Generate Report" button.

Future: available via customer portal.

---

## 13. Dispatch System Integration

### When Creating a Dispatched Job

Show compliance summary for selected site: "45 assets: 40 pass, 3 fail, 2 untested". Highlight warnings.

### On Engineer's Dispatched Job Detail

"Site Assets" section: total count, compliance summary, lifecycle warnings, "View Floor Plans" and "View Asset Register" buttons.

### After Completion

Dispatcher sees asset test summary from job detail on web. Jobsheet PDF includes asset inspection summary.

---

## 14. Web Portal Integration

Full asset register and floor plan functionality on the web portal. Add to sidebar navigation under "Sites" or as separate "Assets" item.

**Full editing on web:** view all assets, add/edit/delete, upload floor plans, place/move/remove pins with mouse, view details and history, configure asset types (admin), generate compliance reports.

Setting up large sites is much more practical at a desk — upload floor plan, click to place each pin while referencing a printed drawing.

---

## 15. Firebase Storage — Images & Photos

### Storage Structure

`{basePath}/sites/{siteId}/floor_plans/{planId}.jpg` for floor plan images.
`{basePath}/sites/{siteId}/assets/{assetId}/photo.jpg` for asset photos.
`{basePath}/sites/{siteId}/assets/{assetId}/defects/{recordId}_{index}.jpg` for defect photos.

### Storage Rules

Solo user files: read/write if authenticated as that user. Company files: read/write if authenticated (Firestore rules handle membership check; Storage rules can't easily query Firestore).

### Image Handling

Floor plan uploads: compress to max 2048px longest edge. Defect photos: compress similarly, JPEG. Use `cached_network_image` for in-app caching.

### Storage Costs

Negligible for small-medium usage. Well within Firebase free tier initially.

---

## 16. Permissions & Role-Based Access

### Asset Type Configuration Permission

New field on CompanyMember: `canManageAssetTypes` (bool, default false). Admins always have this. Dispatchers default true. Engineers default false — admins grant to specific engineers.

### Permission Matrix

| Action | Solo Engineer | Company Engineer | Dispatcher | Admin |
|--------|-------------|-----------------|------------|-------|
| View assets | Own sites | Company sites | Company sites | Company sites |
| Add/edit assets | Own sites | Company sites | Company sites | Company sites |
| Delete assets | Own sites | No | Yes | Yes |
| Test assets | Yes | Yes | Yes | Yes |
| Upload/manage floor plans | Own sites | Company sites | Company sites | Company sites |
| Place/move pins | Own sites | Company sites | Company sites | Company sites |
| Create custom asset types | Own | If permitted | If permitted | Always |
| Modify checklists | Own | If permitted | If permitted | Always |
| Decommission assets | Own sites | No | Yes | Yes |
| Generate compliance report | Own sites | Company sites | Company sites | Company sites |
| View service history | Own | Company | Company | Company |
| Delete service history | NEVER | NEVER | NEVER | NEVER |

**Service history is immutable.** No one can edit or delete records.

---

## 17. SQLite Schema Changes

For solo engineers (SQLite primary, Firestore backup):

Tables: `assets` (all Asset fields + lastModifiedAt), `floor_plans` (all FloorPlan fields + lastModifiedAt), `asset_service_history` (all ServiceRecord fields, checklistResults as JSON, defectPhotoUrls as JSON), `asset_type_config` (all AssetType fields, variants as JSON, defaultChecklist as JSON).

Company users do NOT use SQLite for assets — Firestore-primary with offline persistence.

Bump SQLite DB version and add migration.

---

## 18. Existing Code Changes

**job_form_screen.dart** — add "Site Assets" section with "Test Assets" button.

**signature_screen.dart / PDF generation** — generate asset inspection summary table.

**dispatched_job_detail_screen.dart** — add site asset summary and compliance warnings.

**create_job_screen.dart (dispatch)** — show compliance warnings when selecting site.

**dispatch_dashboard_screen.dart** — compliance alert badges on jobs.

**Web portal screens** — add asset register and floor plan views.

**database_helper.dart** — add SQLite tables and CRUD.

**firestore_sync_service.dart** — add sync for asset collections (solo users).

**analytics_service.dart** — add asset events.

**remote_config_service.dart** — add feature flag getters.

---

## 19. New Files to Create

```
lib/models/
  asset.dart, asset_type.dart, checklist_item.dart,
  checklist_result.dart, service_record.dart, floor_plan.dart

lib/services/
  asset_service.dart, floor_plan_service.dart,
  service_history_service.dart, asset_type_service.dart,
  lifecycle_service.dart, compliance_report_service.dart

lib/screens/assets/
  site_asset_register_screen.dart, asset_detail_screen.dart,
  add_edit_asset_screen.dart, asset_type_config_screen.dart,
  inspection_checklist_screen.dart, batch_testing_screen.dart,
  service_history_screen.dart, compliance_report_screen.dart

lib/screens/floor_plans/
  floor_plan_list_screen.dart, interactive_floor_plan_screen.dart,
  pin_placement_screen.dart, upload_floor_plan_screen.dart

lib/screens/scanner/
  barcode_scanner_screen.dart

lib/widgets/
  asset_pin.dart, compliance_badge.dart,
  lifecycle_progress_bar.dart, asset_summary_card.dart

lib/data/
  default_asset_types.dart
```

---

## 20. Analytics Events

| Event | Parameters | When |
|-------|-----------|------|
| asset_created | asset_type, site_id, has_barcode | New asset added |
| asset_tested | asset_type, result, site_id | Test completed |
| asset_defect_logged | asset_type, severity, has_photo | Defect recorded |
| asset_decommissioned | asset_type, reason, age_years | Asset decommissioned |
| floor_plan_uploaded | site_id, source_type | Floor plan added |
| floor_plan_pin_placed | site_id, asset_type | Pin placed |
| floor_plan_viewed | site_id, asset_count | Floor plan opened |
| barcode_scanned | found (bool), site_id | Scan attempted |
| batch_testing_started | site_id, asset_count | Batch started |
| batch_testing_completed | site_id, pass_count, fail_count | Batch finished |
| compliance_report_generated | site_id, asset_count, pass_rate | Report created |
| asset_type_created | type_name, is_custom | Custom type created |
| asset_type_checklist_modified | type_id, item_count | Checklist modified |

---

## 21. Remote Config Flags

| Key | Default | Purpose |
|-----|---------|---------|
| asset_register_enabled | false | Master toggle |
| floor_plans_enabled | false | Floor plan functionality |
| barcode_scanning_enabled | false | QR/barcode scanning |
| lifecycle_tracking_enabled | false | Lifecycle alerts |
| compliance_report_enabled | false | Site compliance reports |
| batch_testing_enabled | false | Batch testing flow |

---

## 22. Implementation Order

### Phase 1: Data Models & Asset CRUD (Week 1-2)
Create models, default_asset_types.dart, AssetService, AssetTypeService. Build register screen, add/edit screen, detail screen. SQLite tables, Firestore rules. Test CRUD.

### Phase 2: Floor Plans & Pins (Week 2-3)
FloorPlanService, upload screen, interactive view with InteractiveViewer and pin overlay, placement mode, pin tap bottom sheet, multi-level switching. Test upload, place, view.

### Phase 3: Testing & Inspection (Week 3-4)
ServiceHistoryService, inspection checklist screen, pass/fail/number/text inputs, defect logging with photos, auto status update, history on detail screen, batch testing. Test workflow.

### Phase 4: QR/Barcode Scanning (Week 4)
Add mobile_scanner, build scanner screen, barcode lookup, not-found flow, barcode field on asset form.

### Phase 5: Lifecycle Tracking (Week 4-5)
LifecycleService, progress bar widget, lifecycle section on detail, filters, decommission flow.

### Phase 6: Jobsheet Integration (Week 5)
Site Assets section on job form, link tests to jobsheet ID, PDF summary table generation.

### Phase 7: Dispatch Integration (Week 5-6)
Compliance summary on job creation, warnings on engineer job detail, badges on dashboard.

### Phase 8: Compliance Report & Asset Type Config (Week 6)
ComplianceReportService, report PDF generation, asset type config screen, permissions, Remote Config flags, analytics.

### Phase 9: Web Portal Integration (Week 6-7)
Asset register views on web, floor plan viewing/editing with mouse, asset CRUD on web, compliance warnings on web dashboard.

---

## 23. Testing Plan

### Unit Testing
Model serialisation, lifecycle calculations, compliance status from checklist, default checklist loading, barcode lookup.

### Integration Testing
Create asset, upload floor plan, place pin, test asset (verify record + status + pin colour), test during jobsheet (verify PDF), batch test, scan barcode, generate report, decommission, custom checklist.

### Multi-User Testing (Company)
Engineer A adds asset, Engineer B sees it. Engineer tests, others see updated status. Admin configures type, all see it. Permission grants/denials work. Web and mobile stay in sync.

### Floor Plan Testing
Pinch-to-zoom with correct pin positions. 50+ pins performance. Large image compression. Multi-level switching. Long-press drag. Desktop mouse interaction.

---

## Notes for Claude Code

1. **The basePath pattern is critical.** Every service and screen must accept either `users/{uid}` or `companies/{companyId}`. Don't hardcode.

2. **Pin positions use percentages (0.0-1.0), not pixels.** Same approach as existing PDF form certificate field positioning.

3. **InteractiveViewer is the foundation for floor plans.** Image in InteractiveViewer, Stack with Positioned pin widgets at xPercent * imageWidth, yPercent * imageHeight.

4. **Service history is append-only.** Never update or delete ServiceRecord documents. Firestore rules enforce this.

5. **Pre-built asset types are hardcoded in default_asset_types.dart.** Custom types stored in Firestore, merged with defaults at runtime.

6. **Follow existing patterns.** StatefulWidget + setState, ResponsiveListView, adaptive UI, Flutter Animate, Google Fonts Inter, Deep Navy + Coral palette.

7. **Firebase Storage requires the Blaze plan.**

8. **Update FEATURES.md and CHANGELOG.md** after implementation.

9. **mobile_scanner package** for QR/barcode scanning.

10. **Compress floor plan images** before upload — max 2048px longest edge, JPEG quality 80.
