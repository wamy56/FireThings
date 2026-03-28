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

  // ─── Dispatch ─────────────────────────────────────────────────────

  Future<void> logCompanyCreated(String companyId) =>
      _analytics.logEvent(name: 'company_created', parameters: {
        'company_id': companyId,
      });

  Future<void> logCompanyJoined(String companyId, String role) =>
      _analytics.logEvent(name: 'company_joined', parameters: {
        'company_id': companyId,
        'role': role,
      });

  Future<void> logDispatchJobCreated(
    String companyId,
    String? jobType,
    bool hasAssignment,
  ) =>
      _analytics.logEvent(name: 'dispatch_job_created', parameters: {
        'company_id': companyId,
        'job_type': jobType ?? 'unspecified',
        'has_assignment': hasAssignment.toString(),
      });

  Future<void> logDispatchJobAssigned(
          String companyId, String? jobType) =>
      _analytics.logEvent(name: 'dispatch_job_assigned', parameters: {
        'company_id': companyId,
        'job_type': jobType ?? 'unspecified',
      });

  Future<void> logDispatchJobAccepted(String companyId, String jobId) =>
      _analytics.logEvent(name: 'dispatch_job_accepted', parameters: {
        'company_id': companyId,
        'job_id': jobId,
      });

  Future<void> logDispatchJobDeclined(
          String companyId, String? reason) =>
      _analytics.logEvent(name: 'dispatch_job_declined', parameters: {
        'company_id': companyId,
        'reason': reason ?? 'none',
      });

  Future<void> logDispatchJobStatusChanged(
    String companyId,
    String oldStatus,
    String newStatus,
  ) =>
      _analytics
          .logEvent(name: 'dispatch_job_status_changed', parameters: {
        'company_id': companyId,
        'old_status': oldStatus,
        'new_status': newStatus,
      });

  Future<void> logDispatchJobCompleted(
    String companyId,
    String jobId,
    bool hasJobsheet,
  ) =>
      _analytics.logEvent(name: 'dispatch_job_completed', parameters: {
        'company_id': companyId,
        'job_id': jobId,
        'has_jobsheet': hasJobsheet.toString(),
      });

  Future<void> logDispatchJobsheetCreated(
    String companyId,
    String jobId,
    String? templateType,
  ) =>
      _analytics
          .logEvent(name: 'dispatch_jobsheet_created', parameters: {
        'company_id': companyId,
        'job_id': jobId,
        'template_type': templateType ?? 'unknown',
      });

  Future<void> logDispatchDirectionsOpened(String companyId) =>
      _analytics
          .logEvent(name: 'dispatch_directions_opened', parameters: {
        'company_id': companyId,
      });

  Future<void> logDispatchContactCalled(String companyId) =>
      _analytics.logEvent(name: 'dispatch_contact_called', parameters: {
        'company_id': companyId,
      });

  // ── Web Portal Events ──

  Future<void> logWebLogin() =>
      _analytics.logEvent(name: 'web_login');

  Future<void> logWebDashboardViewed() =>
      _analytics.logEvent(name: 'web_dashboard_viewed');

  Future<void> logWebJobCreated() =>
      _analytics.logEvent(name: 'web_job_created');

  Future<void> logWebJobEdited() =>
      _analytics.logEvent(name: 'web_job_edited');

  Future<void> logWebJobAssigned() =>
      _analytics.logEvent(name: 'web_job_assigned');

  Future<void> logWebScheduleViewed() =>
      _analytics.logEvent(name: 'web_schedule_viewed');

  Future<void> logWebJobDetailViewed() =>
      _analytics.logEvent(name: 'web_job_detail_viewed');

  Future<void> logWebBulkAssign() =>
      _analytics.logEvent(name: 'web_bulk_assign');

  Future<void> logWebSearchUsed() =>
      _analytics.logEvent(name: 'web_search_used');

  Future<void> logWebPrintUsed() =>
      _analytics.logEvent(name: 'web_print_used');

  Future<void> logWebAssetRegisterViewed() =>
      _analytics.logEvent(name: 'web_asset_register_viewed');

  Future<void> logWebFloorPlanViewed() =>
      _analytics.logEvent(name: 'web_floor_plan_viewed');

  // --- Asset Register ---

  Future<void> logAssetCreated({
    required String assetType,
    required String siteId,
    required bool hasBarcode,
  }) =>
      _analytics.logEvent(name: 'asset_created', parameters: {
        'asset_type': assetType,
        'site_id': siteId,
        'has_barcode': hasBarcode,
      });

  Future<void> logAssetEdited({required String assetType}) =>
      _analytics.logEvent(
          name: 'asset_edited', parameters: {'asset_type': assetType});

  Future<void> logAssetDeleted({required String assetType}) =>
      _analytics.logEvent(
          name: 'asset_deleted', parameters: {'asset_type': assetType});

  Future<void> logAssetTested({
    required String assetType,
    required String result,
    required String siteId,
  }) =>
      _analytics.logEvent(name: 'asset_tested', parameters: {
        'asset_type': assetType,
        'result': result,
        'site_id': siteId,
      });

  Future<void> logBatchTestingCompleted({
    required String siteId,
    required int passCount,
    required int failCount,
    required int skippedCount,
  }) =>
      _analytics.logEvent(name: 'batch_testing_completed', parameters: {
        'site_id': siteId,
        'pass_count': passCount,
        'fail_count': failCount,
        'skipped_count': skippedCount,
      });

  Future<void> logAssetDecommissioned({
    required String assetType,
    required String reason,
    required String siteId,
  }) =>
      _analytics.logEvent(name: 'asset_decommissioned', parameters: {
        'asset_type': assetType,
        'reason': reason,
        'site_id': siteId,
      });

  Future<void> logBarcodeScan({
    required String result,
    required String siteId,
  }) =>
      _analytics.logEvent(name: 'barcode_scan', parameters: {
        'result': result,
        'site_id': siteId,
      });

  // --- Floor Plans ---

  Future<void> logFloorPlanUploaded({
    required String siteId,
    required String sourceType,
  }) =>
      _analytics.logEvent(name: 'floor_plan_uploaded', parameters: {
        'site_id': siteId,
        'source_type': sourceType,
      });

  Future<void> logFloorPlanViewed({
    required String siteId,
    required int assetCount,
  }) =>
      _analytics.logEvent(name: 'floor_plan_viewed', parameters: {
        'site_id': siteId,
        'asset_count': assetCount,
      });

  Future<void> logFloorPlanPinPlaced({
    required String siteId,
    required String assetType,
  }) =>
      _analytics.logEvent(name: 'floor_plan_pin_placed', parameters: {
        'site_id': siteId,
        'asset_type': assetType,
      });

  Future<void> logAssetRegisterViewed({
    required String siteId,
    required int assetCount,
  }) =>
      _analytics.logEvent(name: 'asset_register_viewed', parameters: {
        'site_id': siteId,
        'asset_count': assetCount,
      });

  Future<void> logDispatchComplianceViewed({
    required String siteId,
    required int assetCount,
    required double passRate,
  }) =>
      _analytics.logEvent(name: 'dispatch_compliance_viewed', parameters: {
        'site_id': siteId,
        'asset_count': assetCount,
        'pass_rate': passRate,
      });

  Future<void> logComplianceReportGenerated({
    required String siteId,
    required int assetCount,
    required double passRate,
  }) =>
      _analytics.logEvent(name: 'compliance_report_generated', parameters: {
        'site_id': siteId,
        'asset_count': assetCount,
        'pass_rate': passRate,
      });

  Future<void> logAssetTypeCreated({
    required String typeName,
    required bool isCustom,
  }) =>
      _analytics.logEvent(name: 'asset_type_created', parameters: {
        'type_name': typeName,
        'is_custom': isCustom,
      });

  Future<void> logAssetTypeChecklistModified({
    required String typeId,
    required int itemCount,
  }) =>
      _analytics.logEvent(
          name: 'asset_type_checklist_modified',
          parameters: {
            'type_id': typeId,
            'item_count': itemCount,
          });
}
