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

  /// Delete a quote.
  Future<void> deleteQuote(String quoteId) async {
    await _db.deleteQuote(quoteId);
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
    return approved.fold<double>(0.0, (sum, q) => sum + q.total);
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
      siteName: quote.siteName,
      siteAddress: quote.customerAddress,
      contactName: quote.customerName,
      contactEmail: quote.customerEmail,
      contactPhone: quote.customerPhone,
      status: DispatchedJobStatus.created,
      priority: JobPriority.normal,
      createdAt: now,
      updatedAt: now,
      createdBy: user.uid,
      createdByName: user.displayName ?? user.email?.split('@')[0] ?? '',
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
}
