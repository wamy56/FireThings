import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_member.dart';
import '../models/user_profile.dart';

/// Manages the current user's profile (company association, FCM token).
/// Caches companyId and role in SharedPreferences for quick startup checks.
class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const _companyIdKey = 'user_company_id';
  static const _companyRoleKey = 'user_company_role';
  static const _fcmTokenKey = 'user_fcm_token';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _cachedProfile;

  /// The current cached profile.
  UserProfile? get profile => _cachedProfile;

  /// Quick check — does the current user belong to a company?
  bool get hasCompany => _cachedProfile?.hasCompany ?? false;

  /// Current company ID from cache.
  String? get companyId => _cachedProfile?.companyId;

  /// Current company role from cache.
  CompanyRole? get companyRole => _cachedProfile?.companyRole;

  /// Whether the user is a dispatcher or admin.
  bool get isDispatcherOrAdmin => _cachedProfile?.isDispatcherOrAdmin ?? false;

  /// Whether the user is an admin.
  bool get isAdmin => _cachedProfile?.isAdmin ?? false;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference? get _profileDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('profile').doc('main');
  }

  /// Load user profile from Firestore + SharedPreferences cache.
  /// Call this after login from AuthWrapper.
  Future<void> loadProfile(String uid) async {
    try {
      // Try Firestore first
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('main')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['uid'] = uid;
        _cachedProfile = UserProfile.fromJson(data);
      } else {
        _cachedProfile = UserProfile(uid: uid);
      }

      // Cache to SharedPreferences
      await _cacheToPrefs(_cachedProfile!);
    } catch (e) {
      debugPrint('UserProfileService: loadProfile failed: $e');
      // Fall back to SharedPreferences
      await _loadFromPrefs(uid);
    }
  }

  /// Save profile to Firestore and update local cache.
  Future<void> saveProfile(UserProfile profile) async {
    try {
      _cachedProfile = profile;
      await _cacheToPrefs(profile);

      final doc = _profileDoc;
      if (doc == null) return;
      await doc.set(profile.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('UserProfileService: saveProfile failed: $e');
    }
  }

  /// Update the FCM token in both the user profile and company member doc.
  Future<void> updateFcmToken(String token) async {
    final uid = _uid;
    if (uid == null) return;

    _cachedProfile = _cachedProfile?.copyWith(fcmToken: token) ??
        UserProfile(uid: uid, fcmToken: token);

    try {
      // Update user profile
      final doc = _profileDoc;
      if (doc != null) {
        await doc.set({'fcmToken': token}, SetOptions(merge: true));
      }

      // Update company member doc if in a company
      final cId = companyId;
      if (cId != null) {
        await _firestore
            .collection('companies')
            .doc(cId)
            .collection('members')
            .doc(uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('UserProfileService: updateFcmToken failed: $e');
    }
  }

  /// Clear cached profile (on sign out).
  Future<void> clearProfile() async {
    _cachedProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_companyIdKey);
    await prefs.remove(_companyRoleKey);
    await prefs.remove(_fcmTokenKey);
  }

  Future<void> _cacheToPrefs(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile.companyId != null) {
      await prefs.setString(_companyIdKey, profile.companyId!);
    } else {
      await prefs.remove(_companyIdKey);
    }
    if (profile.companyRole != null) {
      await prefs.setString(_companyRoleKey, profile.companyRole!.name);
    } else {
      await prefs.remove(_companyRoleKey);
    }
    if (profile.fcmToken != null) {
      await prefs.setString(_fcmTokenKey, profile.fcmToken!);
    }
  }

  Future<void> _loadFromPrefs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cId = prefs.getString(_companyIdKey);
    final roleStr = prefs.getString(_companyRoleKey);
    final token = prefs.getString(_fcmTokenKey);

    CompanyRole? role;
    if (roleStr != null) {
      role = CompanyRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => CompanyRole.engineer,
      );
    }

    _cachedProfile = UserProfile(
      uid: uid,
      companyId: cId,
      companyRole: role,
      fcmToken: token,
    );
  }
}
