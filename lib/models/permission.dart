import 'company_member.dart';

/// Granular permission that can be assigned per-user by a company admin.
/// Each permission has a Firestore key, a human-readable label, and a
/// category for grouping in the admin UI.
enum AppPermission {
  // Web Portal
  webPortalAccess('web_portal_access', 'Web Portal Access', 'Web Portal'),

  // Dispatch
  dispatchCreate('dispatch_create', 'Create Jobs', 'Dispatch'),
  dispatchEdit('dispatch_edit', 'Edit Jobs', 'Dispatch'),
  dispatchDelete('dispatch_delete', 'Delete Jobs', 'Dispatch'),
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
  assetsEdit('assets_edit', 'Edit Assets', 'Assets'),
  assetsDelete('assets_delete', 'Delete Assets', 'Assets'),
  assetsAddPhotos('assets_add_photos', 'Add Asset Photos', 'Assets'),
  assetsDeletePhotos('assets_delete_photos', 'Delete Asset Photos', 'Assets'),

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

  // Company
  companyEdit('company_edit', 'Edit Company', 'Company'),
  companyDelete('company_delete', 'Delete Company', 'Company'),
  teamManage('team_manage', 'Manage Team', 'Company'),
  inviteCodeRegenerate('invite_code_regenerate', 'Regenerate Invite Code', 'Company');

  final String key;
  final String label;
  final String category;

  const AppPermission(this.key, this.label, this.category);

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
          companyEdit.key: false,
          companyDelete.key: false,
          teamManage.key: false,
          inviteCodeRegenerate.key: false,
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
          customersCreate.key: false,
          customersEdit.key: false,
          customersDelete.key: false,
          assetsCreate.key: true,
          assetsEdit.key: true,
          assetsDelete.key: false,
          assetsAddPhotos.key: true,
          assetsDeletePhotos.key: false,
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
          companyEdit.key: false,
          companyDelete.key: false,
          teamManage.key: false,
          inviteCodeRegenerate.key: false,
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
