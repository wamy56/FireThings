import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import '../models/floor_plan.dart';
import 'storage_upload_helper.dart';

/// CRUD + Storage service for floor plans.
/// Uses basePath pattern: 'users/{uid}' or 'companies/{companyId}'.
class FloorPlanService {
  FloorPlanService._();
  static final FloorPlanService instance = FloorPlanService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _plansCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/floor_plans');
  }

  /// Stream all floor plans for a site, ordered by sortOrder.
  Stream<List<FloorPlan>> getFloorPlansStream(
      String basePath, String siteId) {
    return _plansCol(basePath, siteId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
      final plans = <FloorPlan>[];
      for (final doc in snapshot.docs) {
        try {
          plans.add(FloorPlan.fromJson(doc.data()));
        } catch (e) {
          debugPrint('Skipping malformed floor plan ${doc.id}: $e');
        }
      }
      return plans;
    });
  }

  /// Get a single floor plan.
  Future<FloorPlan?> getFloorPlan(
      String basePath, String siteId, String planId) async {
    try {
      final doc = await _plansCol(basePath, siteId).doc(planId).get();
      if (!doc.exists || doc.data() == null) return null;
      return FloorPlan.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting floor plan: $e');
      return null;
    }
  }

  /// Create a floor plan document.
  Future<void> createFloorPlan(
      String basePath, String siteId, FloorPlan plan) async {
    try {
      await _plansCol(basePath, siteId).doc(plan.id).set(plan.toJson());
    } catch (e) {
      debugPrint('Error creating floor plan: $e');
      rethrow;
    }
  }

  /// Update a floor plan document.
  Future<void> updateFloorPlan(
      String basePath, String siteId, FloorPlan plan) async {
    try {
      final updated = plan.copyWith(
        updatedAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );
      await _plansCol(basePath, siteId).doc(updated.id).update(updated.toJson());
    } catch (e) {
      debugPrint('Error updating floor plan: $e');
      rethrow;
    }
  }

  /// Count how many assets are pinned to a floor plan.
  Future<int> getAffectedAssetCount(
      String basePath, String siteId, String planId) async {
    final snap = await _firestore
        .collection('$basePath/sites/$siteId/assets')
        .where('floorPlanId', isEqualTo: planId)
        .get();
    return snap.docs.length;
  }

  /// Delete a floor plan, clear pin positions on affected assets, then
  /// delete the image from Storage.
  Future<void> deleteFloorPlan(
      String basePath, String siteId, String planId,
      {String extension = 'jpg'}) async {
    try {
      final affectedSnap = await _firestore
          .collection('$basePath/sites/$siteId/assets')
          .where('floorPlanId', isEqualTo: planId)
          .get();

      final batch = _firestore.batch();

      for (final doc in affectedSnap.docs) {
        batch.update(doc.reference, {
          'floorPlanId': null,
          'xPercent': null,
          'yPercent': null,
          'updatedAt': DateTime.now().toIso8601String(),
          'lastModifiedAt': DateTime.now().toIso8601String(),
        });
      }

      batch.delete(_plansCol(basePath, siteId).doc(planId));

      await batch.commit();

      await deleteFloorPlanImage(basePath, siteId, planId, extension: extension);
    } catch (e) {
      debugPrint('Error deleting floor plan: $e');
      rethrow;
    }
  }

  /// Upload a floor plan image to Firebase Storage.
  /// Returns the download URL.
  ///
  /// On web, bypasses the Firebase Storage Dart SDK (which has a platform
  /// channel bug with putData) and uploads directly via the Storage REST API.
  Future<String> uploadFloorPlanImage(
      String basePath, String siteId, String planId, Uint8List bytes,
      {String contentType = 'image/jpeg', String extension = 'jpg'}) async {
    final path = '$basePath/sites/$siteId/floor_plans/$planId.$extension';
    return _retryUpload(
        () => StorageUploadHelper.upload(path, bytes, contentType));
  }

  /// Delete a floor plan image from Firebase Storage.
  Future<void> deleteFloorPlanImage(
      String basePath, String siteId, String planId,
      {String extension = 'jpg'}) async {
    try {
      final ref =
          _storage.ref('$basePath/sites/$siteId/floor_plans/$planId.$extension');
      await ref.delete();
    } catch (e) {
      // Image may not exist — ignore
      debugPrint('Floor plan image delete (may not exist): $e');
    }
  }

  Future<T> _retryUpload<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        if (e is TimeoutException || e is ClientException) {
          if (attempt == maxAttempts) rethrow;
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
          continue;
        }
        rethrow;
      }
    }
    throw lastError!;
  }
}
