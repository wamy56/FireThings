import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/asset.dart';
import '../models/asset_type.dart';
import '../models/defect.dart';
import '../models/service_record.dart';
import 'lifecycle_service.dart';

class AssetTestService {
  AssetTestService._();
  static final AssetTestService instance = AssetTestService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> markAssetPassed({
    required String basePath,
    required String siteId,
    required Asset asset,
    required AssetType? assetType,
    required String engineerId,
    required String engineerName,
    String? jobsheetId,
    String? dispatchedJobId,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final record = ServiceRecord(
      id: const Uuid().v4(),
      assetId: asset.id,
      siteId: siteId,
      jobsheetId: jobsheetId,
      dispatchedJobId: dispatchedJobId,
      engineerId: engineerId,
      engineerName: engineerName,
      serviceDate: now,
      overallResult: 'pass',
      createdAt: now,
      checklistVersionTested: assetType?.checklistVersion,
    );
    final recordRef = _firestore
        .doc('$basePath/sites/$siteId/asset_service_history/${record.id}');
    batch.set(recordRef, record.toJson());

    final updatedAsset = asset.copyWith(
      complianceStatus: AssetComplianceStatus.pass,
      lastServiceDate: now,
      lastServiceBy: engineerId,
      lastServiceByName: engineerName,
      lastChecklistVersionTested: assetType?.checklistVersion,
      nextServiceDue: LifecycleService.instance.calculateNextServiceDue(
        lastServiceDate: now,
        assetType: assetType,
      ),
    );
    final assetRef =
        _firestore.doc('$basePath/sites/$siteId/assets/${asset.id}');
    batch.update(assetRef, updatedAsset.toJson());

    final openDefectsSnap = await _firestore
        .collection('$basePath/sites/$siteId/defects')
        .where('assetId', isEqualTo: asset.id)
        .where('status', isEqualTo: Defect.statusOpen)
        .get();

    final rectifiedIds = <String>[];
    for (final defectDoc in openDefectsSnap.docs) {
      batch.update(defectDoc.reference, {
        'status': Defect.statusRectified,
        'rectifiedBy': engineerId,
        'rectifiedByName': engineerName,
        'rectifiedAt': now.toIso8601String(),
        'rectifiedNote': 'Auto-rectified: asset passed test',
      });
      rectifiedIds.add(defectDoc.id);
    }

    await batch.commit();
    return rectifiedIds;
  }

  Future<String> markAssetFailed({
    required String basePath,
    required String siteId,
    required Asset asset,
    required AssetType? assetType,
    required String engineerId,
    required String engineerName,
    required Defect defect,
    String? jobsheetId,
    String? dispatchedJobId,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final record = ServiceRecord(
      id: const Uuid().v4(),
      assetId: asset.id,
      siteId: siteId,
      jobsheetId: jobsheetId,
      dispatchedJobId: dispatchedJobId,
      engineerId: engineerId,
      engineerName: engineerName,
      serviceDate: now,
      overallResult: 'fail',
      defectNote: defect.description,
      defectSeverity: defect.severity,
      defectAction: defect.action,
      defectPhotoUrls: defect.photoUrls,
      createdAt: now,
      checklistVersionTested: assetType?.checklistVersion,
    );
    final recordRef = _firestore
        .doc('$basePath/sites/$siteId/asset_service_history/${record.id}');
    batch.set(recordRef, record.toJson());

    final defectRef =
        _firestore.doc('$basePath/sites/$siteId/defects/${defect.id}');
    batch.set(defectRef, defect.toJson());

    final updatedAsset = asset.copyWith(
      complianceStatus: AssetComplianceStatus.fail,
      lastServiceDate: now,
      lastServiceBy: engineerId,
      lastServiceByName: engineerName,
      lastChecklistVersionTested: assetType?.checklistVersion,
      nextServiceDue: LifecycleService.instance.calculateNextServiceDue(
        lastServiceDate: now,
        assetType: assetType,
      ),
    );
    final assetRef =
        _firestore.doc('$basePath/sites/$siteId/assets/${asset.id}');
    batch.update(assetRef, updatedAsset.toJson());

    await batch.commit();
    return record.id;
  }
}
