import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'database_helper.dart';
import 'defect_service.dart';
import 'analytics_service.dart';
import 'dispatch_service.dart';

/// Manages quotes — CRUD, status transitions, and defect linking.
/// SQLite primary storage with fire-and-forget Firestore sync (like invoices).
class QuoteService {
  QuoteService._();
  static final QuoteService instance = QuoteService._();

  final _db = DatabaseHelper.instance;

  String get _currentEngineerId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Create a new quote.
  Future<Quote> createQuote(Quote quote) async {
    final saved = await _db.insertQuote(quote);
    AnalyticsService.instance.logQuoteCreated(
      fromDefect: quote.defectId != null,
      value: quote.total,
    );
    return saved;
  }

  /// Update an existing quote.
  Future<void> updateQuote(Quote quote) async {
    await _db.updateQuote(quote);
  }

  /// Delete a quote. Clears any linked defect's back-reference.
  /// Blocks deletion of converted quotes (they have a linked dispatched job).
  Future<void> deleteQuote(String quoteId) async {
    final quote = await _db.getQuoteById(quoteId);
    if (quote != null) {
      if (quote.status == QuoteStatus.converted) {
        throw ConvertedQuoteDeletionException(
          'This quote has been converted to a job and cannot be deleted.',
        );
      }
      if (quote.defectId != null && quote.siteId.isNotEmpty) {
        await _clearDefectQuoteLink(quote);
      }
    }
    await _db.deleteQuote(quoteId);
  }

  Future<void> deleteQuotes(List<String> ids) async {
    for (final id in ids) {
      final quote = await _db.getQuoteById(id);
      if (quote != null &&
          quote.status == QuoteStatus.converted) {
        continue;
      }
      if (quote != null &&
          quote.defectId != null &&
          quote.siteId.isNotEmpty) {
        await _clearDefectQuoteLink(quote);
      }
    }
    await _db.deleteQuotes(ids);
  }

  Future<void> _clearDefectQuoteLink(Quote quote) async {
    final basePath = quote.companyId != null && quote.companyId!.isNotEmpty
        ? 'companies/${quote.companyId}'
        : 'users/${quote.engineerId}';
    try {
      await DefectService.instance.updateDefectField(
        basePath,
        quote.siteId,
        quote.defectId!,
        {'linkedQuoteId': null},
      );
    } catch (_) {
      // Defect may already be deleted — non-blocking
    }
  }

  /// Get all quotes for the current engineer.
  Future<List<Quote>> getQuotes() async {
    return _db.getQuotesByEngineerId(_currentEngineerId);
  }

  /// Get quotes filtered by status.
  Future<List<Quote>> getQuotesByStatus(QuoteStatus status) async {
    return _db.getQuotesByStatus(_currentEngineerId, status.name);
  }

  /// Get a single quote by ID.
  Future<Quote?> getQuoteById(String id) async {
    return _db.getQuoteById(id);
  }

  /// Get the next sequential quote number.
  Future<String> getNextQuoteNumber() async {
    return _db.getNextQuoteNumber();
  }

  /// Update quote status with appropriate timestamp tracking.
  Future<void> updateQuoteStatus(
    String quoteId,
    QuoteStatus newStatus, {
    String? convertedJobId,
  }) async {
    final quote = await _db.getQuoteById(quoteId);
    if (quote == null) return;

    final oldStatus = quote.status;
    var updated = quote.copyWith(status: newStatus);

    if (newStatus == QuoteStatus.sent && quote.sentAt == null) {
      updated = updated.copyWith(sentAt: DateTime.now());
    }

    if ((newStatus == QuoteStatus.approved ||
            newStatus == QuoteStatus.declined) &&
        quote.respondedAt == null) {
      updated = updated.copyWith(respondedAt: DateTime.now());
    }

    if (newStatus == QuoteStatus.converted && convertedJobId != null) {
      updated = updated.copyWith(convertedJobId: convertedJobId);
    }

    await _db.updateQuote(updated);

    AnalyticsService.instance.logQuoteStatusChanged(
      fromStatus: oldStatus.name,
      toStatus: newStatus.name,
    );
  }

  /// Link a quote to its source defect in Firestore.
  Future<void> linkQuoteToDefect({
    required String basePath,
    required String siteId,
    required String defectId,
    required String quoteId,
  }) async {
    await DefectService.instance.updateDefectField(
      basePath,
      siteId,
      defectId,
      {'linkedQuoteId': quoteId},
    );
  }

  /// Get counts for dashboard display.
  Future<Map<String, int>> getQuoteCounts() async {
    final all = await getQuotes();
    return {
      'drafts': all.where((q) => q.status == QuoteStatus.draft).length,
      'sent': all.where((q) => q.status == QuoteStatus.sent).length,
      'approved': all.where((q) => q.status == QuoteStatus.approved).length,
      'declined': all.where((q) => q.status == QuoteStatus.declined).length,
      'converted': all.where((q) => q.status == QuoteStatus.converted).length,
    };
  }

  /// Total value of approved quotes.
  Future<double> getApprovedValue() async {
    final approved = await getQuotesByStatus(QuoteStatus.approved);
    return approved.fold<double>(0.0, (acc, q) => acc + q.total);
  }

  /// Convert an approved quote into a dispatched job.
  Future<DispatchedJob> convertQuoteToJob(Quote quote) async {
    if (quote.status != QuoteStatus.approved) {
      throw StateError('Only approved quotes can be converted');
    }
    if (quote.companyId == null) {
      throw StateError('Quote-to-job conversion requires company membership');
    }

    final user = FirebaseAuth.instance.currentUser!;
    final now = DateTime.now();

    final job = DispatchedJob(
      id: const Uuid().v4(),
      companyId: quote.companyId!,
      title: 'Defect Repair: ${quote.siteName}',
      description:
          '${quote.defectDescription ?? ''}\n\nQuote: ${quote.quoteNumber}\nValue: \u00A3${quote.total.toStringAsFixed(2)}',
      jobType: 'Quoted Works',
      siteName: quote.siteName,
      siteAddress: quote.customerAddress,
      companySiteId: quote.siteId.isNotEmpty ? quote.siteId : null,
      contactName: quote.customerName,
      contactEmail: quote.customerEmail,
      contactPhone: quote.customerPhone,
      status: DispatchedJobStatus.created,
      priority: JobPriority.normal,
      createdAt: now,
      updatedAt: now,
      createdBy: user.uid,
      createdByName: user.displayName ?? user.email?.split('@')[0] ?? '',
      sourceQuoteId: quote.id,
    );

    await DispatchService.instance.createJob(job);

    await updateQuoteStatus(
      quote.id,
      QuoteStatus.converted,
      convertedJobId: job.id,
    );

    AnalyticsService.instance.logQuoteConverted(
      quoteId: quote.id,
      jobId: job.id,
      value: quote.total,
    );

    return job;
  }

  // ── Web / Firestore-direct methods ──

  final _firestore = FirebaseFirestore.instance;

  /// Stream all quotes across the company.
  Stream<List<Quote>> getCompanyQuotesStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('quotes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Quote.fromJson(doc.data()))
            .toList());
  }

  /// Stream a single quote document for the detail panel.
  Stream<Quote?> getQuoteStream(String companyId, String quoteId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('quotes')
        .doc(quoteId)
        .snapshots()
        .map((doc) =>
            doc.exists ? Quote.fromJson(doc.data()!) : null);
  }

  /// Save a quote directly to Firestore (web portal, bypasses SQLite).
  Future<void> saveQuoteToFirestore(Quote quote) async {
    final data = quote.toJson();
    final batch = _firestore.batch();

    batch.set(
      _firestore
          .collection('users')
          .doc(quote.engineerId)
          .collection('quotes')
          .doc(quote.id),
      data,
      SetOptions(merge: true),
    );

    if (quote.companyId != null && quote.companyId!.isNotEmpty) {
      batch.set(
        _firestore
            .collection('companies')
            .doc(quote.companyId!)
            .collection('quotes')
            .doc(quote.id),
        data,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Delete a quote directly from Firestore (web portal).
  Future<void> deleteQuoteFromFirestore(
      String engineerId, String quoteId, {String? companyId}) async {
    final batch = _firestore.batch();

    batch.delete(
      _firestore
          .collection('users')
          .doc(engineerId)
          .collection('quotes')
          .doc(quoteId),
    );

    if (companyId != null && companyId.isNotEmpty) {
      batch.delete(
        _firestore
            .collection('companies')
            .doc(companyId)
            .collection('quotes')
            .doc(quoteId),
      );
    }

    await batch.commit();
  }

  /// Get the next quote number from Firestore (web portal).
  Future<String> getNextQuoteNumberFromFirestore(String companyId) async {
    final snap = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('quotes')
        .orderBy('quoteNumber', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 'Q-0001';
    final lastNumber = snap.docs.first.data()['quoteNumber'] as String? ?? 'Q-0000';
    final num = int.tryParse(lastNumber.replaceAll('Q-', '')) ?? 0;
    return 'Q-${(num + 1).toString().padLeft(4, '0')}';
  }
}

class ConvertedQuoteDeletionException implements Exception {
  final String message;
  const ConvertedQuoteDeletionException(this.message);
  @override
  String toString() => 'ConvertedQuoteDeletionException: $message';
}
