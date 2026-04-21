# FireThings — Critical Bug Fixes & Edge Case Hardening

**Version:** 1.0
**Date:** April 2026
**Status:** Proposed — to be implemented before BS 5839 spec (or alongside Phase 1)
**Severity:** Mix of HIGH (data integrity) and MEDIUM (robustness)

**Purpose:** Address bugs and edge cases identified by code review of the asset register, service history, floor plans, and defect-to-quote workflows. These fixes should be implemented BEFORE the BS 5839-1:2025 feature ships, because some of them affect data integrity in ways that would compound once more sites are configured.

**Prerequisites:**

- All existing features as-implemented (asset register, dispatch, defect-to-quote)
- Familiarity with the existing codebase patterns (basePath, immutable service history, gather-then-isolate PDF generation)

**Hand-off to Claude Code:** Each fix is self-contained — they can be implemented in any order, though section 1 (LifecycleService) should land first because several other fixes reference it.

---

## Table of Contents

1. [Hardcoded 1-Year Service Interval — Replace with LifecycleService](#1-hardcoded-1-year-service-interval--replace-with-lifecycleservice) ⚠️ HIGH
2. [Date Arithmetic Edge Cases (Feb 29, Month-End)](#2-date-arithmetic-edge-cases) ⚠️ HIGH
3. [Non-Atomic Test Save (Three Sequential Writes)](#3-non-atomic-test-save) ⚠️ HIGH
4. [Reference Number Race Condition](#4-reference-number-race-condition) MEDIUM
5. [Engineer Name Resolution — "Unknown" in Audit Trail](#5-engineer-name-resolution) ⚠️ HIGH
6. [Photo Upload Limit Race Condition](#6-photo-upload-limit-race-condition) MEDIUM
7. [Orphaned Storage Files on Delete](#7-orphaned-storage-files-on-delete) MEDIUM
8. [Floor Plan Deletion Doesn't Cascade to Pin Positions](#8-floor-plan-deletion-cascade) ⚠️ HIGH
9. [Brittle JSON Parsing — Stream Failure on One Bad Doc](#9-brittle-json-parsing) MEDIUM
10. [No Optimistic UI on Test Save](#10-no-optimistic-ui-on-test-save) MEDIUM
11. [Checklist Drift — Existing Assets Don't Re-Test on Checklist Update](#11-checklist-drift) MEDIUM
12. [Defect-to-Quote Bidirectional Integrity](#12-defect-to-quote-bidirectional-integrity) MEDIUM
13. [Removed Engineer References Become Dangling](#13-removed-engineer-references) LOW
14. [String-Based Compliance Status — Replace with Enum](#14-compliance-status-enum) MEDIUM
15. [Timestamp vs String Deserialization](#15-timestamp-vs-string-deserialization) ⚠️ HIGH
16. [No Network Retry on Photo Upload](#16-no-network-retry-on-photo-upload) MEDIUM
17. [Defect Service Doesn't Use Transactions](#17-defect-service-transactions) MEDIUM
18. [Implementation Order](#18-implementation-order)
19. [Testing Plan](#19-testing-plan)

---

## 1. Hardcoded 1-Year Service Interval — Replace with LifecycleService

### Problem

Every place that tests an asset hardcodes the next service date as 1 year ahead:

```dart
nextServiceDue: DateTime(now.year + 1, now.month, now.day),
```

Found in **four** files:

- `lib/screens/assets/asset_detail_screen.dart:330`
- `lib/screens/assets/batch_test_screen.dart:141`
- `lib/screens/floor_plans/interactive_floor_plan_screen.dart:279`
- `lib/widgets/defect_bottom_sheet.dart:197`

This is wrong for fire alarm systems (BS 5839 = 6 months), fire doors (6-monthly), and emergency lighting (annual luminaire test, monthly function test). It's only correct for fire extinguishers.

The duplication also means any future change has to be made in 4 places — which is exactly the situation that produced this bug in the first place.

### Fix

#### Step 1 — Add `defaultServiceIntervalMonths` to AssetType

**File:** `lib/models/asset_type.dart`

Add the field:

```dart
class AssetType {
  // ... existing fields ...
  final int? defaultServiceIntervalMonths;

  AssetType({
    // ... existing params ...
    this.defaultServiceIntervalMonths,
  });

  Map<String, dynamic> toJson() => {
    // ... existing fields ...
    'defaultServiceIntervalMonths': defaultServiceIntervalMonths,
  };

  factory AssetType.fromJson(Map<String, dynamic> json) => AssetType(
    // ... existing fields ...
    defaultServiceIntervalMonths: json['defaultServiceIntervalMonths'] as int?,
  );

  // Update copyWith similarly
}
```

#### Step 2 — Set sensible defaults in `default_asset_types.dart`

| Asset Type | Service Interval (months) | Justification |
|---|---|---|
| Fire Alarm Panel | 6 | BS 5839-1:2025 |
| Smoke Detector | 6 | BS 5839-1:2025 |
| Heat Detector | 6 | BS 5839-1:2025 |
| Call Point | 6 | BS 5839-1:2025 (with 25% rotation per visit) |
| Sounder/Beacon | 6 | BS 5839-1:2025 |
| Fire Extinguisher | 12 | BS 5306-3 |
| Emergency Lighting | 12 | BS 5266-1 (annual full discharge; monthly function tests handled separately) |
| Fire Door | 6 | Regulatory Reform (Fire Safety) Order |
| AOV / Smoke Vent | 6 | Aligned with fire alarm system |
| Sprinkler Head | 12 | BS EN 12845 |
| Fire Blanket | 12 | BS EN 1869 |
| Other / Custom | null (user-defined) | — |

#### Step 3 — Create `LifecycleService`

**File:** `lib/services/lifecycle_service.dart` (NEW)

```dart
import '../models/asset.dart';
import '../models/asset_type.dart';

/// Centralised lifecycle calculations for assets:
/// - next service due date (with month tolerance)
/// - end-of-life status
/// - service window (5-7 month range for BS 5839)
class LifecycleService {
  LifecycleService._();
  static final LifecycleService instance = LifecycleService._();

  /// Calculate the next service due date from the last service date
  /// using the asset type's default interval.
  ///
  /// If [assetType.defaultServiceIntervalMonths] is null, returns null
  /// (the engineer must manually set it).
  DateTime? calculateNextServiceDue({
    required DateTime lastServiceDate,
    required AssetType? assetType,
  }) {
    final months = assetType?.defaultServiceIntervalMonths;
    if (months == null) return null;
    return _addMonthsSafely(lastServiceDate, months);
  }

  /// Calculate a service window with ±1 month tolerance (BS 5839-1:2025
  /// allows 5-7 months around the standard 6-month interval).
  /// Returns null if the asset type has no default interval.
  ({DateTime start, DateTime end})? calculateServiceWindow({
    required DateTime lastServiceDate,
    required AssetType? assetType,
  }) {
    final months = assetType?.defaultServiceIntervalMonths;
    if (months == null) return null;
    return (
      start: _addMonthsSafely(lastServiceDate, months - 1),
      end: _addMonthsSafely(lastServiceDate, months + 1),
    );
  }

  /// Returns true if the asset is overdue for service
  /// (past the upper bound of the service window).
  bool isServiceOverdue({
    required Asset asset,
    required AssetType? assetType,
  }) {
    if (asset.lastServiceDate == null) return false;
    final window = calculateServiceWindow(
      lastServiceDate: asset.lastServiceDate!,
      assetType: assetType,
    );
    if (window == null) return false;
    return DateTime.now().isAfter(window.end);
  }

  /// Returns true if the asset is approaching the end of its lifespan
  /// (less than 1 year remaining or past expected lifespan).
  bool isEndOfLifeApproaching({
    required Asset asset,
    required AssetType? assetType,
  }) {
    final lifespanYears = asset.expectedLifespanYears
        ?? assetType?.defaultLifespanYears;
    if (lifespanYears == null || asset.installDate == null) return false;
    final ageYears = DateTime.now()
        .difference(asset.installDate!)
        .inDays / 365.25;
    return ageYears > (lifespanYears - 1);
  }

  /// Add months to a date, clamping the day to the new month's length.
  /// e.g. _addMonthsSafely(2026-01-31, 1) -> 2026-02-28
  ///      _addMonthsSafely(2024-02-29, 12) -> 2025-02-28
  DateTime _addMonthsSafely(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final newYear = date.year + (totalMonths ~/ 12);
    final newMonth = (totalMonths % 12) + 1;
    final daysInNewMonth = DateUtils.getDaysInMonth(newYear, newMonth);
    final newDay = date.day > daysInNewMonth ? daysInNewMonth : date.day;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute);
  }
}

class DateUtils {
  static int getDaysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    return const [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];
  }
}
```

#### Step 4 — Replace all four hardcoded calls

In each of the four files, replace:

```dart
nextServiceDue: DateTime(now.year + 1, now.month, now.day),
```

with:

```dart
nextServiceDue: LifecycleService.instance.calculateNextServiceDue(
  lastServiceDate: now,
  assetType: _assetType,  // already loaded in each screen
),
```

Each file already has access to the asset type via the asset's `assetTypeId` and the `AssetTypeService.instance.getType()` cache. Pass it through.

#### Step 5 — Add migration warning

For sites already in production with the wrong 1-year date, add a one-time migration on first load (per site, gated by a Firestore flag `users/{uid}/migrations/service_interval_recalc_v1`):

- For each asset where `lastServiceDate` exists, recalculate `nextServiceDue` using the new logic
- Show a one-time toast: "Service intervals have been recalculated to match BS 5839-1:2025"

### Tests

- `LifecycleService.calculateNextServiceDue` with each asset type
- Edge case: lastServiceDate = 2024-02-29, interval = 12 → 2025-02-28
- Edge case: lastServiceDate = 2026-01-31, interval = 1 → 2026-02-28
- Edge case: lastServiceDate = 2025-12-15, interval = 6 → 2026-06-15 (year rollover)
- isServiceOverdue when lastServiceDate is null → false
- Service window calculation produces start before end

---

## 2. Date Arithmetic Edge Cases

### Problem

`DateTime(now.year + 1, now.month, now.day)` silently rolls over when the resulting date doesn't exist:

- `DateTime(2025, 2, 29)` → `DateTime(2025, 3, 1)`
- `DateTime(2026, 4, 31)` → `DateTime(2026, 5, 1)`

This isn't just the next-service-due bug — `lib/services/invoice_export_service.dart:36` has the same pattern for invoice date ranges, and there are likely more.

### Fix

Resolved by introducing `LifecycleService._addMonthsSafely` (section 1) and using `DateUtils.getDaysInMonth` at all call sites that perform month or year arithmetic on user-meaningful dates.

#### Audit and replace

Run a project-wide grep:

```bash
grep -rn "year + 1\|year - 1\|month + \|month - " lib/
```

For each result, decide:

- If it's a date used for display / scheduling / compliance: replace with `_addMonthsSafely` or equivalent
- If it's purely arithmetic (e.g. age calculation): leave it but add a comment

### Tests

Same as section 1 — clamping coverage.

---

## 3. Non-Atomic Test Save

### Problem

Each test-an-asset operation does THREE sequential Firestore writes with no batching:

```dart
// asset_detail_screen.dart _passAsset, _failAsset
// batch_test_screen.dart _passAsset
// defect_bottom_sheet.dart _save
1. ServiceHistoryService.createRecord(...)        // Write 1
2. AssetService.updateAsset(...)                  // Write 2
3. DefectService.rectifyAllForAsset(...)          // Write 3 (or N writes)
```

If the network drops between writes 1 and 2, the asset still shows the old `complianceStatus` but a new ServiceRecord exists in the audit trail saying it passed. The next time the asset list loads, the user sees stale data and re-tests, creating duplicate records.

If write 3 fails after writes 1-2 succeed, defects remain unrectified even though the asset shows as passed.

The defect_bottom_sheet code already shows awareness of this — it has a comment "Defect and service record are now saved. Update asset status in a separate try/catch so a failure here doesn't show a misleading 'Failed to save defect' message" — which is exactly the wrong fix. It hides the inconsistency from the user instead of resolving it.

### Fix

#### Option A (recommended): WriteBatch

Wrap the three writes in a single Firestore `WriteBatch`. All three commit atomically or none do.

**File:** Create new method `lib/services/asset_test_service.dart` (NEW) to consolidate the three-step flow:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset.dart';
import '../models/service_record.dart';
import '../models/asset_type.dart';
import '../models/defect.dart';
import 'lifecycle_service.dart';

/// Coordinates an atomic asset-test write:
/// - creates ServiceRecord
/// - updates Asset
/// - rectifies open defects (on pass)
/// or all fail together.
class AssetTestService {
  AssetTestService._();
  static final AssetTestService instance = AssetTestService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mark an asset as passed in a single atomic write.
  /// Returns the IDs of any defects that were auto-rectified.
  Future<List<String>> markAssetPassed({
    required String basePath,
    required String siteId,
    required Asset asset,
    required AssetType? assetType,
    required String engineerId,
    required String engineerName,
    String? jobsheetId,
    String? dispatchedJobId,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final record = ServiceRecord(
      id: const Uuid().v4(),
      assetId: asset.id,
      siteId: siteId,
      jobsheetId: jobsheetId,
      dispatchedJobId: dispatchedJobId,
      engineerId: engineerId,
      engineerName: engineerName,
      serviceDate: now,
      overallResult: 'pass',
      createdAt: now,
    );
    final recordRef = _firestore
        .doc('$basePath/sites/$siteId/asset_service_history/${record.id}');
    batch.set(recordRef, record.toJson());

    final updatedAsset = asset.copyWith(
      complianceStatus: Asset.statusPass,
      lastServiceDate: now,
      lastServiceBy: engineerId,
      lastServiceByName: engineerName,
      nextServiceDue: LifecycleService.instance.calculateNextServiceDue(
        lastServiceDate: now,
        assetType: assetType,
      ),
      updatedAt: now,
      lastModifiedAt: now,
    );
    final assetRef = _firestore.doc('$basePath/sites/$siteId/assets/${asset.id}');
    batch.update(assetRef, updatedAsset.toJson());

    // Rectify open defects in the same batch
    final openDefectsSnap = await _firestore
        .collection('$basePath/sites/$siteId/defects')
        .where('assetId', isEqualTo: asset.id)
        .where('status', isEqualTo: 'open')
        .get();

    final rectifiedIds = <String>[];
    for (final defectDoc in openDefectsSnap.docs) {
      batch.update(defectDoc.reference, {
        'status': 'rectified',
        'rectifiedBy': engineerId,
        'rectifiedByName': engineerName,
        'rectifiedAt': now.toIso8601String(),
      });
      rectifiedIds.add(defectDoc.id);
    }

    await batch.commit();
    return rectifiedIds;
  }

  /// Mark an asset as failed in a single atomic write.
  /// Creates the ServiceRecord, updates Asset, and creates the Defect
  /// all together.
  Future<String> markAssetFailed({
    required String basePath,
    required String siteId,
    required Asset asset,
    required AssetType? assetType,
    required String engineerId,
    required String engineerName,
    required Defect defect,
    String? jobsheetId,
    String? dispatchedJobId,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final record = ServiceRecord(
      id: const Uuid().v4(),
      assetId: asset.id,
      siteId: siteId,
      jobsheetId: jobsheetId,
      dispatchedJobId: dispatchedJobId,
      engineerId: engineerId,
      engineerName: engineerName,
      serviceDate: now,
      overallResult: 'fail',
      defectNote: defect.note,
      defectSeverity: defect.severity.name,
      defectAction: defect.action?.name,
      defectPhotoUrls: defect.photoUrls,
      createdAt: now,
    );
    final recordRef = _firestore
        .doc('$basePath/sites/$siteId/asset_service_history/${record.id}');
    batch.set(recordRef, record.toJson());

    final defectRef = _firestore
        .doc('$basePath/sites/$siteId/defects/${defect.id}');
    batch.set(defectRef, defect.toJson());

    final updatedAsset = asset.copyWith(
      complianceStatus: Asset.statusFail,
      lastServiceDate: now,
      lastServiceBy: engineerId,
      lastServiceByName: engineerName,
      nextServiceDue: LifecycleService.instance.calculateNextServiceDue(
        lastServiceDate: now,
        assetType: assetType,
      ),
      updatedAt: now,
      lastModifiedAt: now,
    );
    final assetRef = _firestore.doc('$basePath/sites/$siteId/assets/${asset.id}');
    batch.update(assetRef, updatedAsset.toJson());

    await batch.commit();
    return record.id;
  }
}
```

#### Refactor call sites

Replace the three-step pattern in:

- `asset_detail_screen.dart _passAsset / _failAsset`
- `batch_test_screen.dart _passAsset`
- `interactive_floor_plan_screen.dart _passAsset`
- `defect_bottom_sheet.dart _save`

with single calls to `AssetTestService.instance.markAssetPassed(...)` or `markAssetFailed(...)`.

#### Important

The defect photo upload to Storage must complete BEFORE calling `markAssetFailed`, because Storage uploads aren't part of the Firestore batch. Pattern:

1. Upload photos to Storage → get URLs
2. Construct Defect with URLs
3. Call `markAssetFailed` (atomic Firestore batch)

If step 1 partially fails, the engineer sees the error and retries — no inconsistent state in Firestore.

### Tests

- Successful path: all three writes commit
- Network failure during commit: nothing persists (batch atomicity)
- Defect rectification rolled back if asset update fails
- Concurrent test of same asset by two engineers: last write wins on Asset, both ServiceRecords persist (correct behaviour for audit)

---

## 4. Reference Number Race Condition

### Problem

`AssetService.suggestNextReference` queries existing references, returns max+1. Then the UI writes the asset using that reference. Two engineers adding assets at the same time both see "SD-005", both write "SD-005", and end up with duplicates.

This is a worse problem in companies where multiple engineers work the same site simultaneously.

### Fix

#### Option A: Firestore transaction at write time

Move reference allocation into a transaction inside `AssetService.createAsset`:

```dart
Future<void> createAsset(
    String basePath, String siteId, Asset asset) async {
  // If reference is auto-suggested (matches the pattern), allocate atomically
  if (_isAutoReference(asset.reference, asset.assetTypeId)) {
    final allocated = await _firestore.runTransaction((txn) async {
      final col = _assetsCol(basePath, siteId);
      final existing = await col
          .where('reference', isGreaterThanOrEqualTo: '${_prefix(asset.assetTypeId)}-')
          .where('reference', isLessThanOrEqualTo: '${_prefix(asset.assetTypeId)}-\uf8ff')
          .get();

      int maxNum = 0;
      for (final doc in existing.docs) {
        final ref = doc.data()['reference'] as String? ?? '';
        final parts = ref.split('-');
        if (parts.length >= 2) {
          final num = int.tryParse(parts.last) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      }
      final newRef = '${_prefix(asset.assetTypeId)}-${(maxNum + 1).toString().padLeft(3, '0')}';
      final updated = asset.copyWith(reference: newRef);
      txn.set(_firestore.doc('$basePath/sites/$siteId/assets/${asset.id}'), updated.toJson());
      return newRef;
    });
    debugPrint('Allocated reference: $allocated');
  } else {
    await _assetsCol(basePath, siteId).doc(asset.id).set(asset.toJson());
  }
}
```

#### Option B: Counter document per type per site

Maintain a counter doc at `{basePath}/sites/{siteId}/asset_counters/{typeId}` with a `nextNumber` field. Increment in a transaction. Faster than scanning all assets, scales better for large sites.

```dart
Future<int> _allocateNumber(String basePath, String siteId, String typeId) async {
  return await _firestore.runTransaction((txn) async {
    final ref = _firestore.doc('$basePath/sites/$siteId/asset_counters/$typeId');
    final snap = await txn.get(ref);
    final current = (snap.data()?['nextNumber'] as int?) ?? 0;
    final next = current + 1;
    txn.set(ref, {'nextNumber': next}, SetOptions(merge: true));
    return next;
  });
}
```

**Recommendation:** Option B for sites with 100+ assets; Option A is fine for small sites.

#### Don't break manual references

Engineers must still be able to manually enter "PANEL-1" or "MAIN" — only auto-allocate when the reference field is left blank or matches the suggested pattern.

### Tests

- 100 concurrent createAsset calls produce 100 unique references
- Manual reference "PANEL-MAIN" preserved
- Counter doc survives asset deletion (next number doesn't reset)

---

## 5. Engineer Name Resolution

### Problem

Five+ places in the codebase use:

```dart
engineerName: user.displayName ?? 'Unknown',
```

Once a ServiceRecord is written with `engineerName: 'Unknown'`, it's permanent — service history is immutable. The audit trail is permanently corrupted with "Unknown" entries that should have been the engineer's actual name.

This happens when:

- The user signed up with email but never set a display name
- Display name was cleared at some point
- FirebaseAuth profile sync hasn't completed yet on cold start

### Fix

#### Step 1 — Centralised name resolution

**File:** `lib/services/user_profile_service.dart` (extend existing)

Add a method:

```dart
/// Resolves the display name for the current user, falling back through:
/// 1. UserProfile.displayName (Firestore)
/// 2. UserProfile.fullName (if separate field exists)
/// 3. FirebaseAuth.currentUser.displayName
/// 4. The local-part of the email address (e.g. 'chris' from 'chris@example.com')
/// 5. As a final fallback, a friendly placeholder
///
/// Throws [ProfileNotLoadedException] if no profile is loaded — callers should
/// await profile loading before recording any audit data.
String resolveEngineerName() {
  final profile = currentProfile;
  if (profile?.displayName?.isNotEmpty == true) return profile!.displayName!;
  if (profile?.fullName?.isNotEmpty == true) return profile!.fullName!;

  final user = FirebaseAuth.instance.currentUser;
  if (user?.displayName?.isNotEmpty == true) return user!.displayName!;

  final email = user?.email;
  if (email != null && email.contains('@')) {
    final localPart = email.split('@').first;
    if (localPart.isNotEmpty) {
      return localPart[0].toUpperCase() + localPart.substring(1);
    }
  }

  throw ProfileNotLoadedException(
    'Engineer name cannot be resolved. Profile must be loaded before '
    'recording audit data.'
  );
}

class ProfileNotLoadedException implements Exception {
  final String message;
  ProfileNotLoadedException(this.message);
  @override
  String toString() => 'ProfileNotLoadedException: $message';
}
```

#### Step 2 — Block test save when profile not loaded

If `resolveEngineerName()` would throw, show a blocking dialog:

> "Your engineer profile hasn't loaded yet. Please wait a moment and try again. If this persists, sign out and back in."

Don't fall back to "Unknown" silently.

#### Step 3 — Replace all `user.displayName ?? 'Unknown'` patterns

Search-and-replace in:

- `asset_detail_screen.dart` (×2)
- `batch_test_screen.dart` (×1)
- `interactive_floor_plan_screen.dart` (×1)
- `defect_bottom_sheet.dart` (×1)
- Any others surfaced by `grep -rn "?? 'Unknown'"`

with:

```dart
engineerName: UserProfileService.instance.resolveEngineerName(),
```

#### Step 4 — Onboarding gate

On first sign-in, if no display name is set, force the user to enter one before they can use any feature that creates audit data.

### Tests

- Engineer with displayName set → displayName returned
- Engineer with no displayName, but email → "Chris" returned (capitalised local part)
- Engineer with nothing → throws ProfileNotLoadedException
- Test save when profile not loaded → blocking dialog, no Firestore write

---

## 6. Photo Upload Limit Race Condition

### Problem

`AssetService.uploadAssetPhoto` is read-then-write:

```dart
final asset = await getAsset(...);
if (asset.photoUrls.length >= maxPhotos) return null;
// ... upload to Storage ...
await _assetsCol(...).update({'photoUrls': updatedUrls});
```

Two concurrent uploads on a 4-photo asset both pass the check (`4 < 5`), both upload, both update — and now the asset has 6 photos.

### Fix

Use Firestore's `arrayUnion` and a transaction with the count check inside it:

```dart
Future<String?> uploadAssetPhoto({...}) async {
  // Upload to Storage first (no consistency requirement here)
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = '$basePath/sites/$siteId/assets/$assetId/photos/$timestamp.jpg';
  final url = kIsWeb
      ? await _uploadViaRestApi(path, bytes)
      : await _uploadViaSdk(path, bytes);

  // Now atomically check count and add the URL
  try {
    await _firestore.runTransaction((txn) async {
      final ref = _assetsCol(basePath, siteId).doc(assetId);
      final snap = await txn.get(ref);
      final current = (snap.data()?['photoUrls'] as List<dynamic>?)?.length ?? 0;
      if (current >= maxPhotos) {
        throw _PhotoLimitExceeded();
      }
      txn.update(ref, {
        'photoUrls': FieldValue.arrayUnion([url]),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastModifiedAt': DateTime.now().toIso8601String(),
      });
    });
    return url;
  } on _PhotoLimitExceeded {
    // Roll back: delete the orphaned upload from Storage
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
    return null;
  }
}

class _PhotoLimitExceeded implements Exception {}
```

### Tests

- 10 concurrent uploads on a 0-photo asset → exactly 5 succeed
- Failed transaction cleans up the Storage object

---

## 7. Orphaned Storage Files on Delete

### Problem

When an asset is deleted, photos are deleted in a loop:

```dart
for (final url in asset.photoUrls) {
  try {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  } catch (e) {
    debugPrint('Warning: Failed to delete photo: $e');
  }
}
```

If the network drops mid-loop, some photos remain in Storage with no Firestore reference — they consume storage forever.

The same problem exists for:

- Floor plan images when a site is deleted
- Defect photos when a service record's asset is deleted (defect photos aren't even attempted to be deleted)
- Quote PDFs once the spec ships

### Fix

#### Option A: Cloud Function janitor (recommended)

A scheduled Cloud Function runs nightly:

1. List all files in Storage
2. For each file, check if its Firestore reference still exists
3. If not, delete after a 7-day grace period (in case of write delays)

**File:** `functions/storage_janitor.js` (NEW)

```js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.janitor = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const bucket = admin.storage().bucket();
  const [files] = await bucket.getFiles();

  let deletedCount = 0;
  for (const file of files) {
    const path = file.name; // e.g. "users/abc/sites/xyz/assets/123/photos/456.jpg"
    const refersTo = await isReferenced(path);
    if (!refersTo) {
      const [metadata] = await file.getMetadata();
      const ageDays = (Date.now() - new Date(metadata.timeCreated).getTime()) / 86400000;
      if (ageDays > 7) {
        await file.delete();
        deletedCount++;
      }
    }
  }
  console.log(`Janitor deleted ${deletedCount} orphaned files`);
});

async function isReferenced(storagePath) {
  // Parse path and check if the parent doc exists
  // and contains this URL in its photoUrls array
  // Implementation depends on path patterns
}
```

#### Option B: Track pending deletes

Maintain a `pending_storage_deletes` collection. Failed deletes get queued. A Cloud Function processes the queue with retries and exponential backoff.

#### Option C: Delete after Firestore success

For the immediate code path (asset delete), use this pattern:

1. Read asset to get photo URLs
2. Delete Firestore doc first
3. Try to delete Storage files; on failure, write to `pending_storage_deletes`
4. Retry queue processed by Cloud Function

**Recommendation:** Option A for production; it covers all orphan sources without per-call complexity.

### Tests

- Delete asset with 5 photos, simulate Storage failure on 3rd → orphans cleaned within 7 days
- Janitor doesn't delete files referenced by valid Firestore docs
- Janitor doesn't delete files less than 7 days old

---

## 8. Floor Plan Deletion Cascade

### Problem

`FloorPlanService.deleteFloorPlan` deletes the floor plan doc and image. It does NOT update the assets that have this `floorPlanId` set.

After deletion:

- Assets keep `floorPlanId` pointing to a deleted plan
- Asset detail screen tries to render "View on Floor Plan" but the plan doesn't exist
- Compliance report PDF tries to render the floor plan page → null reference or render error

### Fix

#### Step 1 — Cascade clear pin positions

Update `deleteFloorPlan` to clear `floorPlanId`, `xPercent`, and `yPercent` on all affected assets:

```dart
Future<void> deleteFloorPlan(
    String basePath, String siteId, String planId,
    {String extension = 'jpg'}) async {
  try {
    // Find all assets pinned to this plan
    final affectedSnap = await _firestore
        .collection('$basePath/sites/$siteId/assets')
        .where('floorPlanId', isEqualTo: planId)
        .get();

    final batch = _firestore.batch();

    // Clear pin positions on affected assets
    for (final doc in affectedSnap.docs) {
      batch.update(doc.reference, {
        'floorPlanId': null,
        'xPercent': null,
        'yPercent': null,
        'updatedAt': DateTime.now().toIso8601String(),
        'lastModifiedAt': DateTime.now().toIso8601String(),
      });
    }

    // Delete the floor plan doc
    batch.delete(_plansCol(basePath, siteId).doc(planId));

    await batch.commit();

    // Then delete the image (best effort, outside batch)
    await deleteFloorPlanImage(basePath, siteId, planId, extension: extension);
  } catch (e) {
    debugPrint('Error deleting floor plan: $e');
    rethrow;
  }
}
```

#### Step 2 — Confirmation dialog with count

Before deleting, show how many assets will be affected:

```dart
final affectedCount = await _floorPlanService.getAffectedAssetCount(basePath, siteId, planId);
final confirmed = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Delete floor plan?'),
    content: Text(
      affectedCount > 0
        ? 'This will remove pin positions for $affectedCount assets. '
          'The assets themselves will not be deleted, but they will need '
          'to be re-pinned to a floor plan.'
        : 'No assets are pinned to this floor plan.',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Delete'),
      ),
    ],
  ),
);
```

#### Step 3 — Defensive UI

Wherever assets are loaded with their floor plans, filter out assets whose `floorPlanId` no longer resolves to a real plan. Show them in an "Unpinned" section instead of crashing.

### Tests

- Delete floor plan with 10 pinned assets → all 10 assets have `floorPlanId: null` after
- Delete floor plan with 0 pinned assets → no batch error
- Confirmation dialog correctly counts affected assets

---

## 9. Brittle JSON Parsing

### Problem

`Asset.fromJson` and `ServiceRecord.fromJson` use unchecked casts on required fields:

```dart
id: json['id'] as String,
siteId: json['siteId'] as String,
createdAt: DateTime.parse(json['createdAt'] as String),
```

If a single document has a missing or wrong-type field (corrupted partial sync, schema migration issue, manual Firestore Console edit), the cast throws. Because parsing happens inside `.map()` on a stream, the WHOLE stream fails — not just the bad doc — and the user sees an empty asset list.

### Fix

#### Step 1 — Safe parse helpers

Add to a new file `lib/utils/json_helpers.dart`:

```dart
String? jsonStringRequired(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

DateTime? jsonDateOptional(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  // Firestore Timestamp
  try {
    return value.toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

DateTime jsonDateRequired(dynamic value, {DateTime? fallback}) {
  return jsonDateOptional(value) ?? fallback ?? DateTime.now();
}
```

#### Step 2 — Update model `fromJson` to use helpers

Replace unchecked casts with safe parsing. For required fields, use a sentinel that lets the caller skip the doc:

```dart
factory Asset.fromJson(Map<String, dynamic> json) {
  final id = jsonStringRequired(json, 'id');
  final siteId = jsonStringRequired(json, 'siteId');
  final assetTypeId = jsonStringRequired(json, 'assetTypeId');
  if (id == null || siteId == null || assetTypeId == null) {
    throw const FormatException('Asset missing required fields');
  }
  return Asset(
    id: id,
    siteId: siteId,
    assetTypeId: assetTypeId,
    // ... other fields use jsonDateOptional, etc ...
    createdAt: jsonDateRequired(json['createdAt'], fallback: DateTime.now()),
    updatedAt: jsonDateRequired(json['updatedAt'], fallback: DateTime.now()),
    // ...
  );
}
```

#### Step 3 — Stream-level resilience

Update every `getXxxStream` method to skip bad docs instead of failing the whole stream:

```dart
Stream<List<Asset>> getAssetsStream(String basePath, String siteId) {
  return _assetsCol(basePath, siteId)
      .orderBy('reference')
      .snapshots()
      .map((snapshot) {
        final assets = <Asset>[];
        for (final doc in snapshot.docs) {
          try {
            assets.add(Asset.fromJson(doc.data()));
          } catch (e) {
            debugPrint('Skipping malformed asset ${doc.id}: $e');
            // Optionally: log to Crashlytics for visibility
            FirebaseCrashlytics.instance.recordError(
              e,
              StackTrace.current,
              reason: 'Malformed asset doc',
              information: ['docId: ${doc.id}', 'siteId: $siteId'],
              fatal: false,
            );
          }
        }
        return assets;
      });
}
```

Apply the same pattern to all stream methods in `AssetService`, `FloorPlanService`, `ServiceHistoryService`, `DefectService`, `QuoteService`, `JobsheetService`, `InvoiceService`.

### Tests

- Stream with one malformed doc returns valid docs and logs error
- Asset with missing `id` → FormatException thrown by `fromJson`, caught by stream
- Firestore Timestamp deserializes correctly via `jsonDateOptional`

---

## 10. No Optimistic UI on Test Save

### Problem

When an engineer taps "Pass" on an asset, the UI waits for the Firestore round-trip before updating. On a slow connection (basement, rural site, behind metal walls), this looks like the app froze.

The current pattern:

```dart
setState(() => _isTestSaving = true);
await ServiceHistoryService.createRecord(...);
await AssetService.updateAsset(...);
await DefectService.rectifyAllForAsset(...);
context.showSuccessToast('Asset passed');
setState(() => _isTestSaving = false);
_loadAsset();
```

### Fix

Optimistic UI: update local state immediately, sync in background, revert on failure.

```dart
Future<void> _passAsset() async {
  if (_asset == null) return;

  // Snapshot for rollback
  final originalAsset = _asset!;

  // Optimistic local update
  final now = DateTime.now();
  setState(() {
    _asset = _asset!.copyWith(
      complianceStatus: Asset.statusPass,
      lastServiceDate: now,
    );
  });
  context.showSuccessToast('Marked as passed');

  // Background sync via the new atomic AssetTestService
  try {
    await AssetTestService.instance.markAssetPassed(
      basePath: widget.basePath,
      siteId: widget.siteId,
      asset: originalAsset,
      assetType: _assetType,
      engineerId: AuthService.instance.currentUser!.uid,
      engineerName: UserProfileService.instance.resolveEngineerName(),
    );
    AnalyticsService.instance.logAssetTested(
      assetType: originalAsset.assetTypeId,
      result: 'pass',
      siteId: widget.siteId,
    );
  } catch (e) {
    // Rollback
    if (mounted) {
      setState(() => _asset = originalAsset);
      context.showErrorToast(
        'Failed to save — please check your connection. Test was not recorded.'
      );
    }
  }
}
```

Don't call `_loadAsset()` after — the optimistic state is already correct; reloading wastes a round-trip and creates a flash.

### Tests

- Pass tap on a slow connection → UI updates instantly, network completes in background
- Pass tap with offline simulator → UI updates, then rolls back with error toast
- Multiple rapid taps → debounced, only one Firestore write

---

## 11. Checklist Drift

### Problem

Default checklists are versioned by app release (in `default_asset_types.dart`). When you ship a new version with stricter checklist items (e.g. adding "Stairway lobby coverage verified" for smoke detectors), existing assets that previously passed remain passed — even though they were never tested against the new item.

This is acutely bad for BS 5839 reporting: a compliance report will show 100% passed, but the new clauses haven't actually been verified.

### Fix

#### Step 1 — Version the checklist

Add to `AssetType`:

```dart
final int checklistVersion;  // bumped when default checklist changes
```

#### Step 2 — Stamp version on ServiceRecord

```dart
class ServiceRecord {
  // ... existing ...
  final int? checklistVersionTested;
}
```

#### Step 3 — Detect drift on asset list load

In the asset register screen, for each passed asset, compare:

```dart
final latestRecord = ...; // from ServiceHistoryService
final currentChecklistVersion = assetType.checklistVersion;
final tested = latestRecord?.checklistVersionTested ?? 0;

if (tested < currentChecklistVersion) {
  // Show "Re-test required" badge on the asset card
}
```

#### Step 4 — UI surface

- Asset register: amber "Checklist updated" badge on assets that need re-test
- Filter chip: "Needs re-test"
- Compliance report cover: "X assets tested against an outdated checklist version" warning

#### Step 5 — Don't auto-fail

Don't change `complianceStatus` to `untested` automatically — that would erase real test history. Just surface the drift visually, leaving the engineer to act.

### Tests

- Bump checklist version → existing passed assets show "Re-test required" badge
- Re-test stamps new version → badge clears
- Custom asset types not affected (their version is set by the user)

---

## 12. Defect-to-Quote Bidirectional Integrity

### Problem

The defect-to-quote spec adds `Defect.linkedQuoteId`. But:

- If the quote is deleted, the defect still references it
- If the defect is deleted (rectified), the quote still references it
- Neither side guards against the other being missing

### Fix

#### Step 1 — Bidirectional check on quote deletion

In `QuoteService.deleteQuote`, fetch any linked defect and clear the link first:

```dart
Future<void> deleteQuote(String quoteId) async {
  final quote = await getQuote(quoteId);
  if (quote == null) return;

  final batch = _firestore.batch();

  // Clear back-reference on linked defect
  if (quote.defectId != null) {
    final defectRef = _firestore.doc('$_basePath/sites/${quote.siteId}/defects/${quote.defectId}');
    batch.update(defectRef, {
      'linkedQuoteId': null,
      'lastModifiedAt': DateTime.now().toIso8601String(),
    });
  }

  // Delete the quote
  batch.delete(_firestore.doc('$_basePath/quotes/$quoteId'));
  await batch.commit();
}
```

#### Step 2 — Soft-prevent deletion of converted quotes

If `quote.status == QuoteStatus.converted`, don't allow delete (it would orphan the dispatched job reference). Show "This quote has been converted to a job and cannot be deleted. Cancel the job first."

#### Step 3 — Defect deletion handling

Defects shouldn't really be deleted — they should be marked rectified. If you do allow deletion, do the same back-reference clear on the linked quote.

#### Step 4 — Periodic integrity sweep

Cloud Function (weekly): find defects with `linkedQuoteId` pointing to non-existent quotes; clear the link. Same the other way.

### Tests

- Delete quote → linked defect's `linkedQuoteId` cleared
- Try to delete converted quote → blocked with explanation
- Defect with stale `linkedQuoteId` → integrity sweep clears it

---

## 13. Removed Engineer References

### Problem

When a company removes an engineer (`CompanyMember` deleted from Firestore), the engineer's UID is still referenced in:

- `Asset.lastServiceBy`
- `Asset.createdBy`
- `ServiceRecord.engineerId`
- `Defect.loggedBy`, `Defect.rectifiedBy`
- `Quote.engineerId`
- All audit data

The `*Name` fields (e.g. `lastServiceByName`) preserve the historical name — that's correct. But UI features that try to look up the engineer's current details (e.g. "Tap engineer to call them") will fail silently or crash.

### Fix

#### Step 1 — Document the contract

Add a comment near every `*Id` field that references an engineer:

```dart
/// UID of the engineer who created this. NOTE: This UID may no longer
/// be a member of the company. Use [createdByName] for display purposes.
/// Live engineer details are not guaranteed to be available.
final String createdBy;
```

#### Step 2 — Defensive lookups

Wherever the UI looks up live engineer details (e.g. dispatch dashboard), wrap in null-check:

```dart
final engineer = await CompanyService.instance.getMember(engineerId);
if (engineer == null) {
  // Show historical name without contact actions
  return _buildHistoricalEngineerCard(record.engineerName);
}
return _buildLiveEngineerCard(engineer);
```

#### Step 3 — Keep removed members as ghost records

Optional: instead of deleting `CompanyMember`, set `removed: true` and `removedAt: <timestamp>`. The member doc stays as a tombstone for historical lookups but doesn't appear in active member lists.

### Tests

- Remove engineer, then view a job they previously completed → name renders, contact actions hidden
- Engineer is removed and rejoins → original audit data still attributable; new actions create new records

---

## 14. Compliance Status Enum

### Problem

`Asset.complianceStatus` is a `String` with constants:

```dart
static const String statusPass = 'pass';
static const String statusFail = 'fail';
static const String statusUntested = 'untested';
static const String statusDecommissioned = 'decommissioned';
```

Comparison code is verbose and error-prone:

```dart
if (asset.complianceStatus == 'pass') ...
if (asset.complianceStatus == Asset.statusPass) ...
```

Both are valid. A typo like `'PASS'` or `'passed'` silently fails. The codebase already uses proper enums for `QuoteStatus` and `DefectSeverity` — be consistent.

### Fix

#### Step 1 — Define enum

```dart
enum AssetComplianceStatus {
  pass,
  fail,
  untested,
  decommissioned;

  String get displayLabel {
    switch (this) {
      case AssetComplianceStatus.pass: return 'Pass';
      case AssetComplianceStatus.fail: return 'Fail';
      case AssetComplianceStatus.untested: return 'Untested';
      case AssetComplianceStatus.decommissioned: return 'Decommissioned';
    }
  }
}
```

#### Step 2 — Backwards-compatible serialization

```dart
static AssetComplianceStatus _statusFromJson(dynamic value) {
  if (value is String) {
    for (final s in AssetComplianceStatus.values) {
      if (s.name == value.toLowerCase()) return s;
    }
  }
  return AssetComplianceStatus.untested;
}
```

#### Step 3 — Asset model uses the enum

```dart
class Asset {
  final AssetComplianceStatus complianceStatus;

  // toJson serialises with .name
  // fromJson uses _statusFromJson for resilience
}
```

#### Step 4 — Migration

No Firestore migration needed if `_statusFromJson` is forgiving. The `.name` values match the existing string constants exactly.

#### Step 5 — Update usage sites

`grep -rn "complianceStatus ==" lib/` and replace with enum comparisons. The compiler will catch any miss-cases.

### Tests

- Round-trip serialization preserves status
- Unknown string in Firestore → defaults to untested (no crash)
- Old data with `'pass'` parses to `AssetComplianceStatus.pass`

---

## 15. Timestamp vs String Deserialization

### Problem

```dart
createdAt: DateTime.parse(json['createdAt'] as String)
```

Firestore can return either `Timestamp` (its native type) or `String` (after JSON serialization). The cast `as String` throws if the value is a `Timestamp`. This happens:

- After offline writes that haven't been server-normalised yet
- When reading immediately after writing in the same session
- In Cloud Function-triggered reads where the SDK may return native types

The bug is silent in normal use (most reads return strings) but fails intermittently in edge cases.

### Fix

Use the `jsonDateRequired` / `jsonDateOptional` helpers from section 9. They handle:

- ISO 8601 strings: `'2026-04-21T12:00:00Z'`
- Firestore `Timestamp` objects: `Timestamp.now()`
- Already-parsed `DateTime`: `DateTime.now()`
- `null`: returns null (or fallback)
- Invalid: returns null (or fallback)

Apply to every `DateTime.parse(... as String)` in the codebase:

```bash
grep -rn "DateTime.parse(.*as String)" lib/
```

There will be many hits across all models. Use the helper consistently.

### Tests

- `fromJson` with ISO string → correct DateTime
- `fromJson` with Firestore Timestamp → correct DateTime
- `fromJson` with null → null (or fallback if required)

---

## 16. No Network Retry on Photo Upload

### Problem

`uploadFloorPlanImage` and `uploadAssetPhoto` have a 30-second timeout but no retry. On a flaky mobile connection, a single dropped packet causes the whole upload to fail. The engineer has to re-pick the photo and try again, which is annoying for a 5MB image.

### Fix

Wrap uploads in a retry helper with exponential backoff:

```dart
Future<T> retry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  bool Function(Object error)? retryIf,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      lastError = e;
      if (retryIf != null && !retryIf(e)) rethrow;
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(initialDelay * (1 << (attempt - 1)));
    }
  }
  throw lastError!;
}
```

Apply to upload methods:

```dart
final url = await retry(
  () => kIsWeb
      ? _uploadViaRestApi(path, bytes)
      : _uploadViaSdk(path, bytes),
  maxAttempts: 3,
  retryIf: (e) => e is TimeoutException || e is SocketException,
);
```

Don't retry on auth errors (401), permission errors (403), or 4xx responses — those won't recover.

### Tests

- First attempt times out, second succeeds → returns successfully
- All 3 attempts fail → throws
- 401 response → throws immediately, no retry

---

## 17. Defect Service Transactions

### Problem

`DefectService.rectifyAllForAsset` (called from test pass flow) loops through open defects and updates them one by one — same race condition pattern as section 3.

### Fix

Already covered by the `AssetTestService` consolidation in section 3 — defect rectification happens inside the same `WriteBatch` as the asset and service record updates.

For standalone defect rectification (e.g. an engineer marks a defect rectified without re-testing), use a single batch:

```dart
Future<int> rectifyAllForAsset(...) async {
  final snap = await _firestore
      .collection('$basePath/sites/$siteId/defects')
      .where('assetId', isEqualTo: assetId)
      .where('status', isEqualTo: 'open')
      .get();

  if (snap.docs.isEmpty) return 0;

  final batch = _firestore.batch();
  for (final doc in snap.docs) {
    batch.update(doc.reference, {
      'status': 'rectified',
      'rectifiedBy': rectifiedBy,
      'rectifiedByName': rectifiedByName,
      'rectifiedAt': DateTime.now().toIso8601String(),
      'lastModifiedAt': DateTime.now().toIso8601String(),
    });
  }
  await batch.commit();
  return snap.docs.length;
}
```

### Tests

- Asset with 3 open defects rectified atomically
- Network drop during commit → no partial rectification

---

## 18. Implementation Order

### Phase 1 — Data Integrity (Week 1) ⚠️ HIGH priority

These directly affect the audit trail. Ship before any new sites are added under BS 5839 mode.

1. Section 1: LifecycleService and 6-month service intervals
2. Section 2: Date arithmetic edge cases (rolls into section 1)
3. Section 3: Atomic test save via AssetTestService
4. Section 5: Engineer name resolution
5. Section 8: Floor plan deletion cascade
6. Section 15: Timestamp vs String deserialization

### Phase 2 — Robustness (Week 2)

7. Section 9: Brittle JSON parsing (defensive streams)
8. Section 4: Reference number race condition
9. Section 6: Photo upload limit race
10. Section 17: Defect service transactions
11. Section 12: Defect-to-quote bidirectional integrity

### Phase 3 — UX & Cleanup (Week 3)

12. Section 10: Optimistic UI on test save
13. Section 11: Checklist drift detection
14. Section 14: Compliance status enum
15. Section 16: Network retry on uploads

### Phase 4 — Operational (Week 3-4)

16. Section 7: Storage janitor Cloud Function
17. Section 13: Removed engineer reference handling

---

## 19. Testing Plan

### Unit Tests

- `LifecycleService` — every interval, leap years, month rollovers
- `_addMonthsSafely` — Feb 29, Jan 31, Dec 31 across years
- `UserProfileService.resolveEngineerName` — all 5 fallback paths
- `AssetComplianceStatus` enum round-trips with old string values
- JSON helpers handle all supported types

### Integration Tests

- Atomic test save: simulate network failure between operations
- Floor plan deletion cascades to all pinned assets
- Reference allocation under 50 concurrent createAsset calls
- Photo upload limit holds under 10 concurrent uploads
- Stream resilience: corrupt one doc, verify others still load

### Edge Case Tests (manual, per platform)

- Add asset offline → reconnect → verify syncs without duplicates
- Test asset on a 3G connection with packet loss → verify atomic completion
- Sign in immediately and tap "Pass" before profile loads → verify blocking dialog
- Delete floor plan with 50+ pinned assets → verify cascade completes

### Regression Tests

- Existing compliance report still generates correctly after enum migration
- Existing asset register loads with no UI changes (other than fixed bugs)
- Existing dispatch flows unaffected

### Production Validation

- Monitor Crashlytics for `FormatException` rate before/after section 9 fix
- Monitor Firestore write counts before/after section 3 (batch should reduce by ~3×)
- Audit a sample of 100 assets in production for `lastServiceByName: 'Unknown'` — should be 0 after section 5 fix

---

## Appendix — Severity Justification

| Section | Severity | Why |
|---|---|---|
| 1. Service interval | HIGH | Wrong dates affect every test; compounds over time; affects compliance reports |
| 2. Date arithmetic | HIGH | Silent data corruption on edge dates |
| 3. Atomic test save | HIGH | Inconsistent state between Asset and ServiceRecord; breaks audit trail integrity |
| 4. Reference race | MEDIUM | Duplicates only on simultaneous adds (rare for solo engineers) |
| 5. Engineer name | HIGH | Permanent corruption of audit trail; can't be retroactively fixed |
| 6. Photo race | MEDIUM | Excess photos but no data loss |
| 7. Storage orphans | MEDIUM | Cost issue, not data integrity |
| 8. Floor plan cascade | HIGH | Crashes / null refs in compliance report PDF generation |
| 9. JSON parsing | MEDIUM | Visible UX failure on corrupt doc; not data corruption |
| 10. Optimistic UI | MEDIUM | UX, not data |
| 11. Checklist drift | MEDIUM | Compliance reports become misleading; not data corruption |
| 12. Quote-defect integrity | MEDIUM | Stale references; not data corruption |
| 13. Removed engineer | LOW | Cosmetic UI failures, not data corruption |
| 14. Status enum | MEDIUM | Maintainability and bug-prevention |
| 15. Timestamp deserial | HIGH | Intermittent crashes after writes |
| 16. Network retry | MEDIUM | UX, not data |
| 17. Defect transactions | MEDIUM | Same as section 3 in spirit |

---

*End of bug fix specification. Ready to hand off.*
