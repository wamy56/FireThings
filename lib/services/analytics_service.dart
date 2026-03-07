import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized analytics service wrapping Firebase Analytics.
/// Singleton matching the app's existing service pattern.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Firebase Analytics observer for automatic screen tracking.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ─── Templates ──────────────────────────────────────────────────────

  Future<void> logTemplateSelected(String templateName, String templateType) =>
      _analytics.logEvent(name: 'template_selected', parameters: {
        'template_name': templateName,
        'template_type': templateType,
      });

  // ─── Tools ──────────────────────────────────────────────────────────

  Future<void> logToolOpened(String toolName) =>
      _analytics.logEvent(name: 'tool_opened', parameters: {
        'tool_name': toolName,
      });

  // ─── Jobsheets ──────────────────────────────────────────────────────

  Future<void> logJobsheetStarted(String templateName) =>
      _analytics.logEvent(name: 'jobsheet_started', parameters: {
        'template_name': templateName,
      });

  Future<void> logJobsheetSavedDraft() =>
      _analytics.logEvent(name: 'jobsheet_saved_draft');

  Future<void> logJobsheetCompleted() =>
      _analytics.logEvent(name: 'jobsheet_completed');

  Future<void> logJobsheetPdfGenerated() =>
      _analytics.logEvent(name: 'jobsheet_pdf_generated');

  Future<void> logJobsheetPdfShared() =>
      _analytics.logEvent(name: 'jobsheet_pdf_shared');

  // ─── Invoices ───────────────────────────────────────────────────────

  Future<void> logInvoiceCreated() =>
      _analytics.logEvent(name: 'invoice_created');

  Future<void> logInvoiceSavedDraft() =>
      _analytics.logEvent(name: 'invoice_saved_draft');

  Future<void> logInvoiceSent() =>
      _analytics.logEvent(name: 'invoice_sent');

  Future<void> logInvoiceMarkedPaid() =>
      _analytics.logEvent(name: 'invoice_marked_paid');

  // ─── Customers ──────────────────────────────────────────────────────

  Future<void> logCustomerSaved(String source) =>
      _analytics.logEvent(name: 'customer_saved', parameters: {
        'source': source,
      });

  Future<void> logCustomerSelected() =>
      _analytics.logEvent(name: 'customer_selected');

  // ─── Sites ──────────────────────────────────────────────────────────

  Future<void> logSiteSaved() =>
      _analytics.logEvent(name: 'site_saved');

  Future<void> logSiteSelected() =>
      _analytics.logEvent(name: 'site_selected');

  // ─── PDF Forms ──────────────────────────────────────────────────────

  Future<void> logPdfFormOpened(String formType) =>
      _analytics.logEvent(name: 'pdf_form_opened', parameters: {
        'form_type': formType,
      });

  Future<void> logPdfFormSavedDraft(String formType) =>
      _analytics.logEvent(name: 'pdf_form_saved_draft', parameters: {
        'form_type': formType,
      });

  Future<void> logPdfFormPreviewed(String formType) =>
      _analytics.logEvent(name: 'pdf_form_previewed', parameters: {
        'form_type': formType,
      });

  // ─── Timestamp Camera ──────────────────────────────────────────────

  Future<void> logPhotoCaptured() =>
      _analytics.logEvent(name: 'photo_captured');

  Future<void> logVideoRecordingStarted() =>
      _analytics.logEvent(name: 'video_recording_started');

  Future<void> logVideoRecordingCompleted() =>
      _analytics.logEvent(name: 'video_recording_completed');

  // ─── Auth ───────────────────────────────────────────────────────────

  Future<void> logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  Future<void> logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method);
}
