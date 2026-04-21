import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/asset.dart';

/// CRUD service for assets in the asset register.
/// Uses basePath pattern: 'users/{uid}' for solo engineers,
/// 'companies/{companyId}' for company users.
class AssetService {
  AssetService._();
  static final AssetService instance = AssetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int maxPhotos = 5;

  CollectionReference<Map<String, dynamic>> _assetsCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/assets');
  }

  /// Stream all assets for a site.
  Stream<List<Asset>> getAssetsStream(String basePath, String siteId) {
    return _assetsCol(basePath, siteId)
        .orderBy('reference')
        .snapshots()
        .map((snapshot) {
      final assets = <Asset>[];
      for (final doc in snapshot.docs) {
        try {
          assets.add(Asset.fromJson(doc.data()));
        } catch (e) {
          debugPrint('Skipping malformed asset ${doc.id}: $e');
        }
      }
      return assets;
    });
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

  /// Create a new asset. If the reference matches the auto-suggested pattern
  /// (e.g. "SD-003"), allocates atomically via a counter document to prevent
  /// duplicate references from concurrent creates.
  Future<void> createAsset(
      String basePath, String siteId, Asset asset) async {
    try {
      final ref = asset.reference;
      if (ref != null && _isAutoReference(ref)) {
        final parts = ref.split('-');
        final prefix = parts.sublist(0, parts.length - 1).join('-');
        final number = await _allocateNumber(basePath, siteId, prefix);
        final newRef = '$prefix-${number.toString().padLeft(3, '0')}';
        final updated = asset.copyWith(reference: newRef);
        await _assetsCol(basePath, siteId).doc(updated.id).set(updated.toJson());
      } else {
        await _assetsCol(basePath, siteId).doc(asset.id).set(asset.toJson());
      }
    } catch (e) {
      debugPrint('Error creating asset: $e');
      rethrow;
    }
  }

  bool _isAutoReference(String reference) {
    final parts = reference.split('-');
    if (parts.length < 2) return false;
    return int.tryParse(parts.last) != null;
  }

  Future<int> _allocateNumber(
      String basePath, String siteId, String prefix) async {
    final counterRef = _firestore.doc(
        '$basePath/sites/$siteId/asset_counters/$prefix');
    return await _firestore.runTransaction((txn) async {
      final snap = await txn.get(counterRef);
      final current = (snap.data()?['nextNumber'] as int?) ?? 0;
      final next = current + 1;
      txn.set(counterRef, {'nextNumber': next}, SetOptions(merge: true));
      return next;
    });
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

  /// Find an asset by its barcode value. Returns null if not found.
  Future<Asset?> findByBarcode(
      String basePath, String siteId, String barcode) async {
    try {
      final snapshot = await _assetsCol(basePath, siteId)
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return Asset.fromJson(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error finding asset by barcode: $e');
      return null;
    }
  }

  /// Get the next suggested reference for an asset type at a site.
  /// Reads from the counter document if it exists, otherwise scans assets.
  Future<String> suggestNextReference(
      String basePath, String siteId, String prefix) async {
    try {
      final counterSnap = await _firestore
          .doc('$basePath/sites/$siteId/asset_counters/$prefix')
          .get();
      if (counterSnap.exists) {
        final next = ((counterSnap.data()?['nextNumber'] as int?) ?? 0) + 1;
        return '$prefix-${next.toString().padLeft(3, '0')}';
      }

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

  /// Upload a photo to an asset. Compresses the image, uploads to Storage,
  /// and appends the URL to the asset's photoUrls array.
  /// Returns the download URL, or null if upload fails or max photos reached.
  Future<String?> uploadAssetPhoto({
    required String basePath,
    required String siteId,
    required String assetId,
    required Uint8List bytes,
  }) async {
    try {
      // Upload to Storage first (outside transaction)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$basePath/sites/$siteId/assets/$assetId/photos/$timestamp.jpg';
      final url = await _retryUpload(
        () => kIsWeb
            ? _uploadViaRestApi(path, bytes)
            : _uploadViaSdk(path, bytes),
      );

      // Atomically check count and append URL
      try {
        await _firestore.runTransaction((txn) async {
          final ref = _assetsCol(basePath, siteId).doc(assetId);
          final snap = await txn.get(ref);
          if (!snap.exists) throw _PhotoUploadAborted();
          final current =
              (snap.data()?['photoUrls'] as List<dynamic>?)?.length ?? 0;
          if (current >= maxPhotos) throw _PhotoLimitExceeded();
          txn.update(ref, {
            'photoUrls': FieldValue.arrayUnion([url]),
            'updatedAt': DateTime.now().toIso8601String(),
            'lastModifiedAt': DateTime.now().toIso8601String(),
          });
        });
        return url;
      } on _PhotoLimitExceeded {
        debugPrint('Max photos ($maxPhotos) reached');
        _tryDeleteStorageUrl(url);
        return null;
      } on _PhotoUploadAborted {
        debugPrint('Asset not found during photo upload');
        _tryDeleteStorageUrl(url);
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading asset photo: $e');
      return null;
    }
  }

  void _tryDeleteStorageUrl(String url) {
    try {
      _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  /// Delete a photo from an asset. Removes from Storage and updates photoUrls.
  Future<bool> deleteAssetPhoto({
    required String basePath,
    required String siteId,
    required String assetId,
    required String photoUrl,
  }) async {
    try {
      // Get current asset
      final asset = await getAsset(basePath, siteId, assetId);
      if (asset == null) return false;

      // Remove URL from array
      final updatedUrls = asset.photoUrls.where((u) => u != photoUrl).toList();
      await _assetsCol(basePath, siteId).doc(assetId).update({
        'photoUrls': updatedUrls,
        'updatedAt': DateTime.now().toIso8601String(),
        'lastModifiedAt': DateTime.now().toIso8601String(),
      });

      // Delete from Storage (best effort - don't fail if storage delete fails)
      try {
        final ref = _storage.refFromURL(photoUrl);
        await ref.delete();
      } catch (e) {
        debugPrint('Warning: Failed to delete photo from storage: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting asset photo: $e');
      return false;
    }
  }

  /// Delete all photos for an asset (used when deleting the asset itself).
  Future<void> deleteAllAssetPhotos({
    required String basePath,
    required String siteId,
    required String assetId,
  }) async {
    try {
      final asset = await getAsset(basePath, siteId, assetId);
      if (asset == null || asset.photoUrls.isEmpty) return;

      for (final url in asset.photoUrls) {
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (e) {
          debugPrint('Warning: Failed to delete photo: $e');
        }
      }
    } catch (e) {
      debugPrint('Error deleting all asset photos: $e');
    }
  }

  Future<String> _uploadViaSdk(String path, Uint8List bytes) async {
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<String> _uploadViaRestApi(String path, Uint8List bytes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final idToken = await user.getIdToken();
    final bucket = _storage.bucket;
    final encodedPath = Uri.encodeComponent(path);

    final response = await http.post(
      Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o?uploadType=media&name=$encodedPath',
      ),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Upload failed (${response.statusCode})');
    }

    final metadata = jsonDecode(response.body) as Map<String, dynamic>;
    final token = metadata['downloadTokens'] as String?;
    if (token == null) throw Exception('No download token in response');
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
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
      if (e is TimeoutException || e is http.ClientException) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        continue;
      }
      rethrow;
    }
  }
  throw lastError!;
}

class _PhotoLimitExceeded implements Exception {}

class _PhotoUploadAborted implements Exception {}
