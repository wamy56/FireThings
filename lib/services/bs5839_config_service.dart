import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../data/prohibited_variation_rules.dart';
import '../models/asset.dart';
import '../models/bs5839_system_config.dart';
import '../models/bs5839_variation.dart';
import '../models/prohibited_variation_rule.dart';

class ProhibitedVariationFinding {
  final ProhibitedVariationRule rule;
  final String description;

  const ProhibitedVariationFinding({
    required this.rule,
    required this.description,
  });
}

class Bs5839ConfigService {
  Bs5839ConfigService._();
  static final Bs5839ConfigService instance = Bs5839ConfigService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _configDoc(
      String basePath, String siteId) {
    return _firestore
        .doc('$basePath/sites/$siteId/bs5839_config/current');
  }

  CollectionReference<Map<String, dynamic>> _variationsCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/variations');
  }

  CollectionReference<Map<String, dynamic>> _assetsCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/assets');
  }

  Stream<Bs5839SystemConfig?> getConfigStream(
      String basePath, String siteId) {
    return _configDoc(basePath, siteId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      try {
        return Bs5839SystemConfig.fromJson(snap.data()!);
      } catch (e) {
        debugPrint('Error parsing BS 5839 config: $e');
        return null;
      }
    });
  }

  Future<Bs5839SystemConfig?> getConfig(
      String basePath, String siteId) async {
    try {
      final snap = await _configDoc(basePath, siteId).get();
      if (!snap.exists || snap.data() == null) return null;
      return Bs5839SystemConfig.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('Error loading BS 5839 config: $e');
      return null;
    }
  }

  Stream<List<Bs5839Variation>> getActiveVariations(
      String basePath, String siteId) {
    return _variationsCol(basePath, siteId)
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

  Future<void> saveConfig(
      String basePath, String siteId, Bs5839SystemConfig config) async {
    await _configDoc(basePath, siteId).set(config.toJson());

    // Update site's isBs5839Site flag
    final siteDoc = _firestore.doc('$basePath/sites/$siteId');
    await siteDoc.update({'isBs5839Site': true}).catchError((_) {});
  }

  Future<List<ProhibitedVariationFinding>> detectProhibitedVariations({
    required String basePath,
    required String siteId,
    required Bs5839SystemConfig config,
    List<Asset>? assets,
  }) async {
    final List<Asset> siteAssets = assets ??
        await _assetsCol(basePath, siteId).get().then((snap) => snap.docs
            .map((d) {
              try {
                return Asset.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Asset>()
            .toList());

    final findings = <ProhibitedVariationFinding>[];

    for (final rule in ProhibitedVariationRules.all) {
      final passes = rule.check(config, siteAssets);
      if (!passes) {
        findings.add(ProhibitedVariationFinding(
          rule: rule,
          description: rule.description,
        ));
      }
    }

    return findings;
  }

  Future<List<String>> autoCreateProhibitedVariations({
    required String basePath,
    required String siteId,
    required List<ProhibitedVariationFinding> findings,
    required String engineerId,
    required String engineerName,
  }) async {
    final existingSnap = await _variationsCol(basePath, siteId)
        .where('isProhibited', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .get();

    final existingRuleIds = existingSnap.docs
        .map((d) => d.data()['prohibitedRuleId'] as String?)
        .whereType<String>()
        .toSet();

    final createdIds = <String>[];
    final now = DateTime.now();
    final batch = _firestore.batch();

    for (final finding in findings) {
      if (existingRuleIds.contains(finding.rule.id)) continue;

      final id = _firestore
          .collection('$basePath/sites/$siteId/variations')
          .doc()
          .id;

      final variation = Bs5839Variation(
        id: id,
        siteId: siteId,
        clauseReference: finding.rule.clauseReference,
        description: finding.description,
        justification: 'Auto-detected by compliance check',
        isProhibited: true,
        prohibitedRuleId: finding.rule.id,
        loggedByEngineerId: engineerId,
        loggedByEngineerName: engineerName,
        loggedAt: now,
      );

      batch.set(
        _variationsCol(basePath, siteId).doc(id),
        variation.toJson(),
      );
      createdIds.add(id);
    }

    if (createdIds.isNotEmpty) {
      await batch.commit();
    }

    return createdIds;
  }

  Future<String> uploadZonePlan({
    required String basePath,
    required String siteId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final storagePath =
        '$basePath/sites/$siteId/zone_plans/zone_plan.$ext';
    final ref = _storage.ref(storagePath);

    await ref.putData(
      fileBytes,
      SettableMetadata(contentType: 'image/$ext'),
    );

    return await ref.getDownloadURL();
  }

  Future<void> deleteZonePlan({
    required String basePath,
    required String siteId,
  }) async {
    try {
      final listResult = await _storage
          .ref('$basePath/sites/$siteId/zone_plans/')
          .listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      debugPrint('Error deleting zone plan: $e');
    }
  }
}
