import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/asset_type.dart';
import '../data/default_asset_types.dart';

/// Provides asset types by merging built-in defaults with custom overrides
/// from Firestore.
class AssetTypeService {
  AssetTypeService._();
  static final AssetTypeService instance = AssetTypeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _configCol(String basePath) {
    return _firestore.collection('$basePath/asset_type_config');
  }

  /// Get all asset types (built-in + custom overrides) for a given basePath.
  Future<List<AssetType>> getAssetTypes(String basePath) async {
    try {
      final snapshot = await _configCol(basePath).get();
      final customTypes = snapshot.docs
          .map((doc) => AssetType.fromJson(doc.data()))
          .toList();

      // Start with built-in defaults
      final result = <String, AssetType>{};
      for (final t in DefaultAssetTypes.all) {
        result[t.id] = t;
      }

      // Override with custom types (same ID replaces, new IDs are added)
      for (final t in customTypes) {
        result[t.id] = t;
      }

      return result.values.toList();
    } catch (e) {
      debugPrint('Error loading asset types: $e');
      return DefaultAssetTypes.all;
    }
  }

  /// Look up a single asset type by ID.
  /// Checks custom config first, then falls back to built-in.
  Future<AssetType?> getAssetType(String basePath, String typeId) async {
    try {
      // Check custom first
      final doc = await _configCol(basePath).doc(typeId).get();
      if (doc.exists && doc.data() != null) {
        return AssetType.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error loading custom asset type: $e');
    }

    // Fall back to built-in
    return DefaultAssetTypes.getById(typeId);
  }

  /// Get a built-in asset type synchronously (no Firestore call).
  AssetType? getBuiltInType(String typeId) {
    return DefaultAssetTypes.getById(typeId);
  }

  /// Create or update a custom asset type.
  Future<void> saveCustomType(String basePath, AssetType type) async {
    try {
      await _configCol(basePath).doc(type.id).set(type.toJson());
    } catch (e) {
      debugPrint('Error saving custom asset type: $e');
      rethrow;
    }
  }

  /// Delete a custom asset type.
  Future<void> deleteCustomType(String basePath, String typeId) async {
    try {
      await _configCol(basePath).doc(typeId).delete();
    } catch (e) {
      debugPrint('Error deleting custom asset type: $e');
      rethrow;
    }
  }
}
