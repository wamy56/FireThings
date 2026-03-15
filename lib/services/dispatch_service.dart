import 'package:cloud_firestore/cloud_firestore.dart';
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
    });
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
