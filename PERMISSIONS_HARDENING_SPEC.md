# FireThings — Permissions Hardening Spec

**Version:** 1.0
**Date:** April 2026
**Status:** Proposed — should land before BS 5839 spec or in parallel
**Severity mix:** 7 CRITICAL (security/data integrity), 9 HIGH (correctness/lockout), 8 MEDIUM (consistency), 4 LOW (polish)

**Purpose:** Address every permission-related bug, edge case, and security gap identified in code review of the asset register, dispatch system, company management, and Firestore rules. This spec is independent of the BS 5839, bug-fix, and feature-gap specs — but several of its fixes (especially #1, #2, and #4) make the BS 5839 spec safer to ship.

**Hand-off to Claude Code:** Each item is numbered and self-contained. Implement in priority order (Phase 1 first — they're security and lockout issues), or pick individual items.

**Companion document:** This spec also includes a section on **permission/UI mismatches** — places where the UI hides actions the user actually has permission to do, or shows actions they don't have permission to do. These are bugs that surface as confusing user experience (e.g. "I have permission to create jobs but there's no button anywhere").

---

## Table of Contents

### Phase 1 — Security & Data Integrity Critical Fixes

1. [Joiner Rule Allows Joining Any Company Without Invite Code](#1-joiner-rule-allows-joining-any-company-without-invite-code) ⚠️ CRITICAL SECURITY
2. [Removed Member's User Profile Not Cleared](#2-removed-members-user-profile-not-cleared) ⚠️ HIGH (likely the bug you spotted)
3. [Founder Rule Race Condition](#3-founder-rule-race-condition) ⚠️ CRITICAL SECURITY
4. [Permissions Cached Forever — Never Refreshed](#4-permissions-cached-forever) ⚠️ HIGH
5. [Admin Can Demote Themselves and Lock Out the Company](#5-admin-self-demotion-lockout) ⚠️ HIGH
6. [Admin Can Remove Themselves from the Team](#6-admin-self-removal) ⚠️ HIGH
7. [`leaveCompany` Hard-Deletes the Member Doc](#7-leavecompany-hard-deletes) ⚠️ HIGH
8. [Company Doc World-Readable to Authenticated Users](#8-company-doc-world-readable) MEDIUM
9. [`teamManage` Holders Can Promote Themselves to Admin](#9-teammanage-promotion-escalation) ⚠️ HIGH

### Phase 2 — Permission/UI Mismatches (the "I have permission but no button" class)

10. [Engineer with `dispatchCreate` Has Nowhere to Create Jobs](#10-engineer-dispatchcreate-no-button) ⚠️ HIGH
11. [Engineer with `dispatchEdit` / `dispatchDelete` Cannot Reach Jobs to Edit/Delete](#11-engineer-dispatchedit-dispatchdelete-blocked-by-routing) ⚠️ HIGH
12. [Web Portal Access Gated by Role, Not by `webPortalAccess` Permission](#12-web-portal-role-not-permission) ⚠️ HIGH
13. [Team Management Menu Gated by Role, Not by `teamManage` Permission](#13-team-management-role-not-permission) ⚠️ HIGH
14. [Dispatch Dashboard "Create Job" FAB Doesn't Check Permission](#14-dispatch-fab-no-permission-check) MEDIUM
15. [Settings Screen Gates by Role Throughout — Audit and Fix](#15-settings-screen-role-gating) MEDIUM

### Phase 3 — Permission Logic Gaps & Missing Permissions

16. [Cached Permissions Survive Sign-Out for Next User](#16-cached-permissions-survive-signout) MEDIUM
17. [Self-Update Permissions Doesn't Refresh Local Cache](#17-self-update-no-cache-refresh) MEDIUM
18. [Compliance Metadata is Wide Open](#18-compliance-metadata-open) MEDIUM
19. [Engineer Can Reassign Their Own Job to Anyone](#19-engineer-reassign-jobs) ⚠️ HIGH
20. [`completed_jobsheets` and `invoices` Have No Permission Gates](#20-jobsheets-invoices-no-gates) MEDIUM
21. [`asset_service_history` Writes Have No Permission Gate](#21-service-history-no-gate) MEDIUM
22. [Defects Have No Permission Gate Beyond Membership](#22-defects-no-gate) MEDIUM
23. [Permission Map Missing Keys After Migration](#23-permission-map-migration) MEDIUM

### Phase 4 — Polish & Hardening

24. [Engineer Cannot Create Customers but Can Create Quotes](#24-engineer-quote-without-customer) LOW
25. [Floor Plan Pin Position Bypass via `assetsEdit`](#25-floor-plan-pin-bypass) LOW
26. [Invite Code Collisions Not Checked](#26-invite-code-collisions) LOW
27. [Invite Code Never Expires](#27-invite-code-never-expires) LOW

### Implementation Notes

28. [Implementation Order](#28-implementation-order)
29. [Testing Plan](#29-testing-plan)
30. [Permission Audit Checklist](#30-permission-audit-checklist)

---

# Phase 1 — Security & Data Integrity Critical Fixes

## 1. Joiner Rule Allows Joining Any Company Without Invite Code

### Severity

⚠️ **CRITICAL SECURITY** — exposes all company data to unauthorised access.

### Problem

`firestore.rules` for the members collection:

```
allow create: if hasPermission(companyId, 'team_manage')
              || (request.auth.uid == memberId
                  && request.resource.data.isActive == true
                  && (
                    (request.resource.data.role == "admin"
                      && !exists(/databases/$(database)/documents/companies/$(companyId)))
                    || request.resource.data.role == "engineer"   // ← THIS LINE
                  ));
```

The bottom branch lets any authenticated user write a member doc as `engineer` to ANY existing company — without any check that they have a valid invite code. The invite code check happens client-side in `CompanyService.joinCompany`, but the security rules don't enforce it.

A malicious user with the Firebase SDK can:

1. Read the public `companies` collection (rule allows any auth user)
2. Pick any company by ID
3. Write a member doc making themselves an engineer
4. Now they're "isCompanyMember", which gates read access to: dispatched jobs, sites, customers, asset registers, floor plans, defects, jobsheets, asset service history, quotes — everything

### Fix

#### Step 1 — Move company joining to a Cloud Function

**File:** `functions/company_join.js` (NEW)

```js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.joinCompany = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const { inviteCode } = data;
  if (!inviteCode || typeof inviteCode !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invite code required');
  }

  const code = inviteCode.trim().toUpperCase();
  const db = admin.firestore();

  // Look up the company server-side
  const query = await db.collection('companies')
    .where('inviteCode', '==', code)
    .limit(1)
    .get();

  if (query.empty) {
    throw new functions.https.HttpsError('not-found', 'Invalid invite code');
  }

  const companyDoc = query.docs[0];
  const companyId = companyDoc.id;
  const company = companyDoc.data();

  // Check expiry (see issue #27)
  if (company.inviteCodeExpiresAt &&
      company.inviteCodeExpiresAt.toMillis() < Date.now()) {
    throw new functions.https.HttpsError('failed-precondition', 'Invite code expired');
  }

  const uid = context.auth.uid;
  const memberRef = companyDoc.ref.collection('members').doc(uid);

  // Check existing membership
  const existing = await memberRef.get();
  if (existing.exists && existing.data().isActive === true) {
    throw new functions.https.HttpsError('already-exists', 'Already a member');
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const userRecord = await admin.auth().getUser(uid);

  // Write member + profile atomically
  const batch = db.batch();
  batch.set(memberRef, {
    uid,
    displayName: userRecord.displayName || userRecord.email?.split('@')[0] || 'Engineer',
    email: userRecord.email || '',
    role: 'engineer',
    joinedAt: now,
    isActive: true,
    permissions: defaultEngineerPermissions(),
  });
  batch.set(
    db.doc(`users/${uid}/profile/main`),
    {
      uid,
      companyId,
      companyRole: 'engineer',
    },
    { merge: true }
  );
  await batch.commit();

  return { companyId, companyName: company.name };
});

function defaultEngineerPermissions() {
  // Mirror Dart enum defaults
  return {
    web_portal_access: false,
    dispatch_create: false,
    // ... etc
  };
}
```

#### Step 2 — Remove the engineer self-create branch from rules

**File:** `firestore.rules` — change to:

```
allow create: if hasPermission(companyId, 'team_manage')
              || (request.auth.uid == memberId
                  && request.resource.data.role == "admin"
                  && !exists(/databases/$(database)/documents/companies/$(companyId)));
```

The founder branch stays (and is hardened in #3). The engineer branch is removed entirely — joining now requires the Cloud Function.

#### Step 3 — Update `CompanyService.joinCompany` to call the function

```dart
Future<Company> joinCompany(String inviteCode) async {
  final callable = FirebaseFunctions.instance.httpsCallable('joinCompany');
  final result = await callable.call({'inviteCode': inviteCode});
  final data = result.data as Map;
  final companyId = data['companyId'] as String;
  // Refresh local profile
  await UserProfileService.instance.loadProfile(_uid!);
  AnalyticsService.instance.logCompanyJoined(companyId, CompanyRole.engineer.name);
  return (await getCompany(companyId))!;
}
```

### Tests

- Direct Firestore write of an engineer member doc → permission denied
- Cloud Function with valid code → member added, profile updated
- Cloud Function with invalid code → not-found error
- Cloud Function while already a member → already-exists error

---

## 2. Removed Member's User Profile Not Cleared

### Severity

⚠️ **HIGH** — most likely the bug you spotted in production.

### Problem

`CompanyService.removeMember`:

```dart
Future<void> removeMember(String companyId, String memberUid) async {
  await _companiesCol.doc(companyId).collection('members').doc(memberUid)
      .update({'isActive': false});
}
```

That's the entire method. The removed user's `users/{uid}/profile/main` document still says `companyId: <removed-company>` and `companyRole: engineer`. Their local SharedPreferences cache still says they're a member.

When the removed user opens the app:

1. `loadProfile` reads their profile → "you're in company X"
2. `_loadMemberDoc` reads the member doc → exists but `isActive: false`
3. `isCompanyMember` security rule checks `isActive == true` → returns false
4. UI happily renders the company tabs, dispatch tab, etc.
5. Every Firestore query fails silently with permission denied
6. User sees "you're in company X" but every action errors with no clear explanation

### Fix

#### Step 1 — Update `removeMember` to also clear the user's profile

```dart
Future<void> removeMember(String companyId, String memberUid) async {
  final batch = _firestore.batch();

  // Soft-delete the member doc (preserves audit trail)
  batch.update(
    _companiesCol.doc(companyId).collection('members').doc(memberUid),
    {
      'isActive': false,
      'removedAt': DateTime.now().toIso8601String(),
      'removedBy': _uid,
    },
  );

  // Clear the user's profile so the next login shows "no company"
  batch.set(
    _firestore.collection('users').doc(memberUid).collection('profile').doc('main'),
    {
      'companyId': null,
      'companyRole': null,
    },
    SetOptions(merge: true),
  );

  await batch.commit();
}
```

#### Step 2 — Defensive client-side handling in `_loadMemberDoc`

```dart
Future<void> _loadMemberDoc(String uid, String? companyId) async {
  if (companyId == null) {
    _cachedMember = null;
    return;
  }
  try {
    final memberDoc = await _firestore
        .collection('companies').doc(companyId)
        .collection('members').doc(uid).get();

    if (memberDoc.exists && memberDoc.data() != null) {
      final member = CompanyMember.fromJson(memberDoc.data()!);

      // NEW: if member is inactive, treat as no company
      if (!member.isActive) {
        debugPrint('Member is inactive — clearing profile');
        _cachedMember = null;
        _cachedProfile = _cachedProfile?.copyWith(
          companyId: null,
          companyRole: null,
        );
        // Persist the cleared profile so we don't loop
        if (_cachedProfile != null) {
          await saveProfile(_cachedProfile!);
        }
        return;
      }

      _cachedMember = member;
      _cachedProfile = _cachedProfile?.copyWith(companyRole: member.role);
    } else {
      // Member doc doesn't exist — same recovery
      _cachedMember = null;
      _cachedProfile = _cachedProfile?.copyWith(
        companyId: null,
        companyRole: null,
      );
      if (_cachedProfile != null) await saveProfile(_cachedProfile!);
    }
  } catch (e) {
    debugPrint('UserProfileService: _loadMemberDoc failed: $e');
  }
}
```

The defensive handling is important — there will be users in production who already have stale profiles from previous removals.

#### Step 3 — Push notification to removed user

When a member is removed, send them an FCM notification (if they have a token):

```js
// functions/on_member_removed.js
exports.onMemberRemoved = functions.firestore
  .document('companies/{companyId}/members/{memberId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.isActive === true && after.isActive === false) {
      // Send "you've been removed" notification
      const userDoc = await admin.firestore()
        .doc(`users/${context.params.memberId}/profile/main`).get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: 'Removed from team',
            body: 'You no longer have access to your previous company.',
          },
        });
      }
    }
  });
```

### Tests

- Remove member → their profile.companyId is null after sync
- Removed member opens app → sees "no company" state, not error spam
- Existing stale profile (member inactive) → defensive handler recovers
- FCM notification delivered to removed member

---

## 3. Founder Rule Race Condition

### Severity

⚠️ **CRITICAL SECURITY** — could allow unauthorised admin access if companyId becomes predictable.

### Problem

```
allow create: if (request.auth.uid == memberId
                  && request.resource.data.role == "admin"
                  && !exists(/databases/$(database)/documents/companies/$(companyId)));
```

This rule says: "you can self-add as admin if the company doc doesn't exist yet." It exists so `createCompany`'s batch can write company + member atomically.

Two issues:

1. The rule doesn't check that the company doc IS being created in the same write batch. So someone can write an admin member doc BEFORE the company exists and just leave it there.
2. Combined with #8 (company doc world-readable, including for queries), if anyone exposes a way to predict or enumerate companyIds, they can pre-claim admin status.

Currently companyIds are generated server-side via `_companiesCol.doc()` (random) so the practical risk is low. But it's a design smell — the security model relies on companyId unpredictability rather than enforcing the actual rule (founder = whoever creates the company).

### Fix

Move company creation to a Cloud Function entirely:

**File:** `functions/company_create.js` (NEW)

```js
exports.createCompany = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const { name, address, phone, email } = data;
  if (!name || typeof name !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Name required');
  }

  const uid = context.auth.uid;
  const db = admin.firestore();

  // Check user isn't already in a company
  const existingProfile = await db.doc(`users/${uid}/profile/main`).get();
  if (existingProfile.exists && existingProfile.data().companyId) {
    throw new functions.https.HttpsError('failed-precondition',
      'Already in a company');
  }

  const companyRef = db.collection('companies').doc();
  const inviteCode = await generateUniqueInviteCode();  // see issue #26

  const userRecord = await admin.auth().getUser(uid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.set(companyRef, {
    id: companyRef.id,
    name,
    address: address || null,
    phone: phone || null,
    email: email || null,
    createdBy: uid,
    createdAt: now,
    inviteCode,
    inviteCodeExpiresAt: admin.firestore.Timestamp.fromMillis(
      Date.now() + 90 * 24 * 60 * 60 * 1000
    ),
  });
  batch.set(companyRef.collection('members').doc(uid), {
    uid,
    displayName: userRecord.displayName || 'Admin',
    email: userRecord.email || '',
    role: 'admin',
    joinedAt: now,
    isActive: true,
    permissions: defaultAdminPermissions(),
  });
  batch.set(db.doc(`users/${uid}/profile/main`), {
    uid,
    companyId: companyRef.id,
    companyRole: 'admin',
  }, { merge: true });

  await batch.commit();
  return { companyId: companyRef.id };
});
```

**File:** `firestore.rules` — remove the founder rule entirely:

```
allow create: if hasPermission(companyId, 'team_manage');
```

That's the only direct-create path now. Founders use the Cloud Function; joiners use the Cloud Function (#1).

**File:** `lib/services/company_service.dart` — update `createCompany`:

```dart
Future<Company> createCompany({...}) async {
  final callable = FirebaseFunctions.instance.httpsCallable('createCompany');
  final result = await callable.call({
    'name': name,
    'address': address,
    'phone': phone,
    'email': email,
  });
  final companyId = (result.data as Map)['companyId'] as String;
  await UserProfileService.instance.loadProfile(_uid!);
  AnalyticsService.instance.logCompanyCreated(companyId);
  return (await getCompany(companyId))!;
}
```

### Tests

- Direct client write of admin member doc to non-existent company → permission denied
- Cloud Function creates company + member + profile atomically
- Calling Cloud Function while already in a company → fails

---

## 4. Permissions Cached Forever

### Severity

⚠️ **HIGH** — outdated permissions cause confusing UX and rule failures at submission time.

### Problem

`UserProfileService.loadProfile` runs once on login (`main.dart:392`). After that, `_cachedMember` is in memory and only re-read if you log out and back in. There's no listener on the `members/{uid}` doc.

Real impact:

- Admin removes Engineer A's `quotesCreate` permission while A is logged in
- A continues seeing the "Create Quote" button
- A goes through the entire quote form
- Submit fails with permission denied at the final step
- A has lost their work and doesn't understand why

Same issue applies to role changes, permission grants, and removal (#2).

### Fix

#### Step 1 — Set up a stream listener on the member doc

**File:** `lib/services/user_profile_service.dart`

```dart
StreamSubscription<DocumentSnapshot>? _memberSub;

Future<void> loadProfile(String uid) async {
  // ... existing logic ...

  // After loading, set up a real-time listener
  _setupMemberListener(uid, _cachedProfile?.companyId);
}

void _setupMemberListener(String uid, String? companyId) {
  _memberSub?.cancel();
  if (companyId == null) return;

  _memberSub = _firestore
      .collection('companies')
      .doc(companyId)
      .collection('members')
      .doc(uid)
      .snapshots()
      .listen((doc) async {
    if (!doc.exists || doc.data() == null) {
      // Member removed entirely — clear local state
      _cachedMember = null;
      _cachedProfile = _cachedProfile?.copyWith(
        companyId: null,
        companyRole: null,
      );
      if (_cachedProfile != null) await saveProfile(_cachedProfile!);
      _notifyChange();
      return;
    }

    final newMember = CompanyMember.fromJson(doc.data()!);
    if (!newMember.isActive) {
      // Member soft-deleted (#2) — same recovery
      _cachedMember = null;
      _cachedProfile = _cachedProfile?.copyWith(
        companyId: null,
        companyRole: null,
      );
      if (_cachedProfile != null) await saveProfile(_cachedProfile!);
      _notifyChange();
      return;
    }

    final roleChanged = newMember.role != _cachedMember?.role;
    final permsChanged = !mapEquals(
      newMember.permissions,
      _cachedMember?.permissions,
    );

    _cachedMember = newMember;
    if (roleChanged) {
      _cachedProfile = _cachedProfile?.copyWith(companyRole: newMember.role);
      if (_cachedProfile != null) await _cacheToPrefs(_cachedProfile!);
    }

    if (roleChanged || permsChanged) {
      _notifyChange();
    }
  });
}

@override
Future<void> clearProfile() async {
  _memberSub?.cancel();
  _memberSub = null;
  // ... rest of existing clearProfile logic ...
}
```

#### Step 2 — Add a change notifier

`UserProfileService` should extend `ChangeNotifier` (or use a `ValueNotifier`) so screens can listen for permission changes:

```dart
class UserProfileService extends ChangeNotifier {
  // ...
  void _notifyChange() => notifyListeners();
}
```

#### Step 3 — Make permission-sensitive widgets reactive

In screens that show conditional UI based on permissions, wrap in `AnimatedBuilder` or use a Provider:

```dart
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: UserProfileService.instance,
    builder: (context, _) {
      final canCreate = UserProfileService.instance
          .hasPermission(AppPermission.dispatchCreate);
      return Scaffold(
        floatingActionButton: canCreate
          ? FloatingActionButton(/* ... */)
          : null,
      );
    },
  );
}
```

#### Step 4 — Show "permissions updated" toast

When `_notifyChange` fires AND the user is currently navigating, show a non-blocking toast: "Your permissions were updated. Some actions may now be different."

### Tests

- Admin updates engineer's permissions → engineer's UI updates within 1-2 seconds
- Engineer's role changes → cached role updates
- Engineer's member doc deleted → recovers to no-company state
- No listener leak after sign-out

---

## 5. Admin Self-Demotion Lockout

### Severity

⚠️ **HIGH** — can permanently lock the company out of admin functions.

### Problem

`updateMemberRole` has zero guards. An admin can change their own role to "engineer". If they're the only admin, the company is now adminless and unrecoverable through the UI.

### Fix

#### Step 1 — Block in the service layer

```dart
Future<void> updateMemberRole(
  String companyId,
  String memberUid,
  CompanyRole newRole, {
  Map<String, bool>? permissions,
}) async {
  // Guard: if demoting an admin, ensure another admin exists
  if (newRole != CompanyRole.admin) {
    final currentMemberDoc = await _companiesCol
        .doc(companyId).collection('members').doc(memberUid).get();
    final currentMember = CompanyMember.fromJson(currentMemberDoc.data()!);
    if (currentMember.role == CompanyRole.admin) {
      final adminsSnap = await _companiesCol
          .doc(companyId)
          .collection('members')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();
      if (adminsSnap.docs.length <= 1) {
        throw LastAdminException(
          'Cannot demote the only admin. Promote another member to admin first.'
        );
      }
    }
  }

  final perms = permissions ?? AppPermission.defaultsForRole(newRole);
  // ... rest of existing logic ...
}

class LastAdminException implements Exception {
  final String message;
  LastAdminException(this.message);
  @override
  String toString() => 'LastAdminException: $message';
}
```

#### Step 2 — Block in the Firestore rules

Rules can't easily query collection counts, so this is enforced primarily at the service layer. As a defence-in-depth, add a Cloud Function trigger that reverts illegal demotions:

```js
exports.preventLastAdminDemotion = functions.firestore
  .document('companies/{companyId}/members/{memberId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.role === 'admin' && after.role !== 'admin') {
      const adminsSnap = await admin.firestore()
        .collection(`companies/${context.params.companyId}/members`)
        .where('role', '==', 'admin')
        .where('isActive', '==', true)
        .get();
      if (adminsSnap.empty) {
        // Revert and notify
        await change.after.ref.update({ role: 'admin' });
        // TODO: send notification to the demoted admin
      }
    }
  });
```

#### Step 3 — UI warning

In `team_management_screen.dart` _handleMemberAction, before showing the role change dialog:

```dart
if (member.uid == _currentUid && member.role == CompanyRole.admin) {
  final adminCount = await CompanyService.instance.getAdminCount(companyId);
  if (adminCount <= 1) {
    await showAdaptiveAlertDialog(
      context: context,
      title: 'Cannot Change Role',
      message: 'You are the only admin. Promote another member to admin '
               'before changing your own role.',
      confirmLabel: 'OK',
    );
    return;
  }
}
```

### Tests

- Single admin tries to demote self → exception with explanation
- Two admins, one demotes self → succeeds
- Cloud Function reverts illegal demotion if it slips through

---

## 6. Admin Self-Removal

### Severity

⚠️ **HIGH** — orphans the company.

### Problem

`removeMember` can be called with `memberUid == _uid`. The team management UI doesn't disable the "Remove" option for the current user — it's only the popup menu that's hidden via `!isCurrentUser`, but the action handler doesn't double-check.

Also: the `team_manage` permission gates removeMember in rules. A dispatcher granted `team_manage` can remove the admin. Combined with #5, this can orphan the company.

### Fix

#### Step 1 — Block self-removal in service

```dart
Future<void> removeMember(String companyId, String memberUid) async {
  if (memberUid == _uid) {
    throw const SelfRemovalException(
      'You cannot remove yourself. Use "Leave Company" instead.'
    );
  }

  // If removing the last admin, block
  final targetDoc = await _companiesCol
      .doc(companyId).collection('members').doc(memberUid).get();
  final target = CompanyMember.fromJson(targetDoc.data()!);
  if (target.role == CompanyRole.admin) {
    final adminsSnap = await _companiesCol
        .doc(companyId).collection('members')
        .where('role', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .get();
    if (adminsSnap.docs.length <= 1) {
      throw const LastAdminException(
        'Cannot remove the only admin.'
      );
    }
  }

  // Existing logic from #2 fix
  final batch = _firestore.batch();
  batch.update(
    _companiesCol.doc(companyId).collection('members').doc(memberUid),
    {'isActive': false, 'removedAt': DateTime.now().toIso8601String(), 'removedBy': _uid},
  );
  batch.set(
    _firestore.collection('users').doc(memberUid).collection('profile').doc('main'),
    {'companyId': null, 'companyRole': null},
    SetOptions(merge: true),
  );
  await batch.commit();
}
```

#### Step 2 — Block in security rules

```
match /members/{memberId} {
  // Existing rules...

  // Prevent self-removal via the soft-delete path
  allow update: if hasPermission(companyId, 'team_manage')
                && (
                  // Cannot soft-delete yourself
                  request.auth.uid != memberId
                  || resource.data.isActive == request.resource.data.isActive
                );
}
```

### Tests

- Admin tries to remove self via team management → exception
- Admin tries to remove self via direct Firestore write → permission denied
- Dispatcher with team_manage tries to remove the only admin → blocked at service layer

---

## 7. `leaveCompany` Hard-Deletes the Member Doc

### Severity

⚠️ **HIGH** — destroys audit trail.

### Problem

```dart
Future<void> leaveCompany() async {
  // ...
  final batch = _firestore.batch();
  batch.delete(_companiesCol.doc(cId).collection('members').doc(uid));  // ← HARD DELETE
  // ...
}
```

`removeMember` correctly soft-deletes (`isActive: false`). `leaveCompany` does a hard delete. Once gone, any reference to that uid in dispatched jobs, jobsheets, service history is unresolvable.

The data integrity story should be the same in both directions — engineers leaving voluntarily shouldn't get a different audit treatment than engineers being removed.

### Fix

```dart
Future<void> leaveCompany() async {
  final uid = _uid;
  if (uid == null) return;
  final cId = UserProfileService.instance.companyId;
  if (cId == null) return;

  // Block the only admin from leaving
  final selfDoc = await _companiesCol.doc(cId).collection('members').doc(uid).get();
  if (selfDoc.exists) {
    final self = CompanyMember.fromJson(selfDoc.data()!);
    if (self.role == CompanyRole.admin) {
      final adminsSnap = await _companiesCol
          .doc(cId).collection('members')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();
      if (adminsSnap.docs.length <= 1) {
        throw const LastAdminException(
          'You are the only admin. Promote another member to admin or '
          'delete the company before leaving.'
        );
      }
    }
  }

  final batch = _firestore.batch();

  // Soft-delete instead of hard-delete (preserves audit trail)
  batch.update(
    _companiesCol.doc(cId).collection('members').doc(uid),
    {
      'isActive': false,
      'leftAt': DateTime.now().toIso8601String(),
      // No 'removedBy' — they left voluntarily
    },
  );

  batch.set(
    _firestore.collection('users').doc(uid).collection('profile').doc('main'),
    {'companyId': null, 'companyRole': null},
    SetOptions(merge: true),
  );

  await batch.commit();

  await UserProfileService.instance.saveProfile(UserProfile(uid: uid));
}
```

#### Update security rules to allow self-soft-delete

Currently the rule allows hard self-delete. Change to allow self-soft-delete only:

```
allow update: if request.auth.uid == memberId
              && request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly(['isActive', 'leftAt'])
              && request.resource.data.isActive == false;
```

Remove the `allow delete: ... || request.auth.uid == memberId` self-delete branch entirely.

### Tests

- Engineer leaves company → member doc still exists with `isActive: false, leftAt: <date>`
- Service history references to the engineer still resolve to a name (read from soft-deleted member)
- Only admin tries to leave → blocked
- Other admins exist → leave succeeds

---

## 8. Company Doc World-Readable

### Severity

MEDIUM — privacy/security; enables enumeration attacks.

### Problem

```
match /companies/{companyId} {
  allow read: if request.auth != null;
}
```

Any authenticated user can read every company doc, including names, addresses, phone numbers, emails, and invite codes. The original justification was probably "needed for join-by-invite-code query" — but with #1 moving join to a Cloud Function, this no longer applies.

### Fix

#### Step 1 — Restrict reads to members

```
match /companies/{companyId} {
  allow read: if isCompanyMember(companyId);
  allow create: if false;  // only via Cloud Function (#3)
  allow update: if hasPermission(companyId, 'company_edit');
  allow delete: if hasPermission(companyId, 'company_delete');
}
```

#### Step 2 — Provide a "preview by invite code" Cloud Function

For UX (showing "You're about to join Acme Ltd" before confirming join):

```js
exports.previewCompanyByCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const code = (data.inviteCode || '').trim().toUpperCase();
  const query = await admin.firestore().collection('companies')
    .where('inviteCode', '==', code).limit(1).get();
  if (query.empty) {
    throw new functions.https.HttpsError('not-found', 'Invalid code');
  }
  const c = query.docs[0].data();
  return {
    name: c.name,
    // Deliberately minimal — no address, phone, etc
  };
});
```

### Tests

- Non-member direct query of `/companies` → permission denied
- Non-member preview by code → returns name only
- Member reads own company doc → succeeds

---

## 9. `teamManage` Promotion Escalation

### Severity

⚠️ **HIGH** — privilege escalation.

### Problem

A dispatcher granted `teamManage` can call `updateMemberRole` and promote themselves to admin. The rules say `team_manage` can update any member doc, including the role field. Once admin, they have full access to everything.

### Fix

#### Step 1 — Server-side enforcement via Cloud Function

The cleanest enforcement is to move role changes to a Cloud Function:

**File:** `functions/update_member_role.js` (NEW)

```js
exports.updateMemberRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const { companyId, memberUid, newRole } = data;
  const callerUid = context.auth.uid;
  const db = admin.firestore();

  const callerDoc = await db.doc(`companies/${companyId}/members/${callerUid}`).get();
  if (!callerDoc.exists || !callerDoc.data().isActive) {
    throw new functions.https.HttpsError('permission-denied', 'Not a member');
  }
  const callerRole = callerDoc.data().role;

  // Only admins can change roles AT ALL
  if (callerRole !== 'admin') {
    throw new functions.https.HttpsError('permission-denied',
      'Only admins can change roles');
  }

  // Prevent self-demotion as last admin
  if (memberUid === callerUid && newRole !== 'admin') {
    const adminsSnap = await db.collection(`companies/${companyId}/members`)
      .where('role', '==', 'admin')
      .where('isActive', '==', true)
      .get();
    if (adminsSnap.docs.length <= 1) {
      throw new functions.https.HttpsError('failed-precondition',
        'Cannot demote the only admin');
    }
  }

  await db.doc(`companies/${companyId}/members/${memberUid}`).update({
    role: newRole,
    permissions: defaultsForRole(newRole),
  });

  return { success: true };
});
```

#### Step 2 — Tighten security rules

```
match /members/{memberId} {
  // Team managers can update everything EXCEPT role and permissions
  allow update: if hasPermission(companyId, 'team_manage')
                && !request.resource.data.diff(resource.data).affectedKeys()
                    .hasAny(['role', 'permissions']);

  // Role/permission changes only via Cloud Function (which uses admin SDK)
  // No rule allows direct role/permission writes from clients
}
```

#### Step 3 — Update `CompanyService.updateMemberRole` to call function

```dart
Future<void> updateMemberRole(
  String companyId,
  String memberUid,
  CompanyRole newRole,
) async {
  final callable = FirebaseFunctions.instance.httpsCallable('updateMemberRole');
  await callable.call({
    'companyId': companyId,
    'memberUid': memberUid,
    'newRole': newRole.name,
  });

  if (memberUid == _uid) {
    // Refresh local cache (the listener from #4 will also catch this)
    final profile = UserProfileService.instance.profile;
    if (profile != null) {
      await UserProfileService.instance.saveProfile(
        profile.copyWith(companyRole: newRole),
      );
    }
  }
}
```

#### Step 4 — Same for `updateMemberPermissions`

Move to a Cloud Function with the same admin-only check.

### Tests

- Dispatcher with team_manage tries to promote self via direct Firestore write → permission denied
- Dispatcher with team_manage tries to promote self via Cloud Function → permission denied
- Admin promotes engineer to dispatcher via function → succeeds

---

# Phase 2 — Permission/UI Mismatches

These are the bugs that surface as "I have permission but no button" or "I don't have permission but the button is there." The Firestore rules enforce correctly, but the UI doesn't match.

## 10. Engineer with `dispatchCreate` Has Nowhere to Create Jobs

### Severity

⚠️ **HIGH** — direct user-reported issue. **This is the bug you described.**

### Problem

`main.dart:589`:

```dart
Widget get _dispatchScreen {
  // ...
  if (profile.hasPermission(AppPermission.dispatchViewAll)) {
    return const DispatchDashboardScreen();
  }
  return const EngineerJobsScreen();
}
```

The Dispatch tab routes to `DispatchDashboardScreen` (which has the create FAB) ONLY if you have `dispatchViewAll`. Without it, you go to `EngineerJobsScreen`, which has no create entry point at all.

So an engineer with `dispatchCreate: true, dispatchEdit: true, dispatchDelete: true, dispatchViewAll: false` has **three of the four dispatch permissions but cannot create, edit, or delete a single job** because they can't reach the screens.

The same logic applies to:
- FCM notification routing (`_navigateToJobFromMessage`)
- Local notification routing (`_handleNotificationTap`)
- Dispatch badge subscription

All four places make the SAME mistake: gating "do you see the dashboard" on `dispatchViewAll`.

### Fix

This is a routing problem, not a permission problem — `dispatchViewAll` was meant to gate "can you see all jobs vs only your own" but it's being used as "can you see the dashboard at all."

#### Step 1 — Decouple "see dashboard" from "see all jobs"

The Dispatch Dashboard should be available to anyone with ANY dispatch permission. The dashboard's CONTENT should adapt based on `dispatchViewAll`:

- Has `dispatchViewAll`: shows all company jobs
- No `dispatchViewAll` but has `dispatchCreate`/`dispatchEdit`/`dispatchDelete`: shows only their own assigned jobs PLUS create capability if they have it

#### Step 2 — Refactor the routing logic

**File:** `lib/main.dart`

```dart
Widget get _dispatchScreen {
  final rc = RemoteConfigService.instance;
  final profile = UserProfileService.instance;
  if (!rc.dispatchEnabled || !profile.hasCompany) {
    return const DispatchEmptyScreen();
  }

  // Anyone with ANY dispatch permission gets the dashboard
  // (with content scoped to their permissions)
  final hasAnyDispatchAccess =
    profile.hasPermission(AppPermission.dispatchViewAll) ||
    profile.hasPermission(AppPermission.dispatchCreate) ||
    profile.hasPermission(AppPermission.dispatchEdit) ||
    profile.hasPermission(AppPermission.dispatchDelete);

  if (hasAnyDispatchAccess) {
    return const DispatchDashboardScreen();
  }

  // No management permissions at all — just show their assigned jobs
  return const EngineerJobsScreen();
}
```

#### Step 3 — Make the Dashboard adapt to permissions

**File:** `lib/screens/dispatch/dispatch_dashboard_screen.dart`

```dart
Widget build(BuildContext context) {
  final profile = UserProfileService.instance;
  final canViewAll = profile.hasPermission(AppPermission.dispatchViewAll);
  final canCreate = profile.hasPermission(AppPermission.dispatchCreate);

  return Scaffold(
    appBar: AppBar(
      title: Text(canViewAll ? 'All Jobs' : 'My Jobs'),
    ),
    body: StreamBuilder<List<DispatchedJob>>(
      stream: canViewAll
        ? DispatchService.instance.streamAllJobs(companyId)
        : DispatchService.instance.streamJobsAssignedTo(companyId, _uid),
      builder: (context, snapshot) { /* ... */ },
    ),
    floatingActionButton: canCreate
      ? FloatingActionButton(/* ... */)
      : null,
  );
}
```

#### Step 4 — Fix the same issue in notification routing

```dart
void _navigateToJobFromMessage(Map<String, dynamic> data) {
  // ...
  final profile = UserProfileService.instance;
  // Use the more granular check — anyone with view-all OR edit access
  // gets the full dashboard view of the job
  final canViewFullJob =
    profile.hasPermission(AppPermission.dispatchViewAll) ||
    profile.hasPermission(AppPermission.dispatchEdit);

  if (canViewFullJob) {
    nav.push(MaterialPageRoute(
      builder: (_) => DispatchedJobDetailScreen(companyId: companyId, jobId: jobId),
    ));
  } else {
    nav.push(MaterialPageRoute(
      builder: (_) => EngineerJobDetailScreen(companyId: companyId, jobId: jobId),
    ));
  }
}
```

Apply the same fix to `_handleNotificationTap` and `_subscribeToDispatchBadge`.

### Tests

- Engineer with `dispatchCreate: true, dispatchViewAll: false` → sees dashboard with create FAB but only their own jobs
- Engineer with all dispatch perms false → sees plain EngineerJobsScreen
- Dispatcher with `dispatchViewAll: true` → sees full dashboard with all jobs
- Engineer with `dispatchEdit` but not `dispatchViewAll` → can edit jobs assigned to them only

---

## 11. Engineer with `dispatchEdit` / `dispatchDelete` Cannot Reach Jobs to Edit/Delete

### Severity

⚠️ **HIGH** — same root cause as #10.

### Problem

Same as #10: even if you fix the dashboard routing, an engineer with `dispatchEdit: true, dispatchViewAll: false` will only see their own assigned jobs in the dashboard. They cannot edit jobs they're not assigned to. That MAY be intentional (edit only your own), but the permission name `dispatchEdit` doesn't communicate that.

### Fix

#### Step 1 — Document the scoping behaviour

Update the permission label and description in `lib/models/permission.dart`:

```dart
dispatchEdit('dispatch_edit', 'Edit Jobs',
  'Dispatch',
  description: 'Edit jobs you can see (limited by View All Jobs)'),
```

This needs an extra `description` field on the enum.

#### Step 2 — Validate the matrix

Add documentation:

| Permission combo | Result |
|---|---|
| viewAll: false, edit: true | Edit jobs assigned to you only |
| viewAll: true, edit: false | View all jobs but edit none |
| viewAll: true, edit: true | Edit any company job |
| viewAll: false, edit: false | Cannot reach edit screens |

#### Step 3 — Surface this in Member Permissions UI

In the team management → edit permissions screen, when an admin toggles a permission, show inline help text explaining the scoping:

```
☑ Edit Jobs
   ⓘ Engineers can only edit jobs assigned to them unless they also
     have View All Jobs.
```

### Tests

Same matrix as above, verified end-to-end.

---

## 12. Web Portal Access Gated by Role, Not by `webPortalAccess` Permission

### Severity

⚠️ **HIGH** — defined permission is completely ignored.

### Problem

`lib/screens/web/web_router.dart:95`:

```dart
if (!profile.isDispatcherOrAdmin) return '/access-denied?reason=engineerOnly';
```

The web portal access check uses `isDispatcherOrAdmin` (a role-based shortcut). The `AppPermission.webPortalAccess` enum value exists but is never checked.

Result:
- A dispatcher with `webPortalAccess: false` can still access the web portal (they have the role)
- An engineer with `webPortalAccess: true` (granted by admin) cannot access the web portal (wrong role)

The granular permission is a no-op.

### Fix

```dart
if (!profile.hasPermission(AppPermission.webPortalAccess)) {
  return '/access-denied?reason=noWebAccess';
}
```

Update the access denied screen to show the right message. Update default permissions to ensure dispatchers and admins still have `webPortalAccess: true` by default (they already do per `AppPermission.defaultsForRole`).

### Tests

- Engineer with webPortalAccess: true → can log into web
- Dispatcher with webPortalAccess: false → blocked
- Admin (always has all permissions) → can log in

---

## 13. Team Management Menu Gated by Role, Not by `teamManage` Permission

### Severity

⚠️ **HIGH** — same issue as #12 in a different place.

### Problem

`lib/screens/settings/settings_screen.dart:544`:

```dart
if (profile.isDispatcherOrAdmin) {
  tiles.add(_SettingsTileData(title: 'Team', /* ... */));
}
```

A dispatcher with `teamManage: false` (the default!) sees the menu but the screen is read-only inside (the popup menu is hidden, no actions available). An engineer with `teamManage: true` (granted by admin) cannot reach the menu.

### Fix

```dart
if (profile.hasPermission(AppPermission.teamManage)) {
  tiles.add(_SettingsTileData(title: 'Team', /* ... */));
}
```

For consistency: a member who DOESN'T have `teamManage` but IS in a company should still be able to see a read-only "View Team" screen (so they know who their colleagues are). That should be a separate gate — perhaps the existing rule of `isCompanyMember`.

So the hierarchy becomes:

```dart
// Anyone in a company can view the team list
if (profile.hasCompany) {
  tiles.add(_SettingsTileData(
    title: 'Team',
    subtitle: profile.hasPermission(AppPermission.teamManage)
      ? 'Manage team members'
      : 'View team members',
    onTap: () => /* open team screen with appropriate mode */,
  ));
}
```

The team management screen already uses `_canManageTeam` to gate actions inside, so this works out of the box.

### Tests

- Engineer with teamManage: true → menu visible, can manage
- Engineer with teamManage: false → menu visible but read-only
- Dispatcher with teamManage: false → same — read-only
- User with no company → no menu

---

## 14. Dispatch Dashboard "Create Job" FAB Doesn't Check Permission

### Severity

MEDIUM — confusing UX; rule failure at submission.

### Problem

`lib/screens/dispatch/dispatch_dashboard_screen.dart:102`:

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(context, adaptivePageRoute(builder: (_) => const CreateJobScreen()));
  },
  child: Icon(AppIcons.add),
),
```

No permission check. A dispatcher who has `dispatchCreate: false` (rare but possible if explicitly removed) sees the FAB, taps it, fills the form, hits Save → permission denied.

### Fix

Already covered partially by #10 — the FAB should be conditional:

```dart
floatingActionButton: profile.hasPermission(AppPermission.dispatchCreate)
  ? FloatingActionButton(/* ... */)
  : null,
```

### Tests

- Member with dispatchCreate: false → no FAB shown
- Member with dispatchCreate: true → FAB shown, works

---

## 15. Settings Screen Gates by Role Throughout — Audit and Fix

### Severity

MEDIUM — pattern needs systematic correction.

### Problem

`grep -rn "isDispatcherOrAdmin\|isAdmin" lib/screens/` shows 8+ places where role-based shortcuts are used instead of the granular permissions that the system was designed around. Specific cases identified:

- `settings_screen.dart:544` — Team menu (covered in #13)
- `company_settings_screen.dart:74-167` — Multiple admin-only sections
- `web_router.dart:95` — Web portal access (covered in #12)

### Fix

Audit every usage and replace with the appropriate permission check. The mapping:

| Current check | Should be |
|---|---|
| `isDispatcherOrAdmin` for "Team" menu | `hasPermission(teamManage)` OR `hasCompany` for view-only |
| `isAdmin` for "Edit Company" | `hasPermission(companyEdit)` |
| `isAdmin` for "Delete Company" | `hasPermission(companyDelete)` |
| `isAdmin` for "Regenerate Invite Code" | `hasPermission(inviteCodeRegenerate)` |
| `isDispatcherOrAdmin` for web portal | `hasPermission(webPortalAccess)` |

#### Permission Audit Tool

To prevent regression, add a lint or test that flags any new use of `isAdmin` or `isDispatcherOrAdmin` outside `UserProfileService` itself:

```bash
# CI script
if grep -rn "isAdmin\|isDispatcherOrAdmin" lib/screens/ lib/widgets/; then
  echo "ERROR: Use hasPermission() instead of role shortcuts in UI code"
  exit 1
fi
```

### Tests

For every formerly role-gated UI element, verify with all permission combinations:
- Permission granted → element visible/usable
- Permission denied → element hidden/disabled

---

# Phase 3 — Permission Logic Gaps & Missing Permissions

## 16. Cached Permissions Survive Sign-Out for Next User

### Severity

MEDIUM — brief permission leak across users on shared device.

### Problem

`UserProfileService.clearProfile` clears SharedPreferences but the in-memory `_cachedMember` is set to null, then `loadProfile` for the next user might briefly leave the previous user's permissions visible if there's any UI render between profile clear and member doc load.

### Fix

Make `loadProfile` atomic for cache invalidation:

```dart
Future<void> loadProfile(String uid) async {
  // CLEAR FIRST — synchronous, before any awaits
  _cachedMember = null;
  _cachedProfile = null;
  notifyListeners();

  try {
    // ... existing logic ...
  }
}
```

### Tests

- User A signs out, User B signs in → no flash of A's UI elements
- Rapid switch users → consistent state

---

## 17. Self-Update Permissions Doesn't Refresh Local Cache

### Severity

MEDIUM — fixed automatically by #4 (real-time listener) once that lands.

### Problem

`updateMemberPermissions` writes to Firestore but doesn't update `_cachedMember`. If admin opens "Edit My Permissions" and toggles, the local cache is stale until restart.

### Fix

Already fixed by the real-time listener from #4. As an interim, before #4 lands:

```dart
Future<void> updateMemberPermissions(
  String companyId,
  String memberUid,
  Map<String, bool> permissions,
) async {
  await _companiesCol
      .doc(companyId).collection('members').doc(memberUid)
      .update({'permissions': permissions});

  // If updating self, refresh local cache
  if (memberUid == _uid && UserProfileService.instance._cachedMember != null) {
    UserProfileService.instance._cachedMember =
      UserProfileService.instance._cachedMember!.copyWith(permissions: permissions);
    UserProfileService.instance.notifyListeners();
  }
}
```

### Tests

- Admin updates own permissions → UI reflects immediately

---

## 18. Compliance Metadata is Wide Open

### Severity

MEDIUM — falsifiable audit data.

### Problem

```
match /compliance_meta/{docId} {
  allow read: if isCompanyMember(companyId);
  allow write: if isCompanyMember(companyId);
}
```

Any member can overwrite the "last compliance report" date. Could falsify compliance records.

### Fix

```
match /compliance_meta/{docId} {
  allow read: if isCompanyMember(companyId);
  allow create: if isCompanyMember(companyId);
  allow update: if false;  // immutable
  allow delete: if false;
}
```

If updates are needed (e.g. correcting a date), require admin only:

```
allow update: if hasPermission(companyId, 'company_edit');
```

### Tests

- Engineer overwrites compliance_meta → permission denied
- Admin updates compliance_meta → succeeds

---

## 19. Engineer Can Reassign Their Own Job to Anyone

### Severity

⚠️ **HIGH** — workflow integrity issue.

### Problem

```
allow update: if hasPermission(companyId, 'dispatch_edit')
              || (isCompanyMember(companyId)
                  && resource.data.assignedTo == request.auth.uid
                  && request.resource.data.diff(resource.data).affectedKeys()
                     .hasOnly(['status', 'updatedAt', 'completedAt',
                               'linkedJobsheetId', 'lastUpdatedBy', 'declineReason',
                               'assignedTo', 'assignedToName']));
```

`assignedTo` and `assignedToName` are in the engineer-allowed update keys. An engineer can:
- Reassign their job to another engineer without dispatcher approval
- Set `assignedTo` to null, abandoning the job
- Push uncompleted jobs onto colleagues

### Fix

Remove `assignedTo` and `assignedToName` from the engineer self-update list:

```
allow update: if hasPermission(companyId, 'dispatch_edit')
              || (isCompanyMember(companyId)
                  && resource.data.assignedTo == request.auth.uid
                  && request.resource.data.diff(resource.data).affectedKeys()
                     .hasOnly(['status', 'updatedAt', 'completedAt',
                               'linkedJobsheetId', 'lastUpdatedBy', 'declineReason']));
```

For "decline" workflow (engineer marks "I can't do this"):
- Engineer sets `status: declined` and `declineReason: ...`
- A Cloud Function or dispatcher action then handles reassignment

```js
exports.onJobDeclined = functions.firestore
  .document('companies/{companyId}/dispatched_jobs/{jobId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    if (after.status === 'declined' && before.status !== 'declined') {
      // Notify dispatcher to reassign
      // Optionally clear assignedTo automatically:
      await change.after.ref.update({
        assignedTo: null,
        assignedToName: null,
      });
    }
  });
```

### Tests

- Engineer tries to reassign own job → permission denied
- Engineer declines own job → dispatcher notified, assignment cleared
- Dispatcher reassigns declined job → succeeds

---

## 20. `completed_jobsheets` and `invoices` Have No Permission Gates

### Severity

MEDIUM — any member can edit/delete any invoice or jobsheet.

### Problem

```
match /completed_jobsheets/{jobsheetId} {
  allow read: if isCompanyMember(companyId);
  allow write: if isCompanyMember(companyId);  // ← any member, any action
}
match /invoices/{invoiceId} {
  allow read: if isCompanyMember(companyId);
  allow create, update, delete: if isCompanyMember(companyId);  // ← same
}
```

An engineer can delete an invoice the dispatcher just sent.

### Fix

Add permissions to the enum:

```dart
// In permission.dart
invoicesCreate('invoices_create', 'Create Invoices', 'Invoicing'),
invoicesEdit('invoices_edit', 'Edit Invoices', 'Invoicing'),
invoicesDelete('invoices_delete', 'Delete Invoices', 'Invoicing'),
invoicesSend('invoices_send', 'Send Invoices', 'Invoicing'),
jobsheetsEdit('jobsheets_edit', 'Edit Completed Jobsheets', 'Jobsheets'),
jobsheetsDelete('jobsheets_delete', 'Delete Completed Jobsheets', 'Jobsheets'),
```

Update default matrices for each role.

Update rules:

```
match /invoices/{invoiceId} {
  allow read: if isCompanyMember(companyId);
  allow create: if hasPermission(companyId, 'invoices_create');
  allow update: if hasPermission(companyId, 'invoices_edit');
  allow delete: if hasPermission(companyId, 'invoices_delete');
}

match /completed_jobsheets/{jobsheetId} {
  allow read: if isCompanyMember(companyId);
  allow create: if isCompanyMember(companyId);  // anyone can complete a jobsheet
  allow update: if hasPermission(companyId, 'jobsheets_edit');
  allow delete: if hasPermission(companyId, 'jobsheets_delete');
}
```

### Tests

- Engineer deletes another's invoice → permission denied
- Dispatcher with invoicesDelete → can delete

---

## 21. `asset_service_history` Writes Have No Permission Gate

### Severity

MEDIUM — phantom test records possible.

### Problem

```
match /asset_service_history/{recordId} {
  allow read: if isCompanyMember(companyId);
  allow create: if isCompanyMember(companyId);
}
```

Any member can write a service record. They CANNOT update the asset itself (rules block that without `assets_edit`), but they can poison the audit trail with phantom test records that have no corresponding asset state change.

### Fix

Add permission:

```dart
assetsTest('assets_test', 'Test/Inspect Assets', 'Assets'),
```

Default true for engineers (they're the ones doing tests). Update rules:

```
match /asset_service_history/{recordId} {
  allow read: if isCompanyMember(companyId);
  allow create: if hasPermission(companyId, 'assets_test');
}
```

### Tests

- Engineer with assets_test: false → cannot create service records
- Engineer with assets_test: true → can create

---

## 22. Defects Have No Permission Gate Beyond Membership

### Severity

MEDIUM — anyone can rectify anyone's defect.

### Problem

```
match /defects/{defectId} {
  allow read: if isCompanyMember(companyId);
  allow create, update: if isCompanyMember(companyId);
  allow delete: if hasPermission(companyId, 'assets_delete');
}
```

Any member can mark any defect as rectified, regardless of who logged it or whether they did the work.

### Fix

Add permissions:

```dart
defectsLog('defects_log', 'Log Defects', 'Defects'),
defectsRectify('defects_rectify', 'Mark Defects Rectified', 'Defects'),
defectsDelete('defects_delete', 'Delete Defects', 'Defects'),
```

Update rules:

```
match /defects/{defectId} {
  allow read: if isCompanyMember(companyId);
  allow create: if hasPermission(companyId, 'defects_log');
  allow update: if hasPermission(companyId, 'defects_rectify');
  allow delete: if hasPermission(companyId, 'defects_delete');
}
```

### Tests

- Engineer with defects_log only → can create but not rectify
- Engineer with defects_rectify → can rectify

---

## 23. Permission Map Missing Keys After Migration

### Severity

MEDIUM — silent denials when adding new permissions in updates.

### Problem

When you add a new permission to the enum (like the BS 5839 ones planned), existing member docs in Firestore won't have that key. `member.permissions[newKey.key]` returns null, which becomes `false` in `hasPermission`.

So shipping a new feature could silently lock out users who SHOULD have it by default.

### Fix

In `CompanyMember.fromJson`, merge defaults under any explicitly stored permissions:

```dart
factory CompanyMember.fromJson(Map<String, dynamic> json) {
  final role = CompanyRole.values.firstWhere(
    (r) => r.name == json['role'],
    orElse: () => CompanyRole.engineer,
  );

  // Start with defaults for the role, then override with stored values
  final defaults = AppPermission.defaultsForRole(role);
  final stored = json['permissions'] != null
    ? Map<String, bool>.from(json['permissions'] as Map)
    : <String, bool>{};
  final merged = {...defaults, ...stored};

  return CompanyMember(
    // ... other fields ...
    permissions: merged,
  );
}
```

This way, a new permission added in a release uses its default for users whose docs don't have it explicitly set.

#### Optional: backfill migration

Add a one-time migration to write the merged permissions back to Firestore so the docs become self-describing:

```dart
// On admin login, check if their member doc has all current permission keys
// If not, backfill with defaults
```

### Tests

- Add new permission to enum → existing engineer doc reports default value
- Backfill migration writes complete permissions map

---

# Phase 4 — Polish & Hardening

## 24. Engineer Cannot Create Customers but Can Create Quotes

### Severity

LOW — design oversight.

### Problem

```dart
customersCreate.key: false,
// but...
quotesCreate.key: true,
```

An engineer at a brand-new customer's site can't quote on the spot — they'd need to ask a dispatcher to create the customer first.

### Fix

Either:
- (A) Default `customersCreate: true` for engineers
- (B) Allow quote creation with an inline "new customer" pathway that creates a customer record using a separate permission `customersQuickCreate` (default true for engineers)

Option B is safer — full customer management stays controlled, but quoting workflows aren't blocked.

### Tests

- Engineer creates quote with new customer → both records created

---

## 25. Floor Plan Pin Position Bypass via `assetsEdit`

### Severity

LOW — permission scope mismatch.

### Problem

Pin positions live on the Asset doc (`floorPlanId`, `xPercent`, `yPercent`). `assetsEdit` lets engineers update these, effectively "deleting" pins without `floorPlansDelete`.

### Fix

Either:
- (A) Treat pin positions as part of floor plan management, requiring `floorPlansEdit`
- (B) Accept the current behaviour and document it (engineers can re-pin assets but not delete floor plans)

Option B is probably the right call — it matches user expectations. Just document it.

---

## 26. Invite Code Collisions Not Checked

### Severity

LOW — improbable but possible.

### Problem

`_generateInviteCode` uses 32^6 ≈ 1 billion combinations — fine for now. But there's no uniqueness check. If two companies happen to get the same code, `joinCompany` picks the first by ID, potentially the wrong company.

### Fix

In `createCompany` Cloud Function:

```js
async function generateUniqueInviteCode() {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateRandomCode();
    const existing = await db.collection('companies')
      .where('inviteCode', '==', code).limit(1).get();
    if (existing.empty) return code;
  }
  throw new Error('Could not generate unique invite code');
}
```

---

## 27. Invite Code Never Expires

### Severity

LOW — reduces future attack surface.

### Problem

Codes generated years ago still work. If an ex-employee took a screenshot, they can rejoin.

### Fix

Add `inviteCodeExpiresAt` to the Company doc, default 90 days. Already added in #3 spec. Add a UI affordance for admins to extend or renew the code.

UI: in company settings, show "Invite code expires in 30 days" with a "Renew (90 more days)" button.

---

# Implementation Notes

## 28. Implementation Order

### Phase 1 — Security & Data Integrity (Week 1)

Critical — these have direct security or data-integrity implications. Ship before BS 5839 spec.

1. #1 — Joiner rule (security hole)
2. #3 — Founder rule (defence in depth)
3. #2 — Removed member profile (likely the bug you noticed)
4. #4 — Real-time permission listener
5. #5 — Last admin protection
6. #6 — Self-removal protection
7. #7 — Soft-delete on leave
8. #9 — Promotion escalation prevention
9. #8 — Company doc visibility

### Phase 2 — UI Mismatches (Week 2)

The "permission exists but UI doesn't honour it" class.

10. #10 — Engineer dispatch routing (your reported bug)
11. #11 — Edit/delete scoping documentation
12. #12 — Web portal permission check
13. #13 — Team management menu gate
14. #14 — Dispatch FAB permission check
15. #15 — Settings screen audit

### Phase 3 — Logic Gaps (Week 3)

16. #16 — Cache invalidation
17. #17 — Self-update cache refresh (auto-fixed by #4)
18. #18 — Compliance metadata immutability
19. #19 — Engineer reassignment block
20. #20 — Invoice/jobsheet permissions
21. #21 — Service history permission
22. #22 — Defects permissions
23. #23 — Permission map merge

### Phase 4 — Polish (Week 4)

24. #24 — Engineer customer creation
25. #25 — Floor plan pin scope (likely accept as-is)
26. #26 — Invite code uniqueness
27. #27 — Invite code expiry

---

## 29. Testing Plan

### Unit Tests

- `CompanyMember.fromJson` with missing permissions → defaults applied
- `CompanyMember.fromJson` with role change → permissions merge correctly
- `LastAdminException` thrown when appropriate
- `_addMonthsSafely`-style date helpers (covered by bug fix spec)

### Integration Tests

- Full lifecycle: create company → invite engineer → assign job → engineer completes
- Removed engineer reopens app → recovers to no-company state
- Real-time permission update reflected within 2 seconds
- Last admin demotion blocked at every layer

### Security Tests

- Direct Firestore writes attempting to bypass each rule
- Cloud Function invocations with malformed data
- Role escalation attempts via every documented path

### Multi-User Manual Tests

- Two phones logged in as different members; admin updates engineer's permissions; engineer's UI updates
- Admin removes engineer; engineer's app immediately handles the loss

---

## 30. Permission Audit Checklist

For every UI element in the app that does anything mutative (create/edit/delete/send/approve), ensure:

- [ ] The button/action is hidden or disabled if the user lacks the relevant permission
- [ ] The screen has an early-return guard if the user lacks read permission for its content
- [ ] The save/submit action checks permission before showing a loading spinner
- [ ] The Firestore rule independently enforces the same permission
- [ ] The error message at submit-time clearly explains a permission denial (not a generic "failed to save")

Maintain this checklist as a living document. Add new entries when new permissions are introduced (e.g. for the BS 5839 spec).

### Recommended permissions for BS 5839 spec

When implementing the BS 5839 spec, add these permissions (as referenced in that spec, section 25):

- `bs5839ConfigEdit` (default: dispatchers + admins true)
- `bs5839VisitStart` (default: all engineers true)
- `bs5839VisitSign` (default: all engineers true)
- `bs5839VariationLog` (default: all engineers true)
- `bs5839VariationApprove` (default: admins only)
- `bs5839VariationRectify` (default: admins + dispatchers)
- `bs5839ReportIssue` (default: admins + dispatchers)
- `bs5839CompetencyEditOwn` (default: all engineers true — for self only)
- `bs5839CompetencyViewTeam` (default: admins + dispatchers)

---

*End of permissions hardening specification.*
