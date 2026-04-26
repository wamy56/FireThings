# Phase 5: Legacy PDF System Cleanup — Specification

**Status:** Complete (all three sub-phases done — 5A migration, 5B editor deletion, 5C legacy stack deletion)
**Owner:** Chris Scott
**Estimated effort:** 2-3 focused sessions (not a single sitting)
**Prerequisites:** Phase 1 PDF rebuild complete ✓, four-service migration complete ✓, recursion fixes deployed ✓
**App stage:** Pre-launch beta with 3-4 testers — breaking changes are acceptable, data preservation is not required

---

## Purpose

Remove the legacy PDF customisation system now that the new `PdfBranding`-based system is the source of truth across all five PDF document types (compliance reports, templates/jobsheets, quotes, invoices, BS 5839 reports).

The legacy system was the per-aspect editor (separate screens for header config, footer config, colour scheme, typography, section style) plus the services and data classes that backed them. It worked but produced inconsistent results across document types and required users to configure five things separately. The new branding system replaces all of it with a single configurable brand identity that applies consistently across every document.

This phase is NOT about user-facing features. It's about removing technical debt — orphaned files, redundant data classes, parallel Firestore document trees — to leave the codebase in a state where contributors aren't confused by which system to use.

---

## Decision: No User Data Preservation

**Decision date:** April 2026, during Sub-Phase 5A planning.

The app currently has 3-4 testers in active beta. Migrations and cleanups in this phase will NOT preserve users' existing customisations stored in the legacy `pdf_config/*` Firestore documents. If a tester has customised section styles, typography, header configs, footer configs, or colour schemes via the mobile `UnifiedPdfEditorScreen`, they will lose those customisations after migration and will need to re-set them via the new branding system.

This decision was made because:

1. **The user base is small enough to inform individually.** Three or four people can be told directly: "I'm changing how PDFs are styled — your old customisations won't carry over."
2. **The app is pre-launch.** Breaking changes are normal at this stage. The cost of preserving data is engineering complexity that won't matter once paying customers exist; the value is comfort for a handful of testers.
3. **Legacy code carried forward is a recurring cost.** Every line of code that exists "to preserve old data" is a line that must be maintained, tested, and eventually removed. Cutting cleanly now means less work later.
4. **The orphan Firestore documents are harmless.** They sit there unused, costing trivial storage. They never get read by the new system. They can be cleaned up server-side later, or just left indefinitely without consequence.

This decision applies across all sub-phases. Anywhere this spec previously said "preserve user data" or "migrate existing settings," the answer is now: don't. Cut cleanly.

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
- Uses single rendering paths (`PdfCoverBuilder.build`, `PdfHeaderBuilder.build`, `PdfFooterBuilder.buildBrandedFooter`) — no more 2-way or 3-way conditionals

### Storage Upload Helper (complete)

Centralised the `firebase_storage_web` `putData()` workaround into `StorageUploadHelper`. All eight upload-capable services now route through it.

### Six Orphaned Screens Deleted (complete)

The original per-aspect editors that nothing referenced anymore:

- `pdf_header_designer_screen.dart`
- `pdf_footer_designer_screen.dart`
- `pdf_colour_scheme_screen.dart`
- `pdf_typography_screen.dart`
- `pdf_section_style_screen.dart`
- `branding_screen.dart` (original, superseded by `personal_branding_screen.dart`)

---

## Context: What's Still Live

The audit Claude Code produced confirms the substantive legacy stack is held alive by two roots:

### Root 1: `UnifiedPdfEditorScreen` (mobile PDF editor)

**Location:** `lib/screens/settings/unified_pdf_editor_screen.dart`

Reached from `pdf_design_screen.dart` and `company_pdf_design_screen.dart`. Mobile users still customise their PDFs through this screen. It uses every config service and reads/writes the old Firestore documents at `pdf_config/{type}_{docType}` paths.

This is the parallel mobile equivalent of the new web Branding screen.

### Root 2: `pdf_service.dart` (main jobsheet generator)

**Location:** `lib/services/pdf_service.dart`

The main jobsheet PDF generator. Still uses the old `CompanyPdfConfigService.getEffective*` pattern at the time of writing. Sub-Phase 5A will migrate this to match the four-service pattern.

### Held Alive By These Two Roots (as of pre-Sub-Phase 5A)

- 6 config services (`CompanyPdfConfigService`, `PdfHeaderConfigService`, `PdfFooterConfigService`, `PdfColourSchemeService`, `PdfTypographyService`, `PdfSectionStyleService`)
- 1 legacy logo service (`BrandingService` — old, distinct from `PdfBrandingService`)
- 7 legacy data classes (`PdfHeaderConfig`, `PdfFooterConfig`, `PdfColourScheme`, `HeaderTextLine`, `PdfTypographyConfig`, `PdfSectionStyleConfig`, `PdfDocumentType`)
- Per-aspect Firestore document tree at `companies/{id}/pdf_config/*` and `users/{uid}/pdf_config/*`

After Sub-Phase 5A: `pdf_service.dart` is removed from this list. Only `UnifiedPdfEditorScreen` keeps the legacy stack alive.

### Known Architectural Smells

- **`HeaderStyle` enum collision.** Both `pdf_header_config.dart` (old) and `pdf_branding.dart` (new) define a `HeaderStyle` enum with different values. The `models/models.dart` barrel file currently hides the new one (`export 'pdf_branding.dart' hide HeaderStyle`). This must be resolved before `pdf_header_config.dart` can be deleted.

- **Two parallel Firestore document trees.** Old: `companies/{id}/pdf_config/{type}_{docType}` (19 docs per company), `users/{uid}/pdf_config/{type}_{docType}` (18 docs per user). New: `companies/{id}/branding/main` (1 doc), `users/{uid}/branding/main` (1 doc). Per the no-data-preservation decision: old documents are not migrated, will sit orphaned indefinitely or be cleaned up server-side later.

---

## Sub-Phases

This work is too large for a single session. It splits naturally into three sub-phases that can be done independently. Each one delivers value without requiring the next.

### Sub-Phase 5A: `pdf_service.dart` Migration

**Goal:** Apply the branding-resolution pattern to the main jobsheet generator. Same pattern used in the four-service migration.

**Status:** Approved, in progress as of April 2026.

**Effort:** 3-5 hours focused work.

**Why first:** Once `pdf_service.dart` no longer uses the legacy config services, the data classes are only held alive by `UnifiedPdfEditorScreen`. That makes Sub-Phase 5C (deletion) cleaner because there's only one root to migrate.

**Steps:**

1. Add `PdfColourScheme.fromBranding()` bridge factory so existing section helpers work unchanged. This avoids needing to rewrite every `pdf_widgets/` body section helper in this sub-phase — that's body migration's job, separate effort.

2. Apply the same gather-phase pattern as `compliance_report_service.dart`:
   - `PdfBrandingService.instance.clearCache()` before resolution
   - Non-nullable `PdfBranding` with `defaultBranding()` fallback
   - kIsWeb-guarded Crashlytics with `[BRANDING-RESOLUTION]` debugPrint on web
   - Company name chain: Company doc → SharedPreferences settings → jobsheet.engineerName fallback

3. Use `PdfSectionStyleConfig.defaults()` and `PdfTypographyConfig.defaults()` in the build phase. Per the no-data-preservation decision, do NOT read these from `CompanyPdfConfigService.getEffective*`. Users who customised these via the mobile editor will see defaults — they will need to re-customise via the branding system once their setup matches.

4. Collapse cover/header/footer conditionals to single builder paths (matching template/quote/invoice/BS 5839).

5. Update `JobsheetPdfData` data class:
   - Remove: `headerConfigJson`, `footerConfigJson`, `colourSchemeValue`, `secondaryColourValue`, `sectionStyleJson`, `typographyJson`, `settingsCompanyName`, `settingsTagline`, `settingsAddress`, `settingsPhone`, `regularFontBytes`, `boldFontBytes`
   - Make `brandingJson` non-nullable
   - Add `companyName` (required)

6. Remove the `CompanyPdfConfigService` import — no longer needed in this file.

7. Remove dead code: `_hexToColorValue`, `_JobsheetSettings`, `_buildHeader`, `_extractFontBytes`, `_darkGray` constant.

**Risks specific to this migration:**

- `pdf_service.dart` is the largest and most-used PDF generator. Mobile engineers generate jobsheets constantly — any regression has wide blast radius.
- Jobsheet PDFs include attached photos (asset photos, defect photos, signatures). The migration shouldn't change anything here, but verify after deploy.
- Per-tester behaviour change: anyone who customised section style or typography via mobile editor will see defaults. Inform testers in advance.

**Test surface after migration:**

- Generate a jobsheet on web — full multipage with assets, defects, photos, signatures. Cover, headers on every page, footers, all sections render correctly.
- Generate a jobsheet on mobile (iOS or Android). Same checks. Verify Crashlytics doesn't crash.
- Generate jobsheets for different job types if applicable.
- Verify PDF still loads in print drivers, Adobe Reader, browser PDF viewer (compare with rendered output across viewers — gradient/colour rendering can differ).

**Commit shape:** Two commits. First migrates `pdf_service.dart`, `JobsheetPdfData`, and adds the bridge factory. Second deletes dead code that became unused.

---

### Sub-Phase 5B: `UnifiedPdfEditorScreen` Decision

**Goal:** Decide what to do with the mobile PDF editor.

**Effort:** Discussion + 0-2 hours implementation depending on choice.

**Why this is a decision, not a task:** There are multiple valid options here, each with different user-experience implications.

**Options:**

**Option B1: Replace `UnifiedPdfEditorScreen` with a mobile equivalent of the web Branding screen.**

Build a mobile screen that uses the same `PdfBranding` model. Same logo upload, same colour pickers, same cover/header/footer style choices. Mobile users get the same modern customisation experience web users have.

- **Pros:** Single consistent customisation experience across platforms. Removes the entire legacy editor stack. Mobile users benefit from the new design.
- **Cons:** Significant UI work. Needs design thinking for mobile (the web version is desktop-optimised). Not a pure cleanup — it's a feature replacement.
- **Effort:** 1-2 sessions (4-8 hours).

**Option B2: Delete `UnifiedPdfEditorScreen` entirely. Direct mobile users to the web portal for branding customisation.**

Mobile app no longer offers PDF customisation. Users who want to customise their branding go to the web portal.

- **Pros:** Cheapest option. Removes the entire legacy UI layer. Forces the web portal as the source of truth for customisation.
- **Cons:** UX regression for mobile-only users — they lose the ability to customise without a desktop. Acceptable in your current beta context (3-4 testers, all of whom can use the web portal), but worth reconsidering before public launch.
- **Effort:** Deletion + redirecting/removing nav links (1-2 hours).

**Option B3: Defer until needed.**

Leave `UnifiedPdfEditorScreen` and the legacy stack in place. Don't migrate. Live with the parallel systems until either user feedback says "I need mobile customisation" or until the legacy stack starts causing actual problems.

- **Pros:** Zero work today. The legacy stack isn't actively harmful — just technical debt.
- **Cons:** Codebase has two parallel customisation systems indefinitely. New contributors get confused. Easy to accidentally use the wrong one.
- **Effort:** 0 hours.

### Recommendation given your situation

With 3-4 testers and an active beta, **Option B2 (delete the editor) is more viable than I would have suggested for a launched product.** Your testers can use the web portal for customisation. The mobile editor doesn't need to exist for them. And deleting it removes the largest source of technical debt remaining in the PDF system.

If you want the cleanest possible state heading into Phase 4 (pricing) and beyond, B2 is the right call. You can always rebuild a mobile customisation experience later as Option B1 if user demand justifies it.

If you want to wait for evidence of user demand before deciding, B3 (defer) is fine too.

**B1 (rebuild it now) is overkill for the current stage** — building a mobile customisation experience nobody's asked for is poor use of time pre-launch.

---

### Sub-Phase 5C: Legacy Stack Deletion

**Goal:** Remove all legacy services, data classes, and Firestore documents that are no longer referenced.

**Prerequisites:** Sub-Phase 5A complete (`pdf_service.dart` migrated). Sub-Phase 5B handled (whichever option).

**Effort:** 2-3 hours mechanical deletion work.

**What gets deleted depends on Sub-Phase 5B outcome:**

If Sub-Phase 5B was Option B2 (delete editor) — recommended for current beta state:

- `lib/services/company_pdf_config_service.dart` (entire file)
- `lib/services/pdf_header_config_service.dart` (entire file)
- `lib/services/pdf_footer_config_service.dart` (entire file)
- `lib/services/pdf_colour_scheme_service.dart` (entire file)
- `lib/services/pdf_typography_service.dart` (entire file)
- `lib/services/pdf_section_style_service.dart` (entire file)
- `lib/services/branding_service.dart` (the old one — distinct from `pdf_branding_service.dart`)
- `lib/models/pdf_header_config.dart`
- `lib/models/pdf_footer_config.dart`
- `lib/models/header_text_line.dart`
- `lib/models/pdf_document_type.dart` (enum — only if no remaining callers)
- `PdfFooterBuilder.buildFooter` method (legacy variant — `pdf_service.dart` no longer uses it after 5A)

**Important nuance about `PdfColourScheme`, `PdfTypographyConfig`, `PdfSectionStyleConfig`:** Sub-Phase 5A adds a `fromBranding()` bridge factory so existing body section helpers (`PdfSectionCard`, `PdfModernTable`, etc.) keep working unchanged. Those helpers still take `PdfColourScheme` as a parameter — they're consumers of the bridge.

This means `PdfColourScheme` cannot be deleted in Sub-Phase 5C even if the editor goes away. The body section helpers are still consuming it. Same is potentially true for `PdfTypographyConfig` and `PdfSectionStyleConfig` if their `.defaults()` calls are still used. Deleting any of these requires migrating all the body section helpers to take `PdfBranding` directly — that's the body section migration's job, not Phase 5's.

So if Sub-Phase 5B is Option B2, you can delete: the editor, all the config services, and most of the legacy data classes that supported the editor's per-aspect storage. But the data classes that body helpers still consume must wait for body migration.

If Sub-Phase 5B was Option B3 (defer):

- Nothing in this list can be deleted yet — the editor consumes all of it.

**`HeaderStyle` enum collision resolution:**

Whatever path, the old `HeaderStyle` in `pdf_header_config.dart` needs renaming or deleting. The barrel file currently hides the new `HeaderStyle` in `pdf_branding.dart`. Either:

- Delete old `HeaderStyle` (along with `pdf_header_config.dart`) — possible only after Sub-Phase 5A and Sub-Phase 5B Option B2
- Or rename old `HeaderStyle` to `LegacyHeaderStyle` and remove the `hide` directive — interim measure if the legacy stack stays

**Firestore document cleanup:**

This is server-side, not code. Per the no-data-preservation decision, the orphan documents from old `pdf_config/*` paths can:

- Be left indefinitely (they're harmless — slight Firestore storage cost only)
- Be cleaned up via a one-off Cloud Function when convenient — not blocking anything

Not a priority. Worth doing eventually for tidiness, but not part of any sub-phase's core work.

**Test surface after deletion:**

- Full `flutter analyze` — must be clean.
- Generate every PDF type on web AND mobile.
- Verify the web Branding screen still works correctly.
- If Sub-Phase 5B was Option B2: verify mobile users no longer see broken nav entries pointing at the deleted editor.

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

### Lesson 12: Don't preserve user data through migrations during pre-launch beta

When the user base is small enough to inform individually (a handful of testers), migrations should cut cleanly rather than dragging legacy data preservation forward. Data preservation logic is engineering complexity you'll have to maintain, and exists primarily to avoid contacting users individually.

**Rule:** While in beta with a small tester group, breaking changes in data shape are acceptable. Inform testers, accept they may need to re-customise. Once the user base grows beyond what you can talk to directly, the calculus shifts toward preservation.

---

## Recommended Order of Operations

When you come back to Phase 5:

### Sub-Phase 5A (in progress)

Already approved and running. Pure migration to match the four-service pattern. No data preservation.

### Decision Point: Sub-Phase 5B

After 5A deploys cleanly, decide between:

- **Option B2 (delete the mobile editor)** — recommended for current beta state. Cleanest cut. Forces web portal as customisation source.
- **Option B3 (defer)** — fine if you want to see whether testers ask for mobile customisation before removing the option.

Option B1 (rebuild mobile editor) is overkill for current stage.

### Sub-Phase 5C (mostly only if B2 was chosen)

Mechanical removal of services, data classes, and the legacy footer builder method. Resolve the `HeaderStyle` enum collision. `flutter analyze` should be clean.

Note: even with Option B2, the data classes still consumed by body section helpers (`PdfColourScheme`, possibly `PdfTypographyConfig`, `PdfSectionStyleConfig`) cannot be fully deleted yet because the body helpers consume them via the `fromBranding()` bridge from Sub-Phase 5A. Full deletion of these requires the body section migration.

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

4. **If Sub-Phase 5B = Option B2 (editor deleted):**
   - Verify nav entries no longer point at the deleted editor (no broken links from settings_screen, jobs_hub_screen, invoicing_hub_screen, company_settings_screen)
   - Verify mobile users see appropriate redirect/message if they attempt customisation

5. **If Sub-Phase 5B = Option B3 (deferred):**
   - Verify `UnifiedPdfEditorScreen` still works correctly and writes data that PDF generation reads (its data is now isolated — nothing else reads it)

6. **`flutter analyze` clean across the project** — no unused imports, no orphan references.

7. **No regressions in previously-broken-and-fixed features:**
   - Logo upload (web + mobile)
   - Floor plan upload (web + mobile)
   - Asset photos, defect photos, service history photos

---

## Risks and Mitigations

### Risk: `pdf_service.dart` migration regresses jobsheet generation

**Likelihood:** Medium. It's the most complex PDF generator, used heavily.

**Mitigation:** Test on web AND mobile before declaring done. Generate a jobsheet with a typical mix of content (assets, defects, photos, signatures). Compare to a known-good PDF from before migration. If anything looks different, investigate before deploying broadly.

### Risk: Testers see different PDF body styling than they did before

**Likelihood:** Certain for any tester who customised section style or typography via mobile editor.

**Mitigation:** Inform testers in advance. They can re-customise via the new branding system once it's available to them. Per the no-data-preservation decision, this is accepted.

### Risk: `HeaderStyle` enum collision causes confusing build errors during cleanup

**Likelihood:** High during Sub-Phase 5C if not addressed.

**Mitigation:** Resolve the collision FIRST in Sub-Phase 5C — either rename old `HeaderStyle` to `LegacyHeaderStyle` (interim) or delete it (final). Do this before deleting any data classes that depend on it.

### Risk: Mobile testers expect to customise via mobile (Option B2)

**Likelihood:** Possibly high — engineers used to mobile customisation.

**Mitigation:** Inform testers explicitly. They can use the web portal for customisation. If they push back hard, reconsider Option B1 (rebuild mobile editor) at that point.

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
- **Updated:** April 2026 — incorporates the no-data-preservation decision (3-4 testers in beta, breaking changes acceptable). Updates Sub-Phase 5B recommendation toward Option B2 (delete editor) given small user base. Clarifies that data classes consumed by body section helpers (`PdfColourScheme` and possibly `PdfTypographyConfig`, `PdfSectionStyleConfig`) survive Phase 5 due to the `fromBranding()` bridge factory; full removal requires body section migration.
- **Future updates:** Update this document as Sub-Phase 5A and 5C are completed. Mark sections with their completion status.

---

## Cross-References

- `BODY_SECTION_MIGRATION_SPEC.md` — companion document covering the deeper rendering migration. Body migration is required before `PdfColourScheme` and similar can be fully deleted.
- `CLAUDE.md` — should contain Lessons 1-12 above as standing project guidance.
- `FEATURES.md` — describes what features exist and their tier (when Phase 4 happens).
- `PDF_ARCHITECTURE_REBUILD_SPEC.md` — original Phase 1-5 spec from before this week's debugging.
- `firestore.rules` — security rules covering both old `pdf_config/*` paths and new `branding/*` paths under the same permissions.

---

**End of specification.**
