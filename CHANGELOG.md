# FireThings - Changelog

All changes made to the app, updated at the end of every Claude session. Reverse-chronological order.

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
