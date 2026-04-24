# PDF Architecture Rebuild — Unified Spec

**Status:** Approved for implementation
**Total effort:** ~5-7 weeks elapsed, ~20-24 focused Claude Code sessions
**Prerequisites:**
- The existing web branding customiser is live and working
- `lib/theme/web_theme.dart` exists with FtColors/FtText/etc
- The four PDF services already consume `PdfBranding` conditionally (as per
  the original `PDF_BRANDING_SPEC.md` work)
- `PdfBrandingService` exists at `lib/services/pdf_branding_service.dart`
- `PdfBranding` model exists at `lib/models/pdf_branding.dart`

**Reference:**
- Web preview behaviour: `docs/web-redesign-extras/prototypes/pdf_customiser.html`
- Existing branding spec this builds on: `docs/web-redesign-extras/specs/PDF_BRANDING_SPEC.md`

---

## The problem we're solving

Right now the web customiser's live preview looks great, but the actual PDF
output doesn't match it — the PDF still has the old mobile-era visual
language with a recoloured header slapped on top. That's a trust problem:
the preview promises something the PDF doesn't deliver.

Separately, we need to split customisation into two tiers so that this
feature can support subscription pricing — solo engineers and companies
both deserve good-looking PDFs, but the rich editing experience (web
customiser with live preview across four doc types) is premium.

This spec consolidates both concerns into one coordinated rebuild across
five phases.

---

## Phases at a glance

1. **Rendering rebuild** — make PDF output match the web preview
2. **Branding source split** — company vs personal branding paths
3. **Simplified mobile customiser** — new mobile UI for personal branding
4. **Tier gating** — permission checks + entitlement resolution
5. **Deprecate old editors** — migrate legacy config, remove mobile editors

Do them in order. Each phase builds on the previous one. Don't skip ahead
because later phases assume earlier ones are done.

---

## What does NOT change

- `lib/screens/floor_plans/interactive_floor_plan_screen.dart` — leave alone
- `lib/models/dispatched_job.dart`, `Asset`, `ServiceRecord` — data models unchanged
- Firestore security rules for existing collections (only adding new ones)
- Mobile screens outside `lib/screens/settings/` and the new branding UI
- The web portal's other screens (dashboard, job detail, schedule, etc)
- Any Cloud Functions that exist today

---

# PHASE 1 — Rendering rebuild

**Effort:** ~2 weeks elapsed, 3-4 sessions
**Goal:** Make PDF output match the web preview for the three cover styles
(Bold / Minimal / Bordered) and the typography throughout.

## What's wrong today

The web customiser's `pdf_preview_report.dart` etc. render as Flutter
widgets with proper typography (Outfit display font, Inter body, proper
colour gradients, radial glows on the Bold cover). The actual PDF produced
by `lib/services/pdf_widgets/pdf_cover_builder.dart` uses the `pdf` package
but doesn't implement the same design — it produces something that looks
like the old mobile-era PDFs with a recoloured header.

The gap is specifically:

- Typography — PDFs use default Helvetica, not registered Outfit/Inter
- Cover page layout — bears only superficial resemblance to the web preview
- Section titles and eyebrow text — don't match the web preview's scale or
  weight
- Colour treatment — flat colours instead of the amber radial glow on Bold
  covers, thick navy bars on Bordered covers, amber divider on Minimal
- Summary grid cards — rendered as plain tables instead of the cell grid
  shown in the preview

## What we're building

A rebuilt `PdfCoverBuilder` plus supporting PDF widget work that produces
PDFs visually faithful to the web preview. "Visually faithful" means:
someone looking at a screenshot of the web preview and a screenshot of the
generated PDF says "those are the same thing" — not pixel-identical, but
clearly the same design language.

## Files to create or modify

**New:**
- `lib/services/pdf_widgets/pdf_font_registry.dart` — loads and registers
  Outfit + Inter + JetBrains Mono for use in PDFs
- `lib/services/pdf_widgets/pdf_brand_tokens.dart` — parallel to `web_theme.dart`
  but for `pw.Widget` — reusable text styles, spacing, colours expressed
  as PDF types
- `assets/fonts/outfit/` — TTF files for Outfit weights 600, 700, 800
- `assets/fonts/inter/` — TTF files for Inter weights 400, 500, 600, 700
- `assets/fonts/jetbrains-mono/` — TTF files for JetBrains Mono

**Rewritten (complete replacement of existing file contents):**
- `lib/services/pdf_widgets/pdf_cover_builder.dart` — three cover style
  implementations matching the preview
- `lib/services/pdf_widgets/pdf_modern_header.dart` — Solid/Minimal/Bordered
  page header treatments
- `lib/services/pdf_footer_builder.dart` — Light/Minimal/Coloured footer
  treatments

**Modified (wire up new fonts and cover builder):**
- `lib/services/compliance_report_service.dart`
- `lib/services/quote_pdf_service.dart`
- `lib/services/invoice_pdf_service.dart`
- `lib/services/template_pdf_service.dart`
- `lib/services/bs5839_report_service.dart`
- `pubspec.yaml` — declare font assets

## Font registration

Fonts must be registered with the `pdf` package before any PDF is generated.
The registry loads them once and caches. Pattern:

```dart
// lib/services/pdf_widgets/pdf_font_registry.dart

class PdfFontRegistry {
  PdfFontRegistry._();
  static final PdfFontRegistry instance = PdfFontRegistry._();

  pw.Font? _outfitDisplay;       // weight 800
  pw.Font? _outfitBold;          // weight 700
  pw.Font? _interRegular;        // weight 400
  pw.Font? _interMedium;         // weight 500
  pw.Font? _interSemibold;       // weight 600
  pw.Font? _interBold;           // weight 700
  pw.Font? _mono;                // JetBrains Mono 500

  /// Call once at app startup (e.g., in main.dart before runApp).
  Future<void> ensureLoaded() async {
    if (_outfitDisplay != null) return; // already loaded
    _outfitDisplay = pw.Font.ttf(await rootBundle.load('assets/fonts/outfit/Outfit-ExtraBold.ttf'));
    _outfitBold    = pw.Font.ttf(await rootBundle.load('assets/fonts/outfit/Outfit-Bold.ttf'));
    _interRegular  = pw.Font.ttf(await rootBundle.load('assets/fonts/inter/Inter-Regular.ttf'));
    _interMedium   = pw.Font.ttf(await rootBundle.load('assets/fonts/inter/Inter-Medium.ttf'));
    _interSemibold = pw.Font.ttf(await rootBundle.load('assets/fonts/inter/Inter-SemiBold.ttf'));
    _interBold     = pw.Font.ttf(await rootBundle.load('assets/fonts/inter/Inter-Bold.ttf'));
    _mono          = pw.Font.ttf(await rootBundle.load('assets/fonts/jetbrains-mono/JetBrainsMono-Medium.ttf'));
  }

  pw.Font get outfitDisplay => _requireLoaded(_outfitDisplay);
  pw.Font get outfitBold    => _requireLoaded(_outfitBold);
  pw.Font get interRegular  => _requireLoaded(_interRegular);
  pw.Font get interMedium   => _requireLoaded(_interMedium);
  pw.Font get interSemibold => _requireLoaded(_interSemibold);
  pw.Font get interBold     => _requireLoaded(_interBold);
  pw.Font get mono          => _requireLoaded(_mono);

  pw.Font _requireLoaded(pw.Font? f) {
    if (f == null) {
      throw StateError('PdfFontRegistry.ensureLoaded() must be called before use');
    }
    return f;
  }
}
```

Every PDF service calls `await PdfFontRegistry.instance.ensureLoaded();` at
the top of its generation function before building widgets. The registry
caches so subsequent calls are free.

Font source: download Outfit and Inter from Google Fonts as TTF. Pick weights
that match what the web uses (Outfit 700/800, Inter 400/500/600/700). Commit
the TTF files into the repo under `assets/fonts/`. Don't try to download them
at runtime — PDFs need to generate offline.

## Brand tokens

`pdf_brand_tokens.dart` is the PDF-side parallel of `web_theme.dart`. Where
`web_theme.dart` has `FtColors.primary`, this file has
`PdfBrandTokens.primaryColor()` returning a `PdfColor`. Where `FtText.pageTitle`
is a Flutter `TextStyle`, `PdfBrandTokens.pageTitle()` returns a `pw.TextStyle`.

The reason this is a new file rather than extending
`pdf_typography_service.dart`: the existing typography service is part of
the old per-doctype config system that Phase 5 will deprecate. The new
token file is the replacement.

Pattern:

```dart
class PdfBrandTokens {
  PdfBrandTokens._();

  static PdfColor primary(PdfBranding b) => _parseHex(b.primaryColour);
  static PdfColor accent(PdfBranding b)  => _parseHex(b.accentColour);

  static pw.TextStyle coverTitle(PdfBranding b) => pw.TextStyle(
    font: PdfFontRegistry.instance.outfitDisplay,
    fontSize: 34,
    fontWeight: pw.FontWeight.w800,
    letterSpacing: -0.8,
    color: _coverTextColor(b.coverStyle, primary(b)),
  );

  static pw.TextStyle coverSubtitle(PdfBranding b) => pw.TextStyle(
    font: PdfFontRegistry.instance.interMedium,
    fontSize: 14,
    color: _coverTextColor(b.coverStyle, primary(b)).withOpacity(0.75),
  );

  static pw.TextStyle sectionEyebrow(PdfBranding b) => pw.TextStyle(
    font: PdfFontRegistry.instance.interBold,
    fontSize: 9,
    fontWeight: pw.FontWeight.w700,
    letterSpacing: 1.2,
    color: accent(b),
  );

  static pw.TextStyle sectionTitle(PdfBranding b) => pw.TextStyle(
    font: PdfFontRegistry.instance.outfitDisplay,
    fontSize: 22,
    fontWeight: pw.FontWeight.w800,
    letterSpacing: -0.5,
    color: primary(b),
  );

  // ... body, label, mono, etc.
}
```

Every text element in every PDF builder uses these. Banned: hardcoded
`pw.TextStyle` declarations in builder files.

## Cover builder rewrite

The three cover styles implemented in detail. Each is a full-page
`pw.Widget` rather than a `pw.Page` (the service wraps it in a Page). This
lets the cover share a document with other pages.

**Bold cover** — the signature style. Navy background (primary colour),
amber radial gradient glow in the top-right corner, white text, amber logo
mark, large Outfit display title, Inter meta grid at the bottom.

Reference: the web preview's `pdf-cover` class without the `style-minimal`
or `style-bordered` modifiers. Study the HTML layout of
`prototypes/pdf_customiser.html` for structure.

Specific implementation notes:

- Navy background: `pw.Container` with `decoration: pw.BoxDecoration(color: primary)`
- Radial glow: the `pdf` package does support radial gradients via
  `pw.BoxDecoration(gradient: pw.RadialGradient(...))`. Place a stack-like
  positioned container in the top-right with the amber gradient fading to
  transparent. If `RadialGradient` proves too fiddly in a Page context,
  acceptable fallback: a subtle amber `LinearGradient` from top-right corner
  to mid-page centre.
- Logo mark: `pw.Container` with amber background, rounded corners
  (`borderRadius`), logo image inside. Falls back to a company-initial
  letter in Outfit if no logo uploaded.
- Title: Outfit 800, 34-42px, line-height tight, letter-spacing -0.8 to -1.2
- Subtitle: Inter 500, 14-16px, 75% white opacity
- Meta grid: 2-column grid with label (Inter 700, 10px, uppercase, 50%
  white) above value (Inter 600, 14px, white)
- Top border of meta grid: thin white line at 15% opacity

**Minimal cover** — white background, black/navy text, amber 4px-wide
horizontal divider above the eyebrow. Logo on left, simple layout, no
glows or decorations.

**Bordered cover** — white background, thick navy bars at the top (8px) and
bottom (8px) of the page, same content as Minimal in between.

Each cover style is a separate private function:

```dart
class PdfCoverBuilder {
  PdfCoverBuilder._();

  static pw.Widget build({
    required PdfBranding branding,
    required BrandingDocType docType,
    required String defaultEyebrow,
    required String defaultTitle,
    required String defaultSubtitle,
    required List<({String label, String value})> metaFields,
    required Uint8List? logoBytes,
    required String companyName,
  }) {
    // Resolve text: use branding override if set, otherwise default
    final coverText = branding.coverTextFor(docType);
    final eyebrow = coverText?.eyebrow ?? defaultEyebrow;
    final title = coverText?.title ?? defaultTitle;
    final subtitle = coverText?.subtitle ?? defaultSubtitle;

    switch (branding.coverStyle) {
      case CoverStyle.bold:     return _buildBold(branding: branding, ...);
      case CoverStyle.minimal:  return _buildMinimal(branding: branding, ...);
      case CoverStyle.bordered: return _buildBordered(branding: branding, ...);
    }
  }

  static pw.Widget _buildBold({...}) { /* ~80 lines */ }
  static pw.Widget _buildMinimal({...}) { /* ~60 lines */ }
  static pw.Widget _buildBordered({...}) { /* ~70 lines */ }
}
```

## Page header rebuild

The existing `pdf_modern_header.dart` is a generic header. Rewrite it to
accept a `HeaderStyle` and render the three variants (Solid / Minimal /
Bordered). The structure is the same for all three — logo on left, doc
reference on right — but the colours and borders differ.

```dart
// Entry point
static pw.Widget pageHeader({
  required PdfBranding branding,
  required String companyName,
  required String documentReference, // e.g. "Cert № BS-2026-04-1107 · 21 April 2026"
  required Uint8List? logoBytes,
}) {
  // Conditional: if branding.headerShowCompanyName is false, don't include it
  // Conditional: if branding.headerShowDocNumber is false, don't include the ref

  switch (branding.headerStyle) {
    case HeaderStyle.solid:    return _solidHeader(...);   // navy bg, white text
    case HeaderStyle.minimal:  return _minimalHeader(...); // white bg, navy text, 2px amber border-bottom
    case HeaderStyle.bordered: return _borderedHeader(...);// white bg, navy text, 1px grey border-bottom
  }
}
```

## Footer rebuild

Same pattern as header. `pdf_footer_builder.dart` gains three style
variants (Light / Minimal / Coloured). Page numbers always render on the
right regardless of style.

## Wiring changes to the five PDF services

Each service needs two changes:

1. Call `await PdfFontRegistry.instance.ensureLoaded()` at the top of
   its generation method
2. Replace the existing cover/header/footer logic with calls to the new
   `PdfCoverBuilder.build()`, `PdfHeaderBuilder.pageHeader()`,
   `PdfFooterBuilder.pageFooter()` — all receiving the `PdfBranding` object

Don't delete the existing `pdf_header_config_service` / `pdf_footer_config_service`
etc. yet — Phase 5 handles that migration. For now, if branding is present,
new builders are used; if branding is null (falls through for doc types not in
`appliesTo`), the old builders keep working as a fallback.

This means the five services temporarily have two code paths. Ugly but safe.

## Definition of done (Phase 1)

- `PdfFontRegistry.ensureLoaded()` registers all seven fonts without error
- `assets/fonts/` folder exists with all required TTF files, declared in pubspec.yaml
- Generating a compliance report PDF on an iPhone produces a cover page
  that, when screenshotted and compared to the web preview, is clearly the
  same design language
- Same for quote, invoice, jobsheet, BS 5839 report
- All three cover styles produce visually correct PDFs (Bold / Minimal /
  Bordered)
- All three header styles produce visually correct PDFs
- All three footer styles produce visually correct PDFs
- Typography: titles render in Outfit, body renders in Inter, mono text
  renders in JetBrains Mono — no default Helvetica fallback anywhere
- Colours: primary + accent from `PdfBranding` are applied throughout
- Logo renders correctly when uploaded (test with PNG, JPG, SVG)
- PDFs generate within 3 seconds on mid-range phones (font loading is
  one-time; subsequent generations should be <1s)
- Web "Generate test PDF" button produces output that matches what the
  mobile app produces for the same branding config

## Session breakdown (Phase 1)

### Session 1.1 — Font registry + assets

Download Outfit and Inter TTFs from Google Fonts, place them in
`assets/fonts/`. Download JetBrains Mono. Update `pubspec.yaml` asset
declarations. Create `lib/services/pdf_widgets/pdf_font_registry.dart`
with the `ensureLoaded()` pattern. Add a call to it in `main.dart` before
`runApp`. Verify fonts load by writing a tiny test that generates a
one-page PDF with just "Hello in Outfit" rendered in each weight.

### Session 1.2 — Brand tokens + cover builder

Create `lib/services/pdf_widgets/pdf_brand_tokens.dart`. Rewrite
`lib/services/pdf_widgets/pdf_cover_builder.dart` with all three cover
style implementations. Build against test data (no real PDF service wiring
yet). Generate sample output PDFs for each style and compare to the web
preview visually. Iterate until they match.

### Session 1.3 — Header + footer rebuild + one service wiring

Rewrite `pdf_modern_header.dart` and `pdf_footer_builder.dart` with style
variants. Wire up ONE PDF service end-to-end
(`compliance_report_service.dart`): register fonts, use new cover, use new
header, use new footer. Generate a real compliance PDF on iOS and on
Android, compare to web preview, iterate.

### Session 1.4 — Remaining four services

Apply the same wiring to `quote_pdf_service.dart`,
`invoice_pdf_service.dart`, `template_pdf_service.dart`, and
`bs5839_report_service.dart`. Generate one of each on iOS, verify all
five look consistent and match the preview.

---

# PHASE 2 — Branding source split

**Effort:** ~3-4 days, 2 sessions
**Goal:** Allow branding to be stored at either company or user level, with
resolution logic that picks the right one at PDF generation time.

## The model

Two possible storage locations for a `PdfBranding`:

- **Company-level** — `companies/{companyId}/branding/main`
  (already exists, no change)
- **User-level** — `users/{userId}/branding/main` (NEW)

Resolution logic at PDF generation time:

1. If the user is part of a company (has `companyId` set in their profile):
   - Use company branding from `companies/{companyId}/branding/main`
   - Fall back to `PdfBranding.defaultBranding()` if no company branding exists
2. If the user is NOT part of a company (solo):
   - Use personal branding from `users/{userId}/branding/main`
   - Fall back to `PdfBranding.defaultBranding()` if no personal branding
     exists

User-level branding is never applied to users in a company, even if it
exists. The company's brand wins for anyone on the company's plan.

## Files to modify

- `lib/services/pdf_branding_service.dart` — add user-level methods + resolution

## Service changes

```dart
class PdfBrandingService {
  // EXISTING — company-level methods stay
  Future<PdfBranding> getBranding(String companyId) async {...}
  Stream<PdfBranding> watchBranding(String companyId) {...}
  Future<void> saveBranding(String companyId, PdfBranding branding) async {...}

  // NEW — user-level methods
  Future<PdfBranding> getPersonalBranding(String userId) async {...}
  Stream<PdfBranding> watchPersonalBranding(String userId) {...}
  Future<void> savePersonalBranding(String userId, PdfBranding branding) async {...}

  // NEW — the resolver the PDF services call
  /// Returns the branding that should be used for PDF generation,
  /// based on whether the current user is in a company.
  Future<PdfBranding> resolveBrandingForCurrentUser() async {
    final profile = UserProfileService.instance;
    if (profile.companyId != null) {
      return getBranding(profile.companyId!);
    }
    return getPersonalBranding(profile.userId!);
  }
}
```

The five PDF services stop calling `getBranding(companyId)` directly and
call `resolveBrandingForCurrentUser()` instead. This is a one-line change
per service.

## Firestore rules

Add a rule for the new user-level branding:

```
match /users/{userId}/branding/{docId} {
  allow read, write: if request.auth.uid == userId;
}
```

No permission check — solo users own their own branding. If they later
join a company, their personal branding becomes inert (not deleted, just
unused).

## Definition of done (Phase 2)

- User-level branding can be saved and retrieved
- `resolveBrandingForCurrentUser()` returns company branding for company
  users, personal branding for solo users
- Changing personal branding for a solo user produces a correctly branded
  PDF
- Changing company branding for a company user produces a correctly branded
  PDF (no regression from Phase 1)
- A solo user's personal branding does NOT affect their PDFs if they later
  join a company (company branding takes precedence)
- Firestore rules enforce that users can only edit their own branding

## Session breakdown (Phase 2)

### Session 2.1 — Service methods + resolver

Add the three new methods to `PdfBrandingService` (`getPersonalBranding`,
`watchPersonalBranding`, `savePersonalBranding`) plus the
`resolveBrandingForCurrentUser()` resolver. Update the Firestore rules.
Write tests for the resolver logic.

### Session 2.2 — Wire the five PDF services + verify

Replace `getBranding(companyId)` with `resolveBrandingForCurrentUser()`
in all five PDF services. Manually test: create a solo user account, save
personal branding with a red primary colour, generate a compliance report
(should be red). Create a company user, save company branding with a blue
primary colour, generate the same report (should be blue). Check the
solo user's personal branding does not leak into the company user's PDFs.

---

# PHASE 3 — Simplified mobile customiser

**Effort:** ~1 week, 3-4 sessions
**Goal:** Build a new mobile customiser for personal branding that's
simpler than the web version but produces the same PDF output quality.

## The approach

Not a port of the web customiser. A deliberately simpler experience for
mobile's smaller screens and for users who don't need the full control set.

The mobile UI offers:

- A choice of **5 preset brand kits** (pre-designed colour combinations —
  see "Presets" below)
- **Logo upload** (same as web)
- **One colour override** — user can tap the primary colour of their
  chosen preset to tweak it
- **Cover style picker** (Bold / Minimal / Bordered — same three styles)

No custom hex input for colours. No per-doc-type cover text overrides. No
footer text customisation (footer shows company name only — defaults to
the user's display name for solo users). No header style selection
(defaults to Minimal which looks universally acceptable).

The thinking: mobile customisation is for solo engineers who want their
PDFs to look "like them" without having to art-direct. Choosing a preset
kit + uploading their logo gets them 90% of the way to a branded PDF with
five taps.

## Presets

Five starter kits, each tuned to work well together (colour theory has
been pre-applied by the designer — i.e. you, with my help):

```dart
// lib/models/branding_preset.dart
class BrandingPreset {
  final String id;
  final String name;
  final String description;
  final String primaryColour;
  final String accentColour;
  final CoverStyle suggestedCoverStyle;

  static const List<BrandingPreset> all = [
    BrandingPreset(
      id: 'firething',
      name: 'FireThings',
      description: 'Our signature navy and amber.',
      primaryColour: '#1A1A2E',
      accentColour: '#FFB020',
      suggestedCoverStyle: CoverStyle.bold,
    ),
    BrandingPreset(
      id: 'graphite',
      name: 'Graphite',
      description: 'Classic, understated, professional.',
      primaryColour: '#18181B',
      accentColour: '#DC2626',
      suggestedCoverStyle: CoverStyle.bordered,
    ),
    BrandingPreset(
      id: 'forest',
      name: 'Forest',
      description: 'Deep green with copper highlights.',
      primaryColour: '#064E3B',
      accentColour: '#D97706',
      suggestedCoverStyle: CoverStyle.bold,
    ),
    BrandingPreset(
      id: 'slate',
      name: 'Slate',
      description: 'Cool and contemporary.',
      primaryColour: '#334155',
      accentColour: '#0EA5E9',
      suggestedCoverStyle: CoverStyle.minimal,
    ),
    BrandingPreset(
      id: 'heritage',
      name: 'Heritage',
      description: 'Traditional burgundy and gold.',
      primaryColour: '#7C1D12',
      accentColour: '#B45309',
      suggestedCoverStyle: CoverStyle.bordered,
    ),
  ];
}
```

Users pick a preset, which sets primary/accent/cover style in one tap.
They can then optionally tweak the primary colour via a simple colour picker
(hue slider, no hex input).

## Files to create

```
lib/models/
└── branding_preset.dart                   ← the preset definitions

lib/screens/settings/branding/
├── personal_branding_screen.dart          ← new top-level screen
└── widgets/
    ├── preset_picker.dart                 ← grid of 5 preset cards
    ├── preset_card.dart                   ← individual preset card
    ├── branding_logo_mobile.dart          ← logo upload/preview/remove
    ├── cover_style_picker.dart            ← three style cards
    └── primary_colour_tweaker.dart        ← hue slider with live preview
```

## UX flow

When the user enters the screen for the first time:

1. A simple explainer at the top: "Personal branding appears on all your
   PDFs. Pick a preset to get started."
2. Preset picker — five large cards, each showing its colour pair and a
   small cover-page mini-preview. User taps one → becomes selected.
3. Logo upload section — "Add your logo (optional)"
4. Cover style picker — only shows if user taps "customise further"
   below the preset. Defaults to the preset's suggested style.
5. Primary colour tweak — only shows if user taps "tweak colour" below
   the preset. Opens a hue slider that modifies primary only.
6. Small live preview at the bottom — shows a mini PDF cover that
   updates as settings change. Same widget as the web preview but sized
   for mobile.
7. "Generate test PDF" button at the bottom — produces a real sample PDF.

## Route integration

New route in the app's navigation:

- Settings screen gains a "Personal Branding" tile (visible ONLY when user
  is not in a company — hidden for company users because they can't edit
  their personal branding anyway; company branding is set via web)
- Tile routes to `PersonalBrandingScreen`

For company users, the existing Settings screen's "PDF Design" tile stays
as it is in Phase 3 (the old per-doctype editors). Phase 5 removes that.

## Definition of done (Phase 3)

- Solo user can open Personal Branding screen from Settings
- Picking a preset updates the primary/accent/cover style in Firestore
- Logo upload works, validates size + type, shows preview
- Cover style picker changes the preset's cover style
- Primary colour tweaker adjusts primary hue while keeping accent stable
- Mini live preview updates within 100ms of any change
- "Generate test PDF" button produces a real compliance-style PDF with the
  current settings
- Company users do NOT see the Personal Branding tile in Settings
- Solo user's PDFs (compliance, jobsheet, invoice, quote) all use their
  personal branding

## Session breakdown (Phase 3)

### Session 3.1 — Preset model + screen scaffold

Create `branding_preset.dart` with the five presets. Create
`personal_branding_screen.dart` scaffold with the explainer, preset picker
placeholder, logo section placeholder, and a test-PDF button. Wire
visibility: tile appears in Settings only for solo users.

### Session 3.2 — Preset picker + logo upload

Build the preset grid widget with tappable cards. Wire preset selection
to save to `users/{uid}/branding/main` via `savePersonalBranding`. Build
logo upload widget using the same upload logic as the web customiser.

### Session 3.3 — Cover style picker + colour tweaker + live preview

Build the cover style picker (three cards for Bold/Minimal/Bordered). Build
the primary colour tweaker (hue slider, simple). Build the mini live
preview (reuse the `pdf_preview_page.dart` concept from the web customiser,
scaled down for mobile).

### Session 3.4 — Test PDF button + full end-to-end

Wire the test-PDF button to call `compliance_report_service.dart` with
sample data and the current personal branding. Download or open the PDF.
End-to-end test: set branding, generate test PDF, verify it matches the
preview.

---

# PHASE 4 — Tier gating

**Effort:** ~1 week, 5 sessions (includes RevenueCat integration)
**Goal:** Gate the web customiser, compliance reports, and BS 5839 reports
behind Pro tier. Gate advanced features behind Premium tier. Personal
branding on mobile available to everyone. RevenueCat SDK integrated for
real subscription handling.

**⚠️ IMPORTANT:** RevenueCat dashboard setup (creating the project,
adding products in App Store Connect / Play Console / Stripe, configuring
webhooks) must be completed BY YOU before Session 4.4. Claude Code cannot
do these dashboard steps — they require signing into third-party services.

## The tier structure

Three tiers as resolved in the "Resolved decisions" section at the top of
this spec. Capability mapping:

**Free** — solo engineers, personal branding only, no compliance reports,
no web portal, no team features.

**Pro** — everything in Free plus: web portal, web branding customiser,
team management, compliance reports, BS 5839 certificates.

**Premium** — everything in Pro plus: multi-company, API access, priority
support.

See the "Resolved decisions" section for full feature list per tier,
pricing (£29/£49 per-seat per month), and rationale.

## Files to create

```
lib/models/
└── subscription_tier.dart                 ← enum + tier capability mapping

lib/services/
├── entitlement_service.dart               ← resolves current user's tier + capabilities
└── revenuecat_service.dart                ← RevenueCat SDK wrapper

lib/screens/settings/subscription/
├── subscription_screen.dart               ← tier overview + upgrade prompts
└── widgets/
    ├── tier_card.dart                     ← individual tier in the comparison
    └── upgrade_cta.dart                   ← inline upgrade prompts

functions/src/
└── revenuecat_webhook.ts                  ← Cloud Function for subscription updates
```

Dependencies to add in `pubspec.yaml`:
- `purchases_flutter: ^8.0.0` (or latest) — RevenueCat SDK

## Model

```dart
// lib/models/subscription_tier.dart
enum SubscriptionTier { free, pro, premium }

class TierCapabilities {
  // Branding + PDF
  final bool personalBrandingMobile;
  final bool webBrandingCustomiser;

  // Compliance
  final bool complianceReports;
  final bool bs5839Reports;

  // Web + team
  final bool webDispatchPortal;
  final bool teamManagement;

  // Advanced (Premium only)
  final bool multiCompanySupport;
  final bool apiAccess;
  final bool prioritySupport;

  const TierCapabilities({
    required this.personalBrandingMobile,
    required this.webBrandingCustomiser,
    required this.complianceReports,
    required this.bs5839Reports,
    required this.webDispatchPortal,
    required this.teamManagement,
    required this.multiCompanySupport,
    required this.apiAccess,
    required this.prioritySupport,
  });

  static TierCapabilities forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return const TierCapabilities(
          personalBrandingMobile: true,
          webBrandingCustomiser: false,
          complianceReports: false,
          bs5839Reports: false,
          webDispatchPortal: false,
          teamManagement: false,
          multiCompanySupport: false,
          apiAccess: false,
          prioritySupport: false,
        );
      case SubscriptionTier.pro:
        return const TierCapabilities(
          personalBrandingMobile: true,
          webBrandingCustomiser: true,
          complianceReports: true,
          bs5839Reports: true,             // BS 5839 is Pro per resolved decision #3
          webDispatchPortal: true,
          teamManagement: true,
          multiCompanySupport: false,
          apiAccess: false,
          prioritySupport: false,
        );
      case SubscriptionTier.premium:
        return const TierCapabilities(
          personalBrandingMobile: true,
          webBrandingCustomiser: true,
          complianceReports: true,
          bs5839Reports: true,
          webDispatchPortal: true,
          teamManagement: true,
          multiCompanySupport: true,
          apiAccess: true,
          prioritySupport: true,
        );
    }
  }
}
```

## EntitlementService

Central place for capability checks. Every feature that needs gating asks
this service. Gets user tier from Firestore (set by the RevenueCat webhook
when a subscription changes).

```dart
class EntitlementService {
  static final instance = EntitlementService._();
  EntitlementService._();

  // Cached current tier, refreshed on auth change
  SubscriptionTier _currentTier = SubscriptionTier.free;
  TierCapabilities get capabilities => TierCapabilities.forTier(_currentTier);

  /// Call on app start and whenever auth state changes.
  Future<void> refresh() async {
    final profile = UserProfileService.instance;
    if (profile.companyId != null) {
      // Company tier lives at companies/{id}/subscription/current
      final doc = await FirebaseFirestore.instance
        .collection('companies').doc(profile.companyId!)
        .collection('subscription').doc('current').get();
      _currentTier = _parseTier(doc.data()?['tier'] as String?);
    } else {
      // Personal tier lives at users/{uid}/subscription/current
      final doc = await FirebaseFirestore.instance
        .collection('users').doc(profile.userId!)
        .collection('subscription').doc('current').get();
      _currentTier = _parseTier(doc.data()?['tier'] as String?);
    }
  }

  bool canUse(bool Function(TierCapabilities) check) => check(capabilities);
}
```

## Gating points

Where capability checks are called:

- **Web customiser screen** — route guard. If `!capabilities.webBrandingCustomiser`,
  show an upgrade prompt instead of the customiser.
- **Compliance report generation** — before running
  `compliance_report_service.dart`, check
  `capabilities.complianceReports`. If false, show "Compliance reports
  require Pro" modal with upgrade CTA.
- **BS 5839 report generation** — same, check
  `capabilities.bs5839Reports` before `bs5839_report_service.dart` runs.
- **Web dispatch portal routes** — same pattern, gate the route.

These checks are client-side (UI gating). The server-side enforcement
comes from Firestore rules — add `hasTier('pro')` helper and use it in
rules for compliance reports, branding writes, etc.

## Subscription screen

A Settings → Subscription screen that shows:

- Current tier
- Tier comparison cards
- "Upgrade" button → calls `RevenueCatService.purchaseProduct(...)` which
  opens the platform's native purchase sheet (StoreKit on iOS, Play
  Billing on Android, Stripe checkout on web)
- "Manage billing" link → calls `RevenueCatService.openManageSubscription()`
  which opens the platform-appropriate subscription management UI

## RevenueCat integration (required — not deferred)

Per resolved decision #2, RevenueCat is the billing provider. It's
required in Phase 4 (not deferred) because iOS App Store review will
reject any app that takes payment for digital subscriptions outside of
in-app purchase. RevenueCat wraps StoreKit, Play Billing, and Stripe
behind one API.

### Setup checklist (one-time, not a Claude Code session)

Before starting Session 4.3, you manually complete these steps in the
RevenueCat dashboard. Claude Code cannot do these because they require
signing into third-party services:

1. Create a RevenueCat account and project
2. Add iOS app (App Store Connect integration with shared secret)
3. Add Android app (Play Console integration with service account)
4. Add web app (Stripe publishable key + webhook)
5. Create products in App Store Connect, Play Console, and Stripe for:
   - `firethings_pro_monthly` — £29/month
   - `firethings_pro_annual` — £300/year
   - `firethings_premium_monthly` — £49/month
   - `firethings_premium_annual` — £500/year
6. Create "entitlements" in RevenueCat: `pro` and `premium`
7. Map products to entitlements (both pro monthly and annual → `pro`
   entitlement)
8. Copy RevenueCat API keys (iOS, Android, web) for the app

### SDK integration

```dart
// lib/services/revenuecat_service.dart

class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// Call once at app startup, before any entitlement checks.
  Future<void> initialize() async {
    final apiKey = _apiKeyForCurrentPlatform();
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Call after Firebase Auth completes. Links the current user's
  /// Firebase UID to RevenueCat so entitlements follow them across
  /// devices.
  Future<void> loginUser(String firebaseUid) async {
    await Purchases.logIn(firebaseUid);
  }

  Future<void> logoutUser() async {
    await Purchases.logOut();
  }

  /// Returns the user's current tier based on active entitlements.
  /// This is what EntitlementService calls.
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.containsKey('premium')) {
        return SubscriptionTier.premium;
      }
      if (info.entitlements.active.containsKey('pro')) {
        return SubscriptionTier.pro;
      }
      return SubscriptionTier.free;
    } catch (e) {
      debugPrint('RevenueCat tier fetch failed: $e');
      return SubscriptionTier.free; // safe fallback — no entitlements
    }
  }

  /// Opens the platform-appropriate purchase flow.
  /// On iOS: StoreKit sheet. On Android: Play Billing sheet.
  /// On web: redirect to Stripe checkout.
  Future<bool> purchaseProduct(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages
        .firstWhere((p) => p.storeProduct.identifier == productId);
      if (pkg == null) return false;
      final result = await Purchases.purchasePackage(pkg);
      return result.customerInfo.entitlements.active.isNotEmpty;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false; // user cancelled, not an error
      }
      debugPrint('RevenueCat purchase failed: $e');
      rethrow;
    }
  }

  /// Opens the platform's subscription management UI.
  Future<void> openManageSubscription() async {
    await Purchases.showManageSubscriptions();
  }

  String _apiKeyForCurrentPlatform() {
    if (kIsWeb) return const String.fromEnvironment('REVENUECAT_WEB_KEY');
    if (Platform.isIOS) return const String.fromEnvironment('REVENUECAT_IOS_KEY');
    if (Platform.isAndroid) return const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
    throw UnsupportedError('RevenueCat not supported on this platform');
  }
}
```

### How entitlements flow to Firestore

RevenueCat is the source of truth for tier. But `EntitlementService`
caches the tier in Firestore so that:

- Other parts of the app (Cloud Functions, Firestore rules) can check
  tier server-side
- Tier can be read without an SDK round-trip
- Admin tools can manually override tier for testing

Flow:

1. User purchases Pro on iOS
2. RevenueCat SDK receives the purchase, validates with App Store
3. RevenueCat webhooks fire to your Cloud Function
   `revenueCatWebhook` — which writes the entitlement to
   `users/{uid}/subscription/current` (solo users) or
   `companies/{id}/subscription/current` (company users)
4. `EntitlementService.refresh()` reads this Firestore doc on next call
5. Capability checks use the cached tier

Note the asymmetry: personal subscriptions attach to the user, company
subscriptions attach to the company. The webhook function needs to
know which, based on the RevenueCat user ID (Firebase UID) and whether
that user is a company admin. For v1, simplify: subscribe as the
company admin, write to the company's subscription doc. For v2,
consider subscription management UI that lets multiple seats be assigned.

### Cloud Function — `revenueCatWebhook`

```typescript
// functions/src/revenuecat_webhook.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const revenueCatWebhook = functions.https.onRequest(async (req, res) => {
  // Verify RevenueCat webhook signature (docs.revenuecat.com/docs/webhooks)
  const signature = req.header('Authorization');
  if (signature !== `Bearer ${functions.config().revenuecat.secret}`) {
    res.status(401).send('Invalid signature');
    return;
  }

  const event = req.body.event;
  const firebaseUid = event.app_user_id;
  const entitlements = event.entitlement_ids || [];

  let tier = 'free';
  if (entitlements.includes('premium')) tier = 'premium';
  else if (entitlements.includes('pro')) tier = 'pro';

  // Determine target: user or company
  const userDoc = await admin.firestore().collection('users').doc(firebaseUid).get();
  const companyId = userDoc.data()?.companyId;

  const target = companyId
    ? admin.firestore().collection('companies').doc(companyId)
        .collection('subscription').doc('current')
    : admin.firestore().collection('users').doc(firebaseUid)
        .collection('subscription').doc('current');

  await target.set({
    tier,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    revenueCatEventType: event.type,
    revenueCatEventId: event.id,
  });

  res.status(200).send('OK');
});
```

## Definition of done (Phase 4)

- Solo user on free tier cannot access web customiser (redirected to upgrade)
- Solo user cannot generate compliance reports
- Company user on Pro can access web customiser, can generate compliance
  reports, cannot generate BS 5839 reports
- Company user on Premium can do everything including BS 5839
- Tier is read from Firestore `subscription` doc
- Firestore rules enforce tier checks server-side for writes
- Upgrade prompts are clear, show what's in the tier, have a CTA to pay
- RevenueCat SDK initialised and connected to user accounts via Firebase UID
- Test purchase completes in sandbox mode on iOS, Android, and web
- RevenueCat webhook updates Firestore subscription doc within 30 seconds
  of purchase
- `EntitlementService.refresh()` picks up the new tier after webhook fires

## Session breakdown (Phase 4)

### Session 4.1 — SubscriptionTier + EntitlementService

Create the models and service. Implement with manual tier setting via
Firestore for test accounts — this lets you verify the gating logic
before RevenueCat is integrated.

Add `EntitlementService.refresh()` that reads from the subscription doc,
plus a listener that re-refreshes on auth state changes. Write tests
that set different tier values and verify `capabilities` returns the
right values.

### Session 4.2 — Client-side gating

Add capability checks at the four gating points listed above
(web customiser route, compliance report generation, BS 5839 generation,
web dispatch portal routes). Build `SubscriptionScreen` with tier cards
and upgrade CTAs — CTAs route to a placeholder "Upgrade flow coming soon"
screen for now, wired up in Session 4.4.

Test with manually-set tiers in Firestore — a free user should see
upgrade prompts, a Pro user should see everything except Premium
features, a Premium user should see everything.

### Session 4.3 — Firestore rules + server enforcement

Add `hasTier(tier)` helper function to Firestore rules. Example:

```
function hasTier(companyId, requiredTier) {
  let tier = get(/databases/$(database)/documents/companies/$(companyId)/subscription/current).data.tier;
  return tier == requiredTier ||
         (requiredTier == 'pro' && tier == 'premium');
}
```

Gate write rules for branding, compliance reports, BS 5839 documents.
Rules to update:

- `companies/{id}/branding/{docId}` — requires `pro` or `premium`
- `companies/{id}/compliance_reports/**` — requires `pro` or `premium`
- `companies/{id}/bs5839/**` — requires `pro` or `premium`
- `users/{uid}/branding/{docId}` — no tier gate (personal branding is free)

Manually test with test accounts at different tiers. Verify that a free
user cannot write to `branding/main` even via direct Firestore SDK calls
bypassing the UI.

### Session 4.4 — RevenueCat SDK integration

**Prerequisite:** Complete the "Setup checklist" above in the RevenueCat
dashboard before starting this session. Claude Code cannot do those
steps.

Add `purchases_flutter` to `pubspec.yaml`. Create
`lib/services/revenuecat_service.dart` with the initialize / login /
getCurrentTier / purchaseProduct / openManageSubscription methods
shown above.

Wire `RevenueCatService.initialize()` into `main.dart` before `runApp`.
Wire `RevenueCatService.loginUser(uid)` into the auth completion flow
(after Firebase Auth user is confirmed).

Replace the placeholder upgrade CTAs from Session 4.2 with real calls to
`purchaseProduct`. Test end-to-end purchase on iOS Simulator (sandbox
mode), Android emulator, and web (with Stripe test card).

### Session 4.5 — Cloud Function webhook + entitlement sync

Create `functions/src/revenuecat_webhook.ts` per the code above. Deploy
the function. Configure the webhook URL in the RevenueCat dashboard.

Set Firebase Functions config:
```
firebase functions:config:set revenuecat.secret="YOUR_WEBHOOK_SECRET"
```

Test: complete a test purchase in sandbox mode, verify the webhook
fires, verify the Firestore `subscription/current` doc updates within
30 seconds, verify `EntitlementService.refresh()` picks up the new tier.

Test subscription cancellation — webhook fires, tier downgrades to
`free`, app UI locks the Pro features on next `refresh()`.

---

# PHASE 5 — Deprecate old editors + migrate legacy config

**Effort:** ~1 week, 3-4 sessions
**Goal:** Remove the `UnifiedPdfEditorScreen` and the `pdf_config`
collection. Migrate any existing per-doctype config to the new
`PdfBranding` model so no user loses their customisations.

## What we're removing

Mobile screens:
- `lib/screens/settings/unified_pdf_editor_screen.dart`
- Any supporting widgets only used by the editor
- `lib/screens/company/company_pdf_design_screen.dart`
- `lib/screens/invoicing/pdf_design_screen.dart`

Services:
- `lib/services/company_pdf_config_service.dart`
- `lib/services/pdf_colour_scheme_service.dart`
- `lib/services/pdf_footer_config_service.dart`
- `lib/services/pdf_header_config_service.dart`
- `lib/services/pdf_section_style_service.dart`
- `lib/services/pdf_typography_service.dart`

Firestore data:
- `companies/{id}/pdf_config/*` documents

Code in the five PDF services that reads from the old config services.

## What we're keeping

- `lib/services/pdf_widgets/*` — the widget library (minus the old
  config-reading ones that get deleted)
- Everything built in Phases 1-3
- The `PdfBranding` model and `PdfBrandingService`

## Migration strategy

When Phase 5 ships, some companies will have existing PDF customisations
stored in the old `pdf_config` collection. These must be migrated to
`PdfBranding` on first app open so users don't wake up to default-looking
PDFs.

Write a migration function that runs once per company/user:

```dart
// lib/services/pdf_config_migration_service.dart

class PdfConfigMigrationService {
  /// Run on app startup after auth. Idempotent — safe to call multiple times.
  Future<void> migrateIfNeeded() async {
    final profile = UserProfileService.instance;
    final migrationKey = profile.companyId ?? profile.userId;

    // Check if migration already ran for this account
    final flagDoc = await _migrationFlag(migrationKey).get();
    if (flagDoc.exists) return;

    // Read old config (may not exist — that's fine)
    final oldConfig = await _readOldConfig(migrationKey);

    // Only migrate if we have existing data AND no new branding exists yet
    final existingBranding = await PdfBrandingService.instance
      .getBrandingIfExists(migrationKey);

    if (oldConfig != null && existingBranding == null) {
      final branding = _buildBrandingFromOldConfig(oldConfig);
      if (profile.companyId != null) {
        await PdfBrandingService.instance.saveBranding(profile.companyId!, branding);
      } else {
        await PdfBrandingService.instance.savePersonalBranding(profile.userId!, branding);
      }
    }

    // Mark migration as complete
    await _migrationFlag(migrationKey).set({'migratedAt': FieldValue.serverTimestamp()});
  }

  PdfBranding _buildBrandingFromOldConfig(Map<String, dynamic> oldConfig) {
    // Map old fields to new branding model. Specifics depend on old config
    // structure — Claude Code will need to read the old config models to
    // implement this mapping correctly.
    return PdfBranding(
      primaryColour: oldConfig['primaryColour'] ?? '#1A1A2E',
      accentColour: oldConfig['accentColour'] ?? '#FFB020',
      // ... etc
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
    );
  }
}
```

The migration runs once per account on first app open after Phase 5 ships.
Subsequent opens skip it (flag doc exists). After 30 days of no reports
of issues, the old `pdf_config` collection can be dropped entirely via a
one-time Cloud Function cleanup.

## Files to modify

- Five PDF services — remove the old config-reading code paths, leaving
  only the new branding-based path
- Settings screen — remove the old "PDF Design" tile for company users
  (replace with "Branding managed on web")
- `main.dart` — call `PdfConfigMigrationService.migrateIfNeeded()` on app
  startup

## Definition of done (Phase 5)

- `UnifiedPdfEditorScreen` and related screens deleted
- Old config services deleted
- Migration service runs on first app open, moves existing data correctly,
  marks complete
- Users with pre-existing customisations see their customisations preserved
  (primary colour, accent colour, footer text, logo all carry over)
- Five PDF services have a single code path (branding only, no fallback to
  old config)
- Settings screen no longer shows old per-doctype editors
- No references to deleted services anywhere in the codebase
- App compiles, tests pass, all previously-working PDFs still generate

## Session breakdown (Phase 5)

### Session 5.1 — Migration service

Create `PdfConfigMigrationService`. Read the existing old config models
to understand the shape. Implement `_buildBrandingFromOldConfig` carefully
so no customisation is lost. Add a migration-complete flag collection.
Write tests covering: fresh user (no old config, no migration), existing
user with old config (migration happens), existing user already migrated
(no-op).

### Session 5.2 — Wire migration on app start

Add `PdfConfigMigrationService.migrateIfNeeded()` call in `main.dart`
after auth is established but before the first PDF might be generated.
Manually test with a test account that has old config — verify migration
completes and the new branding matches.

### Session 5.3 — Remove old editor screens

Delete `unified_pdf_editor_screen.dart`, `company_pdf_design_screen.dart`,
`pdf_design_screen.dart`, and any widgets only used by them. Update
Settings screen navigation. Run `flutter analyze` and fix all broken
references.

### Session 5.4 — Remove old services + single-path PDF generation

Delete the six config services listed above. Remove the fallback code in
each of the five PDF services so they have only one path — the new
branding-based one. Run full test suite. Generate each of the five PDF
types on iOS and Android to verify no regression.

---

# Cross-phase concerns

## Testing strategy

This is a big rebuild. Manual testing alone isn't enough. Priority tests
to have in place before Phase 1:

**Golden PDF tests** — for each of the five PDF types and three cover
styles (15 combinations), generate a PDF with fixed test data and compare
to a committed baseline PDF. These catch visual regressions during each
phase. Use the `pdf` package's widget tester plus something like
`golden_toolkit`.

**Integration tests** — set a branding config, generate a PDF, verify
specific bytes/strings appear in the PDF output (logo URL, company name,
primary colour hex code in the header).

**End-to-end manual test script** — a checklist of "log in as user type
X, do action Y, verify Z" that runs before each phase ships. Include:
solo user creates personal branding, company user creates company branding,
BS 5839 report renders correctly, etc.

## Rollback plan

Each phase ships behind a feature flag (remote config). If Phase 1 ships
and PDFs suddenly look wrong on some devices, flip the flag and the five
PDF services revert to the old cover builder. This means keeping the old
code paths alive for one release cycle after each phase.

Specifically:
- Phase 1 feature flag: `pdf_renderer_v2_enabled` (default true, flag off
  reverts to old cover builder)
- Phase 2 feature flag: `personal_branding_enabled` (default true)
- Phase 3 feature flag: `mobile_customiser_v2_enabled` (default true)
- Phase 4 feature flag: `tier_gating_enabled` (default false initially,
  then true after billing works)
- Phase 5: no flag needed (data migration, not behaviour change)

## Documentation updates

After each phase, update:
- `CLAUDE.md` in the repo root with new architecture notes
- `docs/architecture/pdf_system.md` (new) — the single source of truth for
  how PDF generation works after the rebuild

---

# Recommended working style

**One session per file.** These phases are big. Don't try to pack Session
1.1 and 1.2 into one Claude Code turn — context runs out and the work
gets sloppy.

**Always "show me the plan first."** Every prompt. Claude Code's natural
instinct is to start writing immediately; the plan step catches architecture
mistakes before they're encoded.

**Commit after every successful session.** Small commits with clear
messages. If something breaks three phases later, bisect becomes your
friend.

**Test on real devices.** Especially Phase 1 (fonts), Phase 3 (mobile UX),
and Phase 5 (migration). Simulators hide issues.

**Keep the spec updated as a living document.** If you change direction
mid-phase, edit this spec first, then prompt Claude Code to follow the
updated version. Don't let prompt instructions and the spec drift apart.

---

# Resolved decisions

This section replaces the original "Open questions" — these are the
concrete answers that Phase 1-5 build against. If any of these change
during implementation, update this section first, then update the
affected phase sections below, THEN prompt Claude Code against the
updated spec.

## 1. Tier structure and pricing

Three tiers. These numbers are deliberately round and meant to be
adjusted after market testing — what matters architecturally is the
feature split, not the exact prices. Revisit pricing after 3 months
of real subscribers.

### Free (solo engineers, no payment)

**Target user:** Sole-trader fire safety engineers running jobs on their
own. Using FireThings as a work-management tool rather than a team tool.

**What's included:**
- Personal branding via mobile (5 preset kits + logo upload + basic colour tweak)
- Unlimited jobsheets with personal branding
- Unlimited invoices with personal branding
- Unlimited quotes with personal branding
- Asset register (view, edit, basic service records)
- Basic scheduling on mobile (my-jobs list)
- Single-user only — cannot create or join a company

**What's NOT included:**
- Compliance reports (BS 5839, BS 5266, BAFE)
- Web dispatch portal
- Team management
- Company branding customiser
- Advanced reports

**Pricing:** £0 / month. No time limit, no job cap — free forever.

### Pro (per-seat subscription — small-to-medium fire safety businesses)

**Target user:** Fire safety companies with 2-15 engineers. Needs
compliance reporting, team dispatch, branded company documents.

**What's included — everything in Free PLUS:**
- Company accounts (multi-user)
- **Web dispatch portal** (dashboard, schedule, job detail, quotes, invoices)
- **Company branding customiser on web** (full live-preview editor across
  all four document types)
- **Compliance reports** — full inspection reports with asset register,
  defect tracking, recommendations
- **BS 5839-1:2025 compliance certificates** (now in Pro per resolved decision #3)
- Team management, permissions, role-based access
- Full scheduling (resource calendar, drag-and-drop, reassign)
- Customer portal links (read-only reports for end customers)

**Pricing:** £29 / engineer / month billed monthly, or £25 / engineer /
month billed annually (£300 / engineer / year — two months free).
Minimum two seats — this is a team product.

**Rationale for per-seat pricing:** Aligns FireThings revenue with
company growth. A 2-engineer company pays £58/month; a 10-engineer
company pays £290/month. Matches how competitors (Simpro, BigChange,
Joblogic) price.

### Premium (Pro + advanced add-ons)

**Target user:** Larger fire safety businesses (15+ engineers) or
ambitious medium firms who want every advantage.

**What's included — everything in Pro PLUS (features TBD, candidates):**
- **Multi-company support** — for engineers who work under multiple
  brandings (e.g. franchise networks)
- **Advanced reporting** — board-level summaries, multi-site portfolio
  reports, trend analysis
- **API access** — for customers who want to integrate with their own
  accounting/CRM stack
- **Priority support** — guaranteed response time, dedicated contact
- **Custom integrations** — bespoke work as needed
- Features from the existing FEATURE_GAPS_SPEC as they're built
  (recurring jobs, SLA tracking, service contracts, etc — these can
  be Pro OR Premium, decide per-feature)

**Pricing:** £49 / engineer / month billed monthly, or £42 / engineer /
month billed annually (£500 / engineer / year). Minimum five seats.

**Rationale:** Premium is a "serious buyer" tier. Priced high enough
that casual upgrades don't happen — someone moving to Premium has a
specific reason (API, multi-company, priority support). The price
gap between Pro and Premium (£29 → £49 = ~70% increase) is large
enough to feel meaningful, small enough that a growing Pro customer
can justify it when they hit the ceiling.

### Capability mapping

For the `TierCapabilities` model in Phase 4:

| Capability              | Free | Pro | Premium |
|-------------------------|:----:|:---:|:-------:|
| personalBrandingMobile  | ✅   | ✅  | ✅      |
| webBrandingCustomiser   | ❌   | ✅  | ✅      |
| webDispatchPortal       | ❌   | ✅  | ✅      |
| complianceReports       | ❌   | ✅  | ✅      |
| bs5839Reports           | ❌   | ✅  | ✅      |
| teamManagement          | ❌   | ✅  | ✅      |
| multiCompanySupport     | ❌   | ❌  | ✅      |
| apiAccess               | ❌   | ❌  | ✅      |
| prioritySupport         | ❌   | ❌  | ✅      |

## 2. Billing provider — RevenueCat

**Decision:** Use RevenueCat as the subscription orchestration layer.

**Why RevenueCat over raw Stripe:**

FireThings runs on iOS, Android, AND web. Each platform has different
billing requirements:

- **iOS:** Apple requires in-app purchases for digital subscriptions
  accessed within the app. Violating this gets apps rejected from the
  App Store. Stripe cannot be used directly for iOS subscriptions.
- **Android:** Google Play has similar (slightly laxer) rules. Google
  Play Billing required for in-app subscriptions.
- **Web:** No platform restrictions. Stripe works fine.

RevenueCat is a unified SDK that handles all three behind one API. An
active subscription purchased on iOS is visible to the same user on
Android and web. Receipts, renewals, and entitlements sync across
platforms. Without RevenueCat, you'd write three separate integrations
and still need a backend to merge them — RevenueCat is that backend.

**Architecture after integration:**

- App calls `RevenueCat.login(userId)` after Firebase Auth completes
- App calls `RevenueCat.getCurrentEntitlements()` to determine tier
- The tier string ("pro", "premium") feeds into `EntitlementService`
- When a user upgrades, RevenueCat handles the purchase via the correct
  platform's store (StoreKit on iOS, Play Billing on Android, Stripe on
  web) and webhook-pushes the new entitlement to Firestore
- `TierCapabilities.forTier(...)` then picks the right capabilities

**Cost:** RevenueCat is free below $2.5k MRR, then 1% of tracked revenue
above that. Fair pricing — you only pay when you're already making real
money.

**Deferred or in Phase 4?** Do it IN Phase 4. Manual-tier-in-Firestore
for testing is fine for one developer on staging, but the product cannot
ship to paying customers without RevenueCat because iOS will reject it
on review. Scope Phase 4 to include RevenueCat integration from the
start.

## 3. BS 5839 gating — Pro

**Decision:** BS 5839-1:2025 compliance certificates are a Pro feature,
not Premium.

**Implications:**

- Removes the tier-positioning problem where Premium felt "like we're
  gatekeeping compliance" — bad optics for a compliance product
- Makes Pro the "real fire safety business" tier at a clean price point
- Premium becomes a genuine add-on tier (API, multi-company, etc)
  rather than a "you must pay more for regulatory compliance" tier
- In `TierCapabilities`: `bs5839Reports` is `true` for Pro and Premium

This slightly weakens the Premium upgrade story, which is fine — most
fire safety companies never need API access or multi-company support,
and those who do will pay the Premium price without needing to be
pushed there.

## 4. Preset kits — accepted as proposed

The five presets from Phase 3 stand as written:

- FireThings (navy + amber, bold cover) — the default
- Graphite (black + red, bordered cover) — classic/professional
- Forest (deep green + copper, bold cover) — distinctive
- Slate (cool grey + cyan, minimal cover) — contemporary
- Heritage (burgundy + gold, bordered cover) — traditional

No changes needed. Claude Code implements exactly what's in Phase 3.

## 5. Migration grace period — 30 days

**Decision:** 30 days after Phase 5 ships, the old `pdf_config`
Firestore collection is deleted server-side via a one-time Cloud
Function cleanup.

Implementation:

- Phase 5 migration runs on first app open per account (idempotent)
- After 30 days, manually inspect Firestore analytics — if any accounts
  still have `pdf_config` docs but no corresponding `branding/main`, do
  NOT run the cleanup until they've been investigated
- Write a simple Cloud Function `cleanupLegacyPdfConfig` that iterates
  `pdf_config` docs and deletes them. Runs as an on-demand callable,
  not scheduled — you trigger it manually after verification
- Keep a 7-day additional grace after cleanup: restored from backup if
  anyone reports a regression

## 6. Feature flag infrastructure — Firebase Remote Config (already integrated)

**Existing state:** FireThings already uses Firebase Remote Config. There's
a `lib/services/remote_config_service.dart` wrapper used by several
screens (`home_screen.dart`, `dispatch_dashboard_screen.dart`,
`create_job_screen.dart`, `compliance_report_service.dart`, etc). Pubspec
has `firebase_remote_config: ^6.1.4`.

**What this means for the rebuild:** Zero new infrastructure work. Each
phase adds its flag key to `RemoteConfigService` and gates its new
behaviour behind a check. The existing pattern in the codebase is the
template — Claude Code should match it rather than inventing a new one.

Flags to add for this rebuild:

- `pdf_renderer_v2_enabled` (default `true` — flag off reverts to old
  cover builder)
- `personal_branding_enabled` (default `true`)
- `mobile_customiser_v2_enabled` (default `true`)
- `tier_gating_enabled` (default `false` until Phase 4's RevenueCat
  integration is stable, then flip to `true`)
- `legacy_pdf_config_read_enabled` (default `true` during Phase 5's
  30-day grace, then `false`, then cleanup can run)

---


