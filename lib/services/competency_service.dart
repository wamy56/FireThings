import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/engineer_competency.dart';

class CompetencyService {
  CompetencyService._();
  static final CompetencyService instance = CompetencyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(
      String basePath, String memberId) {
    if (basePath.startsWith('companies/')) {
      return _firestore
          .doc('$basePath/members/$memberId/competency/current');
    }
    return _firestore.doc('$basePath/competency/current');
  }

  Stream<EngineerCompetency?> getCompetencyStream(
      String basePath, String memberId) {
    return _doc(basePath, memberId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      try {
        return EngineerCompetency.fromJson(snap.data()!);
      } catch (e) {
        debugPrint('Error parsing competency: $e');
        return null;
      }
    });
  }

  Future<EngineerCompetency?> getCompetency(
      String basePath, String memberId) async {
    try {
      final snap = await _doc(basePath, memberId).get();
      if (!snap.exists || snap.data() == null) return null;
      return EngineerCompetency.fromJson(snap.data()!);
    } catch (e) {
      debugPrint('Error loading competency: $e');
      return null;
    }
  }

  Future<void> saveCompetency(
      String basePath, String memberId, EngineerCompetency competency) async {
    final updated = competency.copyWith(
      totalCpdHoursLast12Months: _calculateCpdHours(competency.cpdRecords),
      updatedAt: DateTime.now(),
    );
    await _doc(basePath, memberId).set(updated.toJson());
  }

  Future<void> addQualification(
      String basePath, String memberId, Qualification qualification) async {
    final existing = await getCompetency(basePath, memberId);
    if (existing == null) return;

    final updated = existing.copyWith(
      qualifications: [...existing.qualifications, qualification],
      updatedAt: DateTime.now(),
    );
    await _doc(basePath, memberId).set(updated.toJson());
  }

  Future<void> updateQualification(
      String basePath, String memberId, Qualification qualification) async {
    final existing = await getCompetency(basePath, memberId);
    if (existing == null) return;

    final quals = existing.qualifications.map((q) {
      return q.id == qualification.id ? qualification : q;
    }).toList();

    final updated = existing.copyWith(
      qualifications: quals,
      updatedAt: DateTime.now(),
    );
    await _doc(basePath, memberId).set(updated.toJson());
  }

  Future<void> removeQualification(
      String basePath, String memberId, String qualificationId) async {
    final existing = await getCompetency(basePath, memberId);
    if (existing == null) return;

    final updated = existing.copyWith(
      qualifications:
          existing.qualifications.where((q) => q.id != qualificationId).toList(),
      updatedAt: DateTime.now(),
    );
    await _doc(basePath, memberId).set(updated.toJson());
  }

  Future<void> addCpdRecord(
      String basePath, String memberId, CpdRecord record) async {
    final existing = await getCompetency(basePath, memberId);
    if (existing == null) return;

    final records = [...existing.cpdRecords, record];
    final updated = existing.copyWith(
      cpdRecords: records,
      totalCpdHoursLast12Months: _calculateCpdHours(records),
      updatedAt: DateTime.now(),
    );
    await _doc(basePath, memberId).set(updated.toJson());
  }

  Future<void> updateCpdRecord(
      String basePath, String memberId, CpdRecord record) async {
    final existing = await getCompetency(basePath, memberId);
    if (existing == null) return;

    final records = existing.cpdRecords.map((r) {
      return r.id == record.id ? record : r;
    }).toList();

    final updated = existing.copyWith(
      cpdRecords: records,
      totalCpdHoursLast12Months: _calculateCpdHours(records),
      updatedAt: DateTime.now(),
    );
    await _doc(basePath, memberId).set(updated.toJson());
  }

  Future<void> removeCpdRecord(
      String basePath, String memberId, String recordId) async {
    final existing = await getCompetency(basePath, memberId);
    if (existing == null) return;

    final records =
        existing.cpdRecords.where((r) => r.id != recordId).toList();
    final updated = existing.copyWith(
      cpdRecords: records,
      totalCpdHoursLast12Months: _calculateCpdHours(records),
      updatedAt: DateTime.now(),
    );
    await _doc(basePath, memberId).set(updated.toJson());
  }

  Future<EngineerCompetency> ensureCompetencyExists(
      String basePath, String memberId, String memberName) async {
    final existing = await getCompetency(basePath, memberId);
    if (existing != null) return existing;

    final now = DateTime.now();
    final competency = EngineerCompetency(
      id: 'current',
      engineerId: memberId,
      engineerName: memberName,
      createdAt: now,
      updatedAt: now,
    );
    await _doc(basePath, memberId).set(competency.toJson());
    return competency;
  }

  double _calculateCpdHours(List<CpdRecord> records) {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    return records
        .where((r) => r.date.isAfter(cutoff))
        .fold(0.0, (total, r) => total + r.hours);
  }

  List<Qualification> getExpiringQualifications(
      EngineerCompetency competency,
      {int withinDays = 30}) {
    final cutoff = DateTime.now().add(Duration(days: withinDays));
    return competency.qualifications.where((q) {
      if (q.expiryDate == null) return false;
      return q.expiryDate!.isBefore(cutoff);
    }).toList();
  }

  List<Qualification> getExpiredQualifications(
      EngineerCompetency competency) {
    final now = DateTime.now();
    return competency.qualifications.where((q) {
      if (q.expiryDate == null) return false;
      return q.expiryDate!.isBefore(now);
    }).toList();
  }
}
