import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/logbook_entry.dart';

class LogbookService {
  LogbookService._();
  static final LogbookService instance = LogbookService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/logbook_entries');
  }

  Stream<List<LogbookEntry>> getEntriesStream(
      String basePath, String siteId) {
    return _col(basePath, siteId)
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return LogbookEntry.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<LogbookEntry>()
            .toList());
  }

  Stream<List<LogbookEntry>> getEntriesByTypeStream(
      String basePath, String siteId, LogbookEntryType type) {
    return _col(basePath, siteId)
        .where('type', isEqualTo: type.name)
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return LogbookEntry.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<LogbookEntry>()
            .toList());
  }

  Stream<List<LogbookEntry>> getRecentEntriesStream(
      String basePath, String siteId, {int days = 90}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _col(basePath, siteId)
        .where('occurredAt', isGreaterThanOrEqualTo: cutoff.toIso8601String())
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return LogbookEntry.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<LogbookEntry>()
            .toList());
  }

  Future<void> saveEntry(
      String basePath, String siteId, LogbookEntry entry) async {
    await _col(basePath, siteId).doc(entry.id).set(entry.toJson());
  }

  Future<void> deleteEntry(
      String basePath, String siteId, String entryId) async {
    await _col(basePath, siteId).doc(entryId).delete();
  }

  String generateId(String basePath, String siteId) {
    return _col(basePath, siteId).doc().id;
  }
}
