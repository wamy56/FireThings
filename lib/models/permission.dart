import 'company_member.dart';

/// Granular permission that can be assigned per-user by a company admin.
/// Each permission has a Firestore key, a human-readable label, and a
/// category for grouping in the admin UI.
enum AppPermission {
  // Web Portal
  webPortalAccess('web_portal_access', 'Web Portal Access', 'Web Portal'),

  // Dispatch
  dispatchCreate('dispatch_create', 'Create Jobs', 'Dispatch'),
  dispatchEdit('dispatch_edit', 'Edit Jobs', 'Dispatch',
      description: 'Edit jobs you can see (limited by View All Jobs)'),
  dispatchDelete('dispatch_delete', 'Delete Jobs', 'Dispatch',
      description: 'Delete jobs you can see (limited by View All Jobs)'),
  dispatchViewAll('dispatch_view_all', 'View All Jobs', 'Dispatch'),

  // Sites
  sitesCreate('sites_create', 'Add Sites', 'Sites'),
  sitesEdit('sites_edit', 'Edit Sites', 'Sites'),
  sitesDelete('sites_delete', 'Delete Sites', 'Sites'),

  // Customers
  customersCreate('customers_create', 'Add Customers', 'Customers'),
  customersEdit('customers_edit', 'Edit Customers', 'Customers'),
  customersDelete('customers_delete', 'Delete Customers', 'Customers'),

  // Assets
  assetsCreate('assets_create', 'Add Assets', 'Assets'),
  assetsEdit('assets_edit', 'Edit Assets', 'Assets',
      description: 'Includes moving floor plan pin positions'),
  assetsDelete('assets_delete', 'Delete Assets', 'Assets'),
  assetsAddPhotos('assets_add_photos', 'Add Asset Photos', 'Assets'),
  assetsDeletePhotos('assets_delete_photos', 'Delete Asset Photos', 'Assets'),
  assetsTest('assets_test', 'Test/Inspect Assets', 'Assets'),

  // Floor Plans
  floorPlansUpload('floor_plans_upload', 'Upload Floor Plans', 'Floor Plans'),
  floorPlansEdit('floor_plans_edit', 'Edit Floor Plans', 'Floor Plans'),
  floorPlansDelete('floor_plans_delete', 'Delete Floor Plans', 'Floor Plans'),

  // Asset Types
  assetTypesManage('asset_types_manage', 'Manage Asset Types', 'Asset Types'),

  // Branding
  pdfBranding('pdf_branding', 'PDF Branding', 'Branding'),

  // Quoting
  quotesCreate('quotes_create', 'Create Quotes', 'Quoting'),
  quotesEdit('quotes_edit', 'Edit Quotes', 'Quoting'),
  quotesSend('quotes_send', 'Send Quotes', 'Quoting'),
  quotesApprove('quotes_approve', 'Approve/Decline Quotes', 'Quoting'),
  quotesConvert('quotes_convert', 'Convert Quote to Job', 'Quoting'),

  // Invoicing
  invoicesCreate('invoices_create', 'Create Invoices', 'Invoicing'),
  invoicesEdit('invoices_edit', 'Edit Invoices', 'Invoicing'),
  invoicesDelete('invoices_delete', 'Delete Invoices', 'Invoicing'),
  invoicesSend('invoices_send', 'Send Invoices', 'Invoicing'),

  // Jobsheets
  jobsheetsEdit('jobsheets_edit', 'Edit Completed Jobsheets', 'Jobsheets'),
  jobsheetsDelete('jobsheets_delete', 'Delete Completed Jobsheets', 'Jobsheets'),

  // Defects
  defectsLog('defects_log', 'Log Defects', 'Defects'),
  defectsRectify('defects_rectify', 'Mark Defects Rectified', 'Defects'),
  defectsDelete('defects_delete', 'Delete Defects', 'Defects'),

  // Company
  companyEdit('company_edit', 'Edit Company', 'Company'),
  companyDelete('company_delete', 'Delete Company', 'Company'),
  teamManage('team_manage', 'Manage Team', 'Company'),
  inviteCodeRegenerate('invite_code_regenerate', 'Regenerate Invite Code', 'Company'),

  // BS 5839
  bs5839ConfigEdit('bs5839_config_edit', 'Edit BS 5839 Config', 'BS 5839'),
  bs5839ApproveVariations('bs5839_approve_variations', 'Approve Variations', 'BS 5839'),
  bs5839IssueReports('bs5839_issue_reports', 'Issue Reports', 'BS 5839'),
  bs5839RecordCpd('bs5839_record_cpd', 'Record CPD', 'BS 5839'),
  bs5839ViewTeamCompetency('bs5839_view_team_competency', 'View Team Competency', 'BS 5839');

  final String key;
  final String label;
  final String category;
  final String? description;

  const AppPermission(this.key, this.label, this.category, {this.description});

  /// Default permission map for a given role. Used when creating members
  /// or when loading a member doc that has no permissions field yet.
  static Map<String, bool> defaultsForRole(CompanyRole role) {
    switch (role) {
      case CompanyRole.admin:
        return {for (final p in AppPermission.values) p.key: true};
      case CompanyRole.dispatcher:
        return {
          webPortalAccess.key: true,
          dispatchCreate.key: true,
          dispatchEdit.key: true,
          dispatchDelete.key: false,
          dispatchViewAll.key: true,
          sitesCreate.key: true,
          sitesEdit.key: true,
          sitesDelete.key: true,
          customersCreate.key: true,
          customersEdit.key: true,
          customersDelete.key: true,
          assetsCreate.key: true,
          assetsEdit.key: true,
          assetsDelete.key: true,
          assetsAddPhotos.key: true,
          assetsDeletePhotos.key: true,
          assetsTest.key: true,
          floorPlansUpload.key: true,
          floorPlansEdit.key: true,
          floorPlansDelete.key: true,
          assetTypesManage.key: false,
          pdfBranding.key: false,
          quotesCreate.key: true,
          quotesEdit.key: true,
          quotesSend.key: true,
          quotesApprove.key: true,
          quotesConvert.key: true,
          invoicesCreate.key: true,
          invoicesEdit.key: true,
          invoicesDelete.key: true,
          invoicesSend.key: true,
          jobsheetsEdit.key: true,
          jobsheetsDelete.key: true,
          defectsLog.key: true,
          defectsRectify.key: true,
          defectsDelete.key: true,
          companyEdit.key: false,
          companyDelete.key: false,
          teamManage.key: false,
          inviteCodeRegenerate.key: false,
          bs5839ConfigEdit.key: true,
          bs5839ApproveVariations.key: false,
          bs5839IssueReports.key: true,
          bs5839RecordCpd.key: true,
          bs5839ViewTeamCompetency.key: true,
        };
      case CompanyRole.engineer:
        return {
          webPortalAccess.key: false,
          dispatchCreate.key: false,
          dispatchEdit.key: false,
          dispatchDelete.key: false,
          dispatchViewAll.key: false,
          sitesCreate.key: false,
          sitesEdit.key: false,
          sitesDelete.key: false,
          customersCreate.key: true,
          customersEdit.key: false,
          customersDelete.key: false,
          assetsCreate.key: true,
          assetsEdit.key: true,
          assetsDelete.key: false,
          assetsAddPhotos.key: true,
          assetsDeletePhotos.key: false,
          assetsTest.key: true,
          floorPlansUpload.key: true,
          floorPlansEdit.key: true,
          floorPlansDelete.key: false,
          assetTypesManage.key: false,
          pdfBranding.key: false,
          quotesCreate.key: true,
          quotesEdit.key: true,
          quotesSend.key: false,
          quotesApprove.key: false,
          quotesConvert.key: false,
          invoicesCreate.key: false,
          invoicesEdit.key: false,
          invoicesDelete.key: false,
          invoicesSend.key: false,
          jobsheetsEdit.key: false,
          jobsheetsDelete.key: false,
          defectsLog.key: true,
          defectsRectify.key: true,
          defectsDelete.key: false,
          companyEdit.key: false,
          companyDelete.key: false,
          teamManage.key: false,
          inviteCodeRegenerate.key: false,
          bs5839ConfigEdit.key: false,
          bs5839ApproveVariations.key: false,
          bs5839IssueReports.key: true,
          bs5839RecordCpd.key: true,
          bs5839ViewTeamCompetency.key: false,
        };
    }
  }

  /// All unique categories in display order.
  static List<String> get categories =>
      values.map((p) => p.category).toSet().toList();

  /// All permissions in a given category.
  static List<AppPermission> forCategory(String category) =>
      values.where((p) => p.category == category).toList();
}
