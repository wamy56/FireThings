# FireThings - Changelog

All changes made to the app, updated at the end of every Claude session. Reverse-chronological order.

---

## 2026-03-28 (Session 52)

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
