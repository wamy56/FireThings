# PDF Branding & Customiser — Implementation Spec

**Status:** Proposed
**Effort:** ~8 sessions, roughly 2-3 weeks elapsed
**Prerequisites:** `lib/theme/web_theme.dart` exists. The web shell has been
redesigned. Storage bucket is configured for company-scoped uploads.

**Reference prototype:** `docs/web-redesign-extras/prototypes/pdf_customiser.html`

---

## What we're building

A web-only screen at `/reports/branding` (under the existing Reports nav
section) that lets dispatchers customise the visual branding of every PDF
the company produces — compliance reports, quotes, invoices, and job sheets.

The architectural insight: this is a **config editor**, not a PDF designer.
The dispatcher edits a single Firestore document. The mobile app reads that
document and applies the branding to its existing PDF rendering. **No
mobile UI changes are needed.** Engineers see the new branding the next
time they generate any PDF, automatically.

The four existing PDF services (`compliance_report_service`,
`quote_pdf_service`, `invoice_pdf_service`, `template_pdf_service`) already
share `PdfHeaderConfig`, `PdfFooterConfig`, and `PdfColourScheme` plumbing.
We're extending that plumbing to read from the new branding document.

---

## What changes

### New
- `lib/models/pdf_branding.dart` — the branding config model
- `lib/services/pdf_branding_service.dart` — read/write Firestore + storage upload
- `lib/screens/web/web_branding_screen.dart` — the customiser screen
- `lib/screens/web/widgets/branding/` — controls, preview, etc
- `companies/{companyId}/branding/main` — single Firestore document per company

### Modified (mobile-side wiring)
- `lib/services/pdf_header_config_service.dart` — merge in branding fields
- `lib/services/pdf_footer_config_service.dart` — merge in branding fields
- `lib/services/pdf_colour_scheme_service.dart` — read primary/accent from branding
- `lib/services/compliance_report_service.dart` — apply branding cover style
- `lib/services/quote_pdf_service.dart` — apply branding cover style
- `lib/services/invoice_pdf_service.dart` — apply branding cover style
- `lib/services/template_pdf_service.dart` — apply branding cover style (jobsheets)

### Does NOT change
- Mobile screens — engineers don't see a customiser
- The `pdf_widgets/` library itself — we're configuring its inputs, not its widgets
- Firestore rules — the `branding` collection uses existing company-scoped patterns
- Any of the four PDF services' core rendering logic — only the config inputs change

---

## Data model

### `lib/models/pdf_branding.dart` (NEW)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum CoverStyle { bold, minimal, bordered }
enum HeaderStyle { solid, minimal, bordered }
enum FooterStyle { light, minimal, coloured }
enum BrandingDocType { report, quote, invoice, jobsheet }

class PdfBranding {
  // Logo
  final String? logoUrl;          // Storage URL, may be null
  final double logoMaxHeight;     // px on cover, default 60

  // Colours
  final String primaryColour;     // hex, e.g. "#1A1A2E"
  final String accentColour;      // hex, e.g. "#FFB020"

  // Typography (simple v1 — Inter + Outfit by default)
  final String fontDisplay;       // "outfit" | "inter" | "playfair"
  final String fontBody;          // "inter" | "roboto"

  // Cover
  final CoverStyle coverStyle;

  // Per-doc-type cover text overrides (all optional)
  // If null, use the system default for that doc type
  final BrandingCoverText? coverTextReport;
  final BrandingCoverText? coverTextQuote;
  final BrandingCoverText? coverTextInvoice;
  final BrandingCoverText? coverTextJobsheet;

  // Page header (shared across all doc types)
  final HeaderStyle headerStyle;
  final bool headerShowCompanyName;
  final bool headerShowDocNumber;

  // Page footer (shared across all doc types)
  final FooterStyle footerStyle;
  final String footerText;        // company-wide text, e.g. "Co № 123 · VAT GB ..."
  final bool footerShowCompanyName;
  final bool footerShowPageNumbers; // true by default

  // Scope — which doc types use this branding
  // If a type is omitted, that doc type falls back to the system default
  final Set<BrandingDocType> appliesTo;

  // Audit
  final String? lastUpdatedBy;
  final DateTime updatedAt;
  final DateTime lastModifiedAt;

  const PdfBranding({
    this.logoUrl,
    this.logoMaxHeight = 60,
    this.primaryColour = '#1A1A2E',
    this.accentColour = '#FFB020',
    this.fontDisplay = 'outfit',
    this.fontBody = 'inter',
    this.coverStyle = CoverStyle.bold,
    this.coverTextReport,
    this.coverTextQuote,
    this.coverTextInvoice,
    this.coverTextJobsheet,
    this.headerStyle = HeaderStyle.solid,
    this.headerShowCompanyName = true,
    this.headerShowDocNumber = true,
    this.footerStyle = FooterStyle.light,
    this.footerText = '',
    this.footerShowCompanyName = true,
    this.footerShowPageNumbers = true,
    this.appliesTo = const {
      BrandingDocType.report,
      BrandingDocType.quote,
      BrandingDocType.invoice,
      BrandingDocType.jobsheet,
    },
    this.lastUpdatedBy,
    required this.updatedAt,
    required this.lastModifiedAt,
  });

  /// Returns the cover text for a specific doc type, or null if no override.
  BrandingCoverText? coverTextFor(BrandingDocType type) {
    switch (type) {
      case BrandingDocType.report:   return coverTextReport;
      case BrandingDocType.quote:    return coverTextQuote;
      case BrandingDocType.invoice:  return coverTextInvoice;
      case BrandingDocType.jobsheet: return coverTextJobsheet;
    }
  }

  /// Whether branding applies to the given doc type.
  bool appliesToDocType(BrandingDocType type) => appliesTo.contains(type);

  Map<String, dynamic> toJson() { /* standard pattern */ }
  factory PdfBranding.fromJson(Map<String, dynamic> json) { /* standard */ }
  PdfBranding copyWith({ /* all fields nullable */ }) { /* standard */ }

  /// The company-wide default if no branding has been configured yet.
  static PdfBranding defaultBranding() => PdfBranding(
    updatedAt: DateTime.now(),
    lastModifiedAt: DateTime.now(),
  );
}

class BrandingCoverText {
  final String? eyebrow;     // small text above the title
  final String? title;       // can use template variables like {{document_number}}
  final String? subtitle;

  const BrandingCoverText({this.eyebrow, this.title, this.subtitle});

  Map<String, dynamic> toJson() => {
    if (eyebrow != null) 'eyebrow': eyebrow,
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
  };

  factory BrandingCoverText.fromJson(Map<String, dynamic> json) =>
    BrandingCoverText(
      eyebrow: json['eyebrow'] as String?,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
    );
}
```

### Firestore structure

```
companies/{companyId}/branding/main      ← single doc per company
```

Single doc, not a collection of templates. v1 is one global brand kit. If
the user asks for multiple kits later, change the path to
`branding/{kitId}` and add a default-kit selector — but don't pre-build that.

### Firestore rules (existing pattern, just add)

```
match /companies/{companyId}/branding/{docId} {
  allow read: if isCompanyMember(companyId);
  allow write: if hasPermission(companyId, 'pdf_branding');
}
```

`pdf_branding` is the existing permission already used by the `pdf_config`
collection for customising company PDF settings — correct scope here
because the branding doc is the same kind of thing. Add this to the
firestore.rules file.

---

## Service layer

### `lib/services/pdf_branding_service.dart` (NEW)

```dart
class PdfBrandingService {
  PdfBrandingService._();
  static final PdfBrandingService instance = PdfBrandingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Cache the current branding in memory so PDF generation doesn't hit
  // Firestore every time. Refresh when the branding doc changes.
  PdfBranding? _cached;
  StreamSubscription? _sub;

  /// Get the current branding for a company. Loads from cache if available,
  /// otherwise from Firestore. Returns the default if no branding doc exists.
  Future<PdfBranding> getBranding(String companyId) async {
    if (_cached != null) return _cached!;
    final doc = await _docRef(companyId).get();
    _cached = doc.exists
      ? PdfBranding.fromJson(doc.data()!)
      : PdfBranding.defaultBranding();
    return _cached!;
  }

  /// Watch the branding doc for live updates (used by the customiser
  /// preview and by the cache invalidation).
  Stream<PdfBranding> watchBranding(String companyId) {
    return _docRef(companyId).snapshots().map((doc) {
      final b = doc.exists
        ? PdfBranding.fromJson(doc.data()!)
        : PdfBranding.defaultBranding();
      _cached = b;
      return b;
    });
  }

  /// Save (overwrite) the branding doc.
  Future<void> saveBranding(String companyId, PdfBranding branding) async {
    final updated = branding.copyWith(
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      lastUpdatedBy: AuthService.instance.currentUser?.uid,
    );
    await _docRef(companyId).set(updated.toJson());
    _cached = updated;
  }

  /// Upload a logo file to Storage and return the download URL.
  /// Validates: PNG/SVG/JPG only, max 1MB.
  Future<String> uploadLogo({
    required String companyId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    if (!['png', 'svg', 'jpg', 'jpeg'].contains(ext)) {
      throw const FormatException('Logo must be PNG, JPG or SVG');
    }
    if (bytes.length > 1024 * 1024) {
      throw const FormatException('Logo must be under 1MB');
    }
    final ref = _storage.ref('companies/$companyId/branding/logo.$ext');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: _mimeFor(ext)),
    );
    return await task.ref.getDownloadURL();
  }

  /// Remove the cached logo (called when user removes their logo).
  Future<void> deleteLogo(String companyId, String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      // Silently ignore — we're going to overwrite branding.logoUrl to null anyway
    }
  }

  DocumentReference<Map<String, dynamic>> _docRef(String companyId) =>
    _firestore.collection('companies').doc(companyId)
      .collection('branding').doc('main');

  String _mimeFor(String ext) => switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'svg' => 'image/svg+xml',
    _ => 'application/octet-stream',
  };
}
```

---

## Web customiser screen

The customiser is a two-pane editor. Reference the prototype at
`prototypes/pdf_customiser.html`.

### File structure

```
lib/screens/web/
├── web_branding_screen.dart                    ← top-level container, watches branding
└── widgets/branding/
    ├── branding_controls_panel.dart            ← left pane (320px)
    ├── branding_preview_canvas.dart            ← right pane
    ├── branding_apply_to_section.dart          ← multi-select for doc-type scope
    ├── branding_logo_upload.dart               ← upload + preview + remove
    ├── branding_colour_picker.dart             ← swatch + hex + presets
    ├── branding_style_toggle_group.dart        ← segmented control
    ├── branding_doc_type_switcher.dart         ← pills above the preview canvas
    ├── pdf_preview_page.dart                   ← the rendered "page" container
    └── pdf_preview_pages/                      ← one preview widget per doc type
        ├── pdf_preview_report.dart
        ├── pdf_preview_quote.dart
        ├── pdf_preview_invoice.dart
        └── pdf_preview_jobsheet.dart
```

### Key UX rules

**Live preview is the killer feature.** Every control change updates the
preview within 100ms. Don't gate it behind a "Save" button. The preview
component is a Flutter widget that takes `PdfBranding` + a doc type and
renders a representative HTML-like page. This is NOT the actual PDF
output — it's a visual approximation that matches closely enough to convey
intent.

**Save is automatic, Publish is explicit.** Every change autosaves to
Firestore as a draft (after a 500ms debounce). The "Apply to all" button
in the topbar publishes the draft as the active branding. The mobile app
reads only published branding, never drafts.

Wait — actually, for v1, simplify: just autosave every change directly. No
draft state. This keeps the data model simple and the user experience is
fine because changes only affect _future_ PDF generations, not anything
already issued.

If the user asks for a draft/publish flow later, add a `BrandingDraft`
collection that mirrors `branding/main` but isn't read by the PDF services.
Promote draft → main via a "Publish" button. v2 problem.

**Document-type switcher.** Above the preview canvas, four pills:
Compliance Report / Quote / Invoice / Job sheet. Clicking switches the
preview content. The active pill uses the navy bg + amber icon treatment
established in the design system.

**Apply branding to.** A multi-select in the controls panel near the top.
All four doc types ticked by default. Unticking one means that doc type's
PDFs fall back to the system default styling (essentially the un-rebranded
look). This is for the rare company that wants e.g. their invoices to look
generic and their compliance certs to look branded.

### Live preview component

The preview component is a Flutter widget that takes the current
`PdfBranding` and a `BrandingDocType`, and renders a styled "page" that
approximates the PDF output. It's NOT the actual PDF — it's a faithful
HTML/Flutter mock built with `Container`, `Column`, `Row`, `Text`,
specifically:

- A `Container` with white bg, 4px radius, a subtle shadow representing
  the paper
- The cover section uses the branding's primary colour bg (or white for
  Minimal/Bordered styles), the accent colour for the divider/eyebrow, the
  logo if uploaded
- The page header uses the branding's headerStyle
- Some hardcoded representative sample content (the prototype shows what
  this looks like — copy the structure for each doc type)
- The footer uses the branding's footerStyle and footerText

This mock is what the dispatcher sees while customising. To get the actual
PDF, they click "Generate test PDF" which uses the existing
`compliance_report_service` etc. with the current (autosaved) branding,
returns a real PDF, and opens it in a new tab.

The mock-vs-real fidelity will be 90-95%. That's fine. The dispatcher
verifies with "Generate test PDF" before publishing.

---

## Mobile-side wiring (the part that makes it work everywhere)

This is where the "it just works on mobile too" magic happens. Each of the
four PDF services needs to:

1. Read the branding config at the start of PDF generation
2. Check `appliesTo` for its doc type
3. If included, apply colours, fonts, styles to the rendering
4. If not included, use defaults

### Pattern for each service

```dart
// Inside each *_pdf_service.dart's generate() method

Future<Uint8List> generateWhateverPdf({...}) async {
  final companyId = AuthService.instance.companyId!;

  // NEW: Read branding
  final branding = await PdfBrandingService.instance.getBranding(companyId);
  final docType = BrandingDocType.report; // or .quote, .invoice, .jobsheet
  final appliesHere = branding.appliesToDocType(docType);

  // If branding doesn't apply, use the existing defaults
  final effectiveBranding = appliesHere
    ? branding
    : PdfBranding.defaultBranding();

  // Existing code, modified to read from effectiveBranding
  final colourScheme = PdfColourScheme.fromHex(
    primaryHex: effectiveBranding.primaryColour,
    accentHex: effectiveBranding.accentColour,
  );

  final headerConfig = await PdfHeaderConfigService.instance
    .getConfigMergedWith(effectiveBranding);

  final footerConfig = await PdfFooterConfigService.instance
    .getConfigMergedWith(effectiveBranding);

  // Pass cover style + cover text overrides to the cover-builder widget
  final coverWidget = _buildCover(
    style: effectiveBranding.coverStyle,
    text: effectiveBranding.coverTextFor(docType),
    primaryColour: effectiveBranding.primaryColour.toPdfColor(),
    accentColour: effectiveBranding.accentColour.toPdfColor(),
    logoBytes: branding.logoUrl != null
      ? await _fetchLogoBytes(branding.logoUrl!)
      : null,
    // ... existing args
  );

  // ... rest of existing PDF generation code unchanged
}
```

### Per-service required cover-builder additions

The four services already have a cover-page-building section. Each needs
to gain support for three layout styles (bold, minimal, bordered). Add a
`PdfCoverBuilder` static class to the `pdf_widgets/` library:

```dart
// lib/services/pdf_widgets/pdf_cover_builder.dart (NEW)

class PdfCoverBuilder {
  PdfCoverBuilder._();

  static pw.Widget build({
    required CoverStyle style,
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<({String label, String value})> metaFields,
    required PdfColor primaryColour,
    required PdfColor accentColour,
    required Uint8List? logoBytes,
    required String companyName,
  }) {
    switch (style) {
      case CoverStyle.bold:     return _buildBold(...);
      case CoverStyle.minimal:  return _buildMinimal(...);
      case CoverStyle.bordered: return _buildBordered(...);
    }
  }

  // Three private builders, one per style.
  // Bold = navy bg + white text + amber radial glow
  // Minimal = white bg + amber 4px divider + dark text
  // Bordered = white bg + thick navy top/bottom borders
}
```

Then each PDF service replaces its bespoke cover-page code with a call to
`PdfCoverBuilder.build(...)`. This is the only NEW pdf_widgets file
required.

### Header and footer builder updates

`PdfHeaderBuilder` and `PdfFooterBuilder` already exist and are shared.
Extend them to accept a style enum:

```dart
PdfHeaderBuilder.buildHeader({
  required HeaderStyle style,        // NEW
  required PdfHeaderConfig config,
  required PdfColor primaryColour,
  required PdfColor accentColour,    // NEW
  // ... existing args
});
```

The three styles (solid / minimal / bordered) determine background, border,
text colour. See the prototype's `pdf-page-header` styles as reference.

Same pattern for `PdfFooterBuilder`.

---

## Edge cases and what to do

**No branding doc exists yet.** `getBranding` returns `PdfBranding.defaultBranding()`.
PDFs render with the existing default colours and styling. No change for
users who never visit the customiser.

**Logo upload fails (network, size, type).** Show an error toast with the
specific reason. Don't write `logoUrl` to Firestore. The previous logo
(if any) stays.

**Customiser shows a doc type that has no per-type cover text override.**
The preview shows the system-default cover text for that doc type (e.g.
"Annual Inspection Certificate" for a compliance report). The dispatcher
can override by typing in the cover text fields, which then writes to
`coverTextReport` / `coverTextQuote` / etc. depending on which doc type
they're currently viewing.

For v1, the simplest approach: the cover text controls in the panel ALWAYS
edit the currently-selected doc type's overrides. Add a small label above
the controls that says "Editing cover text for: Compliance Report" so the
user knows.

**User unchecks all four "Apply to" checkboxes.** Allowed. Means no PDFs
get the custom branding — defaults everywhere. Show a small warning banner:
"Your branding isn't being applied to any documents." Don't block.

**Logo image is enormous (high-res PNG).** Clamp at 1MB on upload. PDFs
embed the bytes, so a huge logo bloats every PDF. If you want to be fancy,
auto-resize on upload to max 500px wide using a Cloud Function. v2.

**Two dispatchers edit branding simultaneously.** Last-write-wins, like
the Schedule. Real-time stream propagates the latest state to both. Add
an "Updated by [name] just now" indicator under the topbar save status
so the second dispatcher sees their colleague's changes appearing.

**Company has no `pdf_branding` permission set anywhere.** Branding is
gated by `pdf_branding`. If somehow no one has that permission (rare but
possible), branding is read-only. Show "Read only — ask an admin to give
you PDF Branding permission" in place of the controls panel.

**Existing PDFs have already been generated with old branding.** Branding
applies to FUTURE PDF generation only. Old PDFs are static files and
don't change. Make this explicit somewhere visible: maybe a small note
under the "Apply to all" button: "Applies to future PDFs only. Existing
PDFs are unchanged."

---

## Definition of done

- New `PdfBranding` model with full `toJson`/`fromJson`/`copyWith`
- `PdfBrandingService` with caching, watching, saving, logo upload
- Web customiser screen renders the prototype's layout in Flutter widgets
- Live preview updates within 100ms of any control change
- Logo upload works (PNG, JPG, SVG, max 1MB)
- All four colour pickers work (presets + hex input both update preview)
- All three style toggles (cover, header, footer) update preview correctly
- All four doc-type previews render with the correct sample content
- Apply-to-all multi-select scopes branding correctly (verified by
  generating a test PDF for an excluded type — should look default)
- Autosave on every change, debounced 500ms
- "Generate test PDF" button produces a real PDF using the current branding
- Mobile compliance report PDF renders with the new branding
- Mobile quote PDF renders with the new branding
- Mobile invoice PDF renders with the new branding
- Mobile jobsheet PDF renders with the new branding
- All four mobile services correctly fall back when their type is excluded
- Permission gate: only users with `pdf_branding` see the customiser
- Tested on Chrome at 1440×900

---

## Implementation order (one item per session)

### Session 1 — Data model + service + Firestore rules

Create:
- `lib/models/pdf_branding.dart` with all enums, the model, and
  `BrandingCoverText`
- `lib/services/pdf_branding_service.dart` with cache, get, watch, save, upload
- Firestore rule for `companies/{companyId}/branding/{docId}`

No UI yet. Write a quick test that creates a default branding, saves it,
loads it back. This is the foundation everything else builds on.

### Session 2 — Customiser screen scaffold

Create:
- `web_branding_screen.dart` with the topbar, two-pane layout
- `branding_controls_panel.dart` with the tab bar (Brand / Type / Layout / Content)
- `branding_preview_canvas.dart` with the toolbar + canvas area + applies-callout

Hardcoded defaults in the preview. No real binding to PdfBrandingService yet.
This produces something that looks like the prototype but isn't functional.

### Session 3 — Brand controls section

Implement the Brand tab content:
- `branding_apply_to_section.dart` with 4 checkable rows
- `branding_logo_upload.dart` with upload + preview + replace/remove
- `branding_colour_picker.dart` × 2 (Primary, Accent) with swatch + hex input + presets
- `branding_style_toggle_group.dart` × 3 (cover, header, footer styles)
- Switches for header/footer toggles
- Cover text fields (eyebrow, title, subtitle) and footer text field

Bind these to local state. No save yet. No live preview yet.

### Session 4 — Live HTML preview for ONE doc type (Compliance Report)

Build:
- `pdf_preview_page.dart` — the page container with paper-like styling
- `pdf_preview_report.dart` — the compliance report preview content with
  cover, header, summary section, asset register section, footer
- Wire local state to the preview so changes update it in real time

Test that changing the primary colour repaints the cover. Test that
changing cover style swaps between the three layouts. Test that changing
footer text updates the footer.

### Session 5 — Add other three doc-type previews + switcher

Build:
- `branding_doc_type_switcher.dart` — the four pills above the canvas
- `pdf_preview_quote.dart`
- `pdf_preview_invoice.dart`
- `pdf_preview_jobsheet.dart`

Each uses the same `pdf_preview_page` container but renders different
sample content. Verify that the brand controls update all four equally.

### Session 6 — Wire to PdfBrandingService (autosave + watch)

Replace local state with `StreamBuilder<PdfBranding>` watching
`PdfBrandingService.watchBranding`. Every control change calls
`PdfBrandingService.saveBranding` after a 500ms debounce. Add the "Saved"
status pill in the topbar.

Wire the logo upload to actually call `uploadLogo`. Wire "Generate test
PDF" to call the existing compliance report service with the current
branding.

End of this session: the customiser is fully functional from a write
perspective. Mobile reads still use defaults.

### Session 7 — Mobile wiring: cover builder + compliance report service

Create `lib/services/pdf_widgets/pdf_cover_builder.dart` with the three
style implementations.

Modify `lib/services/compliance_report_service.dart` to:
- Read branding via `PdfBrandingService.getBranding`
- Check `appliesTo`
- Use `PdfCoverBuilder` for the cover page
- Pass branding colours/styles into header/footer builders

Verify on mobile: open the customiser, change the primary colour to red,
generate a compliance report from a phone, verify the PDF is red.

### Session 8 — Wire the other three PDF services + extended header/footer

Repeat the Session 7 pattern for:
- `quote_pdf_service.dart`
- `invoice_pdf_service.dart`
- `template_pdf_service.dart` (jobsheets)

Extend `PdfHeaderBuilder` and `PdfFooterBuilder` with the new style enums.

End-to-end test:
1. On web, set primary to red, accent to green, cover style to Minimal,
   logo uploaded
2. On mobile, generate one of each: compliance report, quote, invoice,
   jobsheet
3. Verify all four PDFs render with the new branding
4. On web, untick "Invoices" from Apply to all
5. On mobile, generate a new invoice — verify it renders with defaults
6. Generate a new compliance report — verify it still has the new branding

---

## Tests to write as you go

For the model:
- Round-trip JSON serialization (every field, including null overrides)
- `appliesToDocType` returns correct booleans for each enum value
- `coverTextFor` returns the correct override or null
- `defaultBranding` produces sensible defaults

For the service:
- `getBranding` returns default when no doc exists
- `saveBranding` writes correctly with audit fields populated
- `uploadLogo` rejects oversize files
- `uploadLogo` rejects wrong mime types
- `watchBranding` emits on changes

For the customiser screen:
- Changing the primary colour updates the preview
- Switching doc-type pills changes the preview content
- Unticking an Apply-to row writes the correct `appliesTo` set

For the mobile services (integration tests if possible):
- Compliance PDF uses branding colours when `report` is in `appliesTo`
- Compliance PDF uses defaults when `report` is not in `appliesTo`
- Same for quote / invoice / jobsheet

---

## What to ask if you're unsure

- "The user wants logo cropping/repositioning on upload — should I include
  that in v1 or defer to v2?" (My guess: defer. Just upload as-is and
  centre it on the cover.)
- "Should the customiser be available to all admins or just one designated
  'brand owner' role?" (My guess: any user with `pdf_branding`. No new
  role needed.)
- "Custom fonts — only the four predefined options (Outfit/Inter/Playfair/Roboto)
  or should the user be able to upload their own .ttf?" (My guess: predefined
  only. Custom fonts open up a font-licensing nightmare.)
- "What should 'Reset to defaults' do — wipe the doc, or set every field to
  its default value but keep the doc?" (My guess: set fields to default but
  keep the doc, with confirmation. That way the audit trail stays intact.)
