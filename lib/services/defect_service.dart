import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/defect.dart';

/// Service for managing asset defects with full lifecycle (open → rectified).
/// Uses basePath pattern: 'users/{uid}' or 'companies/{companyId}'.
class DefectService {
  DefectService._();
  static final DefectService instance = DefectService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _defectsCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/defects');
  }

  DocumentReference<Map<String, dynamic>> _complianceMetaDoc(
      String basePath, String siteId) {
    return _firestore
        .doc('$basePath/sites/$siteId/compliance_meta/last_report');
  }

  /// Create a new defect.
  Future<void> createDefect(
      String basePath, String siteId, Defect defect) async {
    try {
      await _defectsCol(basePath, siteId)
          .doc(defect.id)
          .set(defect.toJson());
    } catch (e) {
      debugPrint('Error creating defect: $e');
      rethrow;
    }
  }

  /// Mark a single defect as rectified.
  Future<void> rectifyDefect(
    String basePath,
    String siteId,
    String defectId, {
    required String rectifiedBy,
    required String rectifiedByName,
    String? rectifiedNote,
  }) async {
    try {
      await _defectsCol(basePath, siteId).doc(defectId).update({
        'status': Defect.statusRectified,
        'rectifiedBy': rectifiedBy,
        'rectifiedByName': rectifiedByName,
        'rectifiedAt': DateTime.now().toIso8601String(),
        'rectifiedNote': rectifiedNote,
      });
    } catch (e) {
      debugPrint('Error rectifying defect: $e');
      rethrow;
    }
  }

  /// Batch-rectify all open defects for an asset.
  Future<int> rectifyAllForAsset(
    String basePath,
    String siteId,
    String assetId, {
    required String rectifiedBy,
    required String rectifiedByName,
    String? rectifiedNote,
  }) async {
    final snapshot = await _defectsCol(basePath, siteId)
        .where('assetId', isEqualTo: assetId)
        .where('status', isEqualTo: Defect.statusOpen)
        .get();

    if (snapshot.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': Defect.statusRectified,
        'rectifiedBy': rectifiedBy,
        'rectifiedByName': rectifiedByName,
        'rectifiedAt': now,
        'rectifiedNote':
            rectifiedNote ?? 'Auto-rectified: asset passed batch test',
      });
    }
    await batch.commit();
    return snapshot.docs.length;
  }

  /// Stream all defects for a specific asset, newest first.
  Stream<List<Defect>> getDefectsForAsset(
      String basePath, String siteId, String assetId) {
    return _defectsCol(basePath, siteId)
        .where('assetId', isEqualTo: assetId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Defect.fromJson(doc.data()))
            .toList());
  }

  /// One-shot fetch of open defects for an asset.
  Future<List<Defect>> getOpenDefectsForAsset(
      String basePath, String siteId, String assetId) async {
    try {
      final snapshot = await _defectsCol(basePath, siteId)
          .where('assetId', isEqualTo: assetId)
          .where('status', isEqualTo: Defect.statusOpen)
          .get();
      return snapshot.docs
          .map((doc) => Defect.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting open defects for asset: $e');
      return [];
    }
  }

  /// Stream open defects for a site.
  Stream<List<Defect>> getOpenDefectsForSite(
      String basePath, String siteId) {
    return _defectsCol(basePath, siteId)
        .where('status', isEqualTo: Defect.statusOpen)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Defect.fromJson(doc.data()))
            .toList());
  }

  /// One-shot fetch of all defects for a site.
  Future<List<Defect>> getDefectsForSite(
      String basePath, String siteId) async {
    try {
      final snapshot = await _defectsCol(basePath, siteId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => Defect.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting defects for site: $e');
      return [];
    }
  }

  /// Count defects rectified since a given date.
  Future<int> getRectifiedCountSince(
      String basePath, String siteId, DateTime since) async {
    try {
      final snapshot = await _defectsCol(basePath, siteId)
          .where('status', isEqualTo: Defect.statusRectified)
          .where('rectifiedAt',
              isGreaterThanOrEqualTo: since.toIso8601String())
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting rectified count: $e');
      return 0;
    }
  }

  /// Get the date of the last compliance report for this site.
  Future<DateTime?> getLastReportDate(
      String basePath, String siteId) async {
    try {
      final doc = await _complianceMetaDoc(basePath, siteId).get();
      if (!doc.exists || doc.data() == null) return null;
      final dateStr = doc.data()!['lastReportDate'] as String?;
      return dateStr != null ? DateTime.tryParse(dateStr) : null;
    } catch (e) {
      debugPrint('Error getting last report date: $e');
      return null;
    }
  }

  /// Store the date of the latest compliance report.
  Future<void> setLastReportDate(
      String basePath, String siteId, DateTime date) async {
    try {
      await _complianceMetaDoc(basePath, siteId).set({
        'lastReportDate': date.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error setting last report date: $e');
    }
  }

  /// Upload defect photos to Firebase Storage and return download URLs.
  Future<List<String>> uploadDefectPhotos({
    required String basePath,
    required String siteId,
    required String assetId,
    required String defectId,
    required List<Uint8List> photos,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < photos.length; i++) {
      try {
        final ref = _storage.ref(
            '$basePath/sites/$siteId/assets/$assetId/defect_photos/$defectId/$i.jpg');
        await ref.putData(
            photos[i], SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        debugPrint('Error uploading defect photo $i: $e');
      }
    }
    return urls;
  }
}
