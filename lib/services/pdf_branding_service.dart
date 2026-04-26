import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/pdf_branding.dart';
import 'user_profile_service.dart';

class PdfBrandingService {
  PdfBrandingService._();
  static final PdfBrandingService instance = PdfBrandingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  PdfBranding? _cached;
  PdfBranding? _cachedPersonal;

  Future<PdfBranding> getBranding(String companyId) async {
    if (_cached != null) return _cached!;
    final doc = await _docRef(companyId).get();
    _cached = doc.exists
        ? PdfBranding.fromJson(doc.data()!)
        : PdfBranding.defaultBranding();
    return _cached!;
  }

  // Flutter web: Firestore .snapshots() causes infinite recursion via
  // triggerHeartbeat → initializeFirestore. Use one-shot .get() on web.
  Stream<PdfBranding> watchBranding(String companyId) {
    if (kIsWeb) {
      return Stream.fromFuture(_docRef(companyId).get().then((doc) {
        final b = doc.exists
            ? PdfBranding.fromJson(doc.data()!)
            : PdfBranding.defaultBranding();
        _cached = b;
        return b;
      }));
    }
    return _docRef(companyId).snapshots().map((doc) {
      final b = doc.exists
          ? PdfBranding.fromJson(doc.data()!)
          : PdfBranding.defaultBranding();
      _cached = b;
      return b;
    });
  }

  Future<void> saveBranding(String companyId, PdfBranding branding) async {
    final updated = branding.copyWith(
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      lastUpdatedBy: FirebaseAuth.instance.currentUser?.uid,
    );
    await _docRef(companyId).set(updated.toJson());
    _cached = updated;
  }

  Future<String> uploadLogo({
    required String companyId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg'].contains(ext)) {
      throw const FormatException('Logo must be PNG or JPG');
    }
    if (bytes.length > 1024 * 1024) {
      throw const FormatException('Logo must be under 1 MB');
    }
    final ref = _storage.ref('companies/$companyId/branding/logo.$ext');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: _mimeFor(ext)),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteLogo(String companyId, String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  // ── Personal (user-level) branding ──

  Future<PdfBranding> getPersonalBranding(String userId) async {
    if (_cachedPersonal != null) return _cachedPersonal!;
    final doc = await _personalDocRef(userId).get();
    _cachedPersonal = doc.exists
        ? PdfBranding.fromJson(doc.data()!)
        : PdfBranding.defaultBranding();
    return _cachedPersonal!;
  }

  // Flutter web: Firestore .snapshots() causes infinite recursion via
  // triggerHeartbeat → initializeFirestore. Use one-shot .get() on web.
  Stream<PdfBranding> watchPersonalBranding(String userId) {
    if (kIsWeb) {
      return Stream.fromFuture(_personalDocRef(userId).get().then((doc) {
        final b = doc.exists
            ? PdfBranding.fromJson(doc.data()!)
            : PdfBranding.defaultBranding();
        _cachedPersonal = b;
        return b;
      }));
    }
    return _personalDocRef(userId).snapshots().map((doc) {
      final b = doc.exists
          ? PdfBranding.fromJson(doc.data()!)
          : PdfBranding.defaultBranding();
      _cachedPersonal = b;
      return b;
    });
  }

  Future<void> savePersonalBranding(String userId, PdfBranding branding) async {
    final updated = branding.copyWith(
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      lastUpdatedBy: userId,
    );
    await _personalDocRef(userId).set(updated.toJson());
    _cachedPersonal = updated;
  }

  Future<String> uploadPersonalLogo({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg'].contains(ext)) {
      throw const FormatException('Logo must be PNG or JPG');
    }
    if (bytes.length > 1024 * 1024) {
      throw const FormatException('Logo must be under 1 MB');
    }
    final ref = _storage.ref('users/$userId/branding/logo.$ext');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: _mimeFor(ext)),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> deletePersonalLogo(String userId, String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  // ── Resolver ──

  Future<PdfBranding> resolveBrandingForCurrentUser() async {
    final profile = UserProfileService.instance;
    if (profile.companyId != null) {
      return getBranding(profile.companyId!);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      return getPersonalBranding(uid);
    }
    return PdfBranding.defaultBranding();
  }

  void clearCache() {
    _cached = null;
    _cachedPersonal = null;
  }

  DocumentReference<Map<String, dynamic>> _docRef(String companyId) =>
      _firestore
          .collection('companies')
          .doc(companyId)
          .collection('branding')
          .doc('main');

  DocumentReference<Map<String, dynamic>> _personalDocRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('branding')
          .doc('main');

  String _mimeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'application/octet-stream',
      };
}
