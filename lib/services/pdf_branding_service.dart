import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/pdf_branding.dart';

class PdfBrandingService {
  PdfBrandingService._();
  static final PdfBrandingService instance = PdfBrandingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  PdfBranding? _cached;

  Future<PdfBranding> getBranding(String companyId) async {
    if (_cached != null) return _cached!;
    final doc = await _docRef(companyId).get();
    _cached = doc.exists
        ? PdfBranding.fromJson(doc.data()!)
        : PdfBranding.defaultBranding();
    return _cached!;
  }

  Stream<PdfBranding> watchBranding(String companyId) {
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
    if (!['png', 'svg', 'jpg', 'jpeg'].contains(ext)) {
      throw const FormatException('Logo must be PNG, JPG or SVG');
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
    } catch (_) {
      // Silently ignore — branding.logoUrl will be set to null by the caller
    }
  }

  void clearCache() {
    _cached = null;
  }

  DocumentReference<Map<String, dynamic>> _docRef(String companyId) =>
      _firestore
          .collection('companies')
          .doc(companyId)
          .collection('branding')
          .doc('main');

  String _mimeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'svg' => 'image/svg+xml',
        _ => 'application/octet-stream',
      };
}
