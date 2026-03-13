# FireThings - Changelog

All changes made to the app, updated at the end of every Claude session. Reverse-chronological order.

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
