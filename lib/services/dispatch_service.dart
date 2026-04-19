import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/dispatched_job.dart';

/// Manages dispatched jobs — CRUD and real-time streams.
/// Dispatched jobs live in Firestore (companies/{companyId}/dispatched_jobs/)
/// with Firestore offline persistence for caching.
class DispatchService {
  DispatchService._();
  static final DispatchService instance = DispatchService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _jobsCol(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('dispatched_jobs');
  }

  /// Create a new dispatched job.
  Future<void> createJob(DispatchedJob job) async {
    try {
      await _jobsCol(job.companyId).doc(job.id).set(job.toJson());
    } catch (e) {
      debugPrint('DispatchService: createJob failed: $e');
      rethrow;
    }
  }

  /// Update an existing dispatched job.
  Future<void> updateJob(DispatchedJob job) async {
    try {
      await _jobsCol(job.companyId).doc(job.id).update(job.toJson());
    } catch (e) {
      debugPrint('DispatchService: updateJob failed: $e');
      rethrow;
    }
  }

  /// Delete a dispatched job. Admin only.
  Future<void> deleteJob(String companyId, String jobId) async {
    try {
      await _jobsCol(companyId).doc(jobId).delete();
    } catch (e) {
      debugPrint('DispatchService: deleteJob failed: $e');
      rethrow;
    }
  }

  /// Assign a job to an engineer.
  Future<void> assignJob({
    required String companyId,
    required String jobId,
    required String engineerUid,
    required String engineerName,
  }) async {
    final now = DateTime.now();
    await _jobsCol(companyId).doc(jobId).update({
      'assignedTo': engineerUid,
      'assignedToName': engineerName,
      'status': 'assigned',
      'updatedAt': now.toIso8601String(),
      'lastUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  /// Reschedule a job to a new date and optionally a new time.
  /// Pass empty string for [newTime] to clear the time.
  Future<void> rescheduleJob({
    required String companyId,
    required String jobId,
    required DateTime? newDate,
    String? newTime,
  }) async {
    final now = DateTime.now();
    final updates = <String, dynamic>{
      'scheduledDate': newDate?.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'lastUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
    };
    if (newTime != null) {
      updates['scheduledTime'] = newTime.isEmpty ? null : newTime;
    }
    await _jobsCol(companyId).doc(jobId).update(updates);
  }

  /// Stream of all jobs for a company, with optional filters.
  Stream<List<DispatchedJob>> getJobsStream(
    String companyId, {
    DispatchedJobStatus? status,
    String? assignedTo,
  }) {
    Query query = _jobsCol(companyId);

    if (status != null) {
      final statusStr = _statusToFirestore(status);
      query = query.where('status', isEqualTo: statusStr);
    }
    if (assignedTo != null) {
      query = query.where('assignedTo', isEqualTo: assignedTo);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DispatchedJob.fromJson(data);
      }).toList();
    });
  }

  /// Stream of a single job.
  Stream<DispatchedJob?> getJobStream(String companyId, String jobId) {
    return _jobsCol(companyId).doc(jobId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DispatchedJob.fromJson(doc.data() as Map<String, dynamic>);
    });
  }

  /// Stream of jobs assigned to a specific engineer.
  Stream<List<DispatchedJob>> getEngineerJobsStream(
    String companyId,
    String engineerUid,
  ) {
    return _jobsCol(companyId)
        .where('assignedTo', isEqualTo: engineerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                DispatchedJob.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Update job status with validation.
  Future<void> updateJobStatus({
    required String companyId,
    required String jobId,
    required DispatchedJobStatus newStatus,
    String? declineReason,
    String? linkedJobsheetId,
  }) async {
    final now = DateTime.now();
    final updates = <String, dynamic>{
      'status': _statusToFirestore(newStatus),
      'updatedAt': now.toIso8601String(),
      'lastUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
    };

    if (newStatus == DispatchedJobStatus.completed) {
      updates['completedAt'] = now.toIso8601String();
    }
    if (newStatus == DispatchedJobStatus.declined) {
      updates['declineReason'] = declineReason;
      updates['assignedTo'] = null;
      updates['assignedToName'] = null;
    }
    if (linkedJobsheetId != null) {
      updates['linkedJobsheetId'] = linkedJobsheetId;
    }

    await _jobsCol(companyId).doc(jobId).update(updates);
  }

  /// Get count of pending jobs for an engineer.
  Future<int> getPendingJobCount(String companyId, String engineerUid) async {
    try {
      final snapshot = await _jobsCol(companyId)
          .where('assignedTo', isEqualTo: engineerUid)
          .where('status', whereIn: ['assigned', 'accepted', 'en_route', 'on_site'])
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('DispatchService: getPendingJobCount failed: $e');
      return 0;
    }
  }

  /// Stream of pending/active job count for an engineer (real-time).
  Stream<int> streamPendingJobCount(String companyId, String engineerUid) {
    return _jobsCol(companyId)
        .where('assignedTo', isEqualTo: engineerUid)
        .where('status',
            whereIn: ['assigned', 'accepted', 'en_route', 'on_site'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream of unassigned job count for a company (dispatchers/admins).
  Stream<int> streamUnassignedJobCount(String companyId) {
    return _jobsCol(companyId)
        .where('status', isEqualTo: 'created')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Bulk update status for multiple jobs.
  Future<void> bulkUpdateStatus({
    required String companyId,
    required Set<String> jobIds,
    required DispatchedJobStatus newStatus,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    for (final jobId in jobIds) {
      final updates = <String, dynamic>{
        'status': _statusToFirestore(newStatus),
        'updatedAt': now,
        'lastUpdatedBy': uid,
      };
      if (newStatus == DispatchedJobStatus.completed) {
        updates['completedAt'] = now;
      }
      if (newStatus == DispatchedJobStatus.declined) {
        updates['assignedTo'] = null;
        updates['assignedToName'] = null;
      }
      batch.update(_jobsCol(companyId).doc(jobId), updates);
    }
    await batch.commit();
  }

  /// Bulk update priority for multiple jobs.
  Future<void> bulkUpdatePriority({
    required String companyId,
    required Set<String> jobIds,
    required JobPriority newPriority,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final priorityStr = newPriority == JobPriority.normal
        ? 'normal'
        : newPriority == JobPriority.urgent
            ? 'urgent'
            : 'emergency';
    for (final jobId in jobIds) {
      batch.update(_jobsCol(companyId).doc(jobId), {
        'priority': priorityStr,
        'updatedAt': now,
        'lastUpdatedBy': uid,
      });
    }
    await batch.commit();
  }

  /// Bulk update scheduled date for multiple jobs.
  Future<void> bulkUpdateDate({
    required String companyId,
    required Set<String> jobIds,
    required DateTime newDate,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    for (final jobId in jobIds) {
      batch.update(_jobsCol(companyId).doc(jobId), {
        'scheduledDate': newDate.toIso8601String(),
        'updatedAt': now,
        'lastUpdatedBy': uid,
      });
    }
    await batch.commit();
  }

  /// Bulk delete multiple jobs.
  Future<void> bulkDelete({
    required String companyId,
    required Set<String> jobIds,
  }) async {
    final batch = _firestore.batch();
    for (final jobId in jobIds) {
      batch.delete(_jobsCol(companyId).doc(jobId));
    }
    await batch.commit();
  }

  String _statusToFirestore(DispatchedJobStatus status) {
    switch (status) {
      case DispatchedJobStatus.created:
        return 'created';
      case DispatchedJobStatus.assigned:
        return 'assigned';
      case DispatchedJobStatus.accepted:
        return 'accepted';
      case DispatchedJobStatus.enRoute:
        return 'en_route';
      case DispatchedJobStatus.onSite:
        return 'on_site';
      case DispatchedJobStatus.completed:
        return 'completed';
      case DispatchedJobStatus.declined:
        return 'declined';
    }
  }
}
