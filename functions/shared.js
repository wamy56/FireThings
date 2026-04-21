const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");

if (!getApps().length) initializeApp();

const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

function defaultPermissionsForRole(role) {
  const allPerms = {
    web_portal_access: false,
    dispatch_create: false,
    dispatch_edit: false,
    dispatch_delete: false,
    dispatch_view_all: false,
    sites_create: false,
    sites_edit: false,
    sites_delete: false,
    customers_create: false,
    customers_edit: false,
    customers_delete: false,
    assets_create: false,
    assets_edit: false,
    assets_delete: false,
    assets_add_photos: false,
    assets_delete_photos: false,
    assets_test: false,
    floor_plans_upload: false,
    floor_plans_edit: false,
    floor_plans_delete: false,
    asset_types_manage: false,
    pdf_branding: false,
    quotes_create: false,
    quotes_edit: false,
    quotes_send: false,
    quotes_approve: false,
    quotes_convert: false,
    invoices_create: false,
    invoices_edit: false,
    invoices_delete: false,
    invoices_send: false,
    jobsheets_edit: false,
    jobsheets_delete: false,
    defects_log: false,
    defects_rectify: false,
    defects_delete: false,
    bs5839_config_edit: false,
    bs5839_approve_variations: false,
    bs5839_issue_reports: false,
    bs5839_record_cpd: false,
    bs5839_view_team_competency: false,
    company_edit: false,
    company_delete: false,
    team_manage: false,
    invite_code_regenerate: false,
  };

  if (role === "admin") {
    return Object.fromEntries(Object.keys(allPerms).map((k) => [k, true]));
  }

  if (role === "dispatcher") {
    return {
      ...allPerms,
      web_portal_access: true,
      dispatch_create: true,
      dispatch_edit: true,
      dispatch_view_all: true,
      sites_create: true,
      sites_edit: true,
      sites_delete: true,
      customers_create: true,
      customers_edit: true,
      customers_delete: true,
      assets_create: true,
      assets_edit: true,
      assets_delete: true,
      assets_add_photos: true,
      assets_delete_photos: true,
      assets_test: true,
      floor_plans_upload: true,
      floor_plans_edit: true,
      floor_plans_delete: true,
      quotes_create: true,
      quotes_edit: true,
      quotes_send: true,
      quotes_approve: true,
      quotes_convert: true,
      invoices_create: true,
      invoices_edit: true,
      invoices_delete: true,
      invoices_send: true,
      jobsheets_edit: true,
      jobsheets_delete: true,
      defects_log: true,
      defects_rectify: true,
      defects_delete: true,
      bs5839_config_edit: true,
      bs5839_issue_reports: true,
      bs5839_record_cpd: true,
      bs5839_view_team_competency: true,
    };
  }

  // engineer
  return {
    ...allPerms,
    customers_create: true,
    assets_create: true,
    assets_edit: true,
    assets_add_photos: true,
    assets_test: true,
    floor_plans_upload: true,
    floor_plans_edit: true,
    quotes_create: true,
    quotes_edit: true,
    defects_log: true,
    defects_rectify: true,
    bs5839_issue_reports: true,
    bs5839_record_cpd: true,
  };
}

module.exports = { db, auth, messaging, defaultPermissionsForRole };
