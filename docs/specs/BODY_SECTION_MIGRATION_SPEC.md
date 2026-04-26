# Body Section Migration: PdfColourScheme → PdfBranding

**Status:** Specification, not yet started
**Owner:** Chris Scott
**Estimated effort:** 4-6 focused sessions
**Prerequisites:** Phase 5 work complete (or at minimum Sub-Phase 5A: `pdf_service.dart` migration)
**Hand-off target:** Claude Code (with this document as context)

---

## Purpose

The four-service migration (template, quote, invoice, BS 5839, plus compliance fix-up) brought cover, header, and footer rendering under the unified `PdfBranding` system. The bodies of every PDF — section cards, tables, field rows, signature blocks — still use the legacy `PdfColourScheme`, `PdfTypographyConfig`, and `PdfSectionStyleConfig` models.

This means a user customising their branding via the web Branding screen sees their colours and logo on the cover and header, but the body of the document still renders with hardcoded or legacy-config colours and typography. The PDFs are inconsistent end-to-end.

This migration extends the `PdfBranding` system to cover body rendering, making the entire PDF respect a user's branding choices. After this migration, the customiser tabs (Type, Layout, Content) currently labelled "coming soon" on the web Branding screen become meaningful to build — they'd control real, end-to-end behaviour instead of just the wrapper.

This is foundation work. It doesn't ship user-facing features by itself, but it unblocks them.

---

## Why This Migration Is Bigger Than the Four-Service One

The four-service migration was largely mechanical because cover/header/footer were already abstracted into `PdfCoverBuilder`, `PdfHeaderBuilder`, `PdfFooterBuilder`. Each service was just swapping the data those builders consumed.

Body section migration is structurally different. The body builders (in `lib/services/pdf_widgets/`) take richer inputs:

- `PdfColourScheme` exposes around 15 derived colours: `primaryColor`, `primaryLight`, `secondaryColor`, `textPrimary`, `textSecondary`, `textMuted`, `cardBackground`, `borderColor`, etc. Each is computed from the user's primary/secondary colour values.

- `PdfTypographyConfig` exposes named text styles: `sectionHeading`, `fieldLabel`, `fieldValue`, `tableHeader`, `footnote`, etc. Each defines size, weight, colour.

- `PdfSectionStyleConfig` exposes card decoration choices: corner radius, padding, divider style, header treatment.

The current `PdfBranding` model has none of this. It exposes primary colour, accent colour, font family, and cover/header/footer style choices. To migrate the body builders, the branding model needs to grow.

This means the migration is not "swap one parameter for another." It's:

1. **Extend the branding model** to cover everything the body needs
2. **Extend `PdfBrandTokens`** (or a new equivalent) to derive all the colours, styles, and typography the body builders need from the branding model
3. **Migrate each body builder** to take `PdfBranding` instead of the legacy configs, one at a time
4. **Verify every PDF still renders correctly** after each migration
5. **Eventually delete** `PdfColourScheme`, `PdfTypographyConfig`, `PdfSectionStyleConfig` once nothing references them

That's 4-6 focused sessions. Don't try to do it in one sitting.

---

## Context: What's Already in Place

Before starting this migration, Claude Code should familiarise itself with the existing patterns. Reading these files is worthwhile because the migration extends them:

### The Branding Model

`lib/models/pdf_branding.dart` — the unified branding data class. Currently exposes:

- `primaryColour` (hex string)
- `accentColour` (hex string)
- `logoUrl`
- `coverStyle` (Bold / Minimal / Bordered)
- `headerStyle`
- `footerStyle`
- `headerShowCompanyName`
- `footerShowPageNumbers`
- `footerText`
- Per-document-type customisation via `appliesToDocType` and `coverTextFor`

The migration will add fields to this model. That data needs to round-trip through Firestore (`toJson`/`fromJson`) and have sensible defaults via `defaultBranding()`.

### Brand Tokens

`lib/services/pdf_widgets/pdf_brand_tokens.dart` — derives `PdfColor` values from branding. Currently:

- `PdfBrandTokens.primary(branding)` returns the primary colour as a `PdfColor`

The migration will add more token getters here, derived from the same branding. This is the bridge between "user's chosen colours" and "concrete colours used in rendering."

### The Body Section Builders

These are the migration targets. Specific names may differ in your codebase — Claude Code will audit:

- `PdfSectionCard` — wraps a section with a card decoration (background, border, header bar)
- `PdfModernTable` — renders tabular data (asset registers, service history, line items)
- `PdfFieldRow` / `PdfFieldGrid` — key/value field display (site info, customer details)
- `PdfSignatureSection` / signature blocks — engineer signature capture display
- `buildModernHeader` (lowercase b — the in-page content header, distinct from `PdfHeaderBuilder.build`)
- Any `pdf_widgets/` helpers that take `PdfColourScheme` or `PdfTypographyConfig` as parameters

Each currently takes legacy config types. After migration, each takes `PdfBranding`.

### The Generators That Compose Sections

Five PDF services compose body content using the section builders above:

- `pdf_service.dart` (jobsheet) — heaviest user of body sections
- `compliance_report_service.dart` — uses asset register table, defect summary cards, service history table
- `bs5839_report_service.dart` — uses many section cards, modern tables, field grids, modern header
- `quote_pdf_service.dart` — line items table, customer section, totals, terms
- `invoice_pdf_service.dart` — same structure as quote plus payment terms section

Each one currently constructs a `PdfColourScheme` from branding's primary colour (in the build function, after the gather phase) and passes it to the body builders. After migration, each one passes `PdfBranding` directly.

---

## Migration Strategy

The migration must be staged. Doing it all at once means a giant changeset that touches every PDF and is impossible to bisect when something regresses. Stage as follows:

### Stage 1: Extend the Branding Model

**Goal:** Make `PdfBranding` expressive enough to cover body customisation, without changing any rendering yet.

Add fields to `PdfBranding`:

- **Body typography:** `bodyFontFamily` (string, falls back to brand font), `bodyTextSize` (double, default ~10), `bodyHeadingSize` (double, default ~14), `bodyTableHeaderSize` (double, default ~9)
- **Section style:** `sectionCardRadius` (double, default 8), `sectionCardPadding` (double, default 12), `sectionDividerStyle` (enum: solid/subtle/none)
- **Body colour treatment:** `bodyTextColour` (optional override; if null derive from primary/black depending on contrast), `bodyAccentColour` (optional override; if null use accent), `tableHeaderBackground` (enum: primary/accent/neutral)

Audit before adding: ask Claude Code to enumerate every field on `PdfColourScheme`, `PdfTypographyConfig`, and `PdfSectionStyleConfig` that's actually used by body builders. Some legacy fields are dead and shouldn't be carried forward. Don't blindly mirror the legacy config — only add what's actually needed.

Update `PdfBranding.fromJson`, `toJson`, `defaultBranding()`, and any `copyWith` methods to handle the new fields. Use defensive parsing per Lesson 5 below.

**Test surface for Stage 1:** Existing PDFs still generate correctly. The new branding fields exist but nothing reads them yet. `flutter analyze` clean.

**Commit message format:** `feat(branding): extend model with body typography and section style fields`

### Stage 2: Extend PdfBrandTokens

**Goal:** Add token getters that derive all the body-rendering colours and styles from `PdfBranding`.

Extend `PdfBrandTokens` (or create a new sibling class — Claude Code's call based on file size) with:

- `bodyText(branding)` — main body text colour
- `mutedText(branding)` — secondary/muted text colour
- `cardBackground(branding)` — card background colour
- `borderColour(branding)` — border colour for cards, dividers
- `tableHeaderBackground(branding)` — colour for table header rows
- `tableRowAlternate(branding)` — striped row colour
- `sectionHeadingColour(branding)` — section card header text colour
- Whatever else the audit in Stage 1 surfaced as needed

Each function should produce a `PdfColor` that visually matches what `PdfColourScheme` produces today (or improves on it where the legacy was inconsistent). Use the `_blend` helper pattern from `pdf_cover_builder.dart` to derive tints/shades from the brand colours rather than hardcoding.

Add helper functions for typography too:

- `bodyTextStyle(branding, fonts)` — returns a `pw.TextStyle` for body text
- `sectionHeadingStyle(branding, fonts)` — for section card headers
- `tableHeaderStyle(branding, fonts)` — for table headers
- `fieldLabelStyle(branding, fonts)` — for field labels
- `fieldValueStyle(branding, fonts)` — for field values

These are the new equivalents of `PdfTypographyConfig`'s named styles, but they take a non-nullable `PdfBranding` and the loaded `PdfFontRegistry` instance.

**Test surface for Stage 2:** Same as Stage 1 — nothing renders differently yet. The new tokens exist and can be called, but no body builder uses them yet. `flutter analyze` clean.

**Commit message format:** `feat(branding): extend PdfBrandTokens with body rendering tokens`

### Stage 3: Migrate Body Section Builders One at a Time

**Goal:** Each body builder migrates from legacy configs to `PdfBranding` independently. Order matters — start with the simplest and work up to the most complex.

Suggested order (Claude Code should verify with codebase audit):

1. `PdfFieldRow` / `PdfFieldGrid` — simplest, just label/value pairs
2. `PdfSectionCard` — wraps content, but only takes a few colour/style params
3. `PdfModernTable` — more complex, has header rows, alternating rows, cell padding
4. Signature section — has fonts, image embedding, layout
5. `buildModernHeader` — the in-page content header in BS 5839 reports

For each builder:

a. Add a new method or constructor parameter that takes `PdfBranding` instead of the legacy configs. Initially, both APIs coexist — the old one stays so existing callers don't break.

b. The new method internally calls `PdfBrandTokens` to get the tokens it needs. No more constructing a `PdfColourScheme` from primary colour.

c. Update each caller (in the five PDF services) to use the new method, passing `branding` directly. This is per-service work — change `pdf_service.dart` first (jobsheet), test thoroughly, then move to the next service.

d. After all callers are migrated, delete the old method/parameter that took legacy configs.

Each builder migration is one commit. Each service update is one commit. Don't bundle.

**Test surface for Stage 3:** After each builder migration AND service update, every PDF that uses that builder must be regenerated and visually compared against a known-good reference PDF from before the migration. Differences are expected to be minor (colour values might shift slightly because branding tokens derive differently than legacy ones), but anything dramatically different is a regression.

Web AND mobile testing for each service — Crashlytics shouldn't throw, kIsWeb branches should work both ways. Refer to Lesson 9 below.

**Commit message format:** `refactor(<builder name>): migrate to PdfBranding parameter`

### Stage 4: Remove Legacy Config Construction From Generators

**Goal:** After all body builders accept `PdfBranding` directly, the generators no longer need to construct `PdfColourScheme` / `PdfTypographyConfig` / `PdfSectionStyleConfig` in their build functions.

For each of the five PDF services:

- Delete the `final colors = PdfColourScheme(...)` construction in `_buildXxxPdf`
- Delete `final typography = PdfTypographyConfig(...)` if present
- Delete `final sectionStyle = PdfSectionStyleConfig(...)` if present
- The data class no longer needs `colourSchemeValue`, `headerConfigJson` (already done for some services), `sectionStyleJson`, `typographyJson` for these purposes — audit which fields are now genuinely dead

This is the same pattern as the four-service migration — collapsing data flow. The build function starts with `branding` and threads it through directly.

After this stage, no PDF service constructs a legacy config object. They're all using `PdfBranding` end-to-end.

**Test surface for Stage 4:** Generate all five PDF document types on web AND mobile. They should look essentially identical to the Stage 3 output (since Stage 3 already migrated the renderers). The data classes are slimmer.

**Commit message format:** `refactor(<service>): remove legacy config construction post-body-migration`

### Stage 5: Delete Legacy Config Classes

**Goal:** Once nothing in the codebase constructs or consumes `PdfColourScheme`, `PdfTypographyConfig`, or `PdfSectionStyleConfig`, delete them.

This stage depends on Phase 5 progress. Specifically:

- `UnifiedPdfEditorScreen` (mobile) still uses these legacy configs to write to the per-aspect Firestore documents. If `UnifiedPdfEditorScreen` is still alive (Phase 5 Sub-Phase 5B not addressed), the data classes can't be deleted yet.
- The legacy config services (`PdfColourSchemeService`, `PdfTypographyService`, `PdfSectionStyleService`, etc.) similarly stay alive while `UnifiedPdfEditorScreen` reads them.

If Phase 5 is fully complete (Sub-Phases 5A, 5B, AND 5C done):

- Delete `lib/models/pdf_colour_scheme.dart`
- Delete `lib/models/pdf_typography_config.dart`
- Delete `lib/models/pdf_section_style_config.dart`
- Delete the corresponding services
- Resolve any remaining `HeaderStyle` enum collisions
- Update `lib/models/models.dart` barrel file

If Phase 5 is not complete:

- This stage is deferred. Body migration delivers value (consistent branding throughout PDFs) without requiring legacy class deletion. The classes can stay until the editor migration happens.

**Test surface for Stage 5:** `flutter analyze` clean. Generate every PDF type, web AND mobile.

**Commit message format:** `chore: remove legacy PDF config data classes`

---

## What This Migration Does NOT Cover

To be explicit about scope:

- **Mobile PDF editor (`UnifiedPdfEditorScreen`)** — that's Phase 5 Sub-Phase 5B, not this migration. Body migration assumes the editor stays as-is.
- **Customiser tab fleshing (Type, Layout, Content)** — those tabs become buildable AFTER body migration is done. Building them is a separate effort.
- **New body sections or new document types** — out of scope. This is an architecture migration, not a feature addition.
- **Server-side Firestore migration** — old `pdf_config/*` documents stay until Phase 5 cleans them up. Body migration only touches code.

---

## Architectural Lessons (Required Reading Before Starting)

These are banked from a multi-day debugging arc earlier in April 2026. They directly affect how this migration must be done. Claude Code should read these before producing any plan.

### Lesson 1: Eager Firestore listeners cause recursion on Flutter web

`.snapshots().listen()` attached during service init or constructor causes `triggerHeartbeat → _getProvider → initializeFirestore` infinite recursion on Flutter web. We hit this three times before the pattern was clear.

**Rule for this migration:** If body migration introduces any new service that listens to Firestore, those listeners must be `kIsWeb`-guarded (skip on web) or replaced with `Stream.fromFuture(.get())` on web. Mobile keeps real-time streams. Body migration shouldn't introduce many listeners — the branding model is loaded once per PDF generation, not subscribed to. But if any code path adds one, follow the pattern.

### Lesson 2: Firestore offline persistence is disabled on web

JS SDK has long-running `INTERNAL ASSERTION FAILED: Unexpected state` bugs (firebase-js-sdk #4451, #7884, #8250) triggered by IndexedDB persistence interacting with multiple stream subscriptions. Disabled in `main.dart`:

```dart
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: !kIsWeb,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Rule for this migration:** Don't re-enable persistence. The disable is permanent until the SDK fixes it.

### Lesson 3: All Storage uploads go through `StorageUploadHelper`

`firebase_storage_web` has a silent `putData()` bug — uploads from Flutter web fire no network request, throw no error, return no result. They just hang or appear to succeed without actually uploading.

**Rule for this migration:** If any new logo handling, image embedding, or asset fetching is introduced, route uploads through `StorageUploadHelper.upload(path, bytes, contentType)`. Direct `ref.putData()` calls are forbidden.

### Lesson 4: `notifyListeners()` should not fire before async work completes if any listener might cause a re-entrant call

GoRouter's `refreshListenable` re-evaluates redirects synchronously when notified. If a redirect calls a method that notifies BEFORE its async work resolves, GoRouter re-enters the redirect during the yield, finds the same condition still true, and calls the method again — concurrent overlapping calls flood Firestore's async queue and trigger "INTERNAL ASSERTION FAILED" errors that look like SDK bugs.

**Rule for this migration:** Any new state-management pattern that involves notifying listeners during async work should either notify only after the work completes, or coalesce concurrent calls via a stored Future:

```dart
Future<void>? _loadingFuture;

Future<void> loadX() async {
  if (_loadingFuture != null) return _loadingFuture!;
  _loadingFuture = _doLoadX();
  try {
    await _loadingFuture!;
  } finally {
    _loadingFuture = null;
  }
}
```

`UserProfileService.loadProfile` is the reference implementation.

### Lesson 5: Defensive parsing in `fromJson` factories

Firestore is schemaless. Strict casts like `data['name'] as String` will crash if the field is null, missing, or a different type.

**Rule for this migration:** When extending `PdfBranding.fromJson` with new fields:

- Use nullable casts with default values: `as String? ?? ''`, `as double? ?? 8.0`
- Type-check Map values before casting
- Log unexpected types via debugPrint with prefix `[PARSE-WARN]` or similar
- Never throw — return a partial object with defaults if the data is malformed

This ensures users with old branding documents (created before the new fields existed) get sensible defaults rather than crashes.

### Lesson 6: PDF gradients with alpha are unreliable

Different PDF viewers handle alpha-channel transparency differently. We had a hard-edged dark ring on the Bold cover gradient because the renderer was interpolating accent → transparent BLACK linearly.

**Rule for this migration:** When deriving body section colours that involve transparency (e.g. card backgrounds with subtle tint, alternating row stripes, shadow-like effects), pre-blend opaque colours against the known background instead of relying on alpha. The `_blend(fg, bg, t)` helper in `pdf_cover_builder.dart` is the pattern. Use the same approach in `PdfBrandTokens` extensions.

### Lesson 7: Always run `flutter build web --release` before `firebase deploy --only hosting`

`firebase deploy --only hosting` does NOT run the Flutter build. Skipping deploys stale code.

**Rule for this migration:** Standard deploy sequence is FOUR steps:

1. `git push`
2. `flutter build web --release`
3. `firebase deploy --only hosting`
4. Hard refresh + unregister service worker (test)

Skipping step 2 has burned multiple debugging sessions.

### Lesson 8: Service workers cache aggressively

After every deploy, the service worker must be unregistered via DevTools (Application → Service Workers → Unregister) before testing. Otherwise stale code is served.

**Rule for this migration:** When testing changes from this migration on web, always unregister the service worker AND hard-refresh with cache disabled before declaring the deploy "tested."

### Lesson 9: Crashlytics doesn't support Flutter web

`FirebaseCrashlytics.instance.recordError()` will throw on web.

**Rule for this migration:** Any error path that uses Crashlytics needs `if (!kIsWeb)` guard. Web fallback should use a distinctive debugPrint prefix so logs can be grep'd. Recommended prefixes: `[BRANDING-RESOLUTION]` for branding errors (matches existing pattern), `[BODY-RENDER]` for body-rendering errors if any.

### Lesson 10: Demand actual diffs, not summaries

When proposing code changes, present the actual `git diff` output (or before/after blocks). Summaries can hide details that matter — type swaps, dependency removals, helper deletions — that need eyes on them before applying.

**Rule for this migration:** Every commit's diff should be reviewed before applying. No bundled "let me apply all the changes now" — show what's about to land per commit.

### Lesson 11: When multiple unrelated features fail in similar ways at the same time, suspect ONE underlying cause

Four separate-looking bugs earlier this month turned out to be three SDK fragilities plus one architectural bug in `loadProfile`. They looked like four problems requiring four fixes. They were downstream symptoms of fewer root causes.

**Rule for this migration:** If during testing multiple PDF types regress at once, don't assume they're separate regressions. Suspect a shared dependency — the branding tokens, the font registry, the data class. Find the common cause first.

---

## Risks and Mitigations

### Risk: `pdf_service.dart` regression has wide blast radius

`pdf_service.dart` (jobsheet) is the most-used PDF generator. Any visual regression from body migration would affect every engineer's output.

**Mitigation:** Migrate `pdf_service.dart` LAST among the five services in Stage 3. By then, the pattern is proven on the four other services. Keep a pre-migration reference jobsheet PDF on hand for visual comparison after migration.

### Risk: Branding tokens produce visibly different colours than legacy configs

`PdfColourScheme` derives `textMuted`, `cardBackground`, etc. via specific blend formulas. The new tokens may use slightly different formulas, producing slightly different visual results.

**Mitigation:** Compare visual output stage by stage. Minor shifts are acceptable (the migration is a visual cleanup). Dramatic shifts mean the formula needs adjustment. Don't accept "close enough" — match or improve, but don't regress.

### Risk: `UnifiedPdfEditorScreen` writes data the new system doesn't read

If a mobile user customises their PDFs via the legacy editor while body migration is in flight, their settings might be lost or partially applied.

**Mitigation:** Body migration doesn't change what the editor writes. As long as `pdf_service.dart` (which the editor configures) still reads the editor's output, mobile customisation continues to work. Stage 4 is where this could break — be careful when removing legacy config construction in `pdf_service.dart` to ensure the editor's stored data is still honoured (or migrate it to branding format as part of Stage 4).

### Risk: New `PdfBranding` fields aren't backward-compatible with existing branding documents

Users with existing `branding/main` documents in Firestore have those documents without the new fields. Reading them with strict types would crash.

**Mitigation:** Defensive parsing in `fromJson` (Lesson 5). Every new field must have a sensible default for documents that don't have it.

### Risk: Mobile users see different output than web users post-migration

If body migration changes how PDFs render on web before mobile (or vice versa), users could see inconsistent output across devices for the same job.

**Mitigation:** Each service migration must be tested on BOTH web and mobile before declaring done. Don't merge a service migration that only renders correctly on one platform.

---

## Test Plan for Migration Completion

After every stage completes, these tests must pass:

### Functional tests

1. **Generate every PDF type on web:**
   - Compliance report
   - Jobsheet (template)
   - Quote
   - Invoice
   - BS 5839 report

2. **Generate every PDF type on mobile (iOS or Android):**
   - Same five document types
   - Verify Crashlytics doesn't throw
   - Verify branding applies correctly

3. **Verify visual consistency end-to-end:**
   - Cover, header, footer use branding colours/fonts ✓ (already done)
   - Section cards use branding colours/fonts ✓ (this migration)
   - Tables use branding colours/fonts ✓ (this migration)
   - Field rows/grids use branding colours/fonts ✓ (this migration)
   - Signature blocks use branding fonts ✓ (this migration)

4. **Branding customisation propagates everywhere:**
   - Change primary colour in web Branding screen → reflected in section card backgrounds, table headers, field labels in next generated PDF
   - Change accent colour → reflected wherever accent is used
   - Upload logo → appears on cover, header, AND any in-body usage

### Edge case tests

5. **Existing branding documents (created before new fields):**
   - User opens Branding screen → defaults populate for new fields
   - User generates PDF → defaults render correctly
   - User saves branding (re-saving with new fields) → no data loss

6. **Mobile editor still works (if `UnifiedPdfEditorScreen` is alive):**
   - Customise via mobile editor → PDFs reflect those choices
   - Customisations don't conflict with branding

7. **`flutter analyze` clean** at the end of every stage.

---

## When to Pause This Migration

Some signals to stop and reassess rather than push through:

- **A stage takes substantially longer than estimated.** If Stage 3's first builder migration takes 4 hours instead of the expected 1-2, the pattern might be wrong. Stop, reassess.
- **Visual regressions can't be tracked down.** If a PDF looks different after migration and the cause isn't obvious, don't ship it. Investigate before continuing.
- **A different priority arises.** Body migration is foundation work. If a paying-customer issue or a critical feature need comes up, pause this and address that first.
- **Phase 5 Sub-Phase 5B blocks Stage 5.** If `UnifiedPdfEditorScreen` is alive, the legacy config classes can't be deleted in Stage 5. That's fine — Stage 5 becomes "deferred until Phase 5 completes" rather than a blocker for the migration's value.

---

## Recommended Order of Operations

1. **Now:** Hand this document to Claude Code along with whatever Phase 5 progress has been made.
2. **First Claude Code session:** Audit. Don't write code. Have Claude Code enumerate every body builder, every consumer of legacy configs, every field on `PdfColourScheme`/`PdfTypographyConfig`/`PdfSectionStyleConfig` that's actually used. Produce a customised plan with specific file paths and line numbers.
3. **Approve the plan, then proceed stage by stage.** Each stage is its own session.
4. **After Stage 4:** Body migration delivers most of its value (consistent end-to-end branding). Stage 5 (deletion) can wait for Phase 5 to complete `UnifiedPdfEditorScreen` migration.
5. **After body migration:** The "Type", "Layout", and "Content" tabs on the web Branding screen become buildable as meaningful features — they'd control real, end-to-end behaviour. That's a separate effort.

---

## Hand-Off Prompt for Claude Code

Suggested first prompt to give Claude Code along with this document:

> I want to implement the body section migration described in this specification. Before any code changes, audit the current codebase:
>
> 1. **List every body builder** in `lib/services/pdf_widgets/` and elsewhere that takes `PdfColourScheme`, `PdfTypographyConfig`, or `PdfSectionStyleConfig` as a parameter. For each, show the function signature, what fields it actually reads from those configs, and which PDF services call it.
>
> 2. **List every field on `PdfColourScheme`, `PdfTypographyConfig`, `PdfSectionStyleConfig`** that's actually used by any consumer. Distinguish between "used by a body builder" (must carry forward into branding model) and "used only by `UnifiedPdfEditorScreen`" (can stay on legacy config until that screen migrates).
>
> 3. **Audit `PdfBrandTokens`** — what's currently defined, and what would need to be added to cover the body builders' needs.
>
> 4. **Identify any cross-cutting concerns** — places where body builders use other utilities (font loading, helper functions) that might need updates.
>
> Don't propose any code changes yet. Produce the audit, then we'll customise the plan in this specification based on what you find.

---

## Document History

- **Initial draft:** April 2026, after Phase 5 specification was produced and the Phase 1 / four-service migration / recursion fix arc was complete.
- **Future updates:** Mark each stage as complete when it lands. Update with any new architectural lessons learned during the migration.

---

## Cross-References

- `PHASE_5_LEGACY_PDF_CLEANUP_SPEC.md` — companion document covering the legacy stack cleanup. Body migration depends on Phase 5 Sub-Phase 5A but doesn't require Sub-Phase 5B/5C.
- `CLAUDE.md` — should contain Lessons 1-11 above as standing project guidance.
- `FEATURES.md` — describes user-facing features. Body migration doesn't add any directly, but unblocks customiser tab work that does.
- `PDF_ARCHITECTURE_REBUILD_SPEC.md` — original Phase 1-5 spec, predates this migration spec.

---

**End of specification.**
