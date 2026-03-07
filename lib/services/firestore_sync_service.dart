import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'database_helper.dart';

/// Firestore cloud sync service — SQLite primary, Firestore backup.
/// All writes are fire-and-forget; Firestore SDK handles offline queuing.
class FirestoreSyncService {
  static final FirestoreSyncService instance = FirestoreSyncService._();
  FirestoreSyncService._();

  static const _lastSyncKey = 'firestore_last_sync';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current user's UID, or null if not logged in.
  String? get _uid => _auth.currentUser?.uid;

  /// Base path for the current user's data.
  CollectionReference? _userCollection(String collection) {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection(collection);
  }

  // ==================== GENERIC CRUD ====================

  /// Upsert a document to Firestore (fire-and-forget).
  Future<void> upsertDocument(
      String collection, String id, Map<String, dynamic> data) async {
    try {
      final col = _userCollection(collection);
      if (col == null) return;
      await col.doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSync: upsert $collection/$id failed: $e');
    }
  }

  /// Delete a document from Firestore (fire-and-forget).
  Future<void> deleteDocument(String collection, String id) async {
    try {
      final col = _userCollection(collection);
      if (col == null) return;
      await col.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreSync: delete $collection/$id failed: $e');
    }
  }

  /// Fetch all documents in a collection for the current user.
  Future<List<Map<String, dynamic>>> fetchCollection(
      String collection) async {
    try {
      final col = _userCollection(collection);
      if (col == null) return [];
      final snapshot = await col.get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('FirestoreSync: fetch $collection failed: $e');
      return [];
    }
  }

  // ==================== TYPED UPSERT HELPERS ====================

  Future<void> upsertJobsheet(Jobsheet jobsheet) async {
    await upsertDocument('jobsheets', jobsheet.id, jobsheet.toJson());
  }

  Future<void> upsertInvoice(Invoice invoice) async {
    // Store items as a list (not a JSON string) for Firestore readability
    final data = invoice.toJson();
    // items is already a List from toJson — keep it as-is for Firestore
    await upsertDocument('invoices', invoice.id, data);
  }

  Future<void> upsertSavedCustomer(SavedCustomer customer) async {
    await upsertDocument('saved_customers', customer.id, customer.toJson());
  }

  Future<void> upsertSavedSite(SavedSite site) async {
    await upsertDocument('saved_sites', site.id, site.toJson());
  }

  Future<void> upsertJobTemplate(JobTemplate template) async {
    await upsertDocument('job_templates', template.id, template.toJson());
  }

  Future<void> upsertFilledPdfForm(FilledPdfForm filled) async {
    await upsertDocument('filled_templates', filled.id, filled.toJson());
  }

  // ==================== PDF CONFIG SYNC ====================

  Future<void> syncPdfHeaderConfig(String jsonString) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pdf_config')
          .doc('header')
          .set({
        'data': jsonString,
        'lastModifiedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FirestoreSync: sync pdf header failed: $e');
    }
  }

  Future<void> syncPdfFooterConfig(String jsonString) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pdf_config')
          .doc('footer')
          .set({
        'data': jsonString,
        'lastModifiedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FirestoreSync: sync pdf footer failed: $e');
    }
  }

  Future<void> syncPdfColourScheme(String jsonString) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pdf_config')
          .doc('colour_scheme')
          .set({
        'data': jsonString,
        'lastModifiedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FirestoreSync: sync pdf colour scheme failed: $e');
    }
  }

  // ==================== FULL SYNC (pull on launch) ====================

  /// Perform a full bidirectional sync for the current user.
  /// Call after auth is confirmed on app launch.
  Future<void> performFullSync(String engineerId) async {
    final uid = _uid;
    if (uid == null) return;

    debugPrint('FirestoreSync: starting full sync for $engineerId');

    try {
      await _syncCollection<Jobsheet>(
        collection: 'jobsheets',
        engineerId: engineerId,
        fetchLocal: () =>
            DatabaseHelper.instance.getJobsheetsByEngineerId(engineerId),
        fromJson: (json) => Jobsheet.fromJson(json),
        toJson: (item) => item.toJson(),
        getId: (item) => item.id,
        getLastModified: (item) => item.lastModifiedAt,
        insertLocal: (item) => DatabaseHelper.instance.insertJobsheet(item),
        updateLocal: (item) => DatabaseHelper.instance.updateJobsheet(item),
      );

      await _syncCollection<Invoice>(
        collection: 'invoices',
        engineerId: engineerId,
        fetchLocal: () =>
            DatabaseHelper.instance.getInvoicesByEngineerId(engineerId),
        fromJson: (json) => Invoice.fromJson(json),
        toJson: (item) => item.toJson(),
        getId: (item) => item.id,
        getLastModified: (item) => item.lastModifiedAt,
        insertLocal: (item) => DatabaseHelper.instance.insertInvoice(item),
        updateLocal: (item) => DatabaseHelper.instance.updateInvoice(item),
      );

      await _syncCollection<SavedCustomer>(
        collection: 'saved_customers',
        engineerId: engineerId,
        fetchLocal: () =>
            DatabaseHelper.instance.getSavedCustomersByEngineerId(engineerId),
        fromJson: (json) => SavedCustomer.fromJson(json),
        toJson: (item) => item.toJson(),
        getId: (item) => item.id,
        getLastModified: (item) => item.lastModifiedAt,
        insertLocal: (item) =>
            DatabaseHelper.instance.insertSavedCustomer(item),
        updateLocal: (item) =>
            DatabaseHelper.instance.updateSavedCustomer(item),
      );

      await _syncCollection<SavedSite>(
        collection: 'saved_sites',
        engineerId: engineerId,
        fetchLocal: () =>
            DatabaseHelper.instance.getSavedSitesByEngineerId(engineerId),
        fromJson: (json) => SavedSite.fromJson(json),
        toJson: (item) => item.toJson(),
        getId: (item) => item.id,
        getLastModified: (item) => item.lastModifiedAt,
        insertLocal: (item) => DatabaseHelper.instance.insertSavedSite(item),
        updateLocal: (_) async => 0, // SavedSite has no update method — upsert via insert
      );

      await _syncCollection<JobTemplate>(
        collection: 'job_templates',
        engineerId: engineerId,
        fetchLocal: () => DatabaseHelper.instance.getAllJobTemplates(),
        fromJson: (json) => JobTemplate.fromJson(json),
        toJson: (item) => item.toJson(),
        getId: (item) => item.id,
        getLastModified: (item) => item.lastModifiedAt,
        insertLocal: (item) =>
            DatabaseHelper.instance.insertJobTemplate(item),
        updateLocal: (item) =>
            DatabaseHelper.instance.updateJobTemplate(item),
      );

      await _syncCollection<FilledPdfForm>(
        collection: 'filled_templates',
        engineerId: engineerId,
        fetchLocal: () =>
            DatabaseHelper.instance.getFilledPdfFormsByEngineerId(engineerId),
        fromJson: (json) => FilledPdfForm.fromJson(json),
        toJson: (item) => item.toJson(),
        getId: (item) => item.id,
        getLastModified: (item) => item.lastModifiedAt,
        insertLocal: (item) =>
            DatabaseHelper.instance.insertFilledPdfForm(item),
        updateLocal: (item) =>
            DatabaseHelper.instance.updateFilledPdfForm(item),
      );

      // Sync PDF config (pull remote if newer)
      await _syncPdfConfigs();

      // Record last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      debugPrint('FirestoreSync: full sync completed');
    } catch (e) {
      debugPrint('FirestoreSync: full sync failed: $e');
    }
  }

  /// Generic bidirectional sync for a collection.
  Future<void> _syncCollection<T>({
    required String collection,
    required String engineerId,
    required Future<List<T>> Function() fetchLocal,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
    required String Function(T) getId,
    required DateTime? Function(T) getLastModified,
    required Future<dynamic> Function(T) insertLocal,
    required Future<dynamic> Function(T) updateLocal,
  }) async {
    // Fetch remote docs
    final remoteDocs = await fetchCollection(collection);
    final remoteMap = <String, Map<String, dynamic>>{};
    for (final doc in remoteDocs) {
      final id = doc['id'] as String?;
      if (id != null) remoteMap[id] = doc;
    }

    // Fetch local docs
    final localItems = await fetchLocal();
    final localMap = <String, T>{};
    for (final item in localItems) {
      localMap[getId(item)] = item;
    }

    // Pull remote → local (new or newer remote docs)
    for (final entry in remoteMap.entries) {
      final remoteId = entry.key;
      final remoteData = entry.value;

      if (!localMap.containsKey(remoteId)) {
        // Remote doc not in local — insert locally (skip sync-back)
        try {
          final item = fromJson(remoteData);
          await _insertLocalOnly(item, insertLocal);
        } catch (e) {
          debugPrint('FirestoreSync: error inserting remote $collection/$remoteId: $e');
        }
      } else {
        // Both exist — compare lastModifiedAt, keep newer
        final localItem = localMap[remoteId] as T;
        final localModified = getLastModified(localItem);
        final remoteModifiedStr = remoteData['lastModifiedAt'] as String?;
        final remoteModified =
            remoteModifiedStr != null ? DateTime.tryParse(remoteModifiedStr) : null;

        if (remoteModified != null &&
            (localModified == null || remoteModified.isAfter(localModified))) {
          try {
            final item = fromJson(remoteData);
            await _updateLocalOnly(item, updateLocal);
          } catch (e) {
            debugPrint('FirestoreSync: error updating local $collection/$remoteId: $e');
          }
        }
      }
    }

    // Push local → remote (local docs not in Firestore)
    for (final entry in localMap.entries) {
      if (!remoteMap.containsKey(entry.key)) {
        final data = toJson(entry.value);
        await upsertDocument(collection, entry.key, data);
      }
    }
  }

  /// Insert locally without triggering another sync-back.
  /// We use the raw DatabaseHelper insert which will call sync again,
  /// but the doc already exists in Firestore so it's just a no-op upsert.
  Future<void> _insertLocalOnly<T>(
      T item, Future<dynamic> Function(T) insertLocal) async {
    await insertLocal(item);
  }

  /// Update locally without triggering another sync-back.
  Future<void> _updateLocalOnly<T>(
      T item, Future<dynamic> Function(T) updateLocal) async {
    await updateLocal(item);
  }

  /// Sync PDF config from Firestore → SharedPreferences if remote is newer.
  Future<void> _syncPdfConfigs() async {
    final uid = _uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final configCol =
        _firestore.collection('users').doc(uid).collection('pdf_config');

    // Header
    await _pullPdfConfig(
      configCol: configCol,
      docId: 'header',
      prefsKey: 'pdf_header_config_v1',
      prefs: prefs,
    );

    // Footer
    await _pullPdfConfig(
      configCol: configCol,
      docId: 'footer',
      prefsKey: 'pdf_footer_config_v1',
      prefs: prefs,
    );

    // Colour scheme
    await _pullPdfConfig(
      configCol: configCol,
      docId: 'colour_scheme',
      prefsKey: 'pdf_colour_scheme',
      prefs: prefs,
    );
  }

  Future<void> _pullPdfConfig({
    required CollectionReference configCol,
    required String docId,
    required String prefsKey,
    required SharedPreferences prefs,
  }) async {
    try {
      final doc = await configCol.doc(docId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final remoteJson = data['data'] as String?;
      if (remoteJson == null) return;

      // Simple overwrite — remote wins on full sync
      await prefs.setString(prefsKey, remoteJson);
    } catch (e) {
      debugPrint('FirestoreSync: pull pdf config $docId failed: $e');
    }
  }

  // ==================== ACCOUNT DELETION ====================

  /// Delete all Firestore data for the current user (GDPR right-to-erasure).
  /// Deletes all documents in all subcollections, then the user document itself.
  /// Throws on failure — callers must handle errors.
  Future<void> deleteAllUserData() async {
    final uid = _uid;
    if (uid == null) throw Exception('No authenticated user');

    final userDoc = _firestore.collection('users').doc(uid);

    const collections = [
      'jobsheets',
      'invoices',
      'saved_customers',
      'saved_sites',
      'job_templates',
      'filled_templates',
      'pdf_config',
    ];

    for (final name in collections) {
      await _deleteCollection(userDoc, name);
    }

    // Delete the user document itself
    await userDoc.delete();

    debugPrint('FirestoreSync: deleted all data for user $uid');
  }

  /// Delete all documents in a subcollection, batching in groups of 500.
  Future<void> _deleteCollection(
      DocumentReference userDoc, String name) async {
    final col = userDoc.collection(name);
    var snapshot = await col.limit(500).get();

    while (snapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 500) break;
      snapshot = await col.limit(500).get();
    }
  }

  // ==================== SYNC STATUS ====================

  /// Get the last successful sync timestamp.
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastSyncKey);
    return str != null ? DateTime.tryParse(str) : null;
  }
}
