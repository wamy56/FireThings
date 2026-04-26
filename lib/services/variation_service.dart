import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'storage_upload_helper.dart';

import '../models/bs5839_variation.dart';

class VariationService {
  VariationService._();
  static final VariationService instance = VariationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/variations');
  }

  Stream<List<Bs5839Variation>> getVariationsStream(
      String basePath, String siteId) {
    return _col(basePath, siteId)
        .orderBy('loggedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return Bs5839Variation.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Bs5839Variation>()
            .toList());
  }

  Stream<List<Bs5839Variation>> getActiveVariationsStream(
      String basePath, String siteId) {
    return _col(basePath, siteId)
        .where('status', isEqualTo: 'active')
        .orderBy('loggedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return Bs5839Variation.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Bs5839Variation>()
            .toList());
  }

  Stream<List<Bs5839Variation>> getProhibitedVariationsStream(
      String basePath, String siteId) {
    return _col(basePath, siteId)
        .where('isProhibited', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return Bs5839Variation.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Bs5839Variation>()
            .toList());
  }

  Future<void> saveVariation(
      String basePath, String siteId, Bs5839Variation variation) async {
    await _col(basePath, siteId).doc(variation.id).set(variation.toJson());
  }

  Future<void> rectifyVariation({
    required String basePath,
    required String siteId,
    required String variationId,
    required String visitId,
  }) async {
    await _col(basePath, siteId).doc(variationId).update({
      'status': VariationStatus.rectified.name,
      'rectifiedAt': DateTime.now().toIso8601String(),
      'rectifiedByVisitId': visitId,
    });
  }

  Future<void> updateStatus({
    required String basePath,
    required String siteId,
    required String variationId,
    required VariationStatus status,
  }) async {
    final updates = <String, dynamic>{'status': status.name};
    if (status == VariationStatus.rectified) {
      updates['rectifiedAt'] = DateTime.now().toIso8601String();
    }
    await _col(basePath, siteId).doc(variationId).update(updates);
  }

  Future<String> uploadEvidencePhoto({
    required String basePath,
    required String siteId,
    required String variationId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        '$basePath/sites/$siteId/bs5839_evidence/$variationId/$timestamp.$ext';
    final url =
        await StorageUploadHelper.upload(path, fileBytes, 'image/$ext');

    await _col(basePath, siteId).doc(variationId).update({
      'evidencePhotoUrls': FieldValue.arrayUnion([url]),
    });

    return url;
  }

  Future<void> removeEvidencePhoto({
    required String basePath,
    required String siteId,
    required String variationId,
    required String photoUrl,
  }) async {
    try {
      final ref = _storage.refFromURL(photoUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting evidence photo from storage: $e');
    }

    await _col(basePath, siteId).doc(variationId).update({
      'evidencePhotoUrls': FieldValue.arrayRemove([photoUrl]),
    });
  }

  String generateId(String basePath, String siteId) {
    return _col(basePath, siteId).doc().id;
  }
}
