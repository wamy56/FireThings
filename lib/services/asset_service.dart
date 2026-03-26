import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/asset.dart';

/// CRUD service for assets in the asset register.
/// Uses basePath pattern: 'users/{uid}' for solo engineers,
/// 'companies/{companyId}' for company users.
class AssetService {
  AssetService._();
  static final AssetService instance = AssetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _assetsCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/assets');
  }

  /// Stream all assets for a site.
  Stream<List<Asset>> getAssetsStream(String basePath, String siteId) {
    return _assetsCol(basePath, siteId)
        .orderBy('reference')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Asset.fromJson(doc.data()))
            .toList());
  }

  /// Get a single asset.
  Future<Asset?> getAsset(
      String basePath, String siteId, String assetId) async {
    try {
      final doc = await _assetsCol(basePath, siteId).doc(assetId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Asset.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting asset: $e');
      return null;
    }
  }

  /// Create a new asset.
  Future<void> createAsset(
      String basePath, String siteId, Asset asset) async {
    try {
      await _assetsCol(basePath, siteId).doc(asset.id).set(asset.toJson());
    } catch (e) {
      debugPrint('Error creating asset: $e');
      rethrow;
    }
  }

  /// Update an existing asset.
  Future<void> updateAsset(
      String basePath, String siteId, Asset asset) async {
    try {
      final updated = asset.copyWith(
        updatedAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );
      await _assetsCol(basePath, siteId)
          .doc(updated.id)
          .update(updated.toJson());
    } catch (e) {
      debugPrint('Error updating asset: $e');
      rethrow;
    }
  }

  /// Delete an asset.
  Future<void> deleteAsset(
      String basePath, String siteId, String assetId) async {
    try {
      await _assetsCol(basePath, siteId).doc(assetId).delete();
    } catch (e) {
      debugPrint('Error deleting asset: $e');
      rethrow;
    }
  }

  /// Get the count of assets for a site (for summary display).
  Future<int> getAssetCount(String basePath, String siteId) async {
    try {
      final snapshot = await _assetsCol(basePath, siteId).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting asset count: $e');
      return 0;
    }
  }

  /// Get the next suggested reference for an asset type at a site.
  /// E.g. if site has SD-001, SD-002, returns "SD-003".
  Future<String> suggestNextReference(
      String basePath, String siteId, String prefix) async {
    try {
      final snapshot = await _assetsCol(basePath, siteId)
          .where('reference', isGreaterThanOrEqualTo: '$prefix-')
          .where('reference', isLessThanOrEqualTo: '$prefix-\uf8ff')
          .get();

      if (snapshot.docs.isEmpty) return '$prefix-001';

      int maxNum = 0;
      for (final doc in snapshot.docs) {
        final ref = doc.data()['reference'] as String? ?? '';
        final parts = ref.split('-');
        if (parts.length >= 2) {
          final num = int.tryParse(parts.last) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      }
      return '$prefix-${(maxNum + 1).toString().padLeft(3, '0')}';
    } catch (e) {
      debugPrint('Error suggesting reference: $e');
      return '$prefix-001';
    }
  }
}
