import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/company.dart';
import '../models/company_member.dart';
import '../models/company_site.dart';
import '../models/company_customer.dart';
import '../models/user_profile.dart';
import 'geocoding_service.dart';
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

  CollectionReference get _companiesCol =>
      _firestore.collection('companies');

  /// Create a new company via Cloud Function. The current user becomes admin.
  Future<Company> createCompany({
    required String name,
    String? address,
    String? phone,
    String? email,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final callable = FirebaseFunctions.instance.httpsCallable('createCompany');
    final result = await callable.call<Map<String, dynamic>>({
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
    });

    final companyId = result.data['companyId'] as String;

    await UserProfileService.instance.loadProfile(uid);
    AnalyticsService.instance.logCompanyCreated(companyId);

    return (await getCompany(companyId))!;
  }

  /// Join a company via Cloud Function using an invite code.
  Future<Company> joinCompany(String inviteCode) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final callable = FirebaseFunctions.instance.httpsCallable('joinCompany');
    final result = await callable.call<Map<String, dynamic>>({
      'inviteCode': inviteCode,
    });

    final companyId = result.data['companyId'] as String;

    await UserProfileService.instance.loadProfile(uid);
    AnalyticsService.instance.logCompanyJoined(companyId, CompanyRole.engineer.name);

    return (await getCompany(companyId))!;
  }

  /// Leave the current company. Soft-deletes the member doc to preserve audit trail.
  Future<void> leaveCompany() async {
    final uid = _uid;
    if (uid == null) return;
    final cId = UserProfileService.instance.companyId;
    if (cId == null) return;

    final selfDoc = await _companiesCol.doc(cId).collection('members').doc(uid).get();
    if (selfDoc.exists) {
      final self = CompanyMember.fromJson(selfDoc.data()!);
      if (self.role == CompanyRole.admin) {
        final adminCount = await getAdminCount(cId);
        if (adminCount <= 1) {
          throw LastAdminException(
            'You are the only admin. Promote another member to admin or '
            'delete the company before leaving.',
          );
        }
      }
    }

    final batch = _firestore.batch();
    batch.update(
      _companiesCol.doc(cId).collection('members').doc(uid),
      {
        'isActive': false,
        'leftAt': DateTime.now().toIso8601String(),
      },
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

  /// Update a member's role via Cloud Function. Only admins can change roles.
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
  }

  /// Update a member's granular permissions via Cloud Function. Only admins can change permissions.
  Future<void> updateMemberPermissions(
    String companyId,
    String memberUid,
    Map<String, bool> permissions,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable('updateMemberPermissions');
    await callable.call({
      'companyId': companyId,
      'memberUid': memberUid,
      'permissions': permissions,
    });
  }

  /// Remove a member from the company. Soft-deletes and clears their profile.
  Future<void> removeMember(String companyId, String memberUid) async {
    if (memberUid == _uid) {
      throw SelfRemovalException(
        'You cannot remove yourself. Use "Leave Company" instead.',
      );
    }

    final targetDoc = await _companiesCol
        .doc(companyId).collection('members').doc(memberUid).get();
    if (targetDoc.exists) {
      final target = CompanyMember.fromJson(targetDoc.data()!);
      if (target.role == CompanyRole.admin) {
        final adminCount = await getAdminCount(companyId);
        if (adminCount <= 1) {
          throw LastAdminException('Cannot remove the only admin.');
        }
      }
    }

    final batch = _firestore.batch();
    batch.update(
      _companiesCol.doc(companyId).collection('members').doc(memberUid),
      {
        'isActive': false,
        'removedAt': DateTime.now().toIso8601String(),
        'removedBy': _uid,
      },
    );
    batch.set(
      _firestore.collection('users').doc(memberUid).collection('profile').doc('main'),
      {'companyId': null, 'companyRole': null},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Regenerate the invite code. Admin only. Sets 90-day expiry.
  Future<Map<String, dynamic>> regenerateInviteCode(String companyId) async {
    final newCode = _generateInviteCode();
    final expiresAt = DateTime.now().add(const Duration(days: 90));
    await _companiesCol.doc(companyId).update({
      'inviteCode': newCode,
      'inviteCodeExpiresAt': expiresAt.toIso8601String(),
    });
    return {'code': newCode, 'expiresAt': expiresAt};
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

    // Delete all member docs
    for (final memberDoc in membersSnapshot.docs) {
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

  /// Create a shared company site. Auto-geocodes the address if no coords.
  Future<void> createSite(String companyId, CompanySite site) async {
    final geocoded = await _geocodeSiteIfNeeded(site);
    await _companiesCol
        .doc(companyId)
        .collection('sites')
        .doc(geocoded.id)
        .set(geocoded.toJson());
  }

  /// Update a shared company site. Re-geocodes if address changed.
  Future<void> updateSite(String companyId, CompanySite site,
      {String? previousAddress}) async {
    var updated = site;
    // Re-geocode if address changed or coords are missing
    if (previousAddress != null && previousAddress != site.address ||
        site.latitude == null || site.longitude == null) {
      updated = await _geocodeSiteIfNeeded(site);
    }
    await _companiesCol
        .doc(companyId)
        .collection('sites')
        .doc(updated.id)
        .update(updated.toJson());
  }

  /// Attempt to geocode a site's address if lat/lng are missing.
  Future<CompanySite> _geocodeSiteIfNeeded(CompanySite site) async {
    if (site.latitude != null && site.longitude != null) return site;
    try {
      final result = await GeocodingService.instance.geocode(site.address);
      if (result != null) {
        return site.copyWith(latitude: result.lat, longitude: result.lng);
      }
    } catch (_) {
      // Geocoding failure is non-blocking
    }
    return site;
  }

  /// Delete a shared company site.
  Future<void> deleteSite(String companyId, String siteId) async {
    await _companiesCol
        .doc(companyId)
        .collection('sites')
        .doc(siteId)
        .delete();
  }

  Future<void> deleteSites(String companyId, List<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(
        _companiesCol.doc(companyId).collection('sites').doc(id),
      );
    }
    await batch.commit();
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

  Future<void> deleteCustomers(String companyId, List<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(
        _companiesCol.doc(companyId).collection('customers').doc(id),
      );
    }
    await batch.commit();
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

  /// Count active admins in a company.
  Future<int> getAdminCount(String companyId) async {
    final snap = await _companiesCol
        .doc(companyId)
        .collection('members')
        .where('role', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.length;
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

class LastAdminException implements Exception {
  final String message;
  const LastAdminException(this.message);
  @override
  String toString() => 'LastAdminException: $message';
}

class SelfRemovalException implements Exception {
  final String message;
  const SelfRemovalException(this.message);
  @override
  String toString() => 'SelfRemovalException: $message';
}
