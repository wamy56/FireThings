import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_member.dart';
import '../models/permission.dart';
import '../models/user_profile.dart';

/// Manages the current user's profile (company association, FCM token).
/// Caches companyId and role in SharedPreferences for quick startup checks.
/// Extends ChangeNotifier so UI can react to real-time permission updates.
class UserProfileService extends ChangeNotifier {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const _companyIdKey = 'user_company_id';
  static const _companyRoleKey = 'user_company_role';
  static const _fcmTokenKey = 'user_fcm_token';
  static const _permissionsKey = 'user_permissions';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _cachedProfile;
  CompanyMember? _cachedMember;
  StreamSubscription<DocumentSnapshot>? _memberSub;

  /// The current cached profile.
  UserProfile? get profile => _cachedProfile;

  /// The current cached company member (includes permissions).
  CompanyMember? get member => _cachedMember;

  /// Quick check — does the current user belong to a company?
  bool get hasCompany => _cachedProfile?.hasCompany ?? false;

  /// Current company ID from cache.
  String? get companyId => _cachedProfile?.companyId;

  /// Current company role from cache.
  CompanyRole? get companyRole => _cachedMember?.role ?? _cachedProfile?.companyRole;

  /// Whether the user is an admin.
  bool get isAdmin => _cachedMember?.role == CompanyRole.admin;

  /// Whether the user is a dispatcher or admin (backward compat).
  bool get isDispatcherOrAdmin =>
      _cachedMember?.role == CompanyRole.admin ||
      _cachedMember?.role == CompanyRole.dispatcher;

  /// Check a granular permission for the current user.
  /// Admin role always returns true as a safety net.
  bool hasPermission(AppPermission perm) {
    if (_cachedMember == null) return false;
    return _cachedMember!.hasPermission(perm);
  }

  /// Resolves the display name for the current user, falling back through:
  /// 1. CompanyMember.displayName (Firestore)
  /// 2. FirebaseAuth.currentUser.displayName
  /// 3. The local-part of the email address (capitalised)
  /// Never returns 'Unknown' — throws if no name can be resolved.
  String resolveEngineerName() {
    if (_cachedMember?.displayName.isNotEmpty == true) {
      return _cachedMember!.displayName;
    }

    final user = _auth.currentUser;
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
      'recording audit data.',
    );
  }

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference? get _profileDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('profile').doc('main');
  }

  /// Load user profile from Firestore + SharedPreferences cache.
  /// Call this after login from AuthWrapper.
  Future<void> loadProfile(String uid) async {
    _cachedMember = null;
    _cachedProfile = null;
    notifyListeners();

    try {
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

      await _loadMemberDoc(uid, _cachedProfile!.companyId);

      await _cacheToPrefs(_cachedProfile!);

      _setupMemberListener(uid, _cachedProfile!.companyId);
    } catch (e) {
      debugPrint('UserProfileService: loadProfile failed: $e');
      await _loadFromPrefs(uid);
    }
  }

  /// Load the company member doc to get role and permissions.
  Future<void> _loadMemberDoc(String uid, String? companyId) async {
    if (companyId == null) {
      _cachedMember = null;
      return;
    }
    try {
      final memberDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('members')
          .doc(uid)
          .get();

      if (memberDoc.exists && memberDoc.data() != null) {
        final member = CompanyMember.fromJson(memberDoc.data()!);

        if (!member.isActive) {
          debugPrint('UserProfileService: member is inactive — clearing profile');
          _cachedMember = null;
          _cachedProfile = _cachedProfile?.copyWith(
            companyId: null,
            companyRole: null,
          );
          if (_cachedProfile != null) await _cacheToPrefs(_cachedProfile!);
          return;
        }

        _cachedMember = member;
        _cachedProfile = _cachedProfile?.copyWith(companyRole: member.role);
      } else {
        _cachedMember = null;
        _cachedProfile = _cachedProfile?.copyWith(
          companyId: null,
          companyRole: null,
        );
        if (_cachedProfile != null) await _cacheToPrefs(_cachedProfile!);
      }
    } catch (e) {
      debugPrint('UserProfileService: _loadMemberDoc failed: $e');
    }
  }

  void _setupMemberListener(String uid, String? companyId) {
    _memberSub?.cancel();
    _memberSub = null;
    if (companyId == null) return;

    _memberSub = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists || doc.data() == null) {
        _cachedMember = null;
        _cachedProfile = _cachedProfile?.copyWith(
          companyId: null,
          companyRole: null,
        );
        if (_cachedProfile != null) await _cacheToPrefs(_cachedProfile!);
        notifyListeners();
        return;
      }

      final newMember = CompanyMember.fromJson(doc.data()!);
      if (!newMember.isActive) {
        _cachedMember = null;
        _cachedProfile = _cachedProfile?.copyWith(
          companyId: null,
          companyRole: null,
        );
        if (_cachedProfile != null) await _cacheToPrefs(_cachedProfile!);
        notifyListeners();
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
        notifyListeners();
      }
    });
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
      final doc = _profileDoc;
      if (doc != null) {
        await doc.set({'fcmToken': token}, SetOptions(merge: true));
      }

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
    _memberSub?.cancel();
    _memberSub = null;
    _cachedProfile = null;
    _cachedMember = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_companyIdKey);
    await prefs.remove(_companyRoleKey);
    await prefs.remove(_fcmTokenKey);
    await prefs.remove(_permissionsKey);
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
    if (_cachedMember != null) {
      await prefs.setString(
        _permissionsKey,
        jsonEncode(_cachedMember!.toJson()),
      );
    } else {
      await prefs.remove(_permissionsKey);
    }
  }

  Future<void> _loadFromPrefs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cId = prefs.getString(_companyIdKey);
    final roleStr = prefs.getString(_companyRoleKey);
    final token = prefs.getString(_fcmTokenKey);
    final memberJson = prefs.getString(_permissionsKey);

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

    if (memberJson != null) {
      try {
        _cachedMember = CompanyMember.fromJson(
          jsonDecode(memberJson) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('UserProfileService: failed to restore cached member: $e');
        _cachedMember = null;
      }
    }
  }
}

class ProfileNotLoadedException implements Exception {
  final String message;
  ProfileNotLoadedException(this.message);
  @override
  String toString() => 'ProfileNotLoadedException: $message';
}
