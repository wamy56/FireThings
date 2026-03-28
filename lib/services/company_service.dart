import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/company.dart';
import '../models/company_member.dart';
import '../models/company_site.dart';
import '../models/company_customer.dart';
import '../models/user_profile.dart';
import 'user_profile_service.dart';
import 'analytics_service.dart';

/// Manages company creation, membership, and settings.
/// All company data lives in Firestore under companies/{companyId}/.
class CompanyService {
  CompanyService._();
  static final CompanyService instance = CompanyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  String? get _displayName => _auth.currentUser?.displayName;
  String? get _email => _auth.currentUser?.email;

  CollectionReference get _companiesCol =>
      _firestore.collection('companies');

  /// Create a new company. The current user becomes admin.
  Future<Company> createCompany({
    required String name,
    String? address,
    String? phone,
    String? email,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final docRef = _companiesCol.doc();
    final now = DateTime.now();
    final inviteCode = _generateInviteCode();

    final company = Company(
      id: docRef.id,
      name: name,
      address: address,
      phone: phone,
      email: email,
      createdBy: uid,
      createdAt: now,
      inviteCode: inviteCode,
    );

    final member = CompanyMember(
      uid: uid,
      displayName: _displayName ?? 'Admin',
      email: _email ?? '',
      role: CompanyRole.admin,
      joinedAt: now,
    );

    // Batch write: company doc + member doc + user profile
    final batch = _firestore.batch();
    batch.set(docRef, company.toJson());
    batch.set(
      docRef.collection('members').doc(uid),
      member.toJson(),
    );
    batch.set(
      _firestore.collection('users').doc(uid).collection('profile').doc('main'),
      {
        'uid': uid,
        'companyId': docRef.id,
        'companyRole': CompanyRole.admin.name,
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    // Update local profile cache
    await UserProfileService.instance.saveProfile(
      UserProfile(
        uid: uid,
        companyId: docRef.id,
        companyRole: CompanyRole.admin,
        fcmToken: UserProfileService.instance.profile?.fcmToken,
      ),
    );

    AnalyticsService.instance.logCompanyCreated(docRef.id);

    return company;
  }

  /// Join a company using an invite code.
  Future<Company> joinCompany(String inviteCode) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    // Look up company by invite code
    final query = await _companiesCol
        .where('inviteCode', isEqualTo: inviteCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }

    final companyDoc = query.docs.first;
    final company = Company.fromJson(
      companyDoc.data() as Map<String, dynamic>,
    );

    // Check if already a member
    final existingMember = await companyDoc.reference
        .collection('members')
        .doc(uid)
        .get();
    if (existingMember.exists) {
      throw Exception('You are already a member of this company');
    }

    final now = DateTime.now();
    final member = CompanyMember(
      uid: uid,
      displayName: _displayName ?? 'Engineer',
      email: _email ?? '',
      role: CompanyRole.engineer,
      joinedAt: now,
    );

    // Batch write: member doc + user profile
    final batch = _firestore.batch();
    batch.set(
      companyDoc.reference.collection('members').doc(uid),
      member.toJson(),
    );
    batch.set(
      _firestore.collection('users').doc(uid).collection('profile').doc('main'),
      {
        'uid': uid,
        'companyId': company.id,
        'companyRole': CompanyRole.engineer.name,
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    // Update local profile cache
    await UserProfileService.instance.saveProfile(
      UserProfile(
        uid: uid,
        companyId: company.id,
        companyRole: CompanyRole.engineer,
        fcmToken: UserProfileService.instance.profile?.fcmToken,
      ),
    );

    AnalyticsService.instance.logCompanyJoined(company.id, CompanyRole.engineer.name);

    return company;
  }

  /// Leave the current company.
  Future<void> leaveCompany() async {
    final uid = _uid;
    if (uid == null) return;
    final cId = UserProfileService.instance.companyId;
    if (cId == null) return;

    final batch = _firestore.batch();
    batch.delete(
      _companiesCol.doc(cId).collection('members').doc(uid),
    );
    batch.set(
      _firestore.collection('users').doc(uid).collection('profile').doc('main'),
      {
        'uid': uid,
        'companyId': null,
        'companyRole': null,
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    await UserProfileService.instance.saveProfile(
      UserProfile(uid: uid),
    );
  }

  /// Get a company by ID.
  Future<Company?> getCompany(String companyId) async {
    try {
      final doc = await _companiesCol.doc(companyId).get();
      if (!doc.exists) return null;
      return Company.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('CompanyService: getCompany failed: $e');
      return null;
    }
  }

  /// Get all members of a company.
  Future<List<CompanyMember>> getCompanyMembers(String companyId) async {
    try {
      final snapshot = await _companiesCol
          .doc(companyId)
          .collection('members')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => CompanyMember.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('CompanyService: getCompanyMembers failed: $e');
      return [];
    }
  }

  /// Stream of company members (for real-time updates).
  Stream<List<CompanyMember>> getCompanyMembersStream(String companyId) {
    return _companiesCol
        .doc(companyId)
        .collection('members')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CompanyMember.fromJson(doc.data()))
            .toList());
  }

  /// Update a member's role. Admin only.
  Future<void> updateMemberRole(
    String companyId,
    String memberUid,
    CompanyRole newRole,
  ) async {
    await _companiesCol
        .doc(companyId)
        .collection('members')
        .doc(memberUid)
        .update({'role': newRole.name});

    // Also update the member's user profile
    await _firestore
        .collection('users')
        .doc(memberUid)
        .collection('profile')
        .doc('main')
        .set({'companyRole': newRole.name}, SetOptions(merge: true));

    // If updating self, refresh local cache
    if (memberUid == _uid) {
      final profile = UserProfileService.instance.profile;
      if (profile != null) {
        await UserProfileService.instance.saveProfile(
          profile.copyWith(companyRole: newRole),
        );
      }
    }
  }

  /// Remove a member from the company. Admin only.
  Future<void> removeMember(String companyId, String memberUid) async {
    final batch = _firestore.batch();
    batch.update(
      _companiesCol.doc(companyId).collection('members').doc(memberUid),
      {'isActive': false},
    );
    batch.set(
      _firestore.collection('users').doc(memberUid).collection('profile').doc('main'),
      {
        'uid': memberUid,
        'companyId': null,
        'companyRole': null,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Regenerate the invite code. Admin only.
  Future<String> regenerateInviteCode(String companyId) async {
    final newCode = _generateInviteCode();
    await _companiesCol.doc(companyId).update({'inviteCode': newCode});
    return newCode;
  }

  /// Update company details. Admin only.
  Future<void> updateCompany(Company company) async {
    await _companiesCol.doc(company.id).update(company.toJson());
  }

  /// Delete a company and all its data. Admin only.
  Future<void> deleteCompany(String companyId) async {
    // Get all members to clear their profiles
    final membersSnapshot = await _companiesCol
        .doc(companyId)
        .collection('members')
        .get();

    final batch = _firestore.batch();

    // Clear each member's company profile
    for (final memberDoc in membersSnapshot.docs) {
      batch.set(
        _firestore
            .collection('users')
            .doc(memberDoc.id)
            .collection('profile')
            .doc('main'),
        {
          'uid': memberDoc.id,
          'companyId': null,
          'companyRole': null,
        },
        SetOptions(merge: true),
      );
      batch.delete(memberDoc.reference);
    }

    // Delete dispatched_jobs subcollection
    final jobsSnapshot = await _companiesCol
        .doc(companyId)
        .collection('dispatched_jobs')
        .get();
    for (final doc in jobsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete sites subcollection
    final sitesSnapshot = await _companiesCol
        .doc(companyId)
        .collection('sites')
        .get();
    for (final doc in sitesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete customers subcollection
    final customersSnapshot = await _companiesCol
        .doc(companyId)
        .collection('customers')
        .get();
    for (final doc in customersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the company doc
    batch.delete(_companiesCol.doc(companyId));

    await batch.commit();

    // Clear local profile if current user was in this company
    if (UserProfileService.instance.companyId == companyId) {
      final uid = _uid;
      if (uid != null) {
        await UserProfileService.instance.saveProfile(
          UserProfile(uid: uid),
        );
      }
    }
  }

  // ─── Shared Sites ──────────────────────────────────────────────────

  /// Create a shared company site.
  Future<void> createSite(String companyId, CompanySite site) async {
    await _companiesCol
        .doc(companyId)
        .collection('sites')
        .doc(site.id)
        .set(site.toJson());
  }

  /// Update a shared company site.
  Future<void> updateSite(String companyId, CompanySite site) async {
    await _companiesCol
        .doc(companyId)
        .collection('sites')
        .doc(site.id)
        .update(site.toJson());
  }

  /// Delete a shared company site.
  Future<void> deleteSite(String companyId, String siteId) async {
    await _companiesCol
        .doc(companyId)
        .collection('sites')
        .doc(siteId)
        .delete();
  }

  /// One-shot fetch of a single company site by ID.
  Future<CompanySite?> getSite(String companyId, String siteId) async {
    final doc = await _companiesCol
        .doc(companyId)
        .collection('sites')
        .doc(siteId)
        .get();
    if (!doc.exists) return null;
    return CompanySite.fromJson(doc.data()!);
  }

  /// Stream of all company sites (real-time).
  Stream<List<CompanySite>> getSitesStream(String companyId) {
    return _companiesCol
        .doc(companyId)
        .collection('sites')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CompanySite.fromJson(doc.data()))
            .toList());
  }

  // ─── Shared Customers ─────────────────────────────────────────────

  /// Create a shared company customer.
  Future<void> createCustomer(
      String companyId, CompanyCustomer customer) async {
    await _companiesCol
        .doc(companyId)
        .collection('customers')
        .doc(customer.id)
        .set(customer.toJson());
  }

  /// Update a shared company customer.
  Future<void> updateCustomer(
      String companyId, CompanyCustomer customer) async {
    await _companiesCol
        .doc(companyId)
        .collection('customers')
        .doc(customer.id)
        .update(customer.toJson());
  }

  /// Delete a shared company customer.
  Future<void> deleteCustomer(String companyId, String customerId) async {
    await _companiesCol
        .doc(companyId)
        .collection('customers')
        .doc(customerId)
        .delete();
  }

  /// Stream of all company customers (real-time).
  Stream<List<CompanyCustomer>> getCustomersStream(String companyId) {
    return _companiesCol
        .doc(companyId)
        .collection('customers')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CompanyCustomer.fromJson(doc.data()))
            .toList());
  }

  /// Generate a random invite code like "FT-ABC123".
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(6, (_) => chars[random.nextInt(chars.length)])
        .join();
    return 'FT-$code';
  }
}
