# Phase 5: Legacy PDF System Cleanup — Specification

**Status:** Ready to plan, not yet started
**Owner:** Chris Scott
**Estimated effort:** 2-3 focused sessions (not a single sitting)
**Prerequisites:** Phase 1 PDF rebuild complete ✓, four-service migration complete ✓, recursion fixes deployed ✓

---

## Purpose

Remove the legacy PDF customisation system now that the new `PdfBranding`-based system is the source of truth across all five PDF document types (compliance reports, templates/jobsheets, quotes, invoices, BS 5839 reports).

The legacy system was the per-aspect editor (separate screens for header config, footer config, colour scheme, typography, section style) plus the services and data classes that backed them. It worked but produced inconsistent results across document types and required users to configure five things separately. The new branding system replaces all of it with a single configurable brand identity that applies consistently across every document.

This phase is NOT about user-facing features. It's about removing technical debt — orphaned files, redundant data classes, parallel Firestore document trees — to leave the codebase in a state where contributors aren't confused by which system to use.

---

## Context: What's Already Done

### Phase 1 — PDF Rebuild (complete)

Replaced ad-hoc per-document PDF generation with a unified `PdfBranding` model and reusable widget builders (`PdfCoverBuilder`, `PdfHeaderBuilder`, `PdfFooterBuilder`). New web Branding screen replaces the per-aspect mobile editors.

### Four-Service Migration (complete)

Applied the branding-resolution pattern to template, quote, invoice, and BS 5839 PDF services. Each now:

- Calls `PdfBrandingService.instance.clearCache()` before resolving
- Uses non-nullable `PdfBranding` with `defaultBranding()` fallback
- Logs resolution failures via `kIsWeb`-guarded Crashlytics (debugPrint with `[BRANDING-RESOLUTION]` prefix on web)
- Resolves company name via the chain: Company doc → SharedPreferences settings → engineer name fallback (where applicable)
- Uses single rendering paths (`PdfCoverBuilder.build`, `PdfHeaderBuilder.build`, `PdfFooterBuilder.buildBrandedFooter`) — no more 2-way or 3-way conditionals based on whether branding exists

### Storage Upload Helper (complete)

Centralised the `firebase_storage_web` `putData()` workaround into `StorageUploadHelper`. All eight upload-capable services now route through it: `pdf_branding_service`, `floor_plan_service`, `asset_service`, `defect_service`, `service_history_service`, `bs5839_report_service`, `bs5839_config_service`, `variation_service`.

### Six Orphaned Screens Deleted (complete this session)

The original per-aspect editors that nothing referenced anymore:

- `pdf_header_designer_screen.dart`
- `pdf_footer_designer_screen.dart`
- `pdf_colour_scheme_screen.dart`
- `pdf_typography_screen.dart`
- `pdf_section_style_screen.dart`
- `branding_screen.dart` (the original one, superseded by `personal_branding_screen.dart`)

---

## Context: What's Still Live

The audit Claude Code produced confirms the substantive legacy stack is held alive by two roots:

### Root 1: `UnifiedPdfEditorScreen` (mobile PDF editor)

**Location:** `lib/screens/settings/unified_pdf_editor_screen.dart`

Reached from `pdf_design_screen.dart` and `company_pdf_design_screen.dart`. Mobile users still customise their PDFs through this screen. It uses every config service (`PdfHeaderConfigService`, `PdfFooterConfigService`, `PdfColourSchemeService`, `PdfTypographyService`, `PdfSectionStyleService`) and reads/writes the old Firestore documents at `pdf_config/{type}_{docType}` paths.

This is the parallel mobile equivalent of the new web Branding screen. Until it's migrated to `PdfBranding`, the entire legacy config services layer must stay.

### Root 2: `pdf_service.dart` (main jobsheet generator)

**Location:** `lib/services/pdf_service.dart`

The main jobsheet PDF generator. Still uses the old `CompanyPdfConfigService.getEffective*` pattern that was migrated AWAY from in the four-service follow-up. Calls all six `getEffective*` methods on `CompanyPdfConfigService`, which internally delegate to the five individual config services.

This is the only PDF generator still on the legacy pattern. Until migrated, the legacy data classes (`PdfHeaderConfig`, `PdfFooterConfig`, `PdfColourScheme`, etc.) cannot be removed.

### Held Alive By These Two Roots

- 6 config services (`CompanyPdfConfigService`, `PdfHeaderConfigService`, `PdfFooterConfigService`, `PdfColourSchemeService`, `PdfTypographyService`, `PdfSectionStyleService`)
- 1 legacy logo service (`BrandingService` — old, distinct from `PdfBrandingService`)
- 7 legacy data classes (`PdfHeaderConfig`, `PdfFooterConfig`, `PdfColourScheme`, `HeaderTextLine`, `PdfTypographyConfig`, `PdfSectionStyleConfig`, `PdfDocumentType`)
- Per-aspect Firestore document tree at `companies/{id}/pdf_config/*` and `users/{uid}/pdf_config/*`

### Known Architectural Smells

- **`HeaderStyle` enum collision.** Both `pdf_header_config.dart` (old) and `pdf_branding.dart` (new) define a `HeaderStyle` enum with different values. The `models/models.dart` barrel file currently hides the new one (`export 'pdf_branding.dart' hide HeaderStyle`). This must be resolved before `pdf_header_config.dart` can be deleted.

- **Two parallel Firestore document trees.** Old: `companies/{id}/pdf_config/{type}_{docType}` (19 docs per company), `users/{uid}/pdf_config/{type}_{docType}` (18 docs per user). New: `companies/{id}/branding/main` (1 doc), `users/{uid}/branding/main` (1 doc). No migration bridge — switching costs the user their old configuration.

---

## Sub-Phases

This work is too large for a single session. It splits naturally into three sub-phases that can be done independently. Each one delivers value without requiring the next.

### Sub-Phase 5A: `pdf_service.dart` Migration

**Goal:** Apply the branding-resolution pattern to the main jobsheet generator. Same pattern used in the four-service migration this week.

**Effort:** 3-5 hours focused work.

**Why first:** Once `pdf_service.dart` no longer uses the legacy config services, the data classes are only held alive by `UnifiedPdfEditorScreen`. That makes Sub-Phase 5C (deletion) cleaner because there's only one root to migrate, not two.

**Steps:**

1. Apply the same gather-phase pattern as `compliance_report_service.dart`:
   - `PdfBrandingService.instance.clearCache()` before resolution
   - Non-nullable `PdfBranding` with `defaultBranding()` fallback
   - kIsWeb-guarded Crashlytics with `[BRANDING-RESOLUTION]` debugPrint on web
   - Company name chain: Company doc → SharedPreferences settings → fallback

2. Collapse cover/header/footer conditionals to single builder paths (matching template/quote/invoice).

3. Update `JobsheetPdfData` data class to make `brandingJson` non-nullable, add `companyName`, remove fields that are no longer needed (audit before removing — jobsheet has more legacy fields than quote/invoice did).

4. Migrate any helpers that were specific to the old pattern (e.g. `_buildHeader` if it exists, `_hexToColorValue` if it exists locally).

5. Remove `CompanyPdfConfigService` import if no longer needed (likely is — same as quote/invoice).

**Risks specific to this migration:**

- `pdf_service.dart` is the largest and most-used PDF generator. Mobile engineers generate jobsheets constantly — any regression has wide blast radius.
- Jobsheet PDFs include attached photos (asset photos, defect photos, signatures). The migration shouldn't change anything here, but verify after deploy.
- Per the audit, `pdf_service.dart` still uses `PdfFooterBuilder.buildFooter` (the legacy one). Migration should switch it to `buildBrandedFooter`.

**Test surface after migration:**

- Generate a jobsheet on web — full multipage with assets, defects, photos, signatures. Cover, headers on every page, footers, all sections render correctly.
- Generate a jobsheet on mobile (iOS or Android). Same checks. Verify Crashlytics doesn't crash.
- Generate jobsheets for different job types if applicable.
- Verify PDF still loads in print drivers, Adobe Reader, browser PDF viewer (compare with rendered output across viewers — gradient/colour rendering can differ).

**Commit shape:** Two commits. First migrates `pdf_service.dart` and `JobsheetPdfData`. Second deletes any helpers that became dead.

---

### Sub-Phase 5B: `UnifiedPdfEditorScreen` Decision

**Goal:** Decide what to do with the mobile PDF editor.

**Effort:** Discussion + 1-2 hours implementation depending on choice.

**Why this is a decision, not a task:** There are multiple valid options here, each with different user-experience implications.

**Options:**

**Option B1: Replace `UnifiedPdfEditorScreen` with a mobile equivalent of the web Branding screen.**

Build a mobile screen that uses the same `PdfBranding` model. Same logo upload, same colour pickers, same cover/header/footer style choices, same per-document-type toggles. Mobile users get the same modern customisation experience web users have.

- **Pros:** Single consistent customisation experience across platforms. Removes the entire legacy editor stack. Mobile users benefit from the new design.
- **Cons:** Significant UI work. Needs design thinking for mobile (the web version is desktop-optimised). Not a pure cleanup — it's a feature replacement.
- **Effort:** 1-2 sessions (4-8 hours).

**Option B2: Keep `UnifiedPdfEditorScreen` but rewire it to write to the `PdfBranding` document.**

The screen UI stays the same, but instead of writing to per-aspect Firestore docs, it writes to the unified `branding/main` document. Users get the same multi-tab editor experience but the data lives in one place.

- **Pros:** Less UI work. User experience unchanged. Removes the parallel Firestore trees.
- **Cons:** Data shape mismatch — the editor was designed around 5 separate aspects, the branding model is one. Some fields don't map cleanly. Logically odd to have two different UIs writing the same Firestore data.
- **Effort:** Similar to Option B1, possibly more debugging because of the impedance mismatch.

**Option B3: Delete `UnifiedPdfEditorScreen` entirely. Direct mobile users to the web portal for branding customisation.**

Mobile app no longer offers PDF customisation. Users who want to customise their branding go to the web portal.

- **Pros:** Cheapest option by far. Removes the entire legacy UI layer. Forces the web portal as the source of truth for customisation.
- **Cons:** Significant UX regression for mobile-only users. They lose the ability to customise without a desktop. Probably not acceptable for sole-trader users who only have a phone.
- **Effort:** Deletion + redirecting nav links (1 hour).

**Option B4: Defer until needed.**

Leave `UnifiedPdfEditorScreen` and the legacy stack in place. Don't migrate. Live with the parallel systems until either user feedback says "make mobile match web" or until the legacy stack starts causing actual problems.

- **Pros:** Zero work today. The legacy stack isn't actively harmful — just technical debt.
- **Cons:** Codebase has two parallel customisation systems indefinitely. New contributors get confused. Easy to accidentally use the wrong one.
- **Effort:** 0 hours.

**Recommendation:** Defer (Option B4) until you have user feedback or until you decide to migrate the mobile app's design system more broadly. The legacy editor isn't bleeding — it works, mobile users use it, no one's complaining. Spending 4-8 hours building a mobile branding screen when nobody's asked for one is a poor use of time.

When you DO eventually do this, Option B1 is the right choice — single consistent customisation experience. Option B2 is hacky. Option B3 is a UX regression.

---

### Sub-Phase 5C: Legacy Stack Deletion

**Goal:** Remove all legacy services, data classes, and Firestore documents that are no longer referenced.

**Prerequisites:** Sub-Phase 5A complete (`pdf_service.dart` migrated). Sub-Phase 5B handled (whichever option).

**Effort:** 2-3 hours mechanical deletion work.

**What gets deleted:**

After `pdf_service.dart` is migrated AND either `UnifiedPdfEditorScreen` is migrated/deleted OR you accept that the screen stays:

If `UnifiedPdfEditorScreen` is also gone:

- `lib/services/company_pdf_config_service.dart` (entire file)
- `lib/services/pdf_header_config_service.dart` (entire file)
- `lib/services/pdf_footer_config_service.dart` (entire file)
- `lib/services/pdf_colour_scheme_service.dart` (entire file)
- `lib/services/pdf_typography_service.dart` (entire file)
- `lib/services/pdf_section_style_service.dart` (entire file)
- `lib/services/branding_service.dart` (the old one — distinct from `pdf_branding_service.dart`)
- `lib/models/pdf_header_config.dart`
- `lib/models/pdf_footer_config.dart`
- `lib/models/pdf_colour_scheme.dart`
- `lib/models/header_text_line.dart`
- `lib/models/pdf_typography_config.dart`
- `lib/models/pdf_section_style_config.dart`
- `lib/models/pdf_document_type.dart` (enum — only if no remaining callers)
- `PdfFooterBuilder.buildFooter` method (legacy variant — only if `pdf_service.dart` no longer uses it)

If `UnifiedPdfEditorScreen` stays (Option B4 deferred):

- Nothing in this list can be deleted yet — the editor consumes all of it.

**`HeaderStyle` enum collision resolution:**

Whatever path, the old `HeaderStyle` in `pdf_header_config.dart` needs renaming or deleting. The barrel file currently hides the new `HeaderStyle` in `pdf_branding.dart`. Either:

- Delete old `HeaderStyle` (along with `pdf_header_config.dart`) — possible only after Sub-Phase 5A and full Sub-Phase 5B
- Or rename old `HeaderStyle` to `LegacyHeaderStyle` and remove the `hide` directive — interim measure if the legacy stack stays

**Firestore document cleanup:**

This is server-side, not code. Optional one-off Cloud Function to:

- Find users with both `users/{uid}/branding/main` AND `users/{uid}/pdf_config/*` documents
- Delete the `pdf_config/*` documents (orphaned after migration to branding system)
- Same logic for company-level docs

Effort: small (a couple of hours including testing). Not blocking — orphan docs are harmless apart from slight Firestore storage waste.

**Test surface after deletion:**

- Full `flutter analyze` — must be clean.
- Generate every PDF type on web AND mobile.
- Verify the web Branding screen still works correctly.
- Verify mobile customisation flow (whichever option from Sub-Phase 5B) still works.

---

## Architectural Lessons Banked from This Week

These should be added to `CLAUDE.md` (or wherever the project's architectural notes live) BEFORE starting Phase 5. They protect future work from repeating mistakes from this debugging arc.

### Lesson 1: Eager Firestore listeners cause recursion on Flutter web

`.snapshots().listen()` attached during service init or constructor causes `triggerHeartbeat → _getProvider → initializeFirestore` infinite recursion on Flutter web. We hit this three times this week before the pattern was clear.

**Rule:** All `.snapshots().listen()` in services or widgets must either be `kIsWeb`-guarded (skip on web) or replaced with `Stream.fromFuture(.get())` on web. Mobile keeps real-time streams.

**Examples in current codebase:**
- `UserProfileService._setupMemberListener` — kIsWeb-guarded inside the method
- `PdfBrandingService.watchBranding` / `watchPersonalBranding` — return `Stream.fromFuture(.get())` on web
- (Previously) `PdfBrandingService._attachForCurrentUser` — rolled back entirely

### Lesson 2: Firestore offline persistence disabled on web

JS SDK has long-running `INTERNAL ASSERTION FAILED: Unexpected state` bugs (firebase-js-sdk #4451, #7884, #8250) triggered by IndexedDB persistence interacting with multiple stream subscriptions. Disabled on web in `main.dart`:

```dart
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: !kIsWeb,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Rule:** Don't re-enable persistence on web without checking that the SDK has fixed the underlying bug. Mobile keeps full persistence — engineers in plant rooms with no signal still work normally.

**Side effect to be aware of:** Disabling persistence unmasked a latent GoRouter recursion bug (see Lesson 4). If the SDK eventually ships a fix and we re-enable persistence, that GoRouter bug might be re-masked but the underlying issue is still present — the coalescing fix should stay regardless.

### Lesson 3: All Storage uploads go through `StorageUploadHelper`

`firebase_storage_web` has a silent `putData()` bug — uploads from Flutter web fire no network request, throw no error, return no result. They just hang or appear to succeed without actually uploading.

**Rule:** Never call `ref.putData()` directly. Always use `StorageUploadHelper.upload(path, bytes, contentType)`. The helper routes web uploads through the Firebase Storage REST API (bypassing the broken JS SDK path), mobile uses the SDK normally.

**Same applies to `getDownloadURL()`** — same SDK bug. The helper builds the download URL from the upload response token.

### Lesson 4: `notifyListeners()` should not fire before async work completes if any listener might cause a re-entrant call

GoRouter's `refreshListenable` re-evaluates redirects synchronously when notified. If a redirect calls a method that notifies BEFORE its async work resolves (e.g. clears cache then awaits a fetch), GoRouter re-enters the redirect during the yield, finds the same condition still true, and calls the method again. Concurrent overlapping calls flood Firestore's async queue and trigger "INTERNAL ASSERTION FAILED" errors that look like SDK bugs.

**Rule:** When a method is reachable from a redirect or other re-entrant listener, either:

1. Notify only after async work completes, in a try/finally so error paths still notify, OR
2. Coalesce concurrent calls via a stored Future:

```dart
Future<void>? _loadingFuture;

Future<void> loadProfile(String uid) async {
  if (_loadingFuture != null) return _loadingFuture!;
  _loadingFuture = _doLoad(uid);
  try {
    await _loadingFuture!;
  } finally {
    _loadingFuture = null;
  }
}
```

Both fixes can coexist — the recursion fix in `UserProfileService.loadProfile` does both.

### Lesson 5: Defensive parsing in `fromJson` factories

Firestore is schemaless. Strict casts like `data['name'] as String` will crash if the field is null, missing, or a different type. We had crashes from `CompanyMember.fromJson` and `UserProfile.fromJson` because of unexpected field types.

**Rule:** All `fromJson` factories should:

- Use nullable casts with default values: `as String? ?? ''`
- Type-check Map values before casting
- Log unexpected types via debugPrint with a searchable prefix (e.g. `[PARSE-WARN]`)
- Never throw — return a partial object with defaults if the data is malformed

### Lesson 6: PDF gradients with alpha are unreliable

Different PDF viewers handle alpha-channel transparency differently. Chrome's built-in viewer, Adobe Reader, browser print drivers, macOS Preview can all render the same gradient differently. The Bold cover gradient initially had a visible dark ring at the alpha cutoff because the renderer was interpolating accent → transparent BLACK linearly.

**Rule:** When drawing decorative shapes with falloff (glows, shadows, feathered edges), pre-blend opaque colours against the known background instead of relying on alpha. The `_blend(fg, bg, t)` helper in `pdf_cover_builder.dart` is the pattern.

### Lesson 7: Always run `flutter build web --release` before `firebase deploy --only hosting`

`firebase deploy --only hosting` does NOT run the Flutter build. Skipping it deploys stale code from the previous build, which looks like the new code didn't deploy.

**Rule:** Standard deploy sequence is FOUR steps:

1. `git push` (push commits to origin)
2. `flutter build web --release` (rebuild)
3. `firebase deploy --only hosting` (deploy)
4. Hard refresh + unregister service worker (test)

Skipping step 2 has burned multiple debugging sessions.

### Lesson 8: Service workers cache aggressively

After every deploy, the service worker must be unregistered via DevTools (Application → Service Workers → Unregister) before testing. Otherwise users (and you, when testing) see stale code. This is especially confusing because the deployment itself succeeded — it's the cache that's serving the old code.

**Rule:** After `firebase deploy`, always unregister the service worker AND hard-refresh with cache disabled before declaring the deploy "tested."

### Lesson 9: Crashlytics doesn't support Flutter web

`FirebaseCrashlytics.instance.recordError()` will throw on web. Wrap with `if (!kIsWeb)` and use `debugPrint` with a searchable prefix (e.g. `[BRANDING-RESOLUTION]`) for web logging.

**Rule:** Any error path that uses Crashlytics needs a kIsWeb guard. The web fallback should use a distinctive debugPrint prefix so logs can be grep'd.

### Lesson 10: Demand actual diffs, not summaries

When Claude Code says "let me apply all changes now" instead of "here's the diff," pause and ask for the diff. Summaries can hide details that matter — `PdfBrandTokens.primary` swaps, dependency removals, helper deletions — that need eyes on them before applying.

**Rule:** Before approving any code change, see the actual `git diff` output (or equivalent before/after blocks). Approve diffs, not plans expressed as bullet points.

### Lesson 11: When multiple unrelated features fail in similar ways at the same time, suspect ONE underlying cause

This week we hit four separate-looking bugs that turned out to be three SDK fragilities (eager listeners, persistence + IndexedDB, silent putData) plus one architectural bug (GoRouter recursion). At first glance they looked like four different problems requiring four different fixes. They were actually downstream symptoms of a smaller number of root causes.

**Rule:** When debugging, before assuming you've found four bugs, ask "could these all be downstream of one or two underlying causes?" The simpler explanation is almost always more likely.

---

## Recommended Order of Operations

When you come back to Phase 5:

### Session 1 (3-5 hours): Sub-Phase 5A — `pdf_service.dart` migration

Single focused session. Apply the four-service migration pattern to `pdf_service.dart`. Test thoroughly on web AND mobile because jobsheet generation is the most-used PDF feature. Deploy.

### Decision Point: What to do about `UnifiedPdfEditorScreen`

Pick from Options B1, B2, B3, or B4 in Sub-Phase 5B above. My recommendation: defer (B4) unless you have user feedback driving a different choice.

### Session 2 (2-3 hours): Sub-Phase 5C — Deletion (only if UnifiedPdfEditorScreen is also gone)

Mechanical removal of services, data classes, and the legacy footer builder method. Resolve the `HeaderStyle` enum collision. `flutter analyze` should be clean. Deploy.

### Optional Cloud Function: Orphan document cleanup

One-off task. Not blocking anything.

---

## Test Plan for Phase 5 Completion

Whatever the final scope ends up being, these tests confirm the work is complete:

1. **Generate every PDF type on web:**
   - Compliance report
   - Jobsheet (template)
   - Quote
   - Invoice
   - BS 5839 report

2. **Generate every PDF type on mobile (iOS or Android):**
   - Same five document types
   - Verify no Crashlytics errors
   - Verify branding applies correctly

3. **Customise branding via web Branding screen:**
   - Upload logo → appears in preview AND generated PDFs
   - Change colours → reflected in preview AND PDFs
   - Change cover style (Bold/Minimal/Bordered) → preview matches output

4. **Customise PDF via mobile editor (whichever flow remains):**
   - If `UnifiedPdfEditorScreen` still exists, verify it still works and writes data that PDF generation reads
   - If migrated to mobile branding screen, verify same as above

5. **`flutter analyze` clean across the project** — no unused imports, no orphan references.

6. **No regressions in previously-broken-and-fixed features:**
   - Logo upload (web + mobile)
   - Floor plan upload (web + mobile)
   - Asset photos, defect photos, service history photos
   - Member role changes (separate investigation, but worth re-testing as a sanity check)

---

## Risks and Mitigations

### Risk: `pdf_service.dart` migration regresses jobsheet generation

**Likelihood:** Medium. It's the most complex PDF generator, used heavily.

**Mitigation:** Test on web AND mobile before declaring done. Generate a jobsheet with a typical mix of content (assets, defects, photos, signatures). Compare to a known-good PDF from before migration. If anything looks different, investigate before deploying broadly.

### Risk: `HeaderStyle` enum collision causes confusing build errors during cleanup

**Likelihood:** High during Sub-Phase 5C if not addressed.

**Mitigation:** Resolve the collision FIRST in Sub-Phase 5C — either rename old `HeaderStyle` to `LegacyHeaderStyle` (interim) or delete it (final). Do this before deleting any data classes that depend on it.

### Risk: Mobile users with existing customisation lose it after migration

**Likelihood:** Depends on Sub-Phase 5B option.

**Mitigation:** If migrating mobile editor (Options B1 or B2), include a one-time migration step that reads the user's old `pdf_config/*` documents and writes them as a `PdfBranding` document. Users keep their colours, logo, footer text, etc. Without this, anyone with custom branding sees defaults after the migration.

### Risk: `flutter analyze` finds unexpected references during deletion

**Likelihood:** Medium. The audit was thorough but not exhaustive.

**Mitigation:** Run `flutter analyze` after each deletion commit, not just at the end. If something fails, investigate before deleting more.

---

## When to Defer Phase 5 Indefinitely

Phase 5 is technical debt cleanup. It doesn't ship features users see. Defer if any of the following are true:

- You have higher-priority feature work (e.g. Phase 4 pricing/tier gating, new compliance report types, billing improvements)
- You're about to do a major rebuild that would touch this code anyway
- The legacy code is genuinely not causing problems (no contributor confusion, no bugs, no maintenance burden)

Phase 5 is "nice to have", not "must do." The codebase functions correctly with the legacy stack in place — it just has more code than it needs.

---

## Document History

- **Initial draft:** 26 April 2026, after the four-service migration and recursion fix. Captures lessons from the multi-day debugging arc.
- **Future updates:** Update this document as Sub-Phase 5A and 5C are completed. Mark sections with their completion status.

---

## Cross-References

- `CLAUDE.md` — should contain Lessons 1-11 above as standing project guidance
- `FEATURES.md` — describes what features exist and their tier (when Phase 4 happens)
- `PDF_ARCHITECTURE_REBUILD_SPEC.md` — original Phase 1-5 spec from before this week's debugging
- `firestore.rules` — security rules covering both old `pdf_config/*` paths and new `branding/*` paths under the same permissions

---

**End of specification.**
