import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cause_effect_test.dart';

class CauseEffectService {
  CauseEffectService._();
  static final CauseEffectService instance = CauseEffectService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(
      String basePath, String siteId) {
    return _firestore
        .collection('$basePath/sites/$siteId/cause_effect_tests');
  }

  Stream<List<CauseEffectTest>> getTestsForVisitStream(
      String basePath, String siteId, String visitId) {
    return _col(basePath, siteId)
        .where('visitId', isEqualTo: visitId)
        .orderBy('testedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return CauseEffectTest.fromJson(d.data());
              } catch (e) {
                debugPrint('Error parsing cause-effect test: $e');
                return null;
              }
            })
            .whereType<CauseEffectTest>()
            .toList());
  }

  Stream<List<CauseEffectTest>> getAllTestsStream(
      String basePath, String siteId) {
    return _col(basePath, siteId)
        .orderBy('testedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return CauseEffectTest.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<CauseEffectTest>()
            .toList());
  }

  Future<void> saveTest(
      String basePath, String siteId, CauseEffectTest test) async {
    await _col(basePath, siteId).doc(test.id).set(test.toJson());
  }

  String generateId(String basePath, String siteId) {
    return _col(basePath, siteId).doc().id;
  }
}
