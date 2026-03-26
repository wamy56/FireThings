import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/floor_plan.dart';

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
        .map((snapshot) =>
            snapshot.docs.map((doc) => FloorPlan.fromJson(doc.data())).toList());
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

  /// Delete a floor plan document and its image from Storage.
  Future<void> deleteFloorPlan(
      String basePath, String siteId, String planId) async {
    try {
      await _plansCol(basePath, siteId).doc(planId).delete();
      await deleteFloorPlanImage(basePath, siteId, planId);
    } catch (e) {
      debugPrint('Error deleting floor plan: $e');
      rethrow;
    }
  }

  /// Upload a floor plan image to Firebase Storage.
  /// Returns the download URL.
  Future<String> uploadFloorPlanImage(
      String basePath, String siteId, String planId, Uint8List bytes) async {
    try {
      final ref =
          _storage.ref('$basePath/sites/$siteId/floor_plans/$planId.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading floor plan image: $e');
      rethrow;
    }
  }

  /// Delete a floor plan image from Firebase Storage.
  Future<void> deleteFloorPlanImage(
      String basePath, String siteId, String planId) async {
    try {
      final ref =
          _storage.ref('$basePath/sites/$siteId/floor_plans/$planId.jpg');
      await ref.delete();
    } catch (e) {
      // Image may not exist — ignore
      debugPrint('Floor plan image delete (may not exist): $e');
    }
  }
}
