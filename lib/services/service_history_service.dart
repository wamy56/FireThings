import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/service_record.dart';
import 'storage_upload_helper.dart';

/// Append-only service for asset inspection/service history records.
/// Uses basePath pattern: 'users/{uid}' or 'companies/{companyId}'.
class ServiceHistoryService {
  ServiceHistoryService._();
  static final ServiceHistoryService instance = ServiceHistoryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _historyCol(
      String basePath, String siteId) {
    return _firestore
        .collection('$basePath/sites/$siteId/asset_service_history');
  }

  /// Create a new service record (append-only — no update or delete).
  Future<void> createRecord(
      String basePath, String siteId, ServiceRecord record) async {
    try {
      await _historyCol(basePath, siteId)
          .doc(record.id)
          .set(record.toJson());
    } catch (e) {
      debugPrint('Error creating service record: $e');
      rethrow;
    }
  }

  /// Stream all service records for a specific asset, newest first.
  Stream<List<ServiceRecord>> getRecordsForAsset(
      String basePath, String siteId, String assetId) {
    return _historyCol(basePath, siteId)
        .where('assetId', isEqualTo: assetId)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final records = <ServiceRecord>[];
      for (final doc in snapshot.docs) {
        try {
          records.add(ServiceRecord.fromJson(doc.data()));
        } catch (e) {
          debugPrint('Skipping malformed service record ${doc.id}: $e');
        }
      }
      return records;
    });
  }

  /// Stream all service records for a site, newest first.
  Stream<List<ServiceRecord>> getRecordsForSite(
      String basePath, String siteId) {
    return _historyCol(basePath, siteId)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final records = <ServiceRecord>[];
      for (final doc in snapshot.docs) {
        try {
          records.add(ServiceRecord.fromJson(doc.data()));
        } catch (e) {
          debugPrint('Skipping malformed service record ${doc.id}: $e');
        }
      }
      return records;
    });
  }

  /// Get the most recent service record for an asset.
  Future<ServiceRecord?> getLatestRecordForAsset(
      String basePath, String siteId, String assetId) async {
    try {
      final snapshot = await _historyCol(basePath, siteId)
          .where('assetId', isEqualTo: assetId)
          .orderBy('serviceDate', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return ServiceRecord.fromJson(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error getting latest service record: $e');
      return null;
    }
  }

  /// Get all service records for a specific jobsheet.
  Future<List<ServiceRecord>> getRecordsForJobsheet(
      String basePath, String siteId, String jobsheetId) async {
    try {
      final snapshot = await _historyCol(basePath, siteId)
          .where('jobsheetId', isEqualTo: jobsheetId)
          .get();
      return snapshot.docs
          .map((doc) => ServiceRecord.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting records for jobsheet: $e');
      return [];
    }
  }

  /// Upload defect photos to Firebase Storage and return download URLs.
  ///
  /// On web, bypasses the Firebase Storage Dart SDK (platform channel bug)
  /// and uploads directly via the Storage REST API.
  Future<List<String>> uploadDefectPhotos({
    required String basePath,
    required String siteId,
    required String assetId,
    required String recordId,
    required List<Uint8List> photos,
  }) async {
    final urls = <String>[];
    for (int i = 0; i < photos.length; i++) {
      try {
        final path =
            '$basePath/sites/$siteId/assets/$assetId/defects/$recordId/$i.jpg';
        final url =
            await StorageUploadHelper.upload(path, photos[i], 'image/jpeg');
        urls.add(url);
      } catch (e) {
        debugPrint('Error uploading defect photo $i: $e');
      }
    }
    return urls;
  }

}
