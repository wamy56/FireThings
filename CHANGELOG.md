# FireThings - Changelog

All changes made to the app, updated at the end of every Claude session. Reverse-chronological order.

---

## 2026-04-18 (Session 74)

### Web Portal: Quotes & Invoices Dashboard

Added full Quotes and Invoices sections to the web dispatch portal, giving office staff complete control over quoting and invoicing. Both follow the same patterns as the existing Jobs dashboard — DataTable with filters, slide-in detail panel, create/edit forms.

#### New Files (8)
- **`lib/screens/web/dashboard/invoice_helpers.dart`** — Status color/label/badge helpers + CSV export for invoices
- **`lib/screens/web/web_quotes_screen.dart`** — Quotes dashboard: StreamBuilder on company-wide collectionGroup query, summary cards (Drafts/Sent/Approved/Declined/Value), DataTable with sorting/filtering/pagination, CSV export, column visibility toggle, slide-in detail panel
- **`lib/screens/web/web_quote_detail_panel.dart`** — Quote detail slide-in panel: status timeline, items table with totals, permission-gated actions (Mark Sent, Approve, Decline, Convert to Job, Download PDF, Edit, Delete)
- **`lib/screens/web/web_create_quote_screen.dart`** — Create/edit quote form: customer/site autocomplete from company data, dynamic line items with category, VAT toggle, company branding toggle, live total calculation
- **`lib/screens/web/web_invoices_screen.dart`** — Invoices dashboard: same pattern as quotes, summary cards (Drafts/Sent/Paid/Outstanding), overdue date highlighting
- **`lib/screens/web/web_invoice_detail_panel.dart`** — Invoice detail panel: status timeline, items table, actions (Download PDF, Email, Mark Sent, Mark Paid, Edit, Delete)
- **`lib/screens/web/web_create_invoice_screen.dart`** — Create/edit invoice form: customer autocomplete, date pickers, dynamic line items, VAT/branding toggles

#### Modified Files (2)
- **`lib/screens/web/web_router.dart`** — Added 6 new routes: `/quotes`, `/quotes/create`, `/quotes/:id`, `/invoices`, `/invoices/create`, `/invoices/:id`. Quotes routes redirect to `/jobs` when `quotingEnabled` is false.
- **`lib/screens/web/web_shell.dart`** — Added Quotes (conditional on `quotingEnabled`) and Invoices sidebar items. Updated `_selectedIndexFromPath()` for dynamic index calculation.

#### Technical Notes
- Firestore `collectionGroup` queries with `companyId` filter for company-wide visibility
- Composite indexes needed: `quotes` and `invoices` collectionGroups for `companyId` + `createdAt` desc (manual Firebase Console setup)
- `quote_helpers.dart` was created in previous session (Session 73)

---

## 2026-04-18 (Session 73)

### Defect-to-Quote Workflow — Remaining Integration (Phases 4-6)

Completed the defect-to-quote feature implementation. Phases 1-3 (model, service, PDF) and partial Phase 4 (quote screen, quote list) were already done. This session added the quoting hub dashboard, integration points (defect bottom sheet, asset detail, home screen), and quote-to-job conversion.

#### Changes
- **`lib/screens/quoting/quoting_hub_screen.dart`** — New file. Dashboard with 4 stat cards (Drafts, Sent, Approved, Total Value) and quick actions (Create New Quote, View All Quotes). Tapping stat cards navigates to filtered quote list.
- **`lib/widgets/defect_bottom_sheet.dart`** — After saving a defect, shows dialog offering to create a quote (gated behind `quotingEnabled` remote config flag). Passes site/customer info through to QuoteScreen.
- **`lib/screens/assets/asset_detail_screen.dart`** — Added Create Quote / View Quote button to `_ActiveDefectCard` widget. View Quote loads the linked quote by ID.
- **`lib/screens/home/home_screen.dart`** — Added Quotes card on home screen showing active quote count. Navigates to QuotingHubScreen. Gated behind `quotingEnabled`.
- **`lib/services/quote_service.dart`** — Added `convertQuoteToJob()` method. Creates a DispatchedJob from an approved quote, updates quote status to converted, logs analytics.
- **`lib/screens/quoting/quote_screen.dart`** — Added Convert to Job button for approved quotes (company users only). Fixed AppTheme/AppIcons naming issues. Replaced broken `showPremiumDialog` calls with standard `AlertDialog`.
- **`lib/screens/quoting/quote_list_screen.dart`** — Fixed AppTheme/AppIcons naming (primary→primaryBlue, accent→accentOrange, etc.)

#### Bug Fixes (pre-existing in quote screens)
- Fixed `AppTheme.primary/accent/success/error` → `primaryBlue/accentOrange/successGreen/errorRed` across all quoting files
- Fixed `AppIcons.documentText` → `document`, `AppIcons.closeCircle` → `close`, `AppIcons.userTag` → `user`
- Fixed `AppTheme.darkCard` → `darkSurfaceElevated`
- Fixed `UserProfileService.instance.currentProfile` → `.profile`
- Fixed `AnimatedSaveButton` usage (removed non-existent `icon`/`isLoading` params)
- Replaced `showPremiumDialog` with wrong params → standard `showDialog` + `AlertDialog`

---

## 2026-04-18 (Session 72)

### PDF Customizer Overhaul — Template Presets + Bug Fixes

Simplified the PDF customizer from 5 tabs to 3 (Template | Header | Footer). Replaced granular Style and Typography controls with 4 pre-made professional template presets (Modern, Classic, Minimal, Bold) that control the entire PDF look. Added header text editing back (was lost in Session 71 overhaul). Fixed logo centre placement bug.

#### Changes
- **Template tab**: 2x2 grid of 4 preset cards with mini style indicators + colour scheme picker (moved from old Colours tab). Each preset sets header style, section card/header styles, corner radius, spacing, padding, and typography as a cohesive unit.
- **Header tab**: Restored header text line editing with simplified cards (text field + delete + drag-to-reorder). Removed Header Style picker (now controlled by template). Left zone and centre zone support with add line options (Company Name, Tagline, Address, Phone, Engineer Name, Custom Text).
- **Logo centre fix**: Centred logos now appear correctly above the header content row in both the live preview and generated PDFs (jobsheet and invoice). Previously, selecting "Centre" placed the logo at the far right.
- **Removed**: Typography tab (6 font size sliders), Style tab (card style, corner radius, header style, spacing sliders), Colours tab (merged into Template tab)

#### Files Modified
- **`lib/models/pdf_style_preset.dart`** — Added `typographyConfig` getter, `applyToHeaderConfig()` method, `matchFromConfigs()` static matcher. Removed `colourScheme` getter. Changed `headerConfig` to individual property getters (headerStyle, cornerRadius, padding).
- **`lib/screens/settings/unified_pdf_editor_screen.dart`** — Restructured from 5 tabs to 3. Added template preset grid, header text line editing with ReorderableListView, colour picker in template tab.
- **`lib/widgets/unified_pdf_preview.dart`** — Fixed centre logo layout in all 3 header styles (modern/classic/minimal) using Column with centred logo above content row.
- **`lib/services/pdf_widgets/pdf_modern_header.dart`** — Fixed centre logo placement in jobsheet PDF generation. Added `_buildCentredLogo()` helper. All 3 header style builders now handle centre logo via Column layout.
- **`lib/services/pdf_header_builder.dart`** — Fixed centre logo placement in invoice PDF generation. Centre logo now renders above the text row instead of inline.

---

## 2026-04-16 (Session 71)

### Unified PDF Editor - UX Improvement

Consolidated the 5 separate PDF customization screens (Header, Footer, Colour Scheme, Section Style, Typography) into a single tabbed editor with a unified live preview. This solves two UX problems: (1) Section Style and Typography screens had no visual feedback, and (2) users had to navigate in/out of 5 different screens to fully configure PDF styling.

#### New Files Created
- **`lib/widgets/unified_pdf_preview.dart`** — Reusable preview widget showing combined effect of all 5 config types (header, footer, colours, section style, typography). Renders scaled mockup with proper header styles (modern/classic/minimal), section card styles (bordered/shadowed/elevated/flat), section header styles (fullWidth/leftAccent/underlined), and footer zones.
- **`lib/screens/settings/unified_pdf_editor_screen.dart`** — Main unified editor with 5-tab interface (Header, Footer, Colours, Style, Typography). Live preview updates as settings change. Supports both personal (`isCompany: false`) and company (`isCompany: true, companyId: ...`) modes. Single save button persists all configs simultaneously.

#### Files Modified
- **`lib/screens/invoicing/pdf_design_screen.dart`** — Replaced 5 navigation cards per doc type with single "Design" card navigating to `UnifiedPdfEditorScreen`
- **`lib/screens/company/company_pdf_design_screen.dart`** — Simplified from 2335 lines to ~110 lines. Removed all private inline editor screens (`_CompanyHeaderEditorScreen`, `_CompanyFooterEditorScreen`, `_CompanyColourSchemeEditorScreen`, `_CompanySectionStyleEditorScreen`, `_CompanyTypographyEditorScreen`). Now uses `UnifiedPdfEditorScreen` in company mode.
- **`lib/utils/icon_map.dart`** — Added `layout` and `text` icons to Design/Branding section

#### Bug Fixes
- Fixed `AnimatedSaveButton(onSave: ...)` → `AnimatedSaveButton(onPressed: ...)` in `pdf_typography_screen.dart` and `pdf_section_style_screen.dart`
- Fixed `AppTheme.primary` → `AppTheme.primaryBlue` in `pdf_typography_screen.dart` and `company_pdf_design_screen.dart`
- Removed unused imports

---

## 2026-04-15 (Session 70)

### PDF Redesign Implementation - Full 6-Phase Rollout

Implemented comprehensive PDF redesign following the specification in `PDF_REDESIGN_IMPLEMENTATION.md`. This transforms the PDF generation system into a modern, professional design with full user customization for both personal and company PDFs.

#### Phase 1: Updated Model Layer
- **PdfColourScheme** — Added secondary color support, text/background color getters, improved `copyWith` method
- **PdfHeaderConfig** — Added `HeaderStyle` and `HeaderCornerRadius` enums with `style`, `cornerRadius`, `showDivider` fields
- **PdfSectionStyleConfig** (NEW) — Card style (bordered/shadowed/elevated/flat), corner radius (small/medium/large), header style (fullWidth/leftAccent/underlined), spacing and padding controls
- **PdfTypographyConfig** (NEW) — Font size configuration for section headers, field labels, field values, table headers, table body, and footer text
- **PdfStylePreset** (NEW) — Preset combinations (modern, classic, minimal, bold) for quick styling
- Updated `models/models.dart` barrel exports

#### Phase 2: Created PDF Widget Library
New reusable PDF widgets at `lib/services/pdf_widgets/`:
- `pdf_style_helpers.dart` — `buildCardDecoration()`, `labelStyle()`, `valueStyle()`, color constants
- `pdf_modern_header.dart` — `buildModernHeader()` with 3 style variants (modern/classic/minimal)
- `pdf_section_card.dart` — `buildSectionCard()` with styled headers (fullWidth/leftAccent/underlined)
- `pdf_field_row.dart` — `buildFieldGrid()`, `buildCompactFieldRow()` for consistent field layouts
- `pdf_modern_table.dart` — `buildModernTable()`, `buildSimpleTable()` with styled headers
- `pdf_signature_box.dart` — `buildSignatureSection()` with consistent styling

#### Phase 3: Updated Services
- **PdfSectionStyleService** (NEW) — SharedPreferences persistence + Firestore sync for section styles
- **PdfTypographyService** (NEW) — SharedPreferences persistence + Firestore sync for typography
- **FirestoreSyncService** — Added `syncPdfSectionStyle()` and `syncPdfTypography()` methods
- **CompanyPdfConfigService** — Added section style and typography caches, CRUD methods, effective config resolution
- **PdfGenerationData DTOs** — Added `secondaryColourValue`, `sectionStyleJson`, `typographyJson` fields

#### Phase 4: Refactored pdf_service.dart
- Updated imports to use new widget library
- Refactored `_buildHeader()` to use `buildModernHeader()` with style variants
- Refactored `_buildSection()` to use `buildSectionCard()` with configurable styles
- Updated all section builders to use new widgets and respect typography settings
- Removed legacy inline styling code

#### Phase 5: Created Customization Screens
- **PdfSectionStyleScreen** (NEW) — Card style selector, corner radius selector, header style selector, spacing/padding sliders
- **PdfTypographyScreen** (NEW) — Font size sliders for all PDF text elements with reset-to-defaults
- **PdfDesignScreen** — Added navigation cards for Section Style and Typography for both Jobsheet and Invoice

#### Phase 6: Company PDF Support
- Updated `CompanyPdfDesignScreen` with Section Style and Typography config cards
- Added `_CompanySectionStyleEditorScreen` private widget with full styling controls
- Added `_CompanyTypographyEditorScreen` private widget with font size sliders
- Integrated with `CompanyPdfConfigService` for Firestore persistence

**Files Created:**
- `lib/models/pdf_section_style_config.dart`
- `lib/models/pdf_typography_config.dart`
- `lib/models/pdf_style_preset.dart`
- `lib/services/pdf_section_style_service.dart`
- `lib/services/pdf_typography_service.dart`
- `lib/services/pdf_widgets/pdf_style_helpers.dart`
- `lib/services/pdf_widgets/pdf_modern_header.dart`
- `lib/services/pdf_widgets/pdf_section_card.dart`
- `lib/services/pdf_widgets/pdf_field_row.dart`
- `lib/services/pdf_widgets/pdf_modern_table.dart`
- `lib/services/pdf_widgets/pdf_signature_box.dart`
- `lib/screens/settings/pdf_section_style_screen.dart`
- `lib/screens/settings/pdf_typography_screen.dart`

**Files Modified:**
- `lib/models/pdf_colour_scheme.dart`
- `lib/models/pdf_header_config.dart`
- `lib/models/models.dart`
- `lib/services/pdf_service.dart`
- `lib/services/pdf_generation_data.dart`
- `lib/services/firestore_sync_service.dart`
- `lib/services/company_pdf_config_service.dart`
- `lib/screens/invoicing/pdf_design_screen.dart`
- `lib/screens/company/company_pdf_design_screen.dart`
- `lib/utils/icon_map.dart` (added `layout` and `text` icons)

---

## 2026-04-12 (Session 69)

### UI: Permission Toggle Colors Changed to Blue

Changed the toggle switch colors on the "Edit Permissions" screen from orange to blue to better match the app's primary color scheme.

**Changes:**
- Light mode: Uses `AppTheme.primaryBlue` (Deep Navy #1E3A5F)
- Dark mode: Uses `AppTheme.darkPrimaryBlue` (#3D7AC7)

**Files Modified:**
- `lib/screens/company/member_permissions_screen.dart` — Changed `activeTrackColor` and `activeThumbColor` from `accentOrange` to theme-aware blue

**Result:**
- Permission toggles now display in blue on both mobile app and web dispatch portal
- Consistent with primary brand colors across light and dark themes

---

## 2026-04-12 (Session 68)

### UI: Added Icons for Weekly Test & Emergency Lighting Templates

Added distinct icons and colors for two jobsheet templates that were using default styling.

**Changes:**
- Weekly Test: clipboard icon with blue background (#2196F3)
- Emergency Lighting Annual Test: lamp icon with amber background (#FFC107)

**Files Modified:**
- `lib/screens/new_job/new_job_screen.dart` — Added icon cases in `_getTemplateIcon()`
- `lib/utils/theme.dart` — Added color cases in `getTemplateColor()`

---

## 2026-04-12 (Session 67)

### Bug Fix: Compliance Report Defect Photos Not Showing on Web

Fixed an issue where defect photos appeared correctly in compliance reports generated on mobile but were missing when generated on the web portal.

**Root Cause:**
- Floor plan downloads had special `kIsWeb` handling using direct HTTP GET
- Defect photo downloads used `_downloadBytes` which fails silently on web due to redundant URL resolution and no timeout

**Fix:**
- Added `kIsWeb` guard to defect photo download, using the URL directly with `http.get()` on web (matching floor plan pattern)
- Applied same fix to legacy defect photos section

**Files Modified:**
- `lib/services/compliance_report_service.dart` — Added web-specific HTTP GET path for both defect photo download sections (lines ~1076 and ~1105)

**Result:**
- Defect photos now appear correctly in compliance reports generated on web portal
- Mobile behavior unchanged

---

## 2026-04-12 (Session 66)

### Web Portal Max-Width Container Fixes

Fixed two web portal screens that were missing the standard `Center` + `ConstrainedBox(maxWidth: 750)` wrapper, causing content to spread across the full viewport on wide screens.

**Files Modified:**
- `lib/screens/assets/asset_type_config_screen.dart` — Wrapped `_AssetTypeEditScreen` body with max-width 750 container
- `lib/screens/company/member_permissions_screen.dart` — Wrapped `ListView` with max-width 750 container

**Result:**
- Asset type edit/create form now centered on web
- Member permissions screen now centered on web
- Consistent with all other company/asset management screens

---

## 2026-04-12 (Session 65)

### Multi-Site Hosting Architecture Plan

Created comprehensive planning document for expanding Firebase Hosting to support multiple sites.

**New Documentation:**
- `MULTI_SITE_HOSTING_PLAN.md` — Complete implementation guide for multi-site Firebase Hosting architecture

**Planned Architecture:**
- `www.firethings.com` → Marketing/landing site (static HTML or Next.js)
- `app.firethings.com` → Dispatch portal (existing Flutter web app)
- `customers.firethings.com` → Future customer portal

**Document Covers:**
- Firebase multi-site setup (`.firebaserc` and `firebase.json` configuration)
- Marketing site directory structure and example HTML
- DNS/subdomain configuration
- Deployment workflow and CI/CD integration
- Future customer portal considerations
- Implementation checklist

No code changes — planning documentation only.

---

## 2026-04-12 (Session 64)

### Asset Photos Feature

Added support for multiple photos per asset to help engineers locate equipment in the field (hidden in cupboards, ceiling voids, behind locked doors, etc.).

**Model Changes:**
- `lib/models/asset.dart` — Changed `photoUrl: String?` to `photoUrls: List<String>` with migration support for legacy single-photo field
- `lib/models/permission.dart` — Added `assetsAddPhotos` and `assetsDeletePhotos` permissions (engineers can add but not delete by default)

**Service Changes:**
- `lib/services/asset_service.dart` — Added `uploadAssetPhoto()`, `deleteAssetPhoto()`, `deleteAllAssetPhotos()` methods with Firebase Storage integration, image compression (1280px max, 80% quality), and dual SDK/REST API upload paths for web compatibility

**New Widgets:**
- `lib/widgets/full_screen_image_viewer.dart` — Swipeable full-screen image viewer with pinch-to-zoom (InteractiveViewer), page indicator dots, and immersive mode
- `lib/widgets/asset_photo_gallery.dart` — Horizontal scrolling thumbnail gallery with add/delete buttons, permission checks, camera/gallery source picker, and 5-photo limit

**Screen Integration:**
- `lib/screens/assets/asset_detail_screen.dart` — Added Photos section below Notes with `AssetPhotoGallery` widget
- `lib/screens/assets/add_edit_asset_screen.dart` — Updated to preserve existing `photoUrls` when editing assets

**Configuration:**
- Max 5 photos per asset (`AssetService.maxPhotos`)
- Storage path: `{basePath}/sites/{siteId}/assets/{assetId}/photos/{timestamp}.jpg`

---

## 2026-04-12 (Session 63)

### PDF Branding v2 Revert

Reverted all PDF branding v2 changes from Session 62, restoring the original v1 PDF branding system.

**Deleted (v2 files):**
- `lib/screens/pdf_branding/` — entire directory (6 screens: hub, editor, live preview, content block card, variable sheet, preset selector)
- `lib/data/pdf_branding_presets.dart`
- `lib/models/pdf_variable.dart`, `pdf_content_block.dart`, `pdf_colour_scheme_v2.dart`, `pdf_font_config.dart`, `pdf_layout_template.dart`, `pdf_branding_config.dart`
- `lib/services/pdf_branding_migration.dart`, `pdf_branding_config_service.dart`, `pdf_branding_editor_adapter.dart`, `pdf_branding_builder.dart`

**Restored (v1 screens from commit 5d5254f):**
- `lib/screens/settings/pdf_header_designer_screen.dart` (731 lines)
- `lib/screens/settings/pdf_footer_designer_screen.dart` (494 lines)
- `lib/screens/settings/pdf_colour_scheme_screen.dart` (599 lines)
- `lib/screens/invoicing/pdf_design_screen.dart` (181 lines)
- `lib/screens/company/company_pdf_design_screen.dart` (1766 lines)

**Reverted (modified files to pre-session-62 state):**
- `lib/services/pdf_service.dart`, `invoice_pdf_service.dart`, `compliance_report_service.dart`
- `lib/services/company_pdf_config_service.dart`, `firestore_sync_service.dart`, `pdf_generation_data.dart`
- `lib/screens/settings/settings_screen.dart`, `jobs/jobs_hub_screen.dart`, `invoicing/invoicing_hub_screen.dart`
- `lib/screens/company/company_settings_screen.dart`, `web/web_router.dart`
- `lib/models/models.dart` — barrel exports (re-added `permission.dart` export)

**Net change:** ~4,400 lines removed (v2), ~3,770 lines restored (v1)

---

## 2026-04-11 (Session 62)

### PDF Branding Customiser Upgrade (Phases 1-5 Complete)

Complete rewrite of the PDF branding system from basic text line lists to a template-based, block-composable editor with dynamic variables, dual-colour schemes, font selection, and a unified editor UI.

**New Data Models (Phase 1):**
- `lib/models/pdf_variable.dart` — `PdfVariable` enum (13 variables with `{token}` syntax) + `PdfVariableResolver` class
- `lib/models/pdf_content_block.dart` — `ContentBlock` class replacing `HeaderTextLine` with rich styling (text/logo/divider/spacer types, per-block font size, bold/italic/uppercase, alignment, colour override)
- `lib/models/pdf_colour_scheme_v2.dart` — `PdfColourSchemeV2` with primary + optional secondary colours, 8 presets with secondary pairings
- `lib/models/pdf_font_config.dart` — `PdfFontConfig` with 4 font families (Roboto, Inter, Lato, Merriweather)
- `lib/models/pdf_layout_template.dart` — `HeaderLayoutTemplate` (6 variants) + `FooterLayoutTemplate` (4 variants)
- `lib/models/pdf_branding_config.dart` — Unified config replacing separate header/footer/colour models
- `lib/data/pdf_branding_presets.dart` — 5 starter templates (Classic, Modern, Professional, Minimal, Bold)

**Migration & Services (Phase 2):**
- `lib/services/pdf_branding_migration.dart` — V1 → V2 migration (HeaderTextLine → ContentBlock, LogoZone → HeaderLayoutTemplate)
- `lib/services/pdf_branding_config_service.dart` — Unified config service with auto-migration from v1
- `lib/services/pdf_branding_editor_adapter.dart` — Adapter pattern (`PersonalBrandingAdapter` + `CompanyBrandingAdapter`) eliminating ~1400 lines of duplication
- Updated `company_pdf_config_service.dart` with v2 branding config methods
- Updated `firestore_sync_service.dart` with `syncPdfBrandingConfig()`
- Updated `pdf_generation_data.dart` DTOs with `brandingConfigJson` + italic/boldItalic font bytes

**PDF Builder (Phase 3):**
- `lib/services/pdf_branding_builder.dart` — Unified builder replacing `PdfHeaderBuilder` + `PdfFooterBuilder`, renders all 6 header and 4 footer templates, resolves variables, applies per-block styling
- Updated `pdf_service.dart`, `invoice_pdf_service.dart`, `compliance_report_service.dart` — V2 gather phase + isolate dual-path (v2 when brandingConfig exists, v1 fallback)

**New UI (Phase 4):**
- `lib/screens/pdf_branding/template_preset_selector.dart` — Horizontal preset carousel with mini-thumbnail previews
- `lib/screens/pdf_branding/branding_live_preview.dart` — Accurate live preview using actual colours/fonts/blocks
- `lib/screens/pdf_branding/content_block_editor_card.dart` — Collapsed/expanded card for editing content blocks
- `lib/screens/pdf_branding/variable_insertion_sheet.dart` — Bottom sheet with variable chips filtered by doc type
- `lib/screens/pdf_branding/pdf_branding_editor_screen.dart` — Unified editor (header, footer, colours, fonts, logo in one screen)
- `lib/screens/pdf_branding/pdf_branding_hub_screen.dart` — Hub with Jobsheet/Invoice sections

**Navigation Updates:**
- `settings_screen.dart` — Points to `PdfBrandingHubScreen`
- `jobs_hub_screen.dart` — Points to `PdfBrandingHubScreen(docType: jobsheet)`
- `invoicing_hub_screen.dart` — Points to `PdfBrandingHubScreen(docType: invoice)`
- `company_settings_screen.dart` — Uses `CompanyBrandingAdapter` with hub screen
- `web_router.dart` — Updated `/branding` route to use hub + adapter

**Cleanup (Phase 5):**
- Deleted 5 old screens (3,771 lines): `pdf_design_screen.dart`, `pdf_header_designer_screen.dart`, `pdf_footer_designer_screen.dart`, `pdf_colour_scheme_screen.dart`, `company_pdf_design_screen.dart`
- Old v1 services kept for migration reads during transition period

**Net impact:** ~-3,771 lines deleted, ~+2,200 lines added. Zero duplication between personal and company editors.

---

## 2026-04-11 (Session 61)

### Granular Permission System & Role Change Bug Fix

**Bug Fix:**
- Fixed "Failed to save" error when admin changes a member's role — root cause was `CompanyService.updateMemberRole()` writing to another user's profile doc (`users/{memberUid}/profile/main`), blocked by Firestore security rules. Removed cross-user profile writes from `updateMemberRole()`, `removeMember()`, and `deleteCompany()`.

**New Feature: Granular Per-User Permissions**
- Created `AppPermission` enum (`lib/models/permission.dart`) with 22 granular permissions across 9 categories (Web Portal, Dispatch, Sites, Customers, Assets, Floor Plans, Asset Types, Branding, Company)
- Admin/Dispatcher/Engineer roles kept as default permission templates; admins always have all permissions as safety net
- Added `permissions` field (`Map<String, bool>`) to `CompanyMember` model, replacing `canManageAssetTypes`
- Updated `UserProfileService` to load member doc and expose `hasPermission(AppPermission)` method with SharedPreferences caching
- Added `updateMemberPermissions()` to `CompanyService`; `updateMemberRole()` now also writes default permissions for new role
- Replaced all hardcoded `isAdmin`/`isDispatcherOrAdmin` checks across 11 files with granular `hasPermission()` calls
- Built `MemberPermissionsScreen` — admin UI with grouped toggles by category, role dropdown with "apply defaults" option, self-edit safeguards
- Added "Edit Permissions" option to team management popup menu
- Updated Firestore security rules: new `hasPermission()` helper function, split coarse `write` rules into granular `create`/`update`/`delete`
- Zero-migration: `CompanyMember.fromJson()` generates defaults from role when `permissions` field missing

**Files changed:**
- `lib/models/permission.dart` — new file, `AppPermission` enum
- `lib/models/company_member.dart` — added `permissions` map, removed `canManageAssetTypes`
- `lib/models/models.dart` — added permission.dart to barrel
- `lib/services/user_profile_service.dart` — member doc loading, `hasPermission()`, permissions caching
- `lib/services/company_service.dart` — bug fixes, `updateMemberPermissions()`, permissions param on role change
- `lib/screens/company/member_permissions_screen.dart` — new admin permission editor screen
- `lib/screens/company/team_management_screen.dart` — "Edit Permissions" popup option
- `lib/screens/company/company_settings_screen.dart` — granular permission checks
- `lib/screens/company/company_sites_screen.dart` — separate create/edit/delete permissions
- `lib/screens/company/company_customers_screen.dart` �� separate create/edit/delete permissions
- `lib/screens/dispatch/dispatched_job_detail_screen.dart` — `dispatchEdit` permission
- `lib/screens/floor_plans/floor_plan_list_screen.dart` — `floorPlansDelete` permission
- `lib/screens/assets/asset_detail_screen.dart` — `assetsDelete` permission
- `lib/screens/settings/settings_screen.dart` — `teamManage` permission
- `lib/screens/web/web_router.dart` — `webPortalAccess` permission
- `lib/screens/web/web_shell.dart` — `pdfBranding` permission
- `lib/main.dart` — `dispatchViewAll` permission
- `firestore.rules` — `hasPermission()` helper, granular per-resource rules

---

## 2026-04-11 (Session 60)

### Firebase Storage Upload Fixes

**Bug Fixes:**
- **Fixed floor plan upload hanging on web** — root cause: `firebase_storage_web` platform channel bug where `putData` and `getDownloadURL` throw `PlatformException(channel-error, Unable to establish connection on channel)` and the Future never resolves, causing the spinner to hang forever. Fix: bypass the Firebase Storage Dart SDK on web and upload directly via the Firebase Storage REST API, constructing the download URL from the response metadata.
- **Fixed defect photo uploads on web** — same REST API bypass applied to `DefectService.uploadDefectPhotos()` and `ServiceHistoryService.uploadDefectPhotos()`
- **Fixed mobile defect photos "disappearing"** — storage rules only matched single-level paths (`defects/{filename}`) but uploads used nested paths (`defect_photos/{defectId}/{filename}` and `defects/{recordId}/{filename}`). Uploads silently failed (error swallowed by catch block), so defects saved with empty `photoUrls` lists. Fixed by adding correct nested path rules.
- **Added timeouts to floor plan upload** — `putData` (30s) and `getDownloadURL` (10s) now have timeouts with a dedicated `TimeoutException` handler showing a clear error message instead of hanging forever

**Infrastructure:**
- Updated `storage.rules` with correct nested paths for solo and company defect photos (both `defect_photos/` and `defects/` directories)
- Updated `codemagic.yaml` to deploy storage rules alongside hosting (`--only hosting,storage`)
- Deployed storage rules to Firebase

**Files changed:**
- `storage.rules` — added nested defect photo path rules for solo + company
- `lib/services/floor_plan_service.dart` — REST API upload for web, timeouts, progress logging
- `lib/services/defect_service.dart` — REST API upload for web
- `lib/services/service_history_service.dart` — REST API upload for web
- `lib/screens/floor_plans/upload_floor_plan_screen.dart` — timeout handling, PDF rasterization timeout, better error messages
- `codemagic.yaml` — deploy storage rules with hosting
- `lib/screens/assets/add_edit_asset_screen.dart` — added reference prefixes for 6 new asset types

---

## 2026-04-09 (Session 59)

### Floor Plan Web Compression & CORS

- **Web image compression** — new `image_compress_web.dart` using browser-native Canvas API for fast image compression on web (much faster than pure-Dart `image` package). Conditional import via `dart.library.html` with `image_compress_stub.dart` fallback.
- **Mobile image compression** — new `image_utils.dart` with `compressImageBytes()` using the `image` package, designed to run in isolates via `compute()`
- **Floor plan upload** — platform-specific compression: web uses Canvas API, mobile uses `image` package in isolate. Both compress to max 2048px JPEG @ 80% quality.
- **CORS configuration** — added `cors.json` for Firebase Storage bucket (`firethings-51e00.firebasestorage.app`) allowing all origins and methods
- **Compliance report web fix** — `_downloadBytes()` uses `getDownloadURL()` + HTTP GET on web to avoid CORS issues with `getData()`

**Files changed:**
- `lib/utils/image_compress_web.dart` — new file, browser Canvas API compression
- `lib/utils/image_compress_stub.dart` — new file, stub for non-web platforms
- `lib/utils/image_utils.dart` — new file, mobile image compression
- `lib/screens/floor_plans/upload_floor_plan_screen.dart` — platform-specific compression path
- `lib/services/compliance_report_service.dart` — web CORS workaround for `getData()`
- `cors.json` — Firebase Storage CORS configuration

---

## 2026-04-07 (Session 58)

### New Asset Types, Dispatch Badge & Compliance Report Rewrite

**New Features:**
- **6 new built-in asset types** — Fire Alarm Interface (I/O Module), Power Supply Unit, Disabled Refuge Panel (EVC Master), Disabled Refuge Outstation, Fire Telephone, Toilet Alarm System. Each with variants, common faults, and lifecycle data.
- **BS5839 floor plan symbols** — added symbols for all 6 new types (IO, PSU, EVC, RO, FT, TA) with correct shapes (square, rectangle, circle) per BS 5839-1 conventions
- **Dispatch badge count** — bottom navigation Dispatch tab now shows a badge with unassigned job count (for dispatchers/admins) or pending job count (for engineers), using real-time Firestore streams
- **Web schedule panel animation** — job detail panel on schedule screen now has animated overlay with fade transitions instead of instant show/hide

**Improvements:**
- **Compliance report service rewrite** — major refactor (~800 lines changed) for improved structure and maintainability
- **Floor plan upload** — added PDF rasterization support using `Printing.raster()` with first-page extraction and PNG conversion

**Files changed:**
- `lib/data/default_asset_types.dart` — 6 new asset type definitions
- `lib/widgets/bs5839_symbols.dart` — 6 new BS5839 symbol mappings and painters
- `lib/main.dart` — dispatch badge count stream subscription, `_maybeBadgedIcon()` helper
- `lib/services/dispatch_service.dart` — `streamUnassignedJobCount()`, `streamPendingJobCount()`
- `lib/services/compliance_report_service.dart` — major rewrite
- `lib/screens/web/web_schedule_screen.dart` — animated panel overlay
- `lib/screens/floor_plans/upload_floor_plan_screen.dart` — PDF rasterization
- `lib/screens/assets/add_edit_asset_screen.dart` — asset type screen updates for new types
- `lib/screens/assets/site_asset_register_screen.dart` — new type support
- `lib/screens/assets/asset_detail_screen.dart` — new type support
- `lib/screens/assets/asset_type_config_screen.dart` — new type support
- `lib/screens/assets/batch_test_screen.dart` — new type support

---

## 2026-04-07 (Session 57)

### Bug Fixes & Dispatch Improvements

**Bug Fixes:**
- **Fixed "Failed to leave company" error** — Firestore rules now allow members to self-delete their own member doc, so engineers/dispatchers can leave a company (previously only admins could delete member docs)
- **Fixed "View Linked Jobsheet" for dispatchers/admins** — added Firestore fallback to fetch jobsheets from `companies/{companyId}/completed_jobsheets/` when the jobsheet isn't in the local SQLite database (created on a different device)

**New Features:**
- **Create Jobsheet from completed dispatched jobs** — engineers can now create a jobsheet for jobs marked "Complete Without Jobsheet". Both engineer and dispatcher detail screens show a "Create Jobsheet" button for completed jobs without a linked jobsheet. Dispatchers see an info card ("No jobsheet linked yet") until the engineer creates one.
- **Company branding toggle for jobsheets** — added `useCompanyBranding` field to Jobsheet model with SwitchListTile toggle on the job form screen (matching the invoice pattern). Defaults to ON for dispatched jobs, OFF otherwise. Replaces the implicit `dispatchedJobId != null` check in PDF generation.

**Files changed:**
- `firestore.rules` — added self-delete rule for members
- `lib/models/jobsheet.dart` — added `useCompanyBranding` field
- `lib/services/database_helper.dart` — DB version 15 → 16, migration + CREATE TABLE
- `lib/services/pdf_service.dart` — use explicit `useCompanyBranding` field
- `lib/screens/dispatch/engineer_job_detail_screen.dart` — "Create Jobsheet" button for completed jobs, Firestore fallback for view
- `lib/screens/dispatch/dispatched_job_detail_screen.dart` — info card + "Create Jobsheet" for completed jobs, Firestore fallback for view
- `lib/screens/new_job/job_form_screen.dart` — company branding toggle

---

## 2026-04-04 (Session 56)

### Web Dispatcher Jobs Tab Upgrade

**Bug Fixes:**
- **Fixed Active/Urgent filter bug** — clicking "Active" or "Urgent/Emergency" summary cards or dropdown values now correctly filters jobs (previously showed zero results because composite filter values were never matched in `_filterJobs()`)
- **Fixed `companySiteId` not captured on web create** — site autocomplete now stores the selected site's ID, enabling asset register lookups and compliance dots for web-created jobs
- **Fixed cancel with reasons** — replaced hardcoded "Cancelled by dispatcher" with a `CancelJobDialog` offering dispatcher-appropriate reasons (Customer cancelled, Scheduling conflict, Job no longer needed, Duplicate job, Other)

**New Features:**
- **Pagination** — rows-per-page selector (25/50/100), page navigation controls, "Showing X–Y of Z" display. All filters reset to page 1
- **Date range filter** — chip presets (Today, This Week, This Month, Overdue) plus Custom date range picker, rendered below the existing filter bar
- **Column visibility toggle** — settings button to show/hide table columns. New optional columns: Job #, Type, Contact. Sort works with dynamic column layout via key-based sorting
- **Bulk actions toolbar** — Gmail-style bar when rows selected: Assign, Change Status, Change Priority, Set Date, Delete. All backed by Firestore batch writes. Select-all checkbox for current page
- **Asset register integration** — detail panel now shows compliance summary (pass/fail/untested counts, lifecycle warnings) and "View Asset Register" link when a job has a linked site with assets
- **Job duplication** — "Duplicate" button on detail panel pre-fills create form with job data (new ID, cleared status/dates/assignment, title appended "(Copy)")
- **CSV export** — "Export" button downloads currently filtered jobs as CSV with all visible columns plus site address, contact details, and creation info
- **Create job UX** — Ctrl+Enter to save, "Create another job after saving" checkbox that resets the form but keeps site & contact pre-filled for batch creation

**Files changed:**
- `lib/screens/web/web_dashboard_screen.dart` — major rewrite: key-based sorting, pagination, column visibility, bulk toolbar integration, date filter, CSV export
- `lib/screens/web/web_job_detail_panel.dart` — asset register section, duplicate button, cancel dialog
- `lib/screens/web/web_create_job_screen.dart` — companySiteId fix, duplication support, Ctrl+Enter, create-another flow
- `lib/services/dispatch_service.dart` — bulk operations (bulkUpdateStatus, bulkUpdatePriority, bulkUpdateDate, bulkDelete)
- `lib/utils/download_web.dart` / `download_stub.dart` — added optional mimeType parameter
- **New files:** `lib/screens/web/cancel_job_dialog.dart`, `lib/screens/web/dashboard/job_helpers.dart`, `lib/screens/web/dashboard/date_range_filter.dart`, `lib/screens/web/dashboard/bulk_actions_toolbar.dart`, `lib/screens/web/dashboard/csv_export.dart`

---

## 2026-03-30 (Session 55)

### Floor Plan Pin Positioning Fix (Web)

- **Root cause identified**: `webHtmlElementStrategy: WebHtmlElementStrategy.prefer` rendered the floor plan image as an HTML `<img>` DOM element in a separate rendering layer from the Flutter canvas where asset pins are painted. Inside `InteractiveViewer`, the CSS transform on the HTML element desynced from the canvas transform, causing pins to appear displaced from the image on web.
- **Fix**: On web, floor plan image bytes are now loaded via Firebase Storage SDK and rendered using `Image.memory()` on the Flutter canvas, ensuring image and pins share the same rendering layer and transform pipeline.
- **BoxFit change**: Switched from `BoxFit.contain` to `BoxFit.fill` for the floor plan image on all platforms (equivalent since SizedBox matches image dimensions, but more explicit).
- **Compliance report fix**: `pw.Image` inside `pw.SizedBox` with `pw.BoxFit.fill` was not constraining the image — it rendered at intrinsic pixel size (e.g. 2048x1536) instead of the calculated render area (~450x300). Pins positioned at `xPercent * renderW` appeared clustered in the top-left corner. Fixed by passing explicit `width`/`height` directly to `pw.Image`.
- **Files changed**: `lib/screens/floor_plans/interactive_floor_plan_screen.dart`, `lib/services/compliance_report_service.dart`

---

## 2026-03-29 (Session 54)

### Unified Site & Customer List Screens

- **Unified card layout** across all four list screens (saved sites, saved customers, company sites, company customers) — all now use `Card > ListTile` with consistent structure
- **Consistent leading indicator** — all screens now use `CircleAvatar` with `AppIcons.building` icon in `AppTheme.primaryBlue`
- **Action buttons replace menus** — removed 3-dot popup menus, cupertino action sheets, and bare icon buttons. All actions now use small labeled `OutlinedButton` widgets (View Assets, Edit, Delete) in a `Wrap`
- **Added edit to saved sites** — `_showSiteDialog` now supports edit mode, new `DatabaseHelper.updateSavedSite()` method added
- **Added animations to company screens** — company sites and customers now use `animateListItem` stagger animations matching the personal screens
- **Standardised loading/empty states** — company screens now use `LoadingIndicator` and `EmptyState` widgets (matching personal screens) instead of inline `AdaptiveLoadingIndicator` and manual Column-based empty states
- **Pull-to-refresh on personal screens** — already had `AdaptiveRefreshIndicator`, confirmed working
- **Permission gating preserved** — company screens still gate Edit/Delete buttons behind `_canEdit` (dispatcher/admin only)

---

## 2026-03-29 (Session 53)

### Testing UX Rework, Defect Tracking & Floor Plan Fix

- **New `Defect` model** (`lib/models/defect.dart`) — standalone entity with full lifecycle (open/rectified), severity, description, common fault ID, photos, rectification metadata. Firestore path: `{basePath}/sites/{siteId}/defects/`
- **New `DefectService`** (`lib/services/defect_service.dart`) — singleton with CRUD, streams, batch rectification (`rectifyAllForAsset`), photo upload, rectified-count-since queries, and last-report-date tracking
- **`commonFaults` field on `AssetType`** — new `List<String>` field with pre-populated common faults for all 12 built-in asset types (e.g. smoke detector: "Head dirty/contaminated", "Base fault", "Drift compensation exceeded", etc.)
- **Batch test screen rewrite** (`lib/screens/assets/batch_test_screen.dart`) — replaced full-checklist wizard with single-tap Pass/Fail per asset:
  - **Pass**: creates service record, updates asset compliance, auto-rectifies all open defects
  - **Fail**: opens defect bottom sheet with severity picker (minor/major/critical), common faults dropdown, description field, photo capture
  - **Defect badge**: red "X open" badge on asset cards with existing open defects
  - Summary screen now shows defect count
- **Asset detail defect rectification** (`lib/screens/assets/asset_detail_screen.dart`) — new "Active Defects" section with StreamBuilder, severity badges, "Mark Rectified" button with optional note dialog
- **Compliance report fix** (`lib/services/compliance_report_service.dart`) — Section 5 now queries the Defect collection, shows only open defects, adds "X defects rectified since [date]" line, stores last report date for tracking. Legacy fallback for sites without defect entities.
- **`ComplianceReportPdfData`** — added `defectsJson`, `rectifiedCount`, `lastReportDateStr` fields
- **Deleted `InspectionChecklistScreen`** — full per-item checklist removed, replaced by simpler pass/fail + defect workflow everywhere
- **Shared `DefectBottomSheet` widget** (`lib/widgets/defect_bottom_sheet.dart`) — extracted from batch test, reused by asset detail, batch test, and floor plan screens
- **Asset detail inline Pass/Fail** — replaced "Test This Asset" button with side-by-side Pass/Fail buttons. Pass auto-rectifies open defects.
- **Batch test scrollable list** — replaced one-at-a-time wizard with scrollable card list. Filter chips by asset type and zone. Tested assets move to collapsible "Completed" section with result badges.
- **Floor plan testing** — tapping an asset pin now shows full details (type, variant, zone, status, defect count, last service) with Pass/Fail buttons and "View Details" link. Replaces the placeholder "coming soon" toast.
- **Floor plan pin position fix** — removed erroneous AppBar Y-offset double-subtraction in `_onFloorPlanTap`. Pins placed on mobile were stored with incorrect Y coordinates, appearing in wrong positions on web and in compliance report PDFs. New placements will be accurate; existing pins can be dragged to correct.

---

## 2026-03-28 (Session 52)

### Fixes

- **Mobile floor plan drag restored** — Long-press-to-drag pins on mobile was broken after the web drag refactor. The `GestureDetector` with `onPanStart/onPanUpdate/onPanEnd` only existed in placement mode, leaving non-placement-mode pins with `onLongPress` that set state but had no drag handler. Fixed by replacing with `onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd` on the parent `GestureDetector`, which properly handles the entire long-press-then-drag gesture sequence. Works in both placement and normal mode on mobile.
- **Compliance report floor plan pin alignment** — Pins on generated compliance report PDFs clustered in the wrong position instead of matching user-placed locations. Root cause: `pw.Positioned.fill` + `pw.BoxFit.contain` on the floor plan image created ambiguity about where the image actually renders within the container. Fixed by explicitly positioning the image at the calculated render area (`pw.Positioned` with `left`/`top`/`width`/`height`) using `BoxFit.fill`, and adding explicit `width` to the container. Pins now align with the image coordinates exactly.
- **Compliance report floor plan file extension** — Report image download was hardcoded to `.jpg`, failing for PDF-converted floor plans (stored as `.png`). Now uses `plan.fileExtension`.
- **AssetPin gesture passthrough** — `AssetPin` widget's internal `GestureDetector` with `HitTestBehavior.opaque` was consuming gestures even when no callbacks were set, blocking parent gesture handlers. Now conditionally wraps only when `onTap` or `onLongPress` is provided.

### FEATURES.md — Complete Rewrite

- **Full rewrite** of `FEATURES.md` to cover every feature in the app (was severely outdated, missing dispatch, asset register, and web portal)
- Document now covers: navigation, home screen, 6 tools, jobsheets, invoicing, PDF certificates, custom templates, saved data, PDF design, dispatch system (full detail), asset register (12 types, floor plans, inspection, barcode, lifecycle, compliance report, type config), web portal, settings, backend infrastructure (61 analytics events, 18 remote config flags, Firestore structure, Cloud Functions, Storage structure)
- Includes "Future Enhancements" section for tester-requested features
- Designed to be self-contained for handoff to another Claude chat to re-evaluate launch plan

### Floor Plan Improvements (Web)

- **PDF upload support**: Upload screen now accepts PDF files, rasterises first page to PNG via `Printing.raster()` for pin placement
- **Cross-platform image loading**: Replaced `dart:ui` codec with `image` package for dimension extraction (works on web)
- **Web image display**: `CachedNetworkImage` replaced with `Image.network` + `webHtmlElementStrategy: WebHtmlElementStrategy.prefer` on web to bypass CORS — mobile keeps `CachedNetworkImage` for offline caching
- **Web pin dragging**: Replaced `Draggable` widget with `GestureDetector` pan tracking in placement mode — disables `InteractiveViewer` panning during drag, divides delta by zoom scale for correct movement at any zoom level
- **Pin size slider**: Changed from 8 divisions (25% increments) to 20 divisions (10% increments)
- **Pin labels**: Added reference text labels above floor plan pins via `OverflowBox` in `AssetPin` widget — white pill with grey border, scales with pin size slider, toggle icon in app bar, persists per floor plan via `showLabels` field on `FloorPlan` model
- **GoRouter safety**: Fixed 3 unsafe `state.extra as Map` casts in `web_router.dart` with safe type checks

### Asset Register Discoverability

- **Home screen**: Replaced 4-stat row (completed jobs, drafts, invoices) with full-width "Sites & Assets" card showing site count, navigates to SavedSitesScreen
- **Site asset register**: Replaced 4 cryptic app bar icon buttons + popup menu with horizontally scrollable labeled action cards strip (Floor Plans, Batch Test, Scan Barcode, Report, Manage Types)

### Web Layout — Max-Width Constraints

- **4 screens constrained**: Team, Shared Sites, Shared Customers, Company Logo screens wrapped in `Center` + `ConstrainedBox(maxWidth: 750)` to match PDF editor screens on wide displays
- **Pattern**: Same approach used in `pdf_colour_scheme_screen.dart` and `company_pdf_design_screen.dart`

### Floor Plan Model

- Added `fileExtension` field (default `'jpg'`) and `showLabels` field (default `true`) to `FloorPlan` model — constructor, toJson, fromJson, copyWith

### Asset Reference Auto-Fill Fix

- **add_edit_asset_screen**: Reference field now updates when asset type dropdown changes (was stuck on first auto-fill). Uses `_refWasAutoFilled` flag + controller listener pattern to distinguish auto-fill from manual edits.

### Firebase Hosting

- Built and deployed Flutter web app to Firebase Hosting

### Compliance Report — Pin Labels

- Floor plan section now renders reference labels above pin dots when `plan.showLabels` is true

---

## 2026-03-28 (Session 51)

### Asset Register — Phase 9: Web Portal Integration

- **CompanyService**: Added `getSite()` one-shot lookup method for route builders
- **Web routes**: Added 9 new GoRouter routes under `/sites/:siteId/assets/*` and `/sites/:siteId/floor-plans/*` in `web_router.dart`
- **Page refresh resilience**: Created `_SiteDataLoader` and `_FloorPlanLoader` helper widgets that check `state.extra` cache then fall back to Firestore lookup
- **Feature flag gating**: Asset routes redirect to `/sites` when `assetRegisterEnabled` is false
- **kIsWeb guards**: Hidden barcode scanner and batch test buttons on web (site_asset_register_screen), hidden "Scan Barcode" menu item on web (asset_detail_screen), hidden "Take Photo" option on web (upload_floor_plan_screen)
- **Web navigation**: CompanySitesScreen uses `context.go('/sites/{id}/assets')` on web instead of `Navigator.push`
- **URL-aware inner navigation**: All sub-navigations in site_asset_register_screen, asset_detail_screen, and floor_plan_list_screen use `context.go()` on web for proper URL bar updates and deep-linking
- **Analytics**: Added `logWebAssetRegisterViewed()` and `logWebFloorPlanViewed()` events

### Asset Register — Phase 8A: Compliance Report PDF

- **Remote Config flag**: Added `compliance_report_enabled` (default `false`) to `lib/services/remote_config_service.dart`
- **Analytics events**: Added `logComplianceReportGenerated`, `logAssetTypeCreated`, `logAssetTypeChecklistModified` to `lib/services/analytics_service.dart`
- **DTO**: Added `ComplianceReportPdfData` class to `lib/services/pdf_generation_data.dart` with all isolate-safe fields for report generation
- **Service**: Created `lib/services/compliance_report_service.dart` — singleton with gather→compute pattern, generates 7-section PDF (cover, compliance summary, floor plans, asset register table, defect summary, lifecycle alerts, service history)
- **Screen**: Created `lib/screens/assets/compliance_report_screen.dart` — pre-generate view showing site info + report contents list, generate button with loading state, post-generate view with share/print/regenerate
- **Navigation**: Added `siteAddress` parameter to `SiteAssetRegisterScreen`, wired through all 4 callers (saved_sites, company_sites, dispatched_job_detail, engineer_job_detail)
- **App bar**: Replaced standalone compliance report icon with `PopupMenuButton` in site asset register screen (report + manage types)

### Asset Register — Phase 8B: Asset Type Config

- **Model**: Added `canManageAssetTypes` (bool, default false) to `CompanyMember` — field, constructor, toJson, fromJson, copyWith
- **Screen**: Created `lib/screens/assets/asset_type_config_screen.dart` — list view of all types (built-in + custom) with icon/colour/variant/checklist counts, "Default" badge for built-in types
- **Edit screen**: Inline `_AssetTypeEditScreen` with name/category/lifespan fields, icon picker, colour picker, variant management, reorderable checklist editor with add/remove
- **Permissions**: `canEdit` parameter gates all editing UI; built-in types show read-only core fields but allow checklist modification
- **Navigation**: Added "Manage Asset Types" option to site asset register PopupMenuButton, reloads types on return

### Fixes

- Removed unused `_decommissionedGrey` constant and `pdf_header_builder.dart` import from compliance report service
- Removed unused `headerConfig` local variable in compliance report isolate function
- Fixed non-nullable `siteAddress` on `DispatchedJob` — removed unnecessary `?? ''` in dispatch detail screens

---

## 2026-03-22 (Session 50)

### Web Portal — Dispatcher Jobsheet Access (View, Download PDF, Email)

- **Jobsheet copy to company**: Added `copyJobsheetToCompany()` to `lib/services/firestore_sync_service.dart` — copies completed jobsheet JSON to `companies/{companyId}/completed_jobsheets/{id}` in Firestore
- **Signature screen integration**: Modified `lib/screens/signature/signature_screen.dart` to call `copyJobsheetToCompany()` after linking a completed jobsheet to a dispatched job
- **Firestore security rules**: Added `completed_jobsheets` subcollection rule in `firestore.rules` — read+write for company members
- **PDF generation web fix**: Added `kIsWeb` guard in `lib/services/pdf_service.dart` to skip `compute()` (isolates) on web and call `_buildJobsheetPdf()` directly
- **Web file download**: Created `lib/utils/download_stub.dart` (no-op) and `lib/utils/download_web.dart` (browser download via `dart:html` Blob + AnchorElement)
- **Jobsheet viewer**: Implemented `_buildLinkedJobsheetSection()` and `_buildJobsheetCard()` in `lib/screens/web/web_job_detail_panel.dart` — fetches jobsheet from Firestore, renders read-only view with form data (using field labels), notes, defects (red bullets), and engineer/customer signature images (base64 decoded)
- **Download PDF button**: Generates PDF via `PDFService.generateJobsheetPDF()` and triggers browser download with filename `Jobsheet_{jobNumber}_{date}.pdf`
- **Email to Client button**: Shows dialog with pre-filled recipient email (from dispatched job's `contactEmail`), opens `mailto:` link with pre-filled subject/body, includes "Download PDF" button in dialog for convenience
- **Icon**: Added `AppIcons.download` (`document_download`) to `lib/utils/icon_map.dart`

### Web Portal — Colour Scheme Layout + Company Logo

- **Colour scheme layout fix**: Wrapped colour editor body in `Center` > `ConstrainedBox(maxWidth: 600)` in both `pdf_colour_scheme_screen.dart` and `company_pdf_design_screen.dart` — prevents preview and grid from stretching across full web viewport
- **Responsive grid**: Changed preset colour grid from hardcoded `crossAxisCount: 4` to `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 80)` — fits all 8 presets in fewer rows on wider screens, 4 columns on mobile
- **Company logo in sidebar**: `web_shell.dart` now fetches company logo via `CompanyPdfConfigService.getCompanyLogoBytes()` and displays it in the sidebar leading widget. Falls back to fire icon if no logo uploaded. Also shows company name instead of "FireThings" when extended.
- **Login screen logo**: Replaced hardcoded fire icon with `firethings_logo_vertical.png` asset on `web_login_screen.dart`

### Cleanup & Fixes

- **Firestore rules deployed**: `firebase deploy --only firestore:rules` — `completed_jobsheets` collection now accessible in production
- **VSCode analysis**: Fixed all 9 analysis issues — removed unused imports (`company_member.dart`, `user_profile_service.dart`, `go_router.dart`, `adaptive_widgets.dart`), replaced deprecated `value:` with `initialValue:` on 3 `DropdownButtonFormField` widgets, fixed `BuildContext` async gap check, marked `_selectedJobIds` as `final`, suppressed `dart:html` deprecation warnings, fixed double underscore in separator builder

**Build verified**: Both web (`flutter build web`) and Android (`flutter build appbundle --debug`) succeed. `flutter analyze` — 0 issues.

---

## 2026-03-22 (Session 49)

### Web Portal — Phases 1-2 (Foundation + Dashboard)

**Phase 1: Web Build Foundation**
- Created `lib/utils/platform_io.dart` and `lib/utils/platform_web.dart` for conditional `dart:io` imports (web doesn't support `dart:io`)
- Modified `lib/utils/adaptive_widgets.dart` to use conditional import pattern
- Added `kIsWeb` guards in `lib/main.dart`: gated SQLite sync, WorkManager, FCM, local notifications, Crashlytics for web
- Split `JobsheetApp` into web (`MaterialApp.router` with GoRouter) and mobile (`MaterialApp` with `AuthWrapper`) paths
- Added `kIsWeb` guard in `lib/services/database_helper.dart` (SQLite unavailable on web)
- Added `go_router: ^14.0.0` dependency to `pubspec.yaml`
- Created `lib/screens/web/web_router.dart` — GoRouter config with auth redirect guards, ShellRoute for WebShell
- Created `lib/screens/web/web_shell.dart` — sidebar NavigationRail + top bar, responsive (extended/icons-only/drawer/mobile-redirect)
- Created `lib/screens/web/web_login_screen.dart` — centred card login, no registration
- Created `lib/screens/web/web_access_denied_screen.dart` — error screen for engineers/no company

**Phase 2: Dashboard & Job Management**
- Created `lib/screens/web/web_dashboard_screen.dart` — summary cards, filter bar, sortable DataTable, checkbox bulk selection
- Created `lib/screens/web/web_job_detail_panel.dart` — animated slide-in side panel (42% width), status timeline, action buttons
- Created `lib/screens/web/web_create_job_screen.dart` — two-column desktop form with site/customer autocomplete
- Created `lib/screens/web/web_settings_screen.dart` — profile, company info, sign out
- Created `lib/screens/web/web_schedule_screen.dart` — placeholder for Phase 3

**Build verified**: `flutter build web` succeeds. Mobile path unchanged (Android build has pre-existing sqlite3 native asset hash mismatch unrelated to these changes).

### Web Portal — Bug Fixes & Theme Toggle

- **Login fix**: Added `GoRouterRefreshStream` to `web_router.dart` so GoRouter re-evaluates redirect on auth state changes (fixes infinite spinner after login). Made redirect async to load user profile before role/company checks.
- **Filter bar overflow fix**: Changed fixed-width `SizedBox` dropdowns to `Flexible` + `ConstrainedBox(maxWidth)` in `web_dashboard_screen.dart` so they shrink gracefully on narrow windows.
- **Reassign gating**: Edit, Reassign, and Cancel buttons in `web_job_detail_panel.dart` now hidden for completed/declined jobs.
- **Theme toggle**: Added light/dark/system theme cycling to web sidebar. Global `ValueNotifier<ThemeMode>` in `main.dart`, persisted via SharedPreferences. Converted `JobsheetApp` from StatelessWidget to StatefulWidget. Also works for mobile (themeNotifier shared).
- **Icons**: Added `AppIcons.sun` and `AppIcons.moon` to `icon_map.dart` (from `IconsaxPlusLinear`).

### Web Portal — Phase 3 (Schedule View & Polish)

- **Schedule screen**: Full rewrite of `web_schedule_screen.dart` — weekly calendar grid with 7-day columns (Mon–Sun), job blocks colour-coded by engineer or status (toggle), today highlight, prev/next/today week navigation, unscheduled jobs section (horizontal scroll), click-to-open detail panel
- **Dropdown overflow fix**: Added `isExpanded: true` to both `DropdownButtonFormField` widgets in `web_dashboard_screen.dart` filter bar (fixes internal Row overflow)
- **Reassign for declined jobs**: Changed Reassign button guard to only hide for completed (not declined) in `web_job_detail_panel.dart` — dispatchers can reassign declined jobs
- **Keyboard shortcuts**: Added `CallbackShortcuts` to dashboard — `N` opens create job, `/` focuses search, `Esc` closes detail panel
- **Print button**: Added browser print button to job detail panel using conditional import (`print_stub.dart` / `print_web.dart`)
- **Dependencies**: Added `table_calendar: ^3.1.0` to pubspec.yaml

### Web Portal — Phase 4 (Web Push Notifications)

- **Service worker**: Created `web/firebase-messaging-sw.js` with Firebase config, background message handler, notification click handler (focuses tab + navigates to job)
- **Service worker registration**: Added `<script>` to `web/index.html` to register the service worker
- **WebNotificationService**: Created `lib/services/web_notification_service.dart` — singleton, requests browser permission, stores web push token via `UserProfileService.updateFcmToken()`, listens for foreground messages, supports `onForegroundMessage` callback
- **Auth integration**: Initialised `WebNotificationService` in GoRouter redirect after login and page refresh (in `web_router.dart`)
- **Notification bell**: Created `lib/screens/web/web_notification_feed.dart` — bell icon with unread count badge, dropdown overlay showing recently updated jobs (last 24h from Firestore), relative timestamps, click-to-navigate
- **Bell in top bar**: Added `WebNotificationFeed` widget to `web_shell.dart` top bar (between Spacer and company name)
- **Permission denied banner**: Added dismissible orange banner to `web_dashboard_screen.dart` when notification permission not granted

### Web Portal — Phase 4 Continued (Notification Polish)

- **VAPID key**: Configured actual VAPID key in `web_notification_service.dart`
- **Permission flow fix**: Split `initialize()` into two methods — `initialize()` (setup only, no prompt) and `requestPermission()` (must be called from user gesture). Browser requires user interaction to request notification permission; calling from GoRouter redirect was silently denied.
- **Permission denied state**: Added `_permissionDenied` flag to track permanent browser denial. Dashboard banner shows "Enable" button when not yet prompted, or "blocked" message when permanently denied (must change in browser settings).
- **Foreground toast notifications**: Created `lib/screens/web/web_notification_toast.dart` — slide-in card notifications from right side when FCM messages arrive while app is in focus. Auto-dismiss after 5s, max 3 stacked, orange accent bar, "View" button to navigate to job. Wired via `onForegroundMessage` callback in `web_shell.dart`.
- **Notification feed polish**: Enlarged dropdown (width 360→420, maxHeight 400→500). Added "Clear" button with `_clearedAt` timestamp filtering to hide old notifications.

### Web Portal — Phase 5 (Firebase Hosting)

- **Firebase Hosting config**: Added `hosting` section to `firebase.json` — `public: "build/web"`, SPA rewrite (`**` → `/index.html` for GoRouter), ignore patterns for Firebase files

### Web Portal — Phase 6 (Analytics Events)

- **10 web analytics methods**: Added `logWebLogin`, `logWebDashboardViewed`, `logWebJobCreated`, `logWebJobEdited`, `logWebJobAssigned`, `logWebScheduleViewed`, `logWebJobDetailViewed`, `logWebBulkAssign`, `logWebSearchUsed`, `logWebPrintUsed` to `lib/services/analytics_service.dart`
- **Events wired**: `web_router.dart` (login), `web_dashboard_screen.dart` (dashboard viewed, search, job detail viewed), `web_create_job_screen.dart` (job created/edited), `web_schedule_screen.dart` (schedule viewed), `web_job_detail_panel.dart` (reassign, print)

### Web Portal — Dashboard & UI Polish

- **Dismissible detail panel**: Added `GestureDetector` overlay behind job detail panel in `web_dashboard_screen.dart` — clicking outside closes the panel
- **Create job button**: Moved save button from header to bottom of form as full-width prominent button ("Create Job"/"Update Job") in both `web_create_job_screen.dart` and mobile `create_job_screen.dart`
- **Priority toggle fix**: Added `FittedBox(fit: BoxFit.scaleDown)` to all three `SegmentedButton` labels in mobile `create_job_screen.dart` — prevents "Emergency" text wrapping

### Other Changes

- **Codemagic YAML fix**: Changed iOS publishing from `auth: integration` to API key env vars (`$APP_STORE_CONNECT_PRIVATE_KEY`, `$APP_STORE_CONNECT_KEY_ID`, `$APP_STORE_CONNECT_ISSUER_ID`) in `codemagic.yaml` — `auth: integration` requires Teams account
- **Codemagic web workflow**: Added `web-portal` workflow to `codemagic.yaml` (Linux instance, build web + deploy to Firebase Hosting)
- **Dispatch tester**: Added `test@test.com` to `dispatchTesters` list in `lib/services/remote_config_service.dart`

---

## 2026-03-21 (Session 48)

### DIP Switch Calculator — Light Mode Toggle Visibility Fix

- Changed `primaryColor` in all 5 widget builders from conditional `isDark ? darkPrimaryBlue : primaryBlue` to always use `AppTheme.darkPrimaryBlue` (`#3D7AC7`)
- Fixes low contrast of selected/ON toggle states in light mode — brighter blue now clearly visible against white backgrounds
- Affects: toggle containers, switch thumbs/tracks, text/badge colours, rotary switches, result panel, favourites list

---

## 2026-03-21 (Session 47)

### Company PDF Branding — Previews, Colour Picker, Company Logo

**Company logo storage via Firestore Blobs:**
- Added `saveCompanyLogo`, `getCompanyLogoBytes`, `removeCompanyLogo` to `CompanyPdfConfigService` — stores logo bytes at `companies/{companyId}/pdf_config/logo` with in-memory cache
- Added `getEffectiveLogoBytes(useCompanyBranding)` — resolves company logo first, falls back to personal `BrandingService` logo
- Updated `PDFService.generateJobsheetPDF` and `InvoicePDFService.generateInvoicePDF` to use `getEffectiveLogoBytes()` instead of `BrandingService.getLogoBytes()` directly

**Company header editor rebuilt with live preview + logo tab:**
- Added live header preview (white container with navy border, left/centre zones, scaled text + logo)
- Added Logo tab with image picker (camera/gallery), upload/remove buttons, logo placement (`SegmentedButton<LogoZone>`), logo size (`SegmentedButton<LogoSize>`)
- Added Left Zone and Centre tabs with reorderable text lines, font size sliders, bold toggles, add/delete line support
- All text changes update the preview live via `onChanged` → `setState`

**Company footer editor rebuilt with live preview:**
- Added live footer preview (white container with top grey border, left/centre text zones, "Page 1 of 1")
- Added Left Zone and Centre tabs matching the header editor pattern (reorderable lines, font size, bold)

**Company colour scheme editor fully rebuilt:**
- Replaced hardcoded 10-colour `Wrap` with `_buildPresetGrid()` using `PdfColourScheme.presets` (8 named presets in 4-column grid with labels)
- Added "Custom Colour" button → `flutter_colorpicker` dialog via `showPremiumDialog`
- Added rich preview: jobsheet preview (section headers, field rows, certification box, signature boxes) or invoice preview (table with header row, totals, payment details) — all tinted with selected colour
- All editors now use `AnimatedSaveButton` for consistent save UX

---

## 2026-03-21 (Session 46)

### Dispatch — Accept Button + Keyboard Done Bar

**Accept/Decline buttons for assignee-admins:**
- Added assignee action buttons to `DispatchedJobDetailScreen` — when the current user is the job's assignee, they now see the full status progression (Accept → En Route → On Site → Complete) in a "Your Assignment" section above the existing dispatcher Edit/Reassign controls
- Admins who assign jobs to themselves can now accept and progress through the full job lifecycle without needing `EngineerJobDetailScreen`

**Keyboard Done bar added to 8 dispatch/company screens:**
- `CreateJobScreen`, `DeclineJobDialog`, `CreateCompanyScreen`, `JoinCompanyScreen`, `CompanySettingsScreen` (main + edit dialog), `CompanyPdfDesignScreen` (main + header/footer editors), `CompanySitesScreen` (add/edit dialog), `CompanyCustomersScreen` (add/edit dialog)
- All now show the iOS "Done" bar with up/down field navigation arrows when a text field is focused

---

## 2026-03-21 (Session 45)

### Cloud Functions — Node.js 22 Upgrade

- Upgraded Cloud Functions runtime from Node.js 20 to Node.js 22 (Node 20 EOL April 2026)
- Updated `functions/package.json` engines field from `"20"` to `"22"`
- Redeployed both `onJobAssigned` and `onJobStatusChanged` functions successfully

---

## 2026-03-21 (Session 44)

### Dispatch Feature — Deployment Complete (All 8 Steps Done)

All dispatch deployment steps are now complete. The feature is fully built and deployed behind the `dispatch_enabled` Remote Config flag.

**Steps completed this session (5 & 8):**
- **APNs Key Setup (Step 5)** — .p8 key created in Apple Developer (Sandbox & Production), uploaded to both Dev and Prod slots in Firebase Console Cloud Messaging
- **App Store Connect Privacy (Step 8)** — Device ID added under Identifiers, Phone Number added under Contact Info, both marked as App Functionality / Linked to user / No tracking. Published.

**Summary of all 8 deployment steps (Sessions 42-44):**
1. Firebase Blaze plan upgrade
2. Cloud Functions deployed (`onJobAssigned`, `onJobStatusChanged`)
3. Firestore security rules deployed
4. Firestore composite indexes created (`firestore.indexes.json`)
5. APNs authentication key uploaded to Firebase
6. Xcode push notification capabilities configured
7. Privacy policy updated with dispatch disclosures
8. App Store Connect privacy declaration updated

**Remaining to go live:**
- Deploy indexes: `firebase deploy --only firestore:indexes`
- Enable `dispatch_enabled` Remote Config flag for test accounts
- End-to-end multi-user testing

---

## 2026-03-21 (Session 43)

### Dispatch Feature — Deployment (Steps 4, 6)

**Firestore Composite Indexes (Step 4)**
- Created `firestore.indexes.json` with 3 composite indexes for `dispatched_jobs` collection:
  - `companyId + assignedTo + status` (engineer job filtering)
  - `companyId + status + scheduledDate` (dispatch dashboard)
  - `companyId + createdAt DESC` (job list ordering)
- Updated `firebase.json` to reference `firestore.indexes.json`
- Deploy with: `firebase deploy --only firestore:indexes`

**iOS Push Notification Capabilities (Step 6)**
- Created `ios/Runner/Runner.entitlements` with `aps-environment` key (development)
- Added `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` to all 3 Runner build configs (Debug/Release/Profile) in `project.pbxproj`
- Added `UIBackgroundModes` → `remote-notification` to `ios/Runner/Info.plist`

---

## 2026-03-21 (Session 42)

### Dispatch Feature — Deployment (Steps 2-3, 7)

**Firebase Configuration**
- `firebase.json` — added `"functions": { "source": "functions" }` section for Cloud Functions deployment
- `.firebaserc` — created, linking project to `firethings-51e00`
- `functions/package.json` — updated Node.js runtime from 18 (decommissioned) to 20

**Cloud Functions Deployed**
- `onJobAssigned` (us-central1) — sends FCM push notification to engineer when assigned to a dispatched job
- `onJobStatusChanged` (us-central1) — sends FCM push notification to dispatcher when job status changes
- Container image cleanup policy configured (1 day retention)

**Firestore Security Rules Deployed**
- Full company/dispatch security rules now live: member access, dispatcher/admin writes, engineer status field updates, shared sites/customers, PDF config

**Privacy Policy Updated**
- `privacy_policy.md` — added dispatch-related disclosures: push notification tokens, company data sharing between members, dispatched job data (site addresses, contacts), FCM as third-party service
- Updated "Who Can Access Your Data" section to explain company-scoped data sharing
- Updated date to 21 March 2026

---

## 2026-03-15 (Session 41)

### Dispatch Feature — Phase 6: Team Management & Polish

**New Models**
- `lib/models/company_site.dart` — `CompanySite` model (id, name, address, notes, createdBy, timestamps) with toJson/fromJson/copyWith
- `lib/models/company_customer.dart` — `CompanyCustomer` model (id, name, address, email, phone, notes, createdBy, timestamps) with toJson/fromJson/copyWith
- Added barrel exports in `lib/models/models.dart`

**CompanyService — Shared Sites & Customers CRUD**
- `createSite`, `updateSite`, `deleteSite`, `getSitesStream` — Firestore CRUD under `companies/{companyId}/sites/`
- `createCustomer`, `updateCustomer`, `deleteCustomer`, `getCustomersStream` — Firestore CRUD under `companies/{companyId}/customers/`
- Analytics wiring: `logCompanyCreated` on company creation, `logCompanyJoined` on company join

**New Screens**
- `lib/screens/company/company_sites_screen.dart` — StreamBuilder list of shared sites with add/edit/delete (dispatcher/admin only), empty state, real-time updates
- `lib/screens/company/company_customers_screen.dart` — StreamBuilder list of shared customers with add/edit/delete (dispatcher/admin only), empty state, real-time updates
- Both screens wired into Company Settings as "Shared Data" section (visible to dispatcher/admin roles)

**Create Job Screen — Site/Customer Autocomplete**
- Site name field: `Autocomplete<CompanySite>` — auto-fills address and notes on selection
- Contact name field: `Autocomplete<CompanyCustomer>` — auto-fills phone and email on selection
- Data loaded via real-time streams from company sites/customers collections
- Free typing still allowed if no match

**Analytics Events (11 new dispatch events)**
- `company_created`, `company_joined`, `dispatch_job_created`, `dispatch_job_assigned`, `dispatch_job_accepted`, `dispatch_job_declined`, `dispatch_job_status_changed`, `dispatch_job_completed`, `dispatch_jobsheet_created`, `dispatch_directions_opened`, `dispatch_contact_called`
- Wired into: CompanyService (create/join), CreateJobScreen (job create/assign), EngineerJobDetailScreen (accept/decline/status/directions/call), DispatchedJobDetailScreen (reassign), SignatureScreen (jobsheet from dispatch)

**Spec Update**
- `DISPATCH_FEATURE_SPEC.md` — Phase 6 marked complete (items 1-5), items 6-9 noted as excluded

---

## 2026-03-15 (Session 40)

### Dispatch Feature — Phase 5: Push Notifications (FCM)

**Dependencies & Cloud Functions**
- Added `firebase_messaging: ^16.1.1` to pubspec.yaml
- Created `functions/` directory with Cloud Functions (Node.js 18, firebase-functions v2):
  - `onJobAssigned` — Firestore `onWrite` trigger sends push notification to newly assigned engineer with job title and site name
  - `onJobStatusChanged` — Firestore `onUpdate` trigger sends push notification to dispatcher (job creator) when engineer updates job status
- `functions/package.json` with firebase-admin v12 + firebase-functions v5
- `functions/.gitignore` to exclude node_modules

**Client-side FCM Integration (lib/main.dart)**
- Added global `navigatorKey` for notification-driven navigation from outside widget tree
- Added top-level `_firebaseMessagingBackgroundHandler` for background FCM messages
- FCM permission requested on startup (iOS + Android 13+)
- `AuthWrapper` converted from `StatelessWidget` to `StatefulWidget` — manages FCM lifecycle:
  - Gets and stores FCM token via `UserProfileService.updateFcmToken()` on login
  - Listens for token refresh and updates automatically
  - Foreground messages re-fired as local notifications via `NotificationService.showDispatchNotification()`
  - Background tap handling via `FirebaseMessaging.onMessageOpenedApp`
  - Terminated tap handling via `getInitialMessage()` on startup
  - All FCM setup gated behind `RemoteConfigService.dispatchNotificationsEnabled`
  - Subscriptions cancelled on sign-out and widget disposal

**Notification Tap Routing**
- Dispatch notification payload format: `type|jobId|companyId`
- `MainNavigationScreen._handleNotificationTap` extended to parse dispatch payloads and navigate to `DispatchedJobDetailScreen` (dispatchers/admins) or `EngineerJobDetailScreen` (engineers)
- Same routing logic in `AuthWrapper._navigateToJobFromMessage` for FCM taps

**NotificationService Updates (lib/services/notification_service.dart)**
- New `firethings_dispatch` Android notification channel (high importance) for dispatch notifications
- New `showDispatchNotification()` method for foreground FCM re-fire
- Dedicated notification ID (`_dispatchNotificationId = 10`) for dispatch notifications

**Deployment notes:**
- Cloud Functions require Firebase Blaze plan to deploy: `cd functions && npm install && firebase deploy --only functions`
- APNs key must be uploaded to Firebase Console for iOS push notifications
- All client-side code works regardless of whether Cloud Functions are deployed

---

## 2026-03-15 (Session 39)

### Dispatch Feature — Phase 4: Jobsheet Integration & Company PDF Branding

**Workstream A: Jobsheet Integration**
- SQLite schema v13: added `dispatchedJobId` column to jobsheets table, `useCompanyBranding` column to invoices table
- `Jobsheet` model: added `dispatchedJobId` field (toJson/fromJson/copyWith)
- `Invoice` model: added `useCompanyBranding` field (toJson/fromJson/copyWith)
- `NewJobScreen`: added optional `dispatchedJob` parameter, passed through to `JobFormScreen`
- `JobFormScreen`: added `dispatchedJob` parameter + `_prefillFromDispatchedJob()` — auto-fills customer name, site address, job number, system category, and date from dispatched job data
- `SignatureScreen`: added `dispatchedJob` parameter — on jobsheet completion, auto-updates dispatched job status to `completed` with `linkedJobsheetId`
- `EngineerJobDetailScreen`: "On Site" status now shows "Create Jobsheet" (navigates to `NewJobScreen`) + "Complete Without Jobsheet" buttons; "Completed" status shows "View Linked Jobsheet" button when `linkedJobsheetId` exists
- `DispatchedJobDetailScreen`: added "View Linked Jobsheet" button for completed jobs with `linkedJobsheetId`

**Workstream B: Company PDF Branding**
- New `CompanyPdfConfigService` (`lib/services/company_pdf_config_service.dart`) — singleton, reads/writes header, footer, colour scheme from `companies/{companyId}/pdf_config/` Firestore subcollection, in-memory caching, `getEffectiveHeaderConfig`/`getEffectiveFooterConfig`/`getEffectiveColourScheme` methods with company→personal fallback logic
- `PdfService.generateJobsheetPDF()` now uses effective config — company branding auto-applied when jobsheet has `dispatchedJobId`
- `InvoicePdfService.generateInvoicePDF()` now uses effective config — company branding applied when `invoice.useCompanyBranding` is true
- New `CompanyPdfDesignScreen` (`lib/screens/company/company_pdf_design_screen.dart`) — accessible from Company Settings (admin only), inline editors for header, footer, and colour scheme for both jobsheet and invoice document types
- `CompanySettingsScreen`: added "PDF Branding" section tile (admin only)
- `InvoiceScreen`: added "Use Company Branding" `SwitchListTile` (visible when user has company), stored in invoice model
- `HomeScreen`: added dispatched jobs card showing pending job count with tap-to-navigate to dispatch tab

---

## 2026-03-15 (Session 38)

### Documentation Update
- Updated `DISPATCH_FEATURE_SPEC.md` with implementation progress banner and completion markers (✅) on Phase 1-3 items
- Noted remaining items from Phases 1-3: Home screen "Dispatched Jobs" card, company PDF config (deferred to Phase 4), site/customer autocomplete

---

## 2026-03-15 (Session 37)

### Dispatch Feature — Phases 1-3: Full Implementation

**New Data Models** (4 files):
- `lib/models/company.dart` — Company class (id, name, address, phone, email, createdBy, inviteCode)
- `lib/models/company_member.dart` — CompanyMember class + CompanyRole enum (admin/dispatcher/engineer)
- `lib/models/dispatched_job.dart` — DispatchedJob class (30+ fields), DispatchedJobStatus enum, JobPriority enum
- `lib/models/user_profile.dart` — UserProfile class (uid, companyId, companyRole, fcmToken)
- Updated `lib/models/models.dart` barrel to export all 4 new models

**New Services** (3 files):
- `lib/services/user_profile_service.dart` — Singleton, loads/caches user profile from Firestore + SharedPreferences, manages FCM token updates
- `lib/services/company_service.dart` — Singleton, company CRUD (create/join/leave/delete), member management, invite code generation (FT-XXXXXX format), batch Firestore writes
- `lib/services/dispatch_service.dart` — Singleton, dispatched job CRUD, real-time Firestore streams, status transitions with validation, engineer job filtering

**New Company Screens** (4 files):
- `lib/screens/company/create_company_screen.dart` — Form to create company, shows generated invite code on success
- `lib/screens/company/join_company_screen.dart` — Single invite code input, joins as engineer
- `lib/screens/company/company_settings_screen.dart` — View/edit company details, regenerate invite code, leave/delete company
- `lib/screens/company/team_management_screen.dart` — Real-time member list with role badges, admin role change/remove actions

**New Dispatch Screens** (5 files):
- `lib/screens/dispatch/dispatch_dashboard_screen.dart` — Summary cards (unassigned/in-progress/completed/urgent), filterable job list, FAB to create
- `lib/screens/dispatch/create_job_screen.dart` — Full job creation form (all 30+ fields), engineer assignment dropdown, priority segmented control, edit mode
- `lib/screens/dispatch/dispatched_job_detail_screen.dart` — Dispatcher view with all details, reassign, edit, get directions, tap-to-call
- `lib/screens/dispatch/engineer_jobs_screen.dart` — Engineer's assigned jobs grouped by Active/Upcoming/Completed
- `lib/screens/dispatch/engineer_job_detail_screen.dart` — Field-friendly layout with status action buttons (Accept→En Route→On Site→Complete), decline flow, get directions
- `lib/screens/dispatch/decline_job_dialog.dart` — Quick-select reasons + custom text

**Modified Files**:
- `lib/main.dart` — Added UserProfileService init in AuthWrapper, conditional 5th "Dispatch" tab (dispatchers→dashboard, engineers→job list), dynamic nav bar generation
- `lib/screens/settings/settings_screen.dart` — Added "Company" section (create/join when no company, settings/team when in company), gated behind `dispatchEnabled`
- `lib/utils/icon_map.dart` — Added 8 dispatch icons (taskOutline/Bold, routing, call, map, timer, crown, userAdd)
- `firestore.rules` — Added company security rules with helper functions (isCompanyMember, isCompanyAdmin, isCompanyDispatcherOrAdmin), member/job/site/customer subcollection rules
- `pubspec.yaml` — Added `url_launcher: ^6.2.0`

---

## 2026-03-15 (Session 36)

### Dispatch Feature — Remote Config Flag Setup

- **Added 3 dispatch Remote Config defaults**: `dispatch_enabled` (false), `dispatch_max_members` (25), `dispatch_notifications_enabled` (true) — all gated off by default so testers see nothing
- **Added dispatch tester tagging**: `initialize()` now sets `dispatch_tester` Analytics user property for emails in `dispatchTesters` list, enabling targeted Remote Config conditions
- **Added 3 dispatch getters**: `dispatchEnabled`, `dispatchMaxMembers`, `dispatchNotificationsEnabled` on `RemoteConfigService`
- **Imports**: Added `firebase_analytics` and `firebase_auth` to remote config service

---

## 2026-03-15 (Session 35)

### iOS App Icon Fix

- **Regenerated all app icons** from new source image (`app_icon_1024.jpg`) by running `flutter_launcher_icons` — overwrote all iOS and Android icon PNGs
- **Deleted orphan icon files**: removed unused `assets/images/app1024.png` and `assets/images/appp-icon1.jpg`

---

## 2026-03-15 (Session 34)

### Invoice Line Items UI Redesign

- **Item header row**: Moved delete (X) button inline with "Item N" label in its own Row, freeing the description field from being squeezed.
- **Full-width description**: Description TextFormField now spans the entire card width instead of sharing a Row with the delete button.
- **Responsive quantity/price fields**: Replaced fixed-width `SizedBox(width: 100/120)` with `Expanded` so Quantity, Unit Price, and Line Total fill the row evenly on all screen sizes.
- **Always-visible line total**: Line total now shows `£0.00` in muted grey when empty instead of hiding via `SizedBox.shrink()`.
- **Fixed duplicate "+" on button**: Changed label from `'+ Add Another Item'` to `'Add Another Item'` since the icon already provides the "+".

---

## 2026-03-14 (Session 33)

### Timestamp Camera — Remove Dead Code (`_setZoom`, `_switchToUltraWide`, `_isUsingUltraWide`)

- **Removed unused `_setZoom` method** from `timestamp_camera_screen.dart` — zoom is handled elsewhere, this method had no callers.
- **Removed cascading dead code**: `_switchToUltraWide` method (only called by `_setZoom`) and `_isUsingUltraWide` field (only written, never read).
- **Verification**: `flutter analyze` passes with no issues on the file.

---

## 2026-03-14 (Session 32)

### iOS Dark Mode Keyboard — Remove Redundant `keyboardAppearance` From Raw TextFormFields

- **Cleanup: Removed explicit `keyboardAppearance: Theme.of(context).brightness` from 36 raw `TextFormField` instances** across 12 files. Flutter's `TextField` already defaults `keyboardAppearance` to `theme.brightness`, making these lines redundant. Removing them may also fix the flat/borderless keyboard style on iOS 18+ dark mode (if Flutter's engine handles the unset case differently at the platform channel level).
- **Retained: `CustomTextField` keeps its internal `keyboardAppearance` setting** (`lib/widgets/custom_text_field.dart:233`) as the centralised widget for all text input fields.
- **Files modified**: `bank_details_screen.dart` (5), `battery_load_test_screen.dart` (3), `detector_spacing_calculator_screen.dart` (3), `dip_switch_calculator.dart` (2), `invoice_screen.dart` (9), `jobsheet_settings_screen.dart` (1), `pdf_footer_designer_screen.dart` (1), `pdf_header_designer_screen.dart` (1), `profile_screen.dart` (5), `custom_template_builder_screen.dart` (2), `pdf_forms_screen.dart` (2), `pdf_form_builder_screen.dart` (3).

---

## 2026-03-14 (Session 31)

### Timestamp Camera — Revert Session 29 Zoom Changes & Remove 0.5x Toggle

- **Revert: Removed 0.5x ultra-wide lens button** — Session 29 made the 0.5x button functional but broke 1x/2x/5x zoom levels (all appeared far more zoomed in than they should). Reverted all Session 29 zoom changes. The 0.5x lens stop is now removed entirely from `LensSelectorWidget` since it never worked properly.
- **Revert: `ZoomGestureLayer` no longer routes through `onZoomChanged`** — Removed the `onZoomChanged` callback added in Session 29. Pinch-to-zoom now sets the controller zoom level directly again, staying within the main camera's native zoom range.
- **Revert: `LensSelectorWidget` lens stops clamp to camera range** — The 1x/2x/5x buttons now clamp and set zoom directly on the controller instead of routing through `_setZoom`. Removed `hasUltraWide` property.
- **Fix: Custom note keyboard on iOS shows "Done" button** — Added `textInputAction: TextInputAction.done` to the custom note `CustomTextField` in `CameraSettingsPanel`. Previously `maxLines: 2` caused iOS to show a return key with no way to dismiss the keyboard.
- **Preserved: Camera flip fix from Session 29** — The `_setupController` dispose-before-init order and iOS 150ms delay are untouched and continue to work correctly.

---

## 2026-03-14 (Session 30)

### Fix iOS Dark Mode Keyboard — Missing `keyboardAppearance` on Remaining Fields

- **Fix: Added `keyboardAppearance: Theme.of(context).brightness` to 15 remaining raw `TextFormField`/`TextField` instances** across 7 files that were missed in Session 27. Session 27 fixed fields that had `keyboardAppearance` hardcoded to `Brightness.light`, but these 15 fields never had the property set at all (iOS defaults to light keyboard).
  - `profile_screen.dart` — 5 fields (name, email, current/new/confirm password)
  - `pdf_header_designer_screen.dart` — 1 field (header text value)
  - `pdf_footer_designer_screen.dart` — 1 field (footer text value)
  - `jobsheet_settings_screen.dart` — 1 field (`_buildTextField` helper)
  - `pdf_form_builder_screen.dart` — 3 fields (job reference, text field, multiline text)
  - `custom_template_builder_screen.dart` — 2 fields (field label, dropdown options)
  - `pdf_forms_screen.dart` — 2 fields (template name, description in upload dialog)

---

## 2026-03-14 (Session 29)

### Timestamp Camera — Fix 0.5x Lens & Camera Flip on iOS

- **Fix: 0.5x ultra-wide lens button now works** — The lens selector was clamping the 0.5 value to the main camera's minZoom (1.0), silently turning it into a no-op. Removed the `.clamp()` so the raw 0.5 value reaches `_setZoom` which handles the ultra-wide camera switch.
- **Fix: Pinch-to-zoom can now reach ultra-wide** — Added `onZoomChanged` callback to `ZoomGestureLayer` so pinch gestures route through `_setZoom` instead of directly calling `controller.setZoomLevel()`. This allows pinching below 1.0x to trigger the ultra-wide camera switch. The gesture layer's `minZoom` is set to 0.5 when ultra-wide is available.
- **Fix: Camera flip no longer freezes on iOS** — Reversed the init/dispose order in `_setupController()`: the old controller is now disposed BEFORE the new one is initialized, with a 150ms delay on iOS for AVCaptureSession to release hardware. Previously, two simultaneous AVCaptureSessions would conflict, causing a black screen or freeze after flipping.

---

## 2026-03-14 (Session 28)

### PDF Design Screen — Banner Text & Preview Visibility Fix

- **Fix: Updated misleading PDF Design hub banner** — Changed banner from "These settings apply to both invoice and jobsheet PDFs" to clarify that each designer lets you toggle between jobsheet and invoice styling independently.
- **Fix: Jobsheet preview field values visible in dark mode** — Added explicit `color: AppTheme.textPrimary` to `_mockFieldRow()` value text in `pdf_colour_scheme_screen.dart`. Previously, values like "JS-001" and "John Smith" inherited the theme's default text colour, making them invisible (light text on white preview) in dark mode.

---

## 2026-03-14 (Session 27)

### Fix iOS Dark Mode Keyboard Appearance

- **Fix: iOS keyboard now follows app theme** — Replaced all 19 hardcoded `keyboardAppearance: Brightness.light` with `keyboardAppearance: Theme.of(context).brightness` across 6 files (`custom_text_field.dart`, `invoice_screen.dart`, `bank_details_screen.dart`, `dip_switch_calculator.dart`, `battery_load_test_screen.dart`, `detector_spacing_calculator_screen.dart`). iOS keyboards now render in dark style when the app is in dark mode and light style in light mode, while retaining the rounded-rectangle key backgrounds from Session 24.

---

## 2026-03-14 (Session 26)

### Fix Detector Spacing Calculator Bugs

- **Fix: Calculator silent failure at exact multiples of detector radius** — When room dimensions were exact multiples of the detector radius (e.g. 15x15m smoke, 10.6x10.6m heat), `remainingR` became zero causing a division-by-zero (`Infinity.ceil()` throws `UnsupportedError`). Added `if (remainingR <= 0) continue` guard so the loop skips to the next column count.
- **Fix: Auto-switch room type based on width** — Previously the calculator only showed a warning banner when width didn't match the selected room type. Now `_calculate()` automatically switches to Corridor mode when width ≤ 2m and to Open Area when width > 2m, with an explanatory note in the results.

---

## 2026-03-14 (Session 25)

### Separate PDF Designer for Jobsheets vs Invoices

- **Feature: Independent PDF configs per document type** — Added `PdfDocumentType` enum (`jobsheet` / `invoice`) to `pdf_header_config.dart`. All three config services (`PdfHeaderConfigService`, `PdfFooterConfigService`, `PdfColourSchemeService`) now accept a `PdfDocumentType` parameter, storing separate SharedPreferences keys per type (e.g., `pdf_header_config_v1_jobsheet` / `pdf_header_config_v1_invoice`). Includes automatic migration: existing untyped config is copied to both typed keys on first load.
- **Feature: Document type toggle in designer screens** — Added `SegmentedButton<PdfDocumentType>` (Jobsheet / Invoice) to the top of `PdfHeaderDesignerScreen`, `PdfFooterDesignerScreen`, and `PdfColourSchemeScreen`. Switching types auto-saves the current config and loads the config for the selected type.
- **Feature: Jobsheet preview in colour scheme screen** — Added `_buildJobsheetPreview()` showing a jobsheet-style mockup (section headers in primary colour, alternating light-tint rows, certification accent border, dual signature boxes) alongside the existing invoice preview, toggled by the document type selector.
- **Firestore sync updated** — Sync methods now use typed Firestore doc IDs (`header_jobsheet`, `header_invoice`, etc.). Full sync pulls typed docs with fallback migration from old untyped docs. GDPR deletion unaffected (batch-deletes entire `pdf_config` subcollection).
- **PDF generation updated** — `PDFService.generateJobsheetPDF` uses `PdfDocumentType.jobsheet`; `InvoicePDFService.generateInvoicePDF` uses `PdfDocumentType.invoice`.

---

## 2026-03-14 (Session 24)

### Fix Dark Mode iOS Number Keyboard Appearance

- **Fix: iOS dark mode keyboards showing flat keys** — Added `keyboardAppearance: Brightness.light` to all `TextFormField` and `TextField` widgets across the app. In dark mode, iOS renders number keyboards with flat, background-less keys; forcing light appearance restores the rounded-rectangle button backgrounds. Applied to `CustomTextField` (covers most fields app-wide), plus raw text fields in `bank_details_screen.dart`, `battery_load_test_screen.dart`, `detector_spacing_calculator_screen.dart`, `dip_switch_calculator.dart`, and `invoice_screen.dart`.

---

## 2026-03-14 (Session 23)

### Fix Timestamp Camera Video Overlay + Preview Overflow

- **Fix: Video overlay box misaligned** — In `_ffmpegDrawBox()`, replaced `w`/`h` with `iw`/`ih` for input video dimensions. FFmpeg's `drawbox` filter resolves `w`/`h` as the box's own dimensions, not the input frame, causing bottom-position boxes to render at the top and right-position boxes to be misaligned. (`lib/services/timestamp_camera_service.dart`)
- **Fix: Preview overlay text overflowing on right positions** — Changed `CameraOverlayPainter` to always use `TextAlign.left` instead of `TextAlign.right` for right-side positions. The manual x-position calculation already handles right-alignment; adding `TextAlign.right` caused double-offsetting, pushing text off the right edge. (`lib/screens/tools/timestamp_camera/camera_overlay_painter.dart`)

---

## 2026-03-14 (Session 22)

### Revert Timestamp Camera + Fix iOS Keyboard Done Bar

- **Revert: Timestamp Camera rebuild** — Restored all 10 original screen files, `timestamp_camera_service.dart`, and `assets/fonts/Inter-Bold.ttf` from commit `6e5d078` (pre-rebuild "almost working" state). Removed rebuild-only `overlay_settings_sheet.dart`. The Session 21 rebuild introduced too many regressions.
- **Fix: `KeyboardDoneBar` never showing on iOS** — Converted from `StatelessWidget` to `StatefulWidget` with `WidgetsBindingObserver`. The `didChangeMetrics()` callback now triggers `setState()` when the keyboard appears/hides. Previously the widget read `viewInsets` but had no rebuild trigger, so the done bar with up/down field navigation arrows never appeared. Affects all 19 screens using `KeyboardDismissWrapper`. (`lib/widgets/keyboard_done_bar.dart`)

---

## 2026-03-13 (Session 21)

### Timestamp Camera — Complete Tear-Out and Rebuild

- **Delete: Old timestamp camera** — Removed all 10 screen files (`timestamp_camera/` folder), `timestamp_camera_service.dart`, `location_service.dart`, and `Inter-Bold.ttf`. Cleaned references from `home_screen.dart` and `analytics_service.dart`.
- **New: Per-corner overlay system** — Each of the 4 corners (TL, TR, BL, BR) independently assigned a data type: Date, Time, GPS Coordinates, GPS Address, or Custom Note. Replaces old toggle-based system with single-block overlay. Defaults: TL=Date, TR=Time, BL=GPS Coords, BR=None.
- **New: `OverlaySettings` model** — `OverlayDataType` enum + `OverlayCorner` enum + `OverlaySettings` class with `copyWith()` (nullable function pattern for clearing corners), `textForCorner()`, `buildCornerTexts()`, `hasCustomNote`, `hasAnyOverlay`. (`timestamp_camera_service.dart`)
- **New: `CameraOverlayPainter`** — Renders up to 4 independent rounded-rect blocks with white bold text + shadow. Top corners avoid Dynamic Island via `safeAreaTop`. `OverlayWidget` wraps it with 1-second timer for clock updates. (`camera_overlay_painter.dart`)
- **New: `OverlaySettingsSheet`** — DraggableScrollableSheet with 4 dropdown rows (one per corner), custom note text field (shown when any corner uses customNote), and resolution selector. Changes saved immediately. (`overlay_settings_sheet.dart`)
- **New: `VideoProcessingScreen`** — Same proven FFmpeg processing pattern with progress bar, retry with fallback filter, save without overlay buttons. Now receives `OverlaySettings` directly for fallback rebuild. (`video_processing_screen.dart`)
- **New: `TimestampCameraScreen`** — Rebuilt main screen (was 856 lines across 10 files, now ~650 lines in 1 file + 3 supporting files). Inlines FocusIndicator, LensSelectorWidget, and bottom controls. Camera flip with try/finally, 3-pass ultra-wide heuristic, pinch-to-zoom, tap-to-focus, photo/video mode toggle. (`timestamp_camera_screen.dart`)
- **New: FFmpeg per-corner filters** — `buildFfmpegFilter()` and `buildFallbackFfmpegFilter()` generate independent drawbox+drawtext chains per corner. Date/time use `%{pts\:localtime\:EPOCH}`, fallback uses per-second `enable='between(t,N,N+1)'`. (`timestamp_camera_service.dart`)
- **Preserved: `LocationService`** — Identical singleton with GPS stream + reverse geocoding throttling. (`location_service.dart`)
- **Re-integrated: Home screen tile + analytics events** — Timestamp Camera tile and 3 analytics events (photo_captured, video_recording_started, video_recording_completed) re-added.
- **File count**: 12 files → 6 files (4 screens + 2 services)

---

## 2026-03-13 (Session 20)

### Timestamp Camera — Fix Flip, Ultra-Wide, Preview Position, and Unified Overlay

- **Fix: Camera flip spinner forever** — Wrapped `_flipCamera()` and `_switchToUltraWide()` in try/finally so `_isFlipping` is always reset even if `_setupController()` throws. Previously an error left the permanent spinner on screen. (`timestamp_camera_screen.dart`)
- **Fix: 0.5x ultra-wide not showing on iOS** — Camera detection now uses a 3-pass heuristic: (1) name-based for Android ("ultra"/"wide"), (2) iOS AVCaptureDevice ID suffix parsing (`:0` = ultra-wide, `:2` = main), (3) generic fallback for 2+ back cameras. Added debug logging for camera names/assignments. (`timestamp_camera_screen.dart`)
- **Fix: Overlay renders behind Dynamic Island** — Moved overlay widget inside the camera preview's AspectRatio bounds (was full-screen Positioned.fill). Added `safeAreaTop` parameter computed from preview offset vs screen safe area. Painter pushes top-position overlays below the Dynamic Island in preview; saved output uses 0 (no safe area). (`timestamp_camera_screen.dart`, `overlay_widget.dart`, `camera_overlay_painter.dart`)
- **Add: Unified overlay metrics** — New `OverlayMetrics` class and `computeOverlayMetrics(width, height)` function used by all three renderers (live preview painter, photo watermark, FFmpeg video filter). Replaces hardcoded per-resolution switch statements. All use `height * 0.024` fontSize, `width * 0.03` margin, proportional padding/lineGap. (`timestamp_camera_service.dart`)
- **Fix: Photo watermark font selection** — Now selects closest bitmap font (`arial48`/`arial24`/`arial14`) based on target fontSize from shared metrics. Uses shared proportional margin/padding for block positioning. (`timestamp_camera_service.dart`)
- **Fix: FFmpeg overlay sizing** — Replaced `_ffmpegFontSize`, `_ffmpegMargin`, `_ffmpegPadding`, `_ffmpegLineGap` hardcoded helpers with `videoDimensionsForResolution()` + `computeOverlayMetrics()`. Both `buildDynamicFfmpegFilter` and `buildFallbackFfmpegFilter` now use shared metrics. (`timestamp_camera_service.dart`)
- **Simplify: CameraPreviewWidget** — Removed Center/AspectRatio wrapper (moved to parent screen). Widget now just returns `CameraPreview(controller)`. (`camera_preview_widget.dart`)

---

## 2026-03-13 (Session 19)

### Fix: iOS Keyboard Done Bar + Field Navigation Arrows

- **Fix: Done bar never showing on iOS** — `KeyboardDoneBar` used `MediaQuery.of(context).viewInsets.bottom` which is always 0 inside a Scaffold body (Scaffold consumes viewInsets). Switched to `MediaQueryData.fromView(View.of(context)).viewInsets.bottom` to read raw view insets. Changed positioning from `bottom: viewInsets.bottom` to `bottom: 0` since Scaffold already pushes the body above the keyboard. (`keyboard_done_bar.dart`)
- **Add: Up/down field navigation arrows** — Added chevron up/down buttons (using `AppIcons.arrowUp`/`AppIcons.arrowDown`) on the left side of the toolbar, matching iOS native keyboard accessory view behaviour. Up calls `previousFocus()`, down calls `nextFocus()`. Layout: arrows left + spacer + "Done" right. (`keyboard_done_bar.dart`)

---

## 2026-03-13 (Session 18)

### Fix: Invoice Customer Email Not Persisting

- **Fix: customerEmail lost on reload** — Added `customerEmail` (nullable String) to `Invoice` model with full `toJson`/`fromJson`/`copyWith` support. DB migrated from v11→v12 (`ALTER TABLE invoices ADD COLUMN customerEmail TEXT`). Fresh installs include the column in `_createInvoicesTable`. Invoice screen now passes email to `_buildInvoice()` and restores it in `_loadExistingInvoice()`. Firestore sync works automatically via existing `toJson`/`fromJson` flow. (`invoice.dart`, `database_helper.dart`, `invoice_screen.dart`)

---

## 2026-03-12 (Session 17)

### Timestamp Camera — Fix Regressions from Session 16

- **Fix: FFmpeg video overlay fails (code 1)** — Reverted FFmpeg filter from expression-based syntax (`fontsize='(h*0.024)'`) to pre-computed integer values (`fontsize=36`) per resolution. Single-quoted expressions caused FFmpeg parser errors. Kept the drawbox grouping improvement. (`timestamp_camera_service.dart`)
- **Fix: Photo overlay position mismatch** — Reverted photo watermark from `dart:ui`/`CameraOverlayPainter` approach back to isolate-based `img.drawString` with `image` package. Uses same 3% margin ratio as preview so overlay position matches. (`timestamp_camera_service.dart`)
- **Fix: Live preview overlay 20% from bottom** — Removed `safeBottomMargin=0.20` and `safeTopMargin=0.12` from `CameraOverlayPainter`. Now uses 3% margin from edges to match saved photo/video output. (`camera_overlay_painter.dart`)
- **Fix: 0.5x ultra-wide detection fragile** — Replaced index-based assumption (`backCameras[1]`) with name-based detection (`cam.name.contains('ultra')`). Stores explicit `_mainBackCamera` and `_ultraWideCamera` references. (`timestamp_camera_screen.dart`)
- **Fix: Flip camera may not toggle** — Initializes `_isUsingFrontCamera` from actual first camera's direction. Flip now requires both front and back cameras to exist. (`timestamp_camera_screen.dart`)
- **Fix: Max zoom capped at 20x** — Clamped `_maxZoom` to 20.0 in `_setupController`. (`timestamp_camera_screen.dart`)
- **Fix: Remove 10x lens stop** — Only .5x, 1x, 2x, 5x stops shown. (`lens_selector_widget.dart`)

---

## 2026-03-12 (Session 16)

### Timestamp Camera — 4 Fixes

- **Fix: Black screen after background return** — Restructured `didChangeAppLifecycleState` so `resumed` is no longer blocked by the early-return guard. `_handleInactive` now nulls out `_controller` before disposing so resumed state always reinitializes (`timestamp_camera_screen.dart`)
- **Fix: Preview overlay overflow on right edge** — Clamped `blockWidth` to `size.width - margin*2` and ensured clamp upper bound is always >= lower bound. Increased `maxTextWidth` from 55% to 70% for long addresses (`camera_overlay_painter.dart`)
- **Fix: 0.5x ultra-wide lens unavailable on iPhone** — Categorized cameras into back/front lists, detected ultra-wide availability on iOS (`backCameras.length >= 2`). Added `_switchToUltraWide` method and `hasUltraWide` param to `LensSelectorWidget`. Tapping 0.5x switches to ultra-wide camera; 1x+ switches back to main wide camera. `_flipCamera` now toggles front/back instead of cycling all cameras (`timestamp_camera_screen.dart`, `lens_selector_widget.dart`)
- **Fix: Uniform photo & video overlays** — Photo watermark now uses `dart:ui` Canvas with `CameraOverlayPainter` (same as live preview) rendered to PNG then composited onto photo in isolate. FFmpeg video filter now uses single `drawbox` background instead of per-line `box=1`, proportional font sizes (`h*0.024`), proportional margins (`w*0.03`), and 0.55 opacity matching the preview (`timestamp_camera_service.dart`)

---

## 2026-03-11 (Session 15)

### Privacy Policy Markdown Update

- **Updated `privacy_policy.md`**: Created standalone markdown file at project root matching the in-app privacy policy exactly. Previous version was missing ICO registration details (ZC102827), had outdated date (7 March → 10 March 2026), and old Section 9 title ("Contact" → "Data Controller & Contact").

---

## 2026-03-11 (Session 14)

### Timestamp Camera — 5 Bug Fixes + Zoom Enhancement

- **Fix: Pinch-to-zoom broken** — Wrapped overlay in `IgnorePointer` so touch events pass through to the zoom gesture layer beneath (`timestamp_camera_screen.dart`)
- **Fix: Photo/Video toggle overlapping lens selector** — Changed lens selector positioning from hardcoded `bottom: 140` to `MediaQuery.padding.bottom + 180` to clear SafeArea + controls (`timestamp_camera_screen.dart`)
- **Fix: Live overlay text overflowing background box** — Replaced assumed `lineHeight` per entry with actual `paragraph.height` after layout. Uses cumulative paragraph heights + inter-line gaps for accurate block sizing. Reduced `safeBottomMargin` from 0.28 to 0.20 (`camera_overlay_painter.dart`)
- **Fix: Photo watermark sloppy/overlapping text** — Added scale factor `(imgWidth / 1080).clamp(1.0, 3.0)` for spacing relative to image resolution. Added `_wrapText()` helper for word-wrapping long lines. Clamped rect coordinates to image bounds (`timestamp_camera_service.dart`)
- **Fix: Video date/time not rendering** — Switched from `buildDynamicFfmpegFilter` (uses `%{pts:localtime:EPOCH}` which silently fails) to `buildFallbackFfmpegFilter` (pre-computed per-second text) as primary filter. Added `coords` and `address` fields to `VideoProcessingScreen` so retry path preserves GPS data (`timestamp_camera_screen.dart`, `video_processing_screen.dart`)
- **Enhancement: Zoom beyond 2x + dynamic indicator** — Added 5x and 10x lens stops (when camera supports them). Shows dynamic zoom level (e.g. "4.2x") in a yellow pill when pinch-zooming between preset stops (`lens_selector_widget.dart`)

---

## 2026-03-10 (Session 13)

### StandardInfoBox Consistency

- **Moved disclaimer to top of info dialogs**: `StandardInfoBox` now appears at the top of the info dialog in both the Detector Spacing Calculator and Battery Load Test screens, matching the existing order in Decibel Meter and BS 5839 Reference. All four tools now show the warning/disclaimer before technical content.

---

## 2026-03-10 (Session 12)

### Detector Spacing Calculator Improvements

- **Merged heat detector grades**: Removed `pointHeatGrade1` and `pointHeatGrade2` enum values, replaced with single `pointHeat` (5.3m radius, 10.6m corridor spacing, 7.5m max ceiling). Grade 2 values were incorrect per BS 5839-1 Table 4.
- **Corridor spacing corrected**: Heat detector corridor spacing updated from 10.5m to 10.6m (2 × 5.3m radius per Table 4).
- **Ceiling height hard block**: Calculator now blocks calculation entirely when ceiling exceeds max height, showing a red warning card recommending aspirating/beam detection. Removed old height-adjustment reduction logic.
- **Corridor/open area suggestion banner**: Amber info banner appears when width doesn't match selected mode (≤2m in open area suggests corridor; >2m in corridor suggests open area). Removed old corridor width warning from calculation notes.
- **Dropdown subtitle**: Point Heat dropdown item now shows "Fixed-temperature or rate-of-rise (EN 54-5)" subtitle.
- **Info dialog updated**: Removed Grade 1/2 entries, single Point Heat line. Key principles updated to reflect ceiling hard block.

### BS 5839 Reference Screen

- **Heat corridor spacing**: Updated from "10m apart / 5m from wall" to "10.6m apart / 5.3m from wall" for consistency with Table 4.

### Privacy Policy — ICO Registration

- **Date updated**: "Last updated" changed from 7 March 2026 to 10 March 2026.
- **Section 9 renamed**: "Contact" → "Data Controller & Contact".
- **ICO registration**: Added ICO data controller registration number ZC102827 with verification link to ico.org.uk.

---

## 2026-03-08 (Session 11)

### BS 5839-1:2025 Standards Update

- **Standards metadata**: Updated all `standardRef` values from `BS 5839-1:2017 + AMD 1:2020` to `BS 5839-1:2025`. Battery annex ref changed to `Annex E` (was `Annex D / Annex E`).
- **BS 5839 Reference screen**: L2 now explicitly notes sleeping rooms as high-risk. L4 now requires detection at top of lift shafts. Added heat detector ban in L2/L3 sleeping rooms. Added closely-spaced beams definition (< 1m). Added shadow spots guidance. Added BS EN 50575 (CPR) cable requirement. Added red preferred cable colour guidance.
- **Battery Load Test**: Comment updated from `Annex D / Annexe E` to `Annex E`. No formula changes.
- **Decibel Meter**: Reference strings updated from `BS 5839` to `BS 5839-1:2025`. Thresholds unchanged.
- **Detector Spacing**: No changes needed — spacing values unchanged, `BS 5839-1` references are generic.
- **Tools disclaimer gate**: Updated example standard ref in both read-only and acceptance dialogs.

---

## 2026-03-08 (Session 10)

### Disclaimer Refinements

- **Button text**: Shortened accept button from "I Understand & Accept" to "I Accept" for visual balance with "Cancel" button.
- **Read-only view**: Added `ToolsDisclaimerGate.showDisclaimerReadOnly(context)` — shows disclaimer content with just a "Close" button, no acceptance logic.
- **Settings tile**: Added "Tools Disclaimer" tile in Settings > App section (after Privacy Policy, before About) to let users re-read the disclaimer at any time.

---

## 2026-03-08 (Session 9)

### Tools Disclaimer System & Standards Data Freshness

- **Disclaimer gate**: New `ToolsDisclaimerGate` — mandatory one-time acceptance dialog before using any safety-critical tool (BS 5839, Detector Spacing, Battery Load Test, Decibel Meter). DIP Switch and Timestamp Camera excluded.
- **Disclaimer service**: `DisclaimerService` singleton stores accepted version in SharedPreferences. Bump `currentDisclaimerVersion` to force re-acceptance.
- **Standards metadata**: `StandardsMetadata` class — single source of truth for standard refs, review dates, data versions for all 4 safety tools.
- **Standard info box**: `StandardInfoBox` widget — reusable orange warning + blue standards reference boxes for info dialogs. Added to all 4 safety tool info dialogs.
- **Remote Config**: Added `standards_data_version` string flag to `RemoteConfigService` for future "standards update available" banner.
- **Home screen**: 4 safety tool buttons now route through `ToolsDisclaimerGate.navigateToTool()` instead of direct `Navigator.push`.
- **Barrel exports**: Added `tools_disclaimer_gate.dart` and `standard_info_box.dart` to `widgets.dart`.

---

## 2026-03-08 (Session 8)

### Dark Mode Fixes

- Dark mode styling for "Recommendations" card on Battery Load Test screen (was using hardcoded light `Colors.orange.shade50` background)
- Dark mode styling for "Phone Limitations" (orange) and "Calibration" (blue) info boxes on Decibel Meter screen (hardcoded light backgrounds/borders)
- Both now use `isDark` conditional styling matching the pattern from Detector Spacing Calculator

---

## 2026-03-07 (Session 7)

### Firebase Crashlytics (previously unrecorded)

Crashlytics was already fully implemented but never logged in the changelog. Recording it now for completeness.

#### Dependency
- `firebase_crashlytics: ^5.0.7` added to pubspec.yaml

#### Android Gradle
- `com.google.firebase.crashlytics` v2.8.1 plugin added to `android/app/build.gradle.kts` and `android/settings.gradle.kts`

#### `lib/main.dart`
- `runZonedGuarded` wraps the entire app bootstrap
- `FlutterError.onError` → `FirebaseCrashlytics.instance.recordFlutterFatalError`
- `PlatformDispatcher.instance.onError` → `FirebaseCrashlytics.instance.recordError` (returns `true`)
- Zone `onError` callback → `FirebaseCrashlytics.instance.recordError`

#### iOS
- Auto-registered via FlutterFire generated plugin registrant — no manual Gradle/Podfile changes needed
- Added "Upload Crashlytics Symbols" build phase to `ios/Runner.xcodeproj/project.pbxproj` — runs `FirebaseCrashlytics/run` script post-build to upload dSYM files for crash symbolication

### Firestore Security Rules Deployment

- Deployed `firestore.rules` to Firebase via `firebase deploy --only firestore:rules`
- Rules enforce per-user data isolation: `users/{userId}/**` only accessible when `request.auth.uid == userId`

### Changelog & Memory Cleanup

- Added missing Crashlytics changelog entry
- Added Firestore rules deployment entry
- Cleaned up MEMORY.md: removed "account deletion data cleanup" from Firestore "Not included" list (implemented in Session 5)

---

## 2026-03-06 (Session 6)

### In-App Privacy Policy (Launch Plan §4.1 / §5.3 / §5.4)

Added a Privacy Policy screen accessible from Settings, covering all App Store review requirements.

#### New File
- `lib/screens/settings/privacy_policy_screen.dart` — `StatelessWidget` with `ResponsiveListView`, displays 8-section privacy policy inline (no web dependency). Covers: data collected, purpose, storage location, retention, access rights, user rights (access/export/deletion), third-party services (Firebase Auth, Firestore, Crashlytics, Analytics), and contact info.

#### Changes
- **`lib/screens/settings/settings_screen.dart`** — added import for `privacy_policy_screen.dart`; added "Privacy Policy" tile (icon: `AppIcons.lock`) in App section between "Permissions" and "About"

#### Info.plist Status (no changes needed)
- All 6 permission strings already present with clear descriptions
- `ITSAppUsesNonExemptEncryption` already set to `false`

#### Files Modified (1) + 1 New
settings_screen.dart, privacy_policy_screen.dart (new)

---

## 2026-03-06 (Session 5)

### Account Deletion — Firestore Data Cleanup (Launch Plan §11.4)

Added GDPR-compliant Firestore data deletion to the existing account deletion flow. Previously only local data (SQLite, SharedPreferences, branding) and the Firebase Auth user were deleted — Firestore cloud data was left behind.

#### `lib/services/firestore_sync_service.dart`
- Added `deleteAllUserData()` method — deletes all documents in all 7 subcollections (`jobsheets`, `invoices`, `saved_customers`, `saved_sites`, `job_templates`, `filled_templates`, `pdf_config`) under `users/{uid}/`, then deletes the user document itself
- Added `_deleteCollection()` helper — batch-deletes docs in groups of 500 (Firestore batch limit), loops until collection is empty
- Method throws on failure (not fire-and-forget) since this is a critical privacy operation

#### `lib/screens/settings/settings_screen.dart`
- Inserted `FirestoreSyncService.instance.deleteAllUserData()` call into `_showDeleteAccountDialog` deletion sequence, after re-authentication and before local data wipe
- Ordering ensures: user is still authenticated (Firestore permissions), local data preserved if Firestore fails (retry possible), `deleteAccount()` last (invalidates session)

---

## 2026-03-06 (Session 4)

### Remote Config & Feature Flags (Launch Plan §3.5)

Added Firebase Remote Config for server-side feature toggling without app updates. All features default to enabled — existing behaviour unchanged.

#### Dependency
- Added `firebase_remote_config: ^6.1.4` to pubspec.yaml

#### New File
- `lib/services/remote_config_service.dart` — singleton (`RemoteConfigService.instance`) wrapping `FirebaseRemoteConfig`. Initialises with 12h fetch interval (1min in debug), sets defaults for 10 feature flags, calls `fetchAndActivate()`. Exposes typed bool getters for each flag.

#### 10 Feature Flags
| Key | Default | Controls |
|-----|---------|----------|
| `timestamp_camera_enabled` | `true` | Timestamp camera tool |
| `decibel_meter_enabled` | `true` | Decibel meter tool |
| `dip_switch_calculator_enabled` | `true` | DIP switch calculator |
| `detector_spacing_enabled` | `true` | Detector spacing calculator |
| `battery_load_tester_enabled` | `true` | Battery load tester |
| `bs5839_reference_enabled` | `true` | BS 5839 reference |
| `invoicing_enabled` | `true` | Invoicing feature |
| `pdf_forms_enabled` | `true` | PDF certificate forms |
| `cloud_sync_enabled` | `true` | Cloud sync |
| `custom_templates_enabled` | `true` | Custom template builder |

#### Changes
- **`lib/main.dart`** — import + `await RemoteConfigService.instance.initialize()` after Firestore settings
- **`lib/screens/home/home_screen.dart`** — tool tiles conditionally included based on Remote Config flags; grid layout dynamically adapts to visible tool count

#### Files Modified (3) + 1 New
pubspec.yaml, main.dart, home_screen.dart, remote_config_service.dart (new)

---

## 2026-03-06 (Session 3)

### In-App Feedback Mechanism (Launch Plan §3.4)

Added "Send Feedback" button in Settings that opens the native email client with pre-filled device info for low-friction bug reports and feature requests.

#### Dependency
- Added `device_info_plus: ^12.3.0` to pubspec.yaml (v11 conflicted with syncfusion_flutter_pdfviewer's requirement for ^12.1.0)

#### Changes
- **`lib/services/email_service.dart`** — added `static Future<void> sendFeedback()` method that gathers app version (package_info_plus) and device info (device_info_plus) per platform (Android, iOS, Windows, macOS, Linux), then opens native email client via flutter_email_sender with pre-filled subject, recipient, and device info footer
- **`lib/screens/settings/settings_screen.dart`** — replaced "Help & Support" placeholder tile with "Send Feedback" tile; added `_sendFeedback()` method with try/catch and error toast showing fallback email address
- **Recipient**: cscott93@hotmail.co.uk
- **Subject format**: `FireThings Feedback — v{version}`

#### Files Modified (3)
pubspec.yaml, email_service.dart, settings_screen.dart

---

## 2026-03-06 (Session 2)

### Firebase Analytics (Launch Plan §3.3)

Implemented centralized analytics service with 22 tracked events for pre-beta feature usage insights.

#### New File
- `lib/services/analytics_service.dart` — singleton wrapping `FirebaseAnalytics.instance`, exposes typed methods for each event

#### Dependency
- Added `firebase_analytics: ^12.1.2` to pubspec.yaml (v11 conflicted with existing firebase_core ^4.4.0)

#### Screen Tracking
- Added `FirebaseAnalyticsObserver` to `MaterialApp.navigatorObservers` in `main.dart` for automatic screen tracking

#### 22 Instrumented Events
| Event | Where |
|---|---|
| `tool_opened` (x6 tools) | `home_screen.dart` |
| `template_selected` (built_in, custom, pdf_cert) | `new_job_screen.dart` |
| `jobsheet_started` | `job_form_screen.dart` |
| `jobsheet_saved_draft` | `job_form_screen.dart` |
| `site_selected` | `job_form_screen.dart` |
| `jobsheet_completed` | `signature_screen.dart` |
| `jobsheet_pdf_generated` | `job_detail_screen.dart` |
| `jobsheet_pdf_shared` | `job_detail_screen.dart` |
| `invoice_created` | `invoice_screen.dart` |
| `invoice_saved_draft` | `invoice_screen.dart` |
| `invoice_sent` | `invoice_screen.dart` |
| `invoice_marked_paid` | `invoice_screen.dart` |
| `customer_saved` (settings/invoice) | `saved_customers_screen.dart`, `invoice_screen.dart` |
| `customer_selected` | `invoice_screen.dart` |
| `site_saved` | `saved_sites_screen.dart` |
| `pdf_form_opened` (modification/minor_works) | `pdf_form_fill_screen.dart`, `minor_works_form_fill_screen.dart` |
| `pdf_form_saved_draft` | both PDF form screens |
| `pdf_form_previewed` | both PDF form screens |
| `photo_captured` | `timestamp_camera_screen.dart` |
| `video_recording_started` | `timestamp_camera_screen.dart` |
| `video_recording_completed` | `timestamp_camera_screen.dart` |
| `login` / `sign_up` | `login_screen.dart` |

#### Files Modified (14)
pubspec.yaml, main.dart, home_screen.dart, new_job_screen.dart, job_form_screen.dart, signature_screen.dart, job_detail_screen.dart, invoice_screen.dart, saved_customers_screen.dart, saved_sites_screen.dart, pdf_form_fill_screen.dart, minor_works_form_fill_screen.dart, timestamp_camera_screen.dart, login_screen.dart

---

## 2026-03-06

### Firestore Cloud Sync

Implementation of cloud sync per Launch Plan Section 11 (Cloud Sync Architecture & Security) and Section 3.1 (Cloud Sync with Firestore).

#### Architecture (Launch Plan §11.1)

- **SQLite primary, Firestore backup** — offline-first design; app works fully offline, Firestore SDK handles offline queuing
- **Data flow**: write local SQLite first → fire-and-forget Firestore write → pull from Firestore on app launch → last-write-wins via `lastModifiedAt` timestamps

#### Security (Launch Plan §11.2)

- Per-user data isolation: all data stored under `users/{uid}/` in Firestore
- Auth required for all reads/writes — enforced via `firestore.rules` at project root
- Users can only access their own data (`request.auth.uid == userId`)

#### What Was Implemented

- Added `FirestoreSyncService` (`lib/services/firestore_sync_service.dart`) — singleton for bidirectional Firestore sync
- Added `lastModifiedAt` (DateTime?) to all 6 synced models: Jobsheet, Invoice, SavedCustomer, SavedSite, JobTemplate, PdfFormTemplate
- Bumped SQLite DB version to 11 (ALTER TABLE migrations adding lastModifiedAt to all 6 tables)
- Updated `DatabaseHelper` with lastModifiedAt support in all CRUD operations
- Integrated fire-and-forget sync calls into DatabaseHelper CRUD methods
- Added `performFullSync(engineerId)` — bidirectional merge called from `AuthWrapper` on auth
- Synced PDF config (header, footer, colour scheme) to Firestore subcollection `pdf_config/{header,footer,colour_scheme}`
- Updated `PdfColourSchemeService`, `PdfFooterConfigService`, `PdfHeaderConfigService` to trigger Firestore sync on save
- Enabled Firestore persistence with unlimited cache in `main.dart`
- Added `firestore.rules` at project root
- Added "Cloud Sync" section to Settings screen with "Sync Now" button and last sync timestamp

#### Not Yet Implemented (from Launch Plan)

- Real-time Firestore listeners (§11.1 — currently pull-on-launch only)
- E2E encryption for sensitive data (§11.3)
- Template sharing between users

### Changelog & Memory

- Created `CHANGELOG.md` in memory directory
- Added changelog update rule to `MEMORY.md`
