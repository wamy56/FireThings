import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
      String basePath, String siteId, String planId,
      {String extension = 'jpg'}) async {
    try {
      await _plansCol(basePath, siteId).doc(planId).delete();
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
    debugPrint('[FloorPlanService] Uploading ${bytes.length} bytes to $path');

    if (kIsWeb) {
      return _uploadViaRestApi(path, bytes, contentType);
    }

    try {
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      debugPrint('[FloorPlanService] putData complete, getting download URL...');
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[FloorPlanService] Upload error (${e.runtimeType}): $e');
      rethrow;
    }
  }

  /// Web-only: upload via Firebase Storage REST API to avoid platform channel
  /// bug in firebase_storage_web's putData implementation.
  Future<String> _uploadViaRestApi(
      String path, Uint8List bytes, String contentType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final idToken = await user.getIdToken();
    final bucket = _storage.bucket;
    final encodedPath = Uri.encodeComponent(path);

    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o?uploadType=media&name=$encodedPath',
    );

    debugPrint('[FloorPlanService] REST upload to $uri');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': contentType,
      },
      body: bytes,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      debugPrint('[FloorPlanService] REST upload failed: ${response.statusCode} ${response.body}');
      throw Exception('Upload failed (${response.statusCode})');
    }

    debugPrint('[FloorPlanService] REST upload complete, building download URL...');

    // Parse the download token from the REST API response and construct
    // the URL directly — getDownloadURL() has the same channel bug on web.
    final metadata = jsonDecode(response.body) as Map<String, dynamic>;
    final token = metadata['downloadTokens'] as String?;
    if (token == null) {
      throw Exception('Upload succeeded but no download token in response');
    }
    final url =
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
    debugPrint('[FloorPlanService] Got download URL');
    return url;
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
}
