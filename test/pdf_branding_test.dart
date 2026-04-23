import 'package:flutter_test/flutter_test.dart';
import 'package:firethings/models/pdf_branding.dart';

void main() {
  // ── BrandingCoverText ─────────────────────────────────────────

  group('BrandingCoverText serialisation', () {
    test('round-trips with all fields', () {
      const ct = BrandingCoverText(
        eyebrow: 'ANNUAL INSPECTION',
        title: 'Certificate {{document_number}}',
        subtitle: 'Prepared for {{customer_name}}',
      );
      final json = ct.toJson();
      final restored = BrandingCoverText.fromJson(json);

      expect(restored.eyebrow, 'ANNUAL INSPECTION');
      expect(restored.title, 'Certificate {{document_number}}');
      expect(restored.subtitle, 'Prepared for {{customer_name}}');
    });

    test('omits null fields from JSON', () {
      const ct = BrandingCoverText(title: 'Only title');
      final json = ct.toJson();

      expect(json.containsKey('title'), isTrue);
      expect(json.containsKey('eyebrow'), isFalse);
      expect(json.containsKey('subtitle'), isFalse);
    });

    test('fromJson handles all-null gracefully', () {
      final ct = BrandingCoverText.fromJson(<String, dynamic>{});
      expect(ct.eyebrow, isNull);
      expect(ct.title, isNull);
      expect(ct.subtitle, isNull);
    });
  });

  // ── PdfBranding ───────────────────────────────────────────────

  group('PdfBranding serialisation', () {
    late PdfBranding branding;

    setUp(() {
      branding = PdfBranding(
        logoUrl: 'https://storage.example.com/logo.png',
        logoMaxHeight: 80,
        primaryColour: '#FF0000',
        accentColour: '#00FF00',
        fontDisplay: 'playfair',
        fontBody: 'roboto',
        coverStyle: CoverStyle.bordered,
        coverTextReport: const BrandingCoverText(
          eyebrow: 'REPORT',
          title: 'Compliance Report',
          subtitle: 'For site {{site_name}}',
        ),
        coverTextQuote: const BrandingCoverText(
          eyebrow: 'QUOTE',
          title: 'Quotation',
        ),
        coverTextInvoice: const BrandingCoverText(
          title: 'Invoice {{document_number}}',
        ),
        coverTextJobsheet: const BrandingCoverText(
          eyebrow: 'JOB SHEET',
          title: 'Service Record',
          subtitle: 'Engineer: {{engineer_name}}',
        ),
        headerStyle: HeaderStyle.bordered,
        headerShowCompanyName: false,
        headerShowDocNumber: false,
        footerStyle: FooterStyle.coloured,
        footerText: 'Co No 12345 · VAT GB 67890',
        footerShowCompanyName: false,
        footerShowPageNumbers: false,
        appliesTo: const {BrandingDocType.report, BrandingDocType.invoice},
        lastUpdatedBy: 'uid-abc',
        updatedAt: DateTime(2026, 4, 20, 10, 30),
        lastModifiedAt: DateTime(2026, 4, 20, 10, 30),
      );
    });

    test('round-trips with all fields populated', () {
      final json = branding.toJson();
      final restored = PdfBranding.fromJson(json);

      expect(restored.logoUrl, 'https://storage.example.com/logo.png');
      expect(restored.logoMaxHeight, 80);
      expect(restored.primaryColour, '#FF0000');
      expect(restored.accentColour, '#00FF00');
      expect(restored.fontDisplay, 'playfair');
      expect(restored.fontBody, 'roboto');
      expect(restored.coverStyle, CoverStyle.bordered);
      expect(restored.coverTextReport?.eyebrow, 'REPORT');
      expect(restored.coverTextReport?.title, 'Compliance Report');
      expect(restored.coverTextReport?.subtitle, 'For site {{site_name}}');
      expect(restored.coverTextQuote?.eyebrow, 'QUOTE');
      expect(restored.coverTextQuote?.title, 'Quotation');
      expect(restored.coverTextQuote?.subtitle, isNull);
      expect(restored.coverTextInvoice?.title, 'Invoice {{document_number}}');
      expect(restored.coverTextInvoice?.eyebrow, isNull);
      expect(restored.coverTextJobsheet?.eyebrow, 'JOB SHEET');
      expect(restored.headerStyle, HeaderStyle.bordered);
      expect(restored.headerShowCompanyName, false);
      expect(restored.headerShowDocNumber, false);
      expect(restored.footerStyle, FooterStyle.coloured);
      expect(restored.footerText, 'Co No 12345 · VAT GB 67890');
      expect(restored.footerShowCompanyName, false);
      expect(restored.footerShowPageNumbers, false);
      expect(restored.appliesTo,
          {BrandingDocType.report, BrandingDocType.invoice});
      expect(restored.lastUpdatedBy, 'uid-abc');
      expect(restored.updatedAt, DateTime(2026, 4, 20, 10, 30));
      expect(restored.lastModifiedAt, DateTime(2026, 4, 20, 10, 30));
    });

    test('round-trips with minimal fields (defaults)', () {
      final minimal = PdfBranding(
        updatedAt: DateTime(2026, 1, 1),
        lastModifiedAt: DateTime(2026, 1, 1),
      );
      final json = minimal.toJson();
      final restored = PdfBranding.fromJson(json);

      expect(restored.logoUrl, isNull);
      expect(restored.logoMaxHeight, 60);
      expect(restored.primaryColour, '#1A1A2E');
      expect(restored.accentColour, '#FFB020');
      expect(restored.fontDisplay, 'outfit');
      expect(restored.fontBody, 'inter');
      expect(restored.coverStyle, CoverStyle.bold);
      expect(restored.coverTextReport, isNull);
      expect(restored.coverTextQuote, isNull);
      expect(restored.coverTextInvoice, isNull);
      expect(restored.coverTextJobsheet, isNull);
      expect(restored.headerStyle, HeaderStyle.solid);
      expect(restored.headerShowCompanyName, true);
      expect(restored.headerShowDocNumber, true);
      expect(restored.footerStyle, FooterStyle.light);
      expect(restored.footerText, '');
      expect(restored.footerShowCompanyName, true);
      expect(restored.footerShowPageNumbers, true);
      expect(restored.appliesTo, {
        BrandingDocType.report,
        BrandingDocType.quote,
        BrandingDocType.invoice,
        BrandingDocType.jobsheet,
      });
      expect(restored.lastUpdatedBy, isNull);
    });

    test('toJson omits null logoUrl, coverTexts, and lastUpdatedBy', () {
      final minimal = PdfBranding(
        updatedAt: DateTime(2026, 1, 1),
        lastModifiedAt: DateTime(2026, 1, 1),
      );
      final json = minimal.toJson();

      expect(json.containsKey('logoUrl'), isFalse);
      expect(json.containsKey('coverTextReport'), isFalse);
      expect(json.containsKey('coverTextQuote'), isFalse);
      expect(json.containsKey('coverTextInvoice'), isFalse);
      expect(json.containsKey('coverTextJobsheet'), isFalse);
      expect(json.containsKey('lastUpdatedBy'), isFalse);
    });

    test('round-trips via toJsonString / fromJsonString', () {
      final jsonString = branding.toJsonString();
      final restored = PdfBranding.fromJsonString(jsonString);

      expect(restored.primaryColour, branding.primaryColour);
      expect(restored.coverStyle, branding.coverStyle);
      expect(restored.appliesTo, branding.appliesTo);
    });

    test('copyWith preserves unmodified fields', () {
      final modified = branding.copyWith(primaryColour: '#0000FF');

      expect(modified.primaryColour, '#0000FF');
      expect(modified.accentColour, branding.accentColour);
      expect(modified.logoUrl, branding.logoUrl);
      expect(modified.coverStyle, branding.coverStyle);
      expect(modified.headerStyle, branding.headerStyle);
      expect(modified.footerText, branding.footerText);
      expect(modified.appliesTo, branding.appliesTo);
      expect(modified.coverTextReport?.eyebrow, 'REPORT');
    });

    test('copyWith clear flags work', () {
      final cleared = branding.copyWith(
        clearLogoUrl: true,
        clearCoverTextReport: true,
        clearCoverTextQuote: true,
        clearCoverTextInvoice: true,
        clearCoverTextJobsheet: true,
        clearLastUpdatedBy: true,
      );

      expect(cleared.logoUrl, isNull);
      expect(cleared.coverTextReport, isNull);
      expect(cleared.coverTextQuote, isNull);
      expect(cleared.coverTextInvoice, isNull);
      expect(cleared.coverTextJobsheet, isNull);
      expect(cleared.lastUpdatedBy, isNull);
      expect(cleared.primaryColour, branding.primaryColour);
    });
  });

  // ── Helpers ───────────────────────────────────────────────────

  group('PdfBranding helpers', () {
    test('appliesToDocType returns correct booleans', () {
      final subset = PdfBranding(
        appliesTo: const {BrandingDocType.report, BrandingDocType.invoice},
        updatedAt: DateTime(2026, 1, 1),
        lastModifiedAt: DateTime(2026, 1, 1),
      );

      expect(subset.appliesToDocType(BrandingDocType.report), isTrue);
      expect(subset.appliesToDocType(BrandingDocType.invoice), isTrue);
      expect(subset.appliesToDocType(BrandingDocType.quote), isFalse);
      expect(subset.appliesToDocType(BrandingDocType.jobsheet), isFalse);
    });

    test('coverTextFor returns correct override or null', () {
      final b = PdfBranding(
        coverTextReport:
            const BrandingCoverText(title: 'Report Title'),
        coverTextInvoice:
            const BrandingCoverText(title: 'Invoice Title'),
        updatedAt: DateTime(2026, 1, 1),
        lastModifiedAt: DateTime(2026, 1, 1),
      );

      expect(b.coverTextFor(BrandingDocType.report)?.title, 'Report Title');
      expect(
          b.coverTextFor(BrandingDocType.invoice)?.title, 'Invoice Title');
      expect(b.coverTextFor(BrandingDocType.quote), isNull);
      expect(b.coverTextFor(BrandingDocType.jobsheet), isNull);
    });

    test('defaultBranding produces sensible defaults', () {
      final d = PdfBranding.defaultBranding();

      expect(d.logoUrl, isNull);
      expect(d.logoMaxHeight, 60);
      expect(d.primaryColour, '#1A1A2E');
      expect(d.accentColour, '#FFB020');
      expect(d.fontDisplay, 'outfit');
      expect(d.fontBody, 'inter');
      expect(d.coverStyle, CoverStyle.bold);
      expect(d.headerStyle, HeaderStyle.solid);
      expect(d.footerStyle, FooterStyle.light);
      expect(d.footerShowPageNumbers, true);
      expect(d.appliesTo.length, 4);
    });
  });

  // ── Enum round-trips ──────────────────────────────────────────

  group('Enum round-trips', () {
    test('all CoverStyle values serialise correctly', () {
      for (final style in CoverStyle.values) {
        final b = PdfBranding(
          coverStyle: style,
          updatedAt: DateTime(2026, 1, 1),
          lastModifiedAt: DateTime(2026, 1, 1),
        );
        final restored = PdfBranding.fromJson(b.toJson());
        expect(restored.coverStyle, style);
      }
    });

    test('all HeaderStyle values serialise correctly', () {
      for (final style in HeaderStyle.values) {
        final b = PdfBranding(
          headerStyle: style,
          updatedAt: DateTime(2026, 1, 1),
          lastModifiedAt: DateTime(2026, 1, 1),
        );
        final restored = PdfBranding.fromJson(b.toJson());
        expect(restored.headerStyle, style);
      }
    });

    test('all FooterStyle values serialise correctly', () {
      for (final style in FooterStyle.values) {
        final b = PdfBranding(
          footerStyle: style,
          updatedAt: DateTime(2026, 1, 1),
          lastModifiedAt: DateTime(2026, 1, 1),
        );
        final restored = PdfBranding.fromJson(b.toJson());
        expect(restored.footerStyle, style);
      }
    });

    test('all BrandingDocType values serialise correctly', () {
      for (final dt in BrandingDocType.values) {
        final b = PdfBranding(
          appliesTo: {dt},
          updatedAt: DateTime(2026, 1, 1),
          lastModifiedAt: DateTime(2026, 1, 1),
        );
        final restored = PdfBranding.fromJson(b.toJson());
        expect(restored.appliesTo, {dt});
      }
    });

    test('fromJson falls back gracefully on unknown enum values', () {
      final json = PdfBranding(
        updatedAt: DateTime(2026, 1, 1),
        lastModifiedAt: DateTime(2026, 1, 1),
      ).toJson();

      json['coverStyle'] = 'futuristic';
      json['headerStyle'] = 'unknown';
      json['footerStyle'] = 'nope';

      final restored = PdfBranding.fromJson(json);
      expect(restored.coverStyle, CoverStyle.bold);
      expect(restored.headerStyle, HeaderStyle.solid);
      expect(restored.footerStyle, FooterStyle.light);
    });
  });
}
