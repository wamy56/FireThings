import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/inspection_visit.dart';

class InspectionVisitService {
  InspectionVisitService._();
  static final InspectionVisitService instance = InspectionVisitService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/inspection_visits');
  }

  Stream<List<InspectionVisit>> getVisitsStream(
      String basePath, String siteId) {
    return _col(basePath, siteId)
        .orderBy('visitDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return InspectionVisit.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<InspectionVisit>()
            .toList());
  }

  Future<InspectionVisit?> getVisit(
      String basePath, String siteId, String visitId) async {
    try {
      final snap = await _col(basePath, siteId).doc(visitId).get();
      if (!snap.exists || snap.data() == null) return null;
      return InspectionVisit.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('Error loading visit: $e');
      return null;
    }
  }

  Stream<InspectionVisit?> getVisitStream(
      String basePath, String siteId, String visitId) {
    return _col(basePath, siteId).doc(visitId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      try {
        return InspectionVisit.fromJson(snap.data()!);
      } catch (_) {
        return null;
      }
    });
  }

  Future<InspectionVisit?> getLastVisit(
      String basePath, String siteId) async {
    try {
      final snap = await _col(basePath, siteId)
          .orderBy('visitDate', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return InspectionVisit.fromJson(snap.docs.first.data());
    } catch (e) {
      debugPrint('Error loading last visit: $e');
      return null;
    }
  }

  Future<void> saveVisit(
      String basePath, String siteId, InspectionVisit visit) async {
    await _col(basePath, siteId).doc(visit.id).set(visit.toJson());
  }

  Future<void> updateVisit(
      String basePath, String siteId, String visitId,
      Map<String, dynamic> updates) async {
    updates['updatedAt'] = DateTime.now().toIso8601String();
    await _col(basePath, siteId).doc(visitId).update(updates);
  }

  Future<void> completeVisit({
    required String basePath,
    required String siteId,
    required String visitId,
    required InspectionDeclaration declaration,
    String? declarationNotes,
    String? engineerSignatureBase64,
    String? responsiblePersonSignatureBase64,
    String? responsiblePersonSignedName,
    DateTime? nextServiceDueDate,
  }) async {
    final now = DateTime.now();
    await _col(basePath, siteId).doc(visitId).update({
      'completedAt': now.toIso8601String(),
      'declaration': declaration.name,
      'declarationNotes': declarationNotes,
      'engineerSignatureBase64': engineerSignatureBase64,
      'responsiblePersonSignatureBase64': responsiblePersonSignatureBase64,
      'responsiblePersonSignedName': responsiblePersonSignedName,
      'responsiblePersonSignedAt':
          responsiblePersonSignedName != null ? now.toIso8601String() : null,
      'nextServiceDueDate': nextServiceDueDate?.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    final siteDoc = _firestore.doc('$basePath/sites/$siteId');
    await siteDoc.update({
      'lastVisitId': visitId,
      'nextServiceDueDate': nextServiceDueDate?.toIso8601String(),
    }).catchError((_) {});
  }

  Future<void> addServiceRecordId({
    required String basePath,
    required String siteId,
    required String visitId,
    required String serviceRecordId,
  }) async {
    await _col(basePath, siteId).doc(visitId).update({
      'serviceRecordIds': FieldValue.arrayUnion([serviceRecordId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> addMcpTestedId({
    required String basePath,
    required String siteId,
    required String visitId,
    required String mcpAssetId,
  }) async {
    await _col(basePath, siteId).doc(visitId).update({
      'mcpIdsTestedThisVisit': FieldValue.arrayUnion([mcpAssetId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<InspectionVisit?> getVisitByJobsheetId(
      String basePath, String siteId, String jobsheetId) async {
    try {
      final snap = await _col(basePath, siteId)
          .where('jobsheetId', isEqualTo: jobsheetId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return InspectionVisit.fromJson(snap.docs.first.data());
    } catch (e) {
      debugPrint('Error loading visit by jobsheetId: $e');
      return null;
    }
  }

  String generateId(String basePath, String siteId) {
    return _col(basePath, siteId).doc().id;
  }
}
