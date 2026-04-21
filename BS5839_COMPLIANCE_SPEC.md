# FireThings — BS 5839-1:2025 Compliance Report Feature Specification

**Version:** 1.0
**Date:** April 2026
**Status:** Proposed — not yet implemented
**Standard reference:** BS 5839-1:2025 (effective 30 April 2025, supersedes BS 5839-1:2017)

**Purpose:** Transform the existing asset register and site compliance report into a standards-compliant BS 5839-1:2025 inspection and reporting system. This document is the authoritative implementation guide to be handed off to Claude Code. It builds on — and does not replace — the existing `ASSET_REGISTER_SPEC.md`, `PDF_REDESIGN_IMPLEMENTATION.md`, and `DEFECT_TO_QUOTE_SPEC.md`.

**Prerequisites:**

- Asset Register & Floor Plans (`ASSET_REGISTER_SPEC.md`) — **implemented**
- PDF Redesign (`PDF_REDESIGN_IMPLEMENTATION.md`) — **implemented** (reuse the `pdf_widgets/` library)
- Dispatch System — **implemented**
- Firebase Blaze plan — required (already enabled for asset register)

---

## Table of Contents

1. [Overview & Goals](#1-overview--goals)
2. [What Already Exists vs What's Missing](#2-what-already-exists-vs-whats-missing)
3. [Architecture](#3-architecture)
4. [Data Models](#4-data-models)
5. [Firestore Structure & Security Rules](#5-firestore-structure--security-rules)
6. [Updates to Existing Default Asset Types & Checklists](#6-updates-to-existing-default-asset-types--checklists)
7. [BS 5839 Compliance Service — Validation Logic](#7-bs-5839-compliance-service--validation-logic)
8. [Inspection Visit Workflow — Screens](#8-inspection-visit-workflow--screens)
9. [Variations Register — Screens](#9-variations-register--screens)
10. [Cause-and-Effect Testing — Screens](#10-cause-and-effect-testing--screens)
11. [Engineer Competency Tracking](#11-engineer-competency-tracking)
12. [BS 5839 Compliance Report PDF](#12-bs-5839-compliance-report-pdf)
13. [Updates to Existing Compliance Report](#13-updates-to-existing-compliance-report)
14. [Updates to BS 5839 Reference Guide Tool](#14-updates-to-bs-5839-reference-guide-tool)
15. [Updates to Battery Load Tester Tool](#15-updates-to-battery-load-tester-tool)
16. [Updates to Detector Spacing Calculator Tool](#16-updates-to-detector-spacing-calculator-tool)
17. [Jobsheet Integration](#17-jobsheet-integration)
18. [Dispatch System Integration](#18-dispatch-system-integration)
19. [Web Portal Integration](#19-web-portal-integration)
20. [Existing Code Changes](#20-existing-code-changes)
21. [New Files to Create](#21-new-files-to-create)
22. [SQLite Schema Changes](#22-sqlite-schema-changes)
23. [Remote Config Flags](#23-remote-config-flags)
24. [Analytics Events](#24-analytics-events)
25. [Permissions & Role-Based Access](#25-permissions--role-based-access)
26. [Implementation Order](#26-implementation-order)
27. [Testing Plan](#27-testing-plan)
28. [Notes for Claude Code](#28-notes-for-claude-code)

---

## 1. Overview & Goals

### What This Feature Does

Adds a BS 5839-1:2025 compliance layer on top of the existing asset register so engineers can produce inspection reports that meet the current British Standard for fire detection and fire alarm systems in non-domestic premises.

Key outcomes:

1. **Standards-compliant declarations.** Every site can be assigned a system category (L1–L5, P1/P2, M) and the app can produce a formal "satisfactory / satisfactory-with-variations / unsatisfactory" declaration against that category.
2. **Structured inspection visits.** Instead of ad-hoc asset tests, engineers run a typed visit (commissioning / routine service / modification / re-inspection) that groups asset tests, cause-and-effect tests, and documentation reviews into one signed record.
3. **Variations register.** Departures from the standard are recorded, with automatic detection of prohibited variations under Clause 6.6.
4. **Cause-and-effect testing.** Trigger-to-effect tests (e.g. MCP → AOV opens + sounders + door releases + ARC signal) are captured as first-class data, not free-text notes.
5. **Competency evidence.** Engineer qualifications and CPD are recorded and surfaced on every report, satisfying the new Clause 3.13 competent-person definition.
6. **Clause-level traceability.** All clause references in checklists, report sections, and certificates reflect the 2025 renumbering, not 2017.

### Who Uses It

- **Solo engineers** — producing BS 5839 reports for their own customers
- **Company engineers** — running inspections dispatched by the office
- **Dispatchers/admins** — configuring system categories, reviewing variations, issuing final reports
- **Responsible persons (site side)** — countersigning the report declaration (via shared link or email)

### Key Principles

1. **Additive, not a rewrite.** The existing asset register, service history, and compliance report all continue to work unchanged for extinguisher-only sites, fire door surveys, or non-fire-alarm inspections. BS 5839 mode is an additional gated feature.
2. **Gated behind `bs5839_mode_enabled` remote config flag** (default: false) so it can be rolled out to testers first.
3. **Clause 6.6 prohibited variations are hard-stops.** The app refuses to mark a visit "satisfactory" if a prohibited variation is present — it must be "unsatisfactory" with remediation required.
4. **Service history remains immutable.** Everything new also appends to the audit trail; nothing is retroactively editable.
5. **Reuse the existing `pdf_widgets/` library.** No new PDF widget primitives — the BS 5839 report is composed from `buildModernHeader`, `buildSectionCard`, `buildFieldGrid`, `buildModernTable`, `buildSignatureSection` etc.

---

## 2. What Already Exists vs What's Missing

### Already in the app

| Capability | Location | Status |
|---|---|---|
| Asset register with 12 built-in types | `lib/data/default_asset_types.dart`, `lib/screens/assets/` | ✅ Implemented |
| Inspection checklists per asset type | `ChecklistItem`, `ServiceRecord` | ✅ Implemented |
| Service history (immutable) | `asset_service_history/` Firestore subcollection | ✅ Implemented |
| Floor plans with interactive pins | `lib/screens/floor_plans/` | ✅ Implemented |
| Site compliance report PDF | `lib/services/compliance_report_service.dart` | ✅ Implemented |
| Defect logging with photos | `Defect`, defect bottom sheet | ✅ Implemented |
| Defect-to-quote workflow | `lib/models/quote.dart` (per spec) | ✅ Spec'd |
| BS 5839 Reference Guide | Tools grid | ✅ Implemented (needs 2017→2025 refresh) |
| Battery Load Tester | Tools grid | ✅ Implemented (references need updating) |
| PDF widget library | `lib/services/pdf_widgets/` | ✅ Implemented |

### Missing for BS 5839-1:2025 compliance

| Missing capability | Why it matters |
|---|---|
| System category declaration (L1–L5, P1/P2, M) per site | The whole compliance statement hinges on the declared category |
| Visit type (commissioning, service, modification, re-inspection) | Standard requires this on every certificate |
| Responsible person details per site | Needed for declaration signoff and ARC communications |
| ARC (Alarm Receiving Centre) details per site | Transmission details and 2025 transmission-time requirements |
| Variations register with Clause 6.6 prohibited-variation detection | Core 2025 requirement — absence of zone plan in multi-zone sleeping building is prohibited |
| Cause-and-effect test records | Required at handover per 2025 edition; currently only pass/fail on devices |
| Engineer competency / CPD record | Clause 3.13 (2025) formal definition |
| MCP 25% rotation tracker | Quarterly service inspections should cover 25% MCPs rolling |
| Battery load test voltage readings (structured) | Currently just pass/fail, needs actual readings |
| Sounder dB readings (required, not optional) | 2025 emphasis on audibility evidence |
| Cyber security / remote access checks on panels | New 2025 requirement |
| Zone plan verification as a site-level artefact | Its absence is a prohibited variation |
| Logbook review confirmation per visit | Must be evidenced |
| Transmission time to ARC | New 2025 requirement with maximum times |
| 5–7 month service tolerance | 2025 allows ±1 month around 6-month cycles |
| Responsible person countersignature | The engineer's signature alone doesn't meet the standard |
| Clause references in checklists | Existing checklist items don't cite clauses |

---

## 3. Architecture

### Data Ownership (follows existing pattern)

Solo engineer: `users/{uid}/sites/{siteId}/...`
Company user: `companies/{companyId}/sites/{siteId}/...`

All new collections and services accept a `basePath` parameter exactly as the asset register does.

### New Collections Under `{basePath}/sites/{siteId}/`

- `bs5839_config/current` — single document, one per site, holds system metadata
- `inspection_visits/{visitId}` — one document per inspection visit (wraps ServiceRecords)
- `variations/{variationId}` — site variations register
- `cause_effect_tests/{testId}` — cause-and-effect test results, linked to a visit
- `logbook_entries/{entryId}` — structured logbook (replaces free-text)

### New Collections Under `{basePath}/`

- `engineer_competency/current` — per-engineer qualification and CPD record

### Storage

- Firestore for all BS 5839 documents
- Firebase Storage for zone plans, panel photos, additional evidence uploads
- SQLite cache for solo users (same pattern as existing asset register)

---

## 4. Data Models

Create these under `lib/models/`. Follow existing conventions: `toJson`, `fromJson`, `copyWith`, explicit defaults, enum `.name` serialization.

### 4.1 `bs5839_system_config.dart` (NEW)

One per site. Created once, updated when system is modified.

```dart
enum Bs5839SystemCategory {
  l1, l2, l3, l4, l5,
  p1, p2,
  m,
}

enum ArcTransmissionMethod {
  none,           // Not connected to ARC
  digital,        // Redcare/DualCom
  ip,             // All-IP
  psdn,           // Legacy PSTN (being phased out)
  other,
}

class Bs5839SystemConfig {
  final String id;                           // always 'current'
  final String siteId;
  final Bs5839SystemCategory category;
  final String? categoryJustification;       // free text why this category chosen
  final String responsiblePersonName;
  final String? responsiblePersonRole;
  final String? responsiblePersonEmail;
  final String? responsiblePersonPhone;
  final DateTime? originalCommissionDate;
  final DateTime? lastModificationDate;
  final bool arcConnected;
  final ArcTransmissionMethod arcTransmissionMethod;
  final String? arcProvider;                 // e.g. "BT Redcare", "CSL DualCom"
  final String? arcAccountRef;
  final int? arcMaxTransmissionTimeSeconds;  // site's committed max (2025 req)
  final String? zonePlanUrl;                 // Firebase Storage — absence is prohibited variation
  final DateTime? zonePlanLastReviewedAt;
  final bool hasSleepingAccommodation;
  final int numberOfZones;
  final bool cyberSecurityRequired;          // true if panel has network/remote access
  final String? panelMake;
  final String? panelModel;
  final String? panelSerialNumber;
  final String standardVersion;              // default 'BS 5839-1:2025'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
}
```

### 4.2 `inspection_visit.dart` (NEW)

Wraps one engineer visit. Every ServiceRecord gets tagged with a visitId.

```dart
enum InspectionVisitType {
  commissioning,
  routineService,
  modification,
  reInspection,
  emergencyCallOut,
}

enum InspectionDeclaration {
  satisfactory,
  satisfactoryWithVariations,
  unsatisfactory,
  notDeclared,      // visit still in progress
}

class InspectionVisit {
  final String id;
  final String siteId;
  final String engineerId;
  final String engineerName;
  final InspectionVisitType visitType;
  final DateTime visitDate;
  final DateTime? completedAt;

  // Coverage tracking
  final List<String> mcpIdsTestedThisVisit;  // for 25% rolling rotation
  final bool allDetectorsTestedThisVisit;     // full coverage flag
  final List<String> serviceRecordIds;        // links to ServiceRecord docs

  // Documentation review checkpoints
  final bool logbookReviewed;
  final String? logbookReviewNotes;
  final bool zonePlanVerified;
  final String? zonePlanVariationNotes;
  final bool causeAndEffectMatrixProvided;   // for commissioning visits (2025 req)
  final bool cyberSecurityChecksCompleted;

  // Battery tests (one per power supply unit on site)
  final List<BatteryLoadTestReading> batteryTestReadings;

  // Overall system checks
  final bool arcSignallingTested;
  final int? arcTransmissionTimeMeasuredSeconds;
  final bool earthFaultTestPassed;
  final double? earthFaultReadingKOhms;

  // Declaration
  final InspectionDeclaration declaration;
  final String? declarationNotes;
  final DateTime? nextServiceDueDate;        // calculated, 5-7 month window

  // Signatures
  final String? engineerSignatureBase64;
  final String? responsiblePersonSignatureBase64;
  final String? responsiblePersonSignedName;
  final DateTime? responsiblePersonSignedAt;

  // Report linkage
  final String? reportPdfUrl;                // generated report stored in Storage
  final DateTime? reportGeneratedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
}

class BatteryLoadTestReading {
  final String powerSupplyAssetId;
  final double restingVoltage;
  final double loadedVoltage;
  final double? loadCurrentAmps;
  final bool passed;
  final String? notes;
}
```

### 4.3 `bs5839_variation.dart` (NEW)

```dart
enum VariationStatus {
  active,
  rectified,
  supersededByModification,
}

class Bs5839Variation {
  final String id;
  final String siteId;
  final String clauseReference;              // e.g. "16.2e", "25.2f"
  final String description;
  final String justification;                // why the variation exists
  final bool isProhibited;                   // Clause 6.6 auto-detected
  final String? prohibitedRuleId;            // links to ProhibitedVariationRule if auto
  final VariationStatus status;
  final String? agreedByName;                // user/purchaser rep
  final String? agreedByRole;
  final DateTime? dateAgreed;
  final String? loggedByEngineerId;
  final String? loggedByEngineerName;
  final DateTime loggedAt;
  final DateTime? rectifiedAt;
  final String? rectifiedByVisitId;
  final List<String> evidencePhotoUrls;
}
```

### 4.4 `cause_effect_test.dart` (NEW)

```dart
enum EffectType {
  sounderActivation,
  beaconActivation,
  voiceAlarmMessage,
  aovOpen,
  doorHoldOpenRelease,
  liftHomingGroundFloor,
  liftHomingOtherFloor,
  gasShutoff,
  ventilationShutdown,
  arcSignalFire,
  arcSignalFault,
  arcSignalPreAlarm,
  bmsSignal,
  sprinklerRelease,
  smokeCurtainDeploy,
  otherInterface,
}

class CauseEffectTest {
  final String id;
  final String siteId;
  final String visitId;
  final String triggerAssetId;               // e.g. MCP-001
  final String triggerAssetReference;
  final String triggerDescription;           // "Activate MCP on ground floor"
  final List<ExpectedEffect> expectedEffects;
  final DateTime testedAt;
  final String testedByEngineerId;
  final String testedByEngineerName;
  final bool overallPassed;
  final String? notes;
  final List<String> evidencePhotoUrls;
}

class ExpectedEffect {
  final String id;
  final EffectType effectType;
  final String? targetAssetId;
  final String? targetDescription;           // e.g. "Ground floor AOV", "Lift car 1"
  final String expectedBehaviour;            // "Opens within 60 seconds"
  final String? actualBehaviour;
  final int? measuredTimeSeconds;
  final bool passed;
  final String? notes;
}
```

### 4.5 `engineer_competency.dart` (NEW)

One document per engineer, under their own uid (company engineers mirror to `companies/{companyId}/members/{uid}/competency`).

```dart
enum QualificationType {
  fiaUnit1, fiaUnit2, fiaUnit3, fiaUnit4, fiaUnit5, fiaUnit6, fiaUnit7,
  bafeSp203_1,
  eca,
  nicei,
  cityAndGuilds,
  ipaf,
  pasma,
  cscs,
  other,
}

class Qualification {
  final String id;
  final QualificationType type;
  final String? customTypeName;              // when type == other
  final String issuingBody;
  final DateTime issuedDate;
  final DateTime? expiryDate;
  final String? certificateNumber;
  final String? evidenceFileUrl;
}

class CpdRecord {
  final String id;
  final DateTime date;
  final String topic;
  final double hours;
  final String? provider;
  final String? evidenceFileUrl;
  final String? notes;
}

class EngineerCompetency {
  final String id;                           // always 'current'
  final String engineerId;
  final String engineerName;
  final List<Qualification> qualifications;
  final List<CpdRecord> cpdRecords;
  final double totalCpdHoursLast12Months;    // computed at save time
  final DateTime? lastReviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### 4.6 `logbook_entry.dart` (NEW)

Supersedes free-text logbook; engineers still see a combined view.

```dart
enum LogbookEntryType {
  falseAlarm,
  realAlarm,
  systemFault,
  disablement,
  reinstatement,
  serviceVisit,
  modification,
  testOfSystem,
  other,
}

class LogbookEntry {
  final String id;
  final String siteId;
  final LogbookEntryType type;
  final DateTime occurredAt;
  final String description;
  final String? zoneOrDeviceReference;
  final String? cause;                       // false alarm category etc.
  final String? actionTaken;
  final String? loggedByName;
  final String? loggedByRole;                // responsible person or engineer
  final String? visitId;                     // if entered during a visit
  final DateTime createdAt;
}
```

### 4.7 Extend existing `ServiceRecord` (MODIFY)

Add these fields (non-breaking, default null):

```dart
final String? visitId;                       // links to InspectionVisit
final String? clauseReference;               // e.g. "25.4.3"
final double? sounderDbReadingAt1m;          // for sounder/beacon tests
final double? sounderDbReadingAtFurthestPoint;
final bool mcpTestedThisVisit;
final double? batteryVoltageResting;
final double? batteryVoltageUnderLoad;
final String? cyberSecurityNotes;            // for panels
```

### 4.8 Extend existing `Asset` (MODIFY)

Add:

```dart
final String? bs5839ClauseReference;         // dominant clause for this asset
final bool isInSleepingRoom;                 // flags heat-detector-in-sleeping-room prohibition
final bool hasRemoteAccess;                  // for panels, triggers cyber security checks
```

### 4.9 Extend existing `Site` (MODIFY)

Add:

```dart
final bool isBs5839Site;                     // true if bs5839_config/current exists
final String? lastVisitId;                   // quick pointer for dashboard
final DateTime? nextServiceDueDate;          // surfaced on dispatch dashboard
```

### 4.10 `prohibited_variation_rule.dart` (NEW — static data, not Firestore)

Defines the Clause 6.6 rules the compliance service checks automatically.

```dart
class ProhibitedVariationRule {
  final String id;
  final String clauseReference;
  final String description;
  final bool Function(Bs5839SystemConfig config, List<Asset> assets) check;
}

// See section 7 for the actual rule definitions.
```

---


## 5. Firestore Structure & Security Rules

### Collections

Under `{basePath}/sites/{siteId}/`:

- `bs5839_config/current` — singleton, all `Bs5839SystemConfig` fields
- `inspection_visits/{visitId}` — all `InspectionVisit` fields
- `variations/{variationId}` — all `Bs5839Variation` fields
- `cause_effect_tests/{testId}` — all `CauseEffectTest` fields
- `logbook_entries/{entryId}` — all `LogbookEntry` fields

Under `{basePath}/`:

- `engineer_competency/current` (solo) or under `companies/{companyId}/members/{uid}/competency/current` (company)

### Required Indexes

- `inspection_visits: siteId + visitDate desc`
- `inspection_visits: siteId + declaration + visitDate desc`
- `variations: siteId + status + isProhibited`
- `cause_effect_tests: visitId + testedAt desc`
- `cause_effect_tests: siteId + testedAt desc`
- `logbook_entries: siteId + occurredAt desc`
- `logbook_entries: siteId + type + occurredAt desc`

### Security Rules (additions)

Add inside the existing companies match block:

- `sites/{siteId}/bs5839_config/{docId}` — all members read; dispatchers/admins or engineers with `canEditBs5839Config` permission write
- `sites/{siteId}/inspection_visits/{visitId}` — all members read; engineers create; **only the creating engineer or admins can update while declaration == notDeclared; nobody can update once declared; nobody can delete**
- `sites/{siteId}/variations/{variationId}` — all members read; engineers create; only admins or the original logger can update; nobody can delete
- `sites/{siteId}/cause_effect_tests/{testId}` — all members read; engineers create; **immutable once created** (audit trail)
- `sites/{siteId}/logbook_entries/{entryId}` — all members read and create; only admins can delete (rare correction case)
- `members/{uid}/competency/{docId}` — the engineer themselves and admins read/write; other members read-only

For solo users, all paths under `users/{uid}/` follow the existing pattern (own-uid only).

### New Permissions on `CompanyMember`

```dart
final bool canEditBs5839Config;       // default: dispatchers + admins true
final bool canApproveVariations;      // default: admins only
final bool canIssueReports;           // default: dispatchers + admins true
final bool canRecordCpd;              // default: all engineers true (for self)
```

---

## 6. Updates to Existing Default Asset Types & Checklists

Edit `lib/data/default_asset_types.dart`. Bump default checklist versions and add new clause references. Existing custom checklists in Firestore are NOT overwritten — only the defaults change.

### 6.1 Fire Alarm Panel — additions

Add checklist items:

- **"ARC label present at panel"** (yes_no, required if `Bs5839SystemConfig.arcConnected`) — clause 33.2
- **"Remote access requires authentication"** (yes_no, required if `Asset.hasRemoteAccess`) — clause 22 (cyber security, new 2025)
- **"Tamper-resistant fittings on network connections"** (yes_no, required if `Asset.hasRemoteAccess`) — clause 22
- **"Cause and effect matrix on file"** (yes_no, required) — clause 33.4 (handover documentation)
- **"Battery resting voltage (V)"** (number, required) — clause 25.4
- **"Battery loaded voltage (V)"** (number, required) — clause 25.4
- **"Earth fault reading (kΩ)"** (number, optional) — clause 26.2

### 6.2 Smoke Detector — additions

- **"Stairway lobby coverage verified"** (yes_no, required for L1, L2 only) — clause 18.2 (new 2025 — automatic detection now required in stairway lobbies)
- Update existing clause refs to 2025 numbering throughout

### 6.3 Heat Detector — additions

- **"Not installed in a sleeping room"** (yes_no, required for L2, L3) — **HARD FAIL if no for L2/L3** — new 2025 prohibition
  - Implementation: when this fails for an asset on a site with `Bs5839SystemConfig.category == l2 || l3`, the visit cannot be declared satisfactory
- Add an `Asset.isInSleepingRoom` flag to the add/edit asset form for heat detectors and smoke detectors

### 6.4 Call Point — additions

- **"Mounting height 1.2m–1.6m"** (yes_no, required) — clause 20.2 (clarified tolerances in 2025)
- **"Maximum 45m to nearest call point on escape route"** (yes_no, required) — clause 20.2
- **"Tested in 25% rotation this visit"** (yes_no, internal — auto-set by visit workflow)

### 6.5 Sounder / Beacon — checklist changes

- Make existing **"dB reading at 1m"** field **required** (currently optional)
- Add **"dB reading at furthest reasonable point in coverage area"** (number, required) — clause 16
- Add **"Audibility verified ≥65 dB(A) or ambient + 5 dB(A)"** (yes_no, required) — clause 16.2
- Add **"Tone differentiation from other signals confirmed"** (yes_no, required if site has class change/lockdown alerts) — new 2025

### 6.6 Emergency Lighting — minor refresh

No BS 5839-1 changes (this is BS 5266) but add cross-reference note in description.

### 6.7 New asset type: ARC Signalling Equipment

Add a new built-in type:

- **Name:** ARC Signalling Equipment
- **Variants:** Digital Communicator (Redcare), DualCom IP, Pure IP, PSTN Legacy
- **Colour:** `#7C3AED` (violet)
- **Lifespan:** 10 years
- **Default checklist:**
  - Visual inspection
  - Path A signal transmission test (timed)
  - Path B signal transmission test (timed)
  - Fault signal transmission test
  - Reinstatement signal verified
  - Connection label present
  - Maximum signal transmission time within site commitment

### 6.8 New site-level "asset": Zone Plan

Treat zone plan as a non-physical inspectable item (new asset type, no floor plan position required, max 1 per site):

- **Name:** Zone Plan
- **Variants:** Wall-mounted, Digital, Both
- **Colour:** `#0891B2` (cyan)
- **Lifespan:** Maintenance-based (review annually)
- **Default checklist:**
  - Zone plan present and current
  - Matches as-installed system
  - Legible from approach to panel
  - Includes building orientation
  - Includes zone boundaries
  - Includes detector and call point locations

The compliance service treats absence of any "Zone Plan" asset on a multi-zone sleeping-risk site as a **prohibited variation** (Clause 6.6).

### 6.9 Default service interval

Change default `nextServiceDue` calculation in `LifecycleService` from "exactly 6 months" to a `nextServiceDueRangeStart` (5 months) and `nextServiceDueRangeEnd` (7 months). Display as a window in the UI: "Due 15 Sep – 15 Nov 2026".

---

## 7. BS 5839 Compliance Service — Validation Logic

Create `lib/services/bs5839_compliance_service.dart`. This is the brain of the feature.

### 7.1 Singleton structure

```dart
class Bs5839ComplianceService {
  static final Bs5839ComplianceService instance = Bs5839ComplianceService._();
  Bs5839ComplianceService._();

  // ... methods below
}
```

### 7.2 Core methods

```dart
Future<List<ProhibitedVariationFinding>> detectProhibitedVariations(
  String siteId,
);

Future<List<ComplianceIssue>> validateSiteCompliance(
  String siteId, {
  required Bs5839SystemConfig config,
  required List<Asset> assets,
  required List<Bs5839Variation> existingVariations,
});

Future<InspectionDeclaration> calculateDeclaration(
  String siteId,
  String visitId,
);

({DateTime start, DateTime end}) calculateNextServiceWindow(
  DateTime lastServiceDate,
);

Future<McpRotationStatus> getMcpRotationStatus(String siteId);

bool isServiceOverdue(DateTime? lastServiceDate);

Future<bool> isCompetencyCurrent(String engineerId);
```

### 7.3 Prohibited variation rules (Clause 6.6 — hard-coded)

Implement as a static list of `ProhibitedVariationRule`:

```dart
static final List<ProhibitedVariationRule> prohibitedRules = [
  ProhibitedVariationRule(
    id: 'no_zone_plan_multi_zone_sleeping',
    clauseReference: '6.6a',
    description: 'Zone plan absent in a multi-zone building with sleeping accommodation',
    check: (config, assets) {
      if (!config.hasSleepingAccommodation) return true; // not applicable, passes
      if (config.numberOfZones <= 1) return true;
      final hasZonePlan = assets.any((a) =>
        a.assetTypeId == 'zone_plan' &&
        a.complianceStatus != 'decommissioned'
      );
      return hasZonePlan;
    },
  ),
  ProhibitedVariationRule(
    id: 'no_arc_residential_care',
    clauseReference: '6.6b',
    description: 'ARC signalling absent in residential care premises',
    check: (config, assets) {
      // Residential care premises must have ARC signalling per 2025 update
      // This rule only fires if site type is residential care
      if (!_isResidentialCare(config)) return true;
      return config.arcConnected;
    },
  ),
  ProhibitedVariationRule(
    id: 'heat_detector_in_sleeping_room',
    clauseReference: '6.6c',
    description: 'Heat detector installed in a room used for sleeping (L2/L3)',
    check: (config, assets) {
      if (config.category != Bs5839SystemCategory.l2 &&
          config.category != Bs5839SystemCategory.l3) return true;
      final violatingHeatDetector = assets.any((a) =>
        a.assetTypeId == 'heat_detector' &&
        a.isInSleepingRoom == true &&
        a.complianceStatus != 'decommissioned'
      );
      return !violatingHeatDetector;
    },
  ),
  ProhibitedVariationRule(
    id: 'no_stairway_lobby_detection_l1_l2',
    clauseReference: '6.6d',
    description: 'Automatic detection absent from stairway lobbies (L1/L2)',
    check: (config, assets) {
      // Engineer must explicitly confirm via checklist; we read the latest
      // ServiceRecord for each detector and check the stairway lobby item
      // (implementation detail in service)
      // ...
      return true; // placeholder
    },
  ),
];
```

The service exposes `detectProhibitedVariations(siteId)` which runs every rule and returns findings. Findings are auto-inserted into the variations register with `isProhibited: true` and `prohibitedRuleId` set.

### 7.4 Declaration calculation logic

```dart
Future<InspectionDeclaration> calculateDeclaration(siteId, visitId) async {
  final visit = await getVisit(visitId);
  final config = await getSystemConfig(siteId);
  final variations = await getActiveVariations(siteId);
  final serviceRecords = await getServiceRecordsForVisit(visitId);

  // 1. Any prohibited variation = unsatisfactory
  if (variations.any((v) => v.isProhibited && v.status == VariationStatus.active)) {
    return InspectionDeclaration.unsatisfactory;
  }

  // 2. Any required-checklist-item failure that hasn't been remediated = unsatisfactory
  final criticalFailures = serviceRecords.where((r) =>
    r.overallResult == 'fail' &&
    r.defectSeverity == 'critical'
  );
  if (criticalFailures.isNotEmpty) return InspectionDeclaration.unsatisfactory;

  // 3. MCP rotation incomplete over rolling year = satisfactoryWithVariations + log variation
  final mcpStatus = await getMcpRotationStatus(siteId);
  if (!mcpStatus.allCoveredInLast12Months) {
    return InspectionDeclaration.satisfactoryWithVariations;
  }

  // 4. Logbook not reviewed = satisfactoryWithVariations
  if (!visit.logbookReviewed) return InspectionDeclaration.satisfactoryWithVariations;

  // 5. Cause and effect matrix not provided at commissioning = satisfactoryWithVariations
  if (visit.visitType == InspectionVisitType.commissioning &&
      !visit.causeAndEffectMatrixProvided) {
    return InspectionDeclaration.satisfactoryWithVariations;
  }

  // 6. Permissible variations exist = satisfactoryWithVariations
  if (variations.where((v) => !v.isProhibited && v.status == VariationStatus.active).isNotEmpty) {
    return InspectionDeclaration.satisfactoryWithVariations;
  }

  return InspectionDeclaration.satisfactory;
}
```

### 7.5 Service window calculation (5–7 month tolerance)

```dart
({DateTime start, DateTime end}) calculateNextServiceWindow(DateTime lastServiceDate) {
  return (
    start: DateTime(lastServiceDate.year, lastServiceDate.month + 5, lastServiceDate.day),
    end: DateTime(lastServiceDate.year, lastServiceDate.month + 7, lastServiceDate.day),
  );
}
```

Surface the window string in the UI as e.g. "Due between 15 Sep and 15 Nov 2026".

### 7.6 MCP 25% rotation tracking

```dart
class McpRotationStatus {
  final int totalMcps;
  final int testedThisVisit;
  final int testedInLast12Months;
  final List<String> mcpsNotTestedInLast12Months;
  final bool allCoveredInLast12Months;
  final double rollingPercentageThisQuarter;
}
```

Logic: query all assets of type `call_point` for the site, then query all service records in the last 12 months and check which MCPs were tested. Surface untested MCPs as a warning when starting a visit.

### 7.7 Competency check

```dart
Future<bool> isCompetencyCurrent(String engineerId) async {
  final competency = await getCompetency(engineerId);
  if (competency == null) return false;

  // No expired qualifications
  final hasExpired = competency.qualifications.any((q) =>
    q.expiryDate != null && q.expiryDate!.isBefore(DateTime.now())
  );
  if (hasExpired) return false;

  // Minimum 5 hours CPD in last 12 months (configurable via Remote Config)
  if (competency.totalCpdHoursLast12Months <
      RemoteConfigService.instance.bs5839MinCpdHoursPerYear) {
    return false;
  }

  return true;
}
```

If `false`, the report still generates but the cover page shows a yellow "Engineer competency requires CPD update" badge (does NOT block the report — that would be over-strict).

---

## 8. Inspection Visit Workflow — Screens

Create `lib/screens/bs5839/`.

### 8.1 `start_inspection_visit_screen.dart`

Entry point: from Site Asset Register (new "Start BS 5839 Visit" action card), or from a Dispatched Job detail (new "Start Compliance Visit" button).

Form:

- **Visit type** (segmented control): Commissioning / Routine Service / Modification / Re-Inspection / Emergency Call Out
- **Pre-visit checks displayed**:
  - System config status (red if not configured, with "Configure Now" button)
  - Last visit date and declaration
  - MCP rotation status
  - Active variations summary (count of permissible vs prohibited)
  - Engineer competency check result
- **Continue** button creates `InspectionVisit` with `declaration: notDeclared`, navigates to visit dashboard

### 8.2 `inspection_visit_dashboard_screen.dart`

Central hub during a visit. Shows progress checklist:

- ☐ System tests (asset checklist coverage % for this visit)
- ☐ Cause and effect tests (count completed)
- ☐ Battery load tests (count of PSUs tested)
- ☐ Logbook reviewed
- ☐ Zone plan verified
- ☐ Cyber security checks (if applicable)
- ☐ ARC signalling tested (if applicable)
- ☐ Any new variations recorded

Sections:

- **Quick actions row**: Test Assets (opens existing asset register), Run Cause & Effect, Add Variation, Review Logbook
- **Visit summary card**: visit type, started date, engineer, ongoing pass/fail counts
- **Pre-declaration checks**: list of compliance issues blocking declaration
- **"Complete & Sign" button**: enabled only when all required items complete

### 8.3 `bs5839_system_config_screen.dart`

Per-site setup, accessed from site detail "BS 5839 Configuration" or first-time during start-visit flow.

Form sections:

1. **System Category** — radio group with help text under each (L1: Life protection, full coverage; L2: Life protection, sleeping risk + risk-assessed; etc.). Free-text justification field.
2. **Responsible Person** — name (required), role, email, phone
3. **Building characteristics** — sleeping accommodation toggle, number of zones
4. **Panel details** — make, model, serial, has remote access toggle
5. **ARC connection** — connected toggle; if true: provider, account ref, transmission method (radio), max committed transmission time (seconds)
6. **Zone plan upload** — Firebase Storage upload (image or PDF)
7. **Save** — creates/updates `bs5839_config/current`

On save, the compliance service runs `detectProhibitedVariations` and shows a dialog if any are detected, with options to add justification or fix immediately.

### 8.4 `complete_visit_screen.dart`

End-of-visit summary and signature capture.

Sections:

1. **Visit summary** — read-only roll-up of everything tested
2. **Compliance issues** — any blockers must be resolved or acknowledged
3. **Variations review** — list of variations active for this site (permissible + prohibited)
4. **Calculated declaration** — shows the auto-calculated declaration with reasoning ("Satisfactory with variations because: 2 active permissible variations")
5. **Engineer signature pad**
6. **Responsible person signature** — three options:
   - Capture signature on device now
   - Send for email signature later (records placeholder)
   - Mark as "site representative declined to sign" (records reason)
7. **Generate report PDF** — calls the report service, uploads to Storage, marks visit as complete

---

## 9. Variations Register — Screens

### 9.1 `variations_register_screen.dart`

Per-site list view. Two tabs: **Active** and **History**.

Each variation card shows:

- Clause reference (badge)
- Description (truncated)
- Status badge (Active green / Active prohibited red / Rectified grey)
- Logged date and engineer
- Tap to open detail

FAB: "Add Variation"

Header banner if any prohibited variations are active: red bar reading "X prohibited variations require remediation — site cannot be declared satisfactory".

### 9.2 `add_edit_variation_screen.dart`

Form:

- **Clause reference** — text field with autocomplete from a clause list (see section 14 BS 5839 reference data)
- **Description** — multiline
- **Justification** — multiline (required)
- **Agreed by** — name and role (required for non-prohibited)
- **Date agreed** — date picker
- **Evidence photos** — multi-image upload to Firebase Storage
- **Status** — Active / Rectified / Superseded by Modification

When creating, the service runs the prohibited rules check on save. If the new variation matches a known prohibited pattern, `isProhibited` is auto-set to true and a warning dialog appears.

### 9.3 `prohibited_variations_alert_widget.dart`

Reusable widget shown on the inspection visit dashboard, the variations register, the site detail, and (if admin) the dispatch dashboard. Red banner with prohibited variation count and "View" action.

---

## 10. Cause-and-Effect Testing — Screens

### 10.1 `cause_effect_test_list_screen.dart`

Per-visit list of tests run. Each card shows:

- Trigger device reference
- Effect count (passed / total)
- Tested date and engineer
- Overall pass/fail badge

FAB: "New Cause & Effect Test"

### 10.2 `cause_effect_test_screen.dart`

Workflow screen. Three steps:

1. **Choose trigger device** — picker from site assets (typically MCP, smoke detector, heat detector, beam detector). Shows current asset reference and floor plan thumbnail.
2. **Define expected effects** — for each effect, choose `EffectType`, optional target asset, and expected behaviour text. Sensible defaults loaded from a `CauseEffectTemplateService` (see 10.3).
3. **Execute test** — for each expected effect, engineer captures actual behaviour, optional measured time, pass/fail toggle. Photo evidence supported per test. ARC signal effect type prompts for transmission time in seconds.

On save, creates `CauseEffectTest` document linked to the visit.

### 10.3 Template suggestions per category

Add `lib/data/cause_effect_templates.dart` — for each `Bs5839SystemCategory`, suggest typical expected effects when an MCP is the trigger:

```dart
const Map<Bs5839SystemCategory, List<EffectType>> mcpDefaultEffects = {
  Bs5839SystemCategory.l1: [
    EffectType.sounderActivation,
    EffectType.beaconActivation,
    EffectType.aovOpen,
    EffectType.doorHoldOpenRelease,
    EffectType.liftHomingGroundFloor,
    EffectType.arcSignalFire,
  ],
  // ...
};
```

This pre-fills the expected effects list — engineer can add/remove per site.

---

## 11. Engineer Competency Tracking

### 11.1 `competency_screen.dart`

Settings → Profile → Competency Record.

Sections:

- **Qualifications** — list with add/edit/delete. Each shows type, issuing body, issued date, expiry date (red if expired or expiring within 90 days)
- **CPD Records** — chronological list. Add new with date, topic, hours, optional provider and evidence file
- **Summary card** — "X total CPD hours in last 12 months" + competency status badge

### 11.2 Background calculation

When CPD records are added/edited/deleted, recalculate `totalCpdHoursLast12Months` and persist on the parent document. This avoids recomputing on every report generation.

### 11.3 Reminders

Workmanager job (12-hour interval, hooks into existing `NotificationService`):

- Notify if any qualification expires within 30 days
- Notify if `totalCpdHoursLast12Months` falls below threshold

---

## 12. BS 5839 Compliance Report PDF

Create `lib/services/bs5839_report_service.dart`. Reuse the existing `pdf_widgets/` library entirely — no new widget primitives required.

### 12.1 Data class

Add to `lib/services/pdf_generation_data.dart`:

```dart
class Bs5839ReportPdfData {
  final String siteName;
  final String siteAddress;
  final Bs5839SystemConfig config;
  final InspectionVisit visit;
  final List<ServiceRecord> serviceRecords;
  final List<Asset> assets;
  final List<CauseEffectTest> causeEffectTests;
  final List<Bs5839Variation> activeVariations;
  final List<LogbookEntry> recentLogbookEntries;
  final EngineerCompetency engineerCompetency;
  final List<FloorPlan> floorPlans;
  final List<DefectSummary> defects;
  final ComplianceCalculation calculation;

  // PDF design (reuses existing config)
  final PdfHeaderConfig headerConfig;
  final PdfFooterConfig footerConfig;
  final PdfColourScheme colourScheme;
  final PdfSectionStyleConfig sectionStyle;
  final PdfTypographyConfig typography;
  final Uint8List? logoBytes;
}
```

### 12.2 Page structure

Use `pw.MultiPage` with this section order:

**Page 1 — Cover & Declaration**

- `buildModernHeader` with document type "BS 5839-1:2025 Inspection Report"
- Large declaration banner: green "SATISFACTORY" / amber "SATISFACTORY WITH VARIATIONS" / red "UNSATISFACTORY" / grey "NOT DECLARED"
- `buildFieldGrid` with: site name, address, system category, visit type, visit date, engineer name, declaration, next service window
- Footer note: "This report has been issued in accordance with BS 5839-1:2025"

**Page 2 — System Identification**

- `buildSectionCard` "System Configuration":
  - Category and justification
  - Number of zones, sleeping accommodation y/n
  - Panel make/model/serial
  - ARC connected y/n, provider, transmission method, max transmission time
  - Original commission date, last modification date
- `buildSectionCard` "Responsible Person":
  - Name, role, email, phone
- `buildSectionCard` "Engineer Competency":
  - Engineer name, qualifications table (using `buildModernTable`)
  - Total CPD hours last 12 months
  - Competency status

**Page 3 — Inspection Scope**

- `buildSectionCard` "This Visit":
  - Visit type, date, duration
  - Coverage summary: X assets tested of Y total, Z% coverage
  - MCP rotation: tested this visit / rolling 12-month coverage
  - Logbook reviewed y/n
  - Zone plan verified y/n
  - Cause and effect matrix provided (commissioning only)
  - Cyber security checks (if applicable)
  - ARC signalling tested + measured transmission time

**Pages 4+ — Asset Inspection Results**

- `buildModernTable` with columns: Ref | Type | Location | Zone | Clause | Result | Defect
- Group by zone or floor plan for readability
- One row per ServiceRecord this visit

**Cause & Effect Test Results section**

- One `buildSectionCard` per CauseEffectTest:
  - Trigger device reference and description
  - `buildModernTable` of expected effects with columns: Effect Type | Target | Expected | Actual | Time (s) | Result

**Battery & Sounder Readings section**

- `buildModernTable` of battery readings: PSU Ref | Resting V | Loaded V | Load A | Result
- `buildModernTable` of sounder readings: Sounder Ref | dB at 1m | dB at furthest point | ≥65dB or ambient+5 | Result

**Variations Register section**

- TWO separate tables, clearly labelled:
  - **Permissible Variations** (yellow header) — Clause | Description | Justification | Agreed by | Date
  - **PROHIBITED VARIATIONS — NON-COMPLIANCE** (red header) — Clause | Description | Why prohibited | Logged
- If no variations: render "No variations recorded for this site" placeholder

**Defects & Remedial Actions section**

- `buildModernTable` with: Asset Ref | Severity | Description | Action | Timescale
- Photos: thumbnail grid grouped by asset

**Logbook Summary section**

- Last 90 days of logbook entries via `buildModernTable`: Date | Type | Description | Logged by

**Floor Plan pages**

- One page per floor plan (existing implementation, reused)
- Pin colours reflect declaration outcome for each asset this visit

**Final page — Declaration & Signatures**

- Full text declaration paragraph (template — see 12.3)
- `buildSignatureSection` with engineer + responsible person signatures
- Footer: "Reported against BS 5839-1:2025 — Standard version date: [date]"

### 12.3 Declaration paragraph templates

Store in `lib/data/declaration_templates.dart`:

```dart
const String satisfactoryDeclaration =
  'I confirm that the fire detection and fire alarm system installed at the '
  'above premises has been inspected and tested in accordance with the '
  'recommendations of BS 5839-1:2025 for a Category {category} system. '
  'The system was found to be in satisfactory condition at the time of inspection.';

const String satisfactoryWithVariationsDeclaration =
  'I confirm that the fire detection and fire alarm system installed at the '
  'above premises has been inspected and tested in accordance with the '
  'recommendations of BS 5839-1:2025 for a Category {category} system. '
  'The system was found to be in satisfactory condition at the time of inspection, '
  'subject to the variations from the standard recorded in the Variations Register.';

const String unsatisfactoryDeclaration =
  'I confirm that the fire detection and fire alarm system installed at the '
  'above premises has been inspected and tested in accordance with the '
  'recommendations of BS 5839-1:2025 for a Category {category} system. '
  'The system was found to be UNSATISFACTORY due to the issues set out in this '
  'report. The system does not currently meet the recommendations of the standard '
  'and remedial action is required.';
```

The report service substitutes `{category}` with the formatted category string at render time.

### 12.4 Storage

After PDF generation, upload to Firebase Storage at:
`{basePath}/sites/{siteId}/bs5839_reports/{visitId}.pdf`

Update `InspectionVisit.reportPdfUrl` and `reportGeneratedAt`.

### 12.5 Sharing

- Share sheet (existing pattern)
- Email to responsible person directly (uses `EmailService.sendBs5839Report` — new method, mirrors `sendQuote`)
- Customer portal link (placeholder — depends on future customer portal feature)

---

## 13. Updates to Existing Compliance Report

The existing `compliance_report_service.dart` should remain functional for non-BS-5839 reports (extinguisher only, fire blanket, ad-hoc inspections). Apply these refinements:

### 13.1 Add disclaimer

When `bs5839_mode_enabled` is on but the site has no `bs5839_config`, the existing compliance report PDF gets a footer line:

> "This is a general site compliance summary. It is not a BS 5839-1:2025 inspection report. To produce a BS 5839 report, configure the system category from the site detail screen."

### 13.2 Surface BS 5839 status on the existing report cover

If `bs5839_config` exists and there is at least one completed visit:

- Add badge to existing report cover: "BS 5839: [last declaration]"
- Add note: "For full BS 5839 reporting, generate a BS 5839 Inspection Report instead"

### 13.3 Routing

Asset Register screen "Report" action card becomes a sheet with two options:

- **Site Compliance Summary** (existing)
- **BS 5839-1:2025 Inspection Report** (new — disabled if no system config or no completed visits)

### 13.4 Data quality fixes (independent of BS 5839)

While in this code, fix these existing issues seen in the placeholder report PDF:

- Asset register table: location and zone columns should fall back to "—" or pull from floor plan name if location is empty (currently shows blank for many assets)
- Defect descriptions: validate min length (5 chars) on save to prevent "jdjjd"-style entries
- Service history: collapse same-asset same-day records into a single row with a "View attempts" expansion


---

## 14. Updates to BS 5839 Reference Guide Tool

The existing tool already references "BS 5839-1:2025" (per `FEATURES.md`) but the underlying data should be reviewed against the 2025 changes. Key updates required:

### 14.1 Data structure

Refactor the reference data into a versioned static dataset at `lib/data/bs5839_2025_reference.dart`:

```dart
class Bs5839Clause {
  final String reference;            // e.g. "16.2"
  final String title;
  final String body;                  // markdown-supported
  final String section;               // category for filtering
  final List<String> keywords;
  final bool changedFrom2017;         // surface a "NEW IN 2025" badge
  final String? renumberedFrom;       // old 2017 number if applicable
}

const String referenceDataVersion = '2025-04-30';
```

### 14.2 Categories to update

For each of the 11 existing categories in the reference guide, audit content for these 2025 changes. Add a "What changed in 2025" callout where applicable:

- **System Categories** — clarification of L1–L5 definitions; L4 lift shaft top detection; L2 sleeping risk consideration
- **Detectors** — heat detectors not allowed in sleeping rooms (L2/L3); smoke detectors preferred for sleeping areas
- **Detector Siting** — closely spaced beams now defined as <1m apart centre-to-centre; obstruction rules for items <250mm and gaps >300mm; ceiling void guidance update
- **Sounders** — tone differentiation requirement when shared with class change/lockdown alerts; class change up to 10 seconds duration
- **Call Points** — clarified mounting height (1.2m–1.6m) and distance tolerances
- **Cables & Wiring** — minor updates only
- **Ancillary Equipment** — cause and effect matrix at handover
- **Void Detection** — new ceiling void guidance
- **Testing & Maintenance** — service interval tolerance 5–7 months; MCP rotation 25%
- **Fire Detection Zones** — zone plan rules
- **False Alarm Management** — minor
- **NEW CATEGORY: Cyber Security** — remote access authentication, tamper-resistant fittings, network connection labelling
- **NEW CATEGORY: ARC Signalling** — maximum signal transmission times, fault reporting times, all-IP transition guidance

### 14.3 Renumbering map

Add a `clauseRenumberingMap` in the reference data so old certificates referencing 2017 clauses can be cross-referenced. Display in the reference guide's search results: "Looking for clause 25.2? In BS 5839-1:2025 this is now clause 26.2."

### 14.4 Bump remote config

Update `standards_data_version` flag default to the new release date, e.g. `'2026-04-21'`.

---

## 15. Updates to Battery Load Tester Tool

The existing tool implements `Cmin = 1.25 * ((T1 * I1) + (D * I2 * T2))` referencing BS 5839-1 Annex D / E. Updates:

### 15.1 Verify formula against 2025 annex

The 2025 update did not change the standby/alarm calculation principle, but the annex references have shifted. Update the calculation explanation text to reference the correct 2025 annex letter and clause.

### 15.2 Add ARC and remote access load consideration

If the panel has remote access (per `Bs5839SystemConfig.cyberSecurityRequired`), the standby current input should include a note: "Include any always-on network module current draw."

### 15.3 Result persistence

When used during an active inspection visit, allow the engineer to save the calculation result directly into the visit's `BatteryLoadTestReading` for the relevant PSU asset, rather than just displaying on screen.

---

## 16. Updates to Detector Spacing Calculator Tool

### 16.1 Add beam spacing input

Per 2025, add an optional input: "Closely spaced ceiling beams" — shows guidance text "Beams less than 1 metre apart centre-to-centre are treated as closely spaced. Use the lower of slab-to-slab or beam-to-beam spacing for detector calculations."

### 16.2 Stairway lobby preset

Add a quick preset button: "Stairway lobby (L1/L2)" which sets sensible defaults and explains that automatic detection is required in stairway lobbies for L1/L2 systems under the 2025 update.

### 16.3 Persist into asset register

When used during an active inspection visit, allow saving the calculation to the site as a "Design calculation" record (could be a simple note on the floor plan or attached to a panel asset).

---

## 17. Jobsheet Integration

### 17.1 Visit can be linked to a jobsheet

Add `jobsheetId` field to `InspectionVisit`. When a jobsheet is created from a dispatched job that uses BS 5839, link it.

### 17.2 Jobsheet PDF cross-reference

When a jobsheet has a linked BS 5839 visit:

- Add a section after the existing Asset Inspection Summary: "BS 5839-1:2025 Inspection Report"
- Show: visit type, declaration outcome, link/note that the full report is a separate PDF
- If declaration is unsatisfactory, render a red callout: "Site is currently non-compliant with BS 5839-1:2025 — see attached report"

### 17.3 Defect-to-quote integration

When a defect from a BS 5839 visit is converted to a quote (per `DEFECT_TO_QUOTE_SPEC.md`), the quote PDF should reference the variation/clause:

- Quote line item descriptions should auto-include clause reference if the defect was a checklist failure: "Replace heat detector in bedroom 3 (BS 5839-1:2025 cl. 18.2 — heat detectors no longer permitted in sleeping rooms)"
- Quote PDF defect summary section should show prohibited variation status if applicable

---

## 18. Dispatch System Integration

### 18.1 Site selection in Create Job

When selecting a site that has `bs5839_config`, show in the compliance summary:

- System category badge (L1, L2, etc.)
- Last visit declaration
- Next service due window
- Active prohibited variation count (red badge if >0)

### 18.2 Dispatched Job Detail

Add new section for engineers: "BS 5839 Inspection" with:

- "Start Compliance Visit" button (creates `InspectionVisit` linked to this job)
- Pre-visit checks (same as section 8.1)
- After visit complete: link to generated report PDF

### 18.3 Dispatch Dashboard

- Surface sites with overdue services (past the 7-month upper bound)
- Surface sites with active prohibited variations
- Filter chip: "BS 5839 sites only"

### 18.4 Engineer notifications

New FCM notifications via Cloud Functions:

- `onVisitDeclarationUnsatisfactory` — notify dispatcher when an engineer signs off as unsatisfactory
- `onProhibitedVariationDetected` — notify dispatcher when the system auto-detects a prohibited variation during a visit
- `onServiceWindowApproaching` — periodic check, notify dispatcher 30 days before service window opens for any site

---

## 19. Web Portal Integration

The web portal already supports asset register and floor plans. Extend with:

### 19.1 New routes

| Route | Screen |
|---|---|
| `/sites/:siteId/bs5839/config` | System configuration screen |
| `/sites/:siteId/bs5839/visits` | Visit list for site |
| `/sites/:siteId/bs5839/visits/:visitId` | Visit detail and report viewer |
| `/sites/:siteId/bs5839/variations` | Variations register |
| `/team/competency` | Team-wide competency matrix (admin only) |

### 19.2 Sidebar additions

Under existing "Sites" sidebar item, expand site context menu to include:

- BS 5839 Configuration
- Variations Register
- Inspection Visits

### 19.3 Office-side variation management

The web portal is the natural place for dispatchers/admins to:

- Review variations logged by engineers
- Mark variations as rectified once remedial work completes
- Approve quotes generated from BS 5839 defects

### 19.4 Report distribution from office

Web portal supports:

- Send BS 5839 report to responsible person via email
- Mark report as "issued"
- Track report acknowledgement

### 19.5 Team competency matrix

New screen at `/team/competency` for admins:

- Table of all engineers with: total qualifications, expired qualifications, CPD hours last 12 months, competency status badge
- Click engineer to view full record
- Bulk reminder sender for engineers with low CPD

---

## 20. Existing Code Changes

### Files to modify

| File | Changes |
|---|---|
| `lib/models/asset.dart` | Add `bs5839ClauseReference`, `isInSleepingRoom`, `hasRemoteAccess` fields with toJson/fromJson/copyWith updates |
| `lib/models/service_record.dart` | Add `visitId`, `clauseReference`, `sounderDbReadingAt1m`, `sounderDbReadingAtFurthestPoint`, `mcpTestedThisVisit`, `batteryVoltageResting`, `batteryVoltageUnderLoad`, `cyberSecurityNotes` |
| `lib/models/site.dart` | Add `isBs5839Site`, `lastVisitId`, `nextServiceDueDate` |
| `lib/models/defect.dart` | Already extended for `linkedQuoteId` per defect-to-quote spec; also add `bs5839ClauseReference` and `triggeredProhibitedRule` (bool) |
| `lib/models/company_member.dart` | Add `canEditBs5839Config`, `canApproveVariations`, `canIssueReports`, `canRecordCpd` permission booleans |
| `lib/data/default_asset_types.dart` | Update checklists per section 6; add ARC Signalling Equipment and Zone Plan as new built-in types |
| `lib/services/lifecycle_service.dart` | Replace single `nextServiceDue` calculation with window-based calculation (see section 7.5) |
| `lib/services/compliance_report_service.dart` | Add disclaimer, BS 5839 status badge, new routing per section 13 |
| `lib/services/asset_service.dart` | Asset add/edit needs to populate `isInSleepingRoom` for heat/smoke detectors |
| `lib/services/service_history_service.dart` | When ServiceRecord created during a visit, tag with visitId; trigger compliance recheck |
| `lib/services/pdf_generation_data.dart` | Add `Bs5839ReportPdfData` class |
| `lib/screens/assets/site_asset_register_screen.dart` | Add "Start BS 5839 Visit" action card; replace single Report action with menu |
| `lib/screens/assets/inspection_checklist_screen.dart` | Show clause references on checklist items; require structured battery and dB readings; flag heat-detector-in-sleeping-room as critical for L2/L3 |
| `lib/screens/sites/site_detail_screen.dart` | Add BS 5839 Configuration link; show declaration status if config exists |
| `lib/screens/dispatch/create_job_screen.dart` | Surface BS 5839 details in site compliance summary |
| `lib/screens/dispatch/dispatch_dashboard_screen.dart` | Surface prohibited variation alerts and overdue service alerts |
| `lib/screens/dispatch/dispatched_job_detail_screen.dart` | Add "Start Compliance Visit" button; link to generated report |
| `lib/screens/web/web_shell.dart` | Add new routes per section 19.1 |
| `lib/screens/web/web_site_detail_screen.dart` | Add expandable BS 5839 menu |
| `lib/services/database_helper.dart` | Add new SQLite tables (section 22); bump DB version |
| `lib/services/firestore_sync_service.dart` | Add sync for new collections; conflict resolution for visits |
| `lib/services/analytics_service.dart` | Add new events (section 24) |
| `lib/services/remote_config_service.dart` | Add new flags (section 23) |
| `lib/services/email_service.dart` | Add `sendBs5839Report` method |
| `lib/services/notification_service.dart` | Add competency reminder, service window approaching notifications |
| `functions/index.js` | Add `onVisitDeclarationUnsatisfactory`, `onProhibitedVariationDetected`, `scheduledServiceWindowCheck` Cloud Functions |
| `firestore.rules` | Add rules per section 5 |
| `firestore.indexes.json` | Add indexes per section 5 |
| `storage.rules` | Add rules for `bs5839_reports/` and `zone_plans/` paths |
| `lib/screens/tools/bs5839_reference_screen.dart` | Refresh data per section 14 |
| `lib/screens/tools/battery_load_tester_screen.dart` | Update annex refs and add visit-save option per section 15 |
| `lib/screens/tools/detector_spacing_screen.dart` | Add beam spacing and stairway lobby preset per section 16 |
| `lib/widgets/defect_bottom_sheet.dart` | Show clause reference if defect originates from BS 5839 checklist failure |
| `lib/data/bs5839_2025_reference.dart` | NEW — replaces existing inline reference data |
| `lib/data/cause_effect_templates.dart` | NEW — per-category default expected effects |
| `lib/data/declaration_templates.dart` | NEW — declaration paragraph templates |
| `lib/data/prohibited_variation_rules.dart` | NEW — Clause 6.6 rule definitions |
| `FEATURES.md` | Append new section "BS 5839-1:2025 Inspection Reports" mirroring the existing "Asset Register & Floor Plans" structure |
| `CHANGELOG.md` | Add entry for the BS 5839 release |

---

## 21. New Files to Create

```
lib/models/
  bs5839_system_config.dart
  inspection_visit.dart
  bs5839_variation.dart
  cause_effect_test.dart
  engineer_competency.dart
  logbook_entry.dart
  prohibited_variation_rule.dart
  battery_load_test_reading.dart
  expected_effect.dart
  qualification.dart
  cpd_record.dart

lib/services/
  bs5839_compliance_service.dart
  bs5839_system_config_service.dart
  inspection_visit_service.dart
  variation_service.dart
  cause_effect_service.dart
  competency_service.dart
  logbook_service.dart
  bs5839_report_service.dart

lib/screens/bs5839/
  start_inspection_visit_screen.dart
  inspection_visit_dashboard_screen.dart
  bs5839_system_config_screen.dart
  complete_visit_screen.dart
  variations_register_screen.dart
  add_edit_variation_screen.dart
  cause_effect_test_list_screen.dart
  cause_effect_test_screen.dart
  visit_history_screen.dart
  visit_detail_screen.dart
  logbook_screen.dart
  add_logbook_entry_screen.dart

lib/screens/competency/
  competency_screen.dart
  add_qualification_screen.dart
  add_cpd_record_screen.dart
  team_competency_matrix_screen.dart   (web admin)

lib/widgets/
  prohibited_variations_alert_widget.dart
  bs5839_declaration_badge.dart
  service_window_chip.dart
  competency_status_chip.dart
  visit_progress_checklist.dart

lib/data/
  bs5839_2025_reference.dart
  cause_effect_templates.dart
  declaration_templates.dart
  prohibited_variation_rules.dart
```

---

## 22. SQLite Schema Changes

For solo engineers (SQLite primary). Bump DB version to **18** (current is 17 per defect-to-quote spec).

```sql
CREATE TABLE bs5839_system_config (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  category TEXT NOT NULL,
  category_justification TEXT,
  responsible_person_name TEXT NOT NULL,
  responsible_person_role TEXT,
  responsible_person_email TEXT,
  responsible_person_phone TEXT,
  original_commission_date TEXT,
  last_modification_date TEXT,
  arc_connected INTEGER NOT NULL,
  arc_transmission_method TEXT,
  arc_provider TEXT,
  arc_account_ref TEXT,
  arc_max_transmission_time_seconds INTEGER,
  zone_plan_url TEXT,
  zone_plan_last_reviewed_at TEXT,
  has_sleeping_accommodation INTEGER NOT NULL,
  number_of_zones INTEGER NOT NULL,
  cyber_security_required INTEGER NOT NULL,
  panel_make TEXT,
  panel_model TEXT,
  panel_serial_number TEXT,
  standard_version TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  created_by TEXT NOT NULL,
  updated_by TEXT NOT NULL,
  last_modified_at TEXT NOT NULL
);

CREATE INDEX idx_bs5839_config_site ON bs5839_system_config(site_id);

CREATE TABLE inspection_visits (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  engineer_id TEXT NOT NULL,
  engineer_name TEXT NOT NULL,
  visit_type TEXT NOT NULL,
  visit_date TEXT NOT NULL,
  completed_at TEXT,
  mcp_ids_tested_this_visit TEXT,        -- JSON array
  all_detectors_tested_this_visit INTEGER NOT NULL DEFAULT 0,
  service_record_ids TEXT,                -- JSON array
  logbook_reviewed INTEGER NOT NULL DEFAULT 0,
  logbook_review_notes TEXT,
  zone_plan_verified INTEGER NOT NULL DEFAULT 0,
  zone_plan_variation_notes TEXT,
  cause_and_effect_matrix_provided INTEGER NOT NULL DEFAULT 0,
  cyber_security_checks_completed INTEGER NOT NULL DEFAULT 0,
  battery_test_readings TEXT,             -- JSON array
  arc_signalling_tested INTEGER NOT NULL DEFAULT 0,
  arc_transmission_time_measured_seconds INTEGER,
  earth_fault_test_passed INTEGER NOT NULL DEFAULT 0,
  earth_fault_reading_kohms REAL,
  declaration TEXT NOT NULL,
  declaration_notes TEXT,
  next_service_due_date TEXT,
  engineer_signature_base64 TEXT,
  responsible_person_signature_base64 TEXT,
  responsible_person_signed_name TEXT,
  responsible_person_signed_at TEXT,
  report_pdf_url TEXT,
  report_generated_at TEXT,
  jobsheet_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_modified_at TEXT NOT NULL
);

CREATE INDEX idx_visits_site_date ON inspection_visits(site_id, visit_date DESC);

CREATE TABLE bs5839_variations (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  clause_reference TEXT NOT NULL,
  description TEXT NOT NULL,
  justification TEXT NOT NULL,
  is_prohibited INTEGER NOT NULL DEFAULT 0,
  prohibited_rule_id TEXT,
  status TEXT NOT NULL,
  agreed_by_name TEXT,
  agreed_by_role TEXT,
  date_agreed TEXT,
  logged_by_engineer_id TEXT,
  logged_by_engineer_name TEXT,
  logged_at TEXT NOT NULL,
  rectified_at TEXT,
  rectified_by_visit_id TEXT,
  evidence_photo_urls TEXT,               -- JSON array
  last_modified_at TEXT NOT NULL
);

CREATE INDEX idx_variations_site_status ON bs5839_variations(site_id, status);
CREATE INDEX idx_variations_prohibited ON bs5839_variations(site_id, is_prohibited);

CREATE TABLE cause_effect_tests (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  visit_id TEXT NOT NULL,
  trigger_asset_id TEXT NOT NULL,
  trigger_asset_reference TEXT NOT NULL,
  trigger_description TEXT,
  expected_effects TEXT NOT NULL,         -- JSON array of ExpectedEffect
  tested_at TEXT NOT NULL,
  tested_by_engineer_id TEXT NOT NULL,
  tested_by_engineer_name TEXT NOT NULL,
  overall_passed INTEGER NOT NULL,
  notes TEXT,
  evidence_photo_urls TEXT                -- JSON array
);

CREATE INDEX idx_ce_tests_visit ON cause_effect_tests(visit_id);
CREATE INDEX idx_ce_tests_site ON cause_effect_tests(site_id, tested_at DESC);

CREATE TABLE engineer_competency (
  id TEXT PRIMARY KEY,
  engineer_id TEXT NOT NULL UNIQUE,
  engineer_name TEXT NOT NULL,
  qualifications TEXT NOT NULL,           -- JSON array
  cpd_records TEXT NOT NULL,              -- JSON array
  total_cpd_hours_last_12_months REAL NOT NULL DEFAULT 0,
  last_reviewed_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_modified_at TEXT NOT NULL
);

CREATE TABLE logbook_entries (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  type TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  description TEXT NOT NULL,
  zone_or_device_reference TEXT,
  cause TEXT,
  action_taken TEXT,
  logged_by_name TEXT,
  logged_by_role TEXT,
  visit_id TEXT,
  created_at TEXT NOT NULL,
  last_modified_at TEXT NOT NULL
);

CREATE INDEX idx_logbook_site ON logbook_entries(site_id, occurred_at DESC);
```

Add to existing tables (use `ALTER TABLE` in `_onUpgrade`):

```sql
ALTER TABLE assets ADD COLUMN bs5839_clause_reference TEXT;
ALTER TABLE assets ADD COLUMN is_in_sleeping_room INTEGER;
ALTER TABLE assets ADD COLUMN has_remote_access INTEGER;

ALTER TABLE asset_service_history ADD COLUMN visit_id TEXT;
ALTER TABLE asset_service_history ADD COLUMN clause_reference TEXT;
ALTER TABLE asset_service_history ADD COLUMN sounder_db_reading_at_1m REAL;
ALTER TABLE asset_service_history ADD COLUMN sounder_db_reading_at_furthest_point REAL;
ALTER TABLE asset_service_history ADD COLUMN mcp_tested_this_visit INTEGER;
ALTER TABLE asset_service_history ADD COLUMN battery_voltage_resting REAL;
ALTER TABLE asset_service_history ADD COLUMN battery_voltage_under_load REAL;
ALTER TABLE asset_service_history ADD COLUMN cyber_security_notes TEXT;

ALTER TABLE saved_sites ADD COLUMN is_bs5839_site INTEGER;
ALTER TABLE saved_sites ADD COLUMN last_visit_id TEXT;
ALTER TABLE saved_sites ADD COLUMN next_service_due_date TEXT;
```

Company users do NOT use SQLite for these new collections — they use Firestore directly with offline persistence (same pattern as existing asset register).

---

## 23. Remote Config Flags

Add these flags to `RemoteConfigService` and Firebase Console (defaults shown):

| Flag | Default | Purpose |
|---|---|---|
| `bs5839_mode_enabled` | `false` | Master toggle for entire BS 5839-1:2025 feature set |
| `bs5839_visits_enabled` | `false` | Inspection visit workflow |
| `bs5839_variations_register_enabled` | `false` | Variations register screens |
| `bs5839_cause_effect_enabled` | `false` | Cause-and-effect testing screens |
| `bs5839_competency_tracking_enabled` | `false` | Engineer competency screens |
| `bs5839_report_enabled` | `false` | BS 5839 report PDF generation |
| `bs5839_logbook_structured_enabled` | `false` | Structured logbook entries |
| `bs5839_min_cpd_hours_per_year` | `5.0` | Threshold for competency status |
| `bs5839_service_window_warning_days` | `30` | Days before service window opens to warn |
| `bs5839_reference_data_version` | `'2025-04-30'` | Version of cached reference data |

Tester targeting via the existing `dispatch_tester` user property pattern, or add a new `bs5839_tester` property if you want separate cohorts.

---

## 24. Analytics Events

Add to `AnalyticsService` (mirroring existing event method patterns):

| Event | Parameters | When |
|---|---|---|
| `bs5839_config_created` | site_id, category | First-time config saved for a site |
| `bs5839_config_updated` | site_id, category, field_changed | Config edited |
| `bs5839_visit_started` | site_id, visit_type, engineer_id | New visit created |
| `bs5839_visit_completed` | site_id, visit_id, declaration, duration_minutes | Visit declared and signed |
| `bs5839_variation_logged` | site_id, clause, is_prohibited | New variation added |
| `bs5839_prohibited_variation_detected` | site_id, rule_id, clause | Auto-detection fired |
| `bs5839_variation_rectified` | site_id, variation_id, days_active | Variation marked rectified |
| `bs5839_cause_effect_test_run` | site_id, visit_id, trigger_type, effect_count, passed | C&E test saved |
| `bs5839_report_generated` | site_id, visit_id, declaration | Report PDF created |
| `bs5839_report_emailed` | site_id, visit_id, recipient_count | Report sent via email |
| `competency_qualification_added` | engineer_id, qualification_type | Qualification logged |
| `competency_cpd_record_added` | engineer_id, hours, topic | CPD entry saved |
| `competency_status_warning` | engineer_id, reason | Background check fired warning |
| `bs5839_service_overdue_alert` | site_id, days_overdue | Service window passed |
| `logbook_entry_added` | site_id, type, by_role | Logbook entry created |
| `bs5839_reference_searched` | search_term, category | Reference guide search (existing tool, adds tracking) |

Total new events: 16.

---

## 25. Permissions & Role-Based Access

Add to `CompanyMember` model (defaults in parens):

- `canEditBs5839Config` (Admin: true, Dispatcher: true, Engineer: false but admin-grantable)
- `canApproveVariations` (Admin: true, Dispatcher: false, Engineer: false)
- `canIssueReports` (Admin: true, Dispatcher: true, Engineer: true)
- `canRecordCpd` (everyone: true — for self only)
- `canViewTeamCompetency` (Admin: true, Dispatcher: true, Engineer: false)

### Permission Matrix

| Action | Solo | Engineer (company) | Dispatcher | Admin |
|---|---|---|---|---|
| Configure BS 5839 system | Own sites | If granted | Yes | Yes |
| Start inspection visit | Own | Yes | Yes | Yes |
| Sign off declaration | Own | Yes | Yes | Yes |
| Add variation | Own | Yes | Yes | Yes |
| Mark variation rectified | Own | If granted | If granted | Yes |
| Run cause & effect tests | Own | Yes | Yes | Yes |
| Issue (email) report | Own | Yes | Yes | Yes |
| Edit own competency | Yes | Yes | Yes | Yes |
| View team competency | N/A | No | Yes | Yes |
| Edit other engineer competency | N/A | No | No | Yes |
| Delete inspection visit | NEVER | NEVER | NEVER | NEVER |
| Delete variation | NEVER | NEVER | NEVER | NEVER |
| Delete cause & effect test | NEVER | NEVER | NEVER | NEVER |

All audit trail data is immutable. Mistakes are corrected by adding new records (e.g. a re-inspection visit that supersedes the prior one), not by editing.

---

## 26. Implementation Order

Roughly 8 weeks of work, split into phases that ship behind separate feature flags so each can be released for tester feedback independently.

### Phase 1 — Foundation (Week 1)

- All new data models in `lib/models/`
- SQLite schema updates and migrations (DB v18)
- Firestore security rules and indexes
- Storage rules
- New permission booleans on `CompanyMember`
- Static data files: `bs5839_2025_reference.dart`, `prohibited_variation_rules.dart`, `declaration_templates.dart`, `cause_effect_templates.dart`
- Default asset type updates (section 6)
- Remote Config flags

### Phase 2 — System Configuration (Week 2)

- `bs5839_system_config_service.dart`
- `bs5839_system_config_screen.dart`
- Site detail integration (BS 5839 Configuration link)
- Zone plan upload to Firebase Storage
- Auto-detection of prohibited variations on save

### Phase 3 — Compliance Validation (Week 2-3)

- `bs5839_compliance_service.dart` with all rules and calculations
- Service window calculation update in `LifecycleService`
- MCP rotation tracker
- Unit tests for every prohibited rule
- Unit tests for declaration calculation

### Phase 4 — Variations Register (Week 3)

- `variation_service.dart`
- `variations_register_screen.dart`
- `add_edit_variation_screen.dart`
- `prohibited_variations_alert_widget.dart`

### Phase 5 — Inspection Visit Workflow (Week 4)

- `inspection_visit_service.dart`
- `start_inspection_visit_screen.dart`
- `inspection_visit_dashboard_screen.dart`
- `complete_visit_screen.dart`
- `visit_history_screen.dart`, `visit_detail_screen.dart`
- Asset register integration ("Start BS 5839 Visit" action card)
- Inspection checklist screen updates (clause refs, structured readings)
- Tag ServiceRecords with visitId

### Phase 6 — Cause & Effect Testing (Week 5)

- `cause_effect_service.dart`
- `cause_effect_test_list_screen.dart`
- `cause_effect_test_screen.dart`
- Templates by category integration

### Phase 7 — Competency Tracking (Week 5-6)

- `competency_service.dart`
- `competency_screen.dart`
- `add_qualification_screen.dart`, `add_cpd_record_screen.dart`
- Background reminders via Workmanager
- Web team competency matrix (admin)

### Phase 8 — BS 5839 Report PDF (Week 6-7)

- `Bs5839ReportPdfData` class
- `bs5839_report_service.dart` using existing `pdf_widgets/` library
- Report storage in Firebase Storage
- Existing compliance report disclaimer + routing
- Email distribution via `EmailService.sendBs5839Report`

### Phase 9 — Tool Updates (Week 7)

- BS 5839 Reference Guide data refresh
- Battery Load Tester annex refs and visit-save
- Detector Spacing Calculator beam spacing and presets

### Phase 10 — Dispatch & Web Integration (Week 7-8)

- Dispatch dashboard alerts
- Create Job and Job Detail BS 5839 surfaces
- Web routes and screens
- Office-side variation management workflow
- Cloud Functions for declaration and overdue notifications

### Phase 11 — Logbook & Polish (Week 8)

- Structured logbook screens
- Migration prompt for any free-text logbook content
- Documentation: update `FEATURES.md`, `CHANGELOG.md`
- Final QA pass

---

## 27. Testing Plan

### Unit Tests

- All new model serialisation (toJson/fromJson round-trip)
- Every `ProhibitedVariationRule.check` function with positive and negative cases
- `Bs5839ComplianceService.calculateDeclaration` covering all branches:
  - All clean → satisfactory
  - Permissible variation present → satisfactoryWithVariations
  - Prohibited variation present → unsatisfactory
  - Critical defect → unsatisfactory
  - MCP rotation incomplete → satisfactoryWithVariations
  - Logbook not reviewed → satisfactoryWithVariations
  - Cause and effect matrix missing on commissioning → satisfactoryWithVariations
- Service window calculation edge cases (month boundaries, leap years)
- MCP rotation rolling 12-month calculation
- Competency status calculation including expired qualifications

### Integration Tests

- End-to-end visit: configure system → start visit → test assets → run C&E tests → log variation → complete and sign → generate report
- Heat detector in sleeping room blocks satisfactory declaration on L2 site
- Adding zone plan resolves prohibited variation
- Variation rectification by re-inspection visit
- Solo engineer flow (SQLite) and company engineer flow (Firestore) both produce identical reports
- Offline visit completion syncs correctly when back online
- Web portal report generation matches mobile output

### Visual / PDF Tests

- BS 5839 report PDF for each declaration outcome (satisfactory, satisfactory with variations, unsatisfactory, not declared)
- Each report style preset applied (Modern, Classic, Minimal, Bold)
- Personal vs company branding both render correctly
- Empty states: site with no variations, no cause & effect tests, no logbook entries
- Long content: site with 100+ assets, 20+ variations, 50+ cause & effect tests
- Multi-page floor plans render correctly
- Signatures (engineer + responsible person) appear correctly
- Photo evidence (defect photos, variation photos, C&E photos) render as thumbnails

### Multi-User / Company Tests

- Engineer A starts visit, Engineer B sees it in progress
- Engineer completes visit, dispatcher gets notification
- Prohibited variation auto-detected, dispatcher gets notification
- Admin marks variation rectified, all team see status change
- Company branding applied to BS 5839 report when generated by company user

### Cross-Platform

- Android visit creation and report generation
- iOS visit creation and report generation
- Web (Chrome) office-side review and report distribution
- Desktop (Windows/macOS) report generation

### Regression

- Existing compliance report still works for non-BS 5839 sites
- Existing asset register, floor plans, and service history unchanged
- Existing jobsheet generation unchanged
- Existing dispatch flows unchanged when `bs5839_mode_enabled` is false

---

## 28. Notes for Claude Code

1. **Read the existing specs first.** Particularly `ASSET_REGISTER_SPEC.md` (architecture, basePath pattern, immutability rules) and `PDF_REDESIGN_IMPLEMENTATION.md` (widget library to reuse). This BS 5839 spec assumes both are fully implemented.

2. **The `basePath` pattern is non-negotiable.** Every new service must accept `users/{uid}` or `companies/{companyId}` exactly like the asset register does. Do not hardcode paths.

3. **All new audit data is immutable.** `InspectionVisit` once declared, `Bs5839Variation` once logged, `CauseEffectTest` always — these are never edited or deleted. Corrections happen via new records.

4. **Reuse PDF widgets.** Do NOT introduce new PDF widget primitives. The BS 5839 report is a composition of `buildModernHeader`, `buildSectionCard`, `buildFieldGrid`, `buildModernTable`, `buildSignatureSection`. If something genuinely doesn't fit, add it to the shared library, not as a one-off.

5. **Prohibited variation detection runs in two places:**
   (a) When `bs5839_system_config` is saved — full sweep
   (b) When a `ServiceRecord` is created — incremental check on the affected asset
   Avoid running the full sweep on every asset edit; it's expensive.

6. **Declaration calculation is pure.** Make it a pure function over its inputs so it can be unit tested without Firestore. Inject the data, return the declaration.

7. **Static data over Firestore.** Prohibited rules, declaration templates, cause-and-effect templates, the BS 5839 reference dataset all live in Dart files, not Firestore. They version-bump with app releases. Use Remote Config only for the version string and feature flags.

8. **Firestore writes during a visit can be heavy.** When completing a visit, batch the final updates (visit document + service history flush + report URL + site lastVisitId update) into a single `WriteBatch`.

9. **Cyber security checklist items only render when relevant.** Don't show the cyber security checklist on a panel asset unless `Asset.hasRemoteAccess` is true. Same for ARC items unless `Bs5839SystemConfig.arcConnected` is true.

10. **Compliance recheck on asset edits.** When an asset is added/edited (especially adding a heat detector or toggling `isInSleepingRoom`), trigger a background `detectProhibitedVariations` call for the site so the dashboard stays accurate.

11. **Service window display.** Always show the window ("Due 15 Sep – 15 Nov 2026"), never just the midpoint. Engineers and dispatchers need to see the tolerance.

12. **MCP rotation must be rolling.** Don't reset on calendar quarter or year — track which MCPs have been tested in the trailing 12 months from any given query date.

13. **Responsible person signature is optional but tracked.** Three states: signed in person, sent for email signature (placeholder + reminder), declined to sign with reason. Don't block report generation on signature absence — but show clearly on the report which state applies.

14. **Email distribution via existing `EmailService` pattern.** The `sendBs5839Report` method should mirror `sendQuote` from the defect-to-quote spec — same signature shape, same attachment pattern.

15. **Update `FEATURES.md` after implementation.** Add a full "BS 5839-1:2025 Inspection Reports" section mirroring the structure of the existing "Asset Register & Floor Plans" section, including the analytics events table and remote config flag table.

16. **Update `CHANGELOG.md`** with the BS 5839 release version, listing each phase as it lands.

17. **Standard reference attribution.** Every BS 5839 report PDF must footer with "Reported against BS 5839-1:2025" and include the standard version string. This is essential — engineers need to be able to prove which edition of the standard the report was issued under.

18. **No claims of legal certification.** The app does not certify the engineer or the system. The report is a statement by the engineer of what they tested and found. Make sure all UI copy and PDF copy reflects this — avoid words like "certified", "guaranteed", or "legally compliant".

19. **Backwards compatibility.** Sites without `bs5839_config` continue to use the existing compliance report. Don't migrate them automatically — let users opt in by configuring system category.

20. **Watch for performance.** A large site (500+ assets, 20+ visits, 50+ variations) should still produce a report in under 30 seconds on a mid-tier mobile. PDF generation already runs in an isolate per the existing pattern — make sure data gathering happens on the main thread first, then everything serializable goes into the isolate.

---

## Appendix A — BS 5839-1:2025 Key Changes Reference

For your own reference and as a checklist while implementing. These are the changes from the 2017 edition that this spec addresses:

1. **Effective date:** 30 April 2025; 2017 edition withdrawn the same day
2. **Renumbering:** All clauses renumbered. Certificates must reference 2025 numbering
3. **Heat detectors banned in sleeping rooms** for L2 and L3 systems
4. **Stairway lobbies require automatic detection** for L1 and L2
5. **Smoke detectors preferred** for sleeping areas (not heat)
6. **L4 systems** now require detection at top of lift shafts
7. **L2 systems** must consider sleeping risk in addition to risk-assessed rooms
8. **Cyber security** new requirements for remote access (authentication, tamper protection, labelling)
9. **ARC transmission times** maximum times specified for L and P systems
10. **Cause and effect matrix** must be provided at handover (commissioning)
11. **Service interval tolerance** 5–7 months around the 6-month cycle
12. **Variations** Clause 6.6 lists prohibited variations that cannot be permitted
13. **Competent person** formally defined in Clause 3.13 with CPD expectation
14. **Call point clarifications** mounting height 1.2–1.6m, distance tolerances
15. **Sounder tone differentiation** required when shared with non-fire alerts (class change, lockdown)
16. **Closely spaced beams** defined as <1m centre-to-centre
17. **Obstructions** items <250mm and gaps >300mm clarified
18. **Class change alerts** in schools may now last up to 10 seconds
19. **BS 4422:2024 Fire Vocabulary** definitions adopted
20. **All-IP transition** by 2027 — transmission systems must support

---

## Appendix B — Files Touched Summary

- **New files:** ~36 (11 models, 8 services, ~13 screens, 4 data files)
- **Modified files:** ~30 (across models, services, screens, config, docs)
- **New SQLite tables:** 6
- **New Firestore subcollections:** 5
- **New Remote Config flags:** 10
- **New analytics events:** 16
- **New Cloud Functions:** 3
- **Estimated effort:** 8 weeks single developer, ~6 weeks with Claude Code

---

*End of specification. Ready to hand off.*
