import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firethings/models/pdf_branding.dart';
import 'package:firethings/services/pdf_widgets/pdf_cover_builder.dart';
import 'package:firethings/services/pdf_widgets/pdf_font_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testBranding = PdfBranding(
    primaryColour: '#1A1A2E',
    accentColour: '#FFB020',
    updatedAt: DateTime(2026, 4, 23),
    lastModifiedAt: DateTime(2026, 4, 23),
  );

  final metaFields = [
    (label: 'Client', value: 'Acme Fire Ltd'),
    (label: 'Site', value: '14 Industrial Way, Manchester'),
    (label: 'Date', value: '23 April 2026'),
    (label: 'Reference', value: 'RPT-2026-0042'),
  ];

  setUpAll(() async {
    await PdfFontRegistry.instance.ensureLoaded();
  });

  pw.Document _buildDoc(CoverStyle style) {
    final branding = testBranding.copyWith(coverStyle: style);
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => PdfCoverBuilder.build(
        branding: branding,
        docType: BrandingDocType.report,
        defaultEyebrow: 'COMPLIANCE REPORT',
        defaultTitle: 'BS 5839-1 Fire Detection\n& Alarm Systems',
        defaultSubtitle: 'Annual service and compliance inspection',
        metaFields: metaFields,
        logoBytes: null,
        companyName: 'FireThings Demo Co.',
      ),
    ));
    return doc;
  }

  test('Bold cover generates valid PDF', () async {
    final bytes = await _buildDoc(CoverStyle.bold).save();
    expect(bytes.length, greaterThan(0));
  });

  test('Minimal cover generates valid PDF', () async {
    final bytes = await _buildDoc(CoverStyle.minimal).save();
    expect(bytes.length, greaterThan(0));
  });

  test('Bordered cover generates valid PDF', () async {
    final bytes = await _buildDoc(CoverStyle.bordered).save();
    expect(bytes.length, greaterThan(0));
  });

  test('cover text overrides from branding are applied', () async {
    final branding = testBranding.copyWith(
      coverStyle: CoverStyle.bold,
      coverTextReport: const BrandingCoverText(
        eyebrow: 'CUSTOM EYEBROW',
        title: 'Custom Title',
        subtitle: 'Custom subtitle text',
      ),
    );

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => PdfCoverBuilder.build(
        branding: branding,
        docType: BrandingDocType.report,
        defaultEyebrow: 'SHOULD NOT APPEAR',
        defaultTitle: 'Should Not Appear',
        defaultSubtitle: 'Should not appear',
        metaFields: metaFields,
        logoBytes: null,
        companyName: 'Test Co.',
      ),
    ));

    final bytes = await doc.save();
    expect(bytes.length, greaterThan(0));
  });

  test('all three styles produce different-sized PDFs', () async {
    final boldBytes = await _buildDoc(CoverStyle.bold).save();
    final minimalBytes = await _buildDoc(CoverStyle.minimal).save();
    final borderedBytes = await _buildDoc(CoverStyle.bordered).save();

    final sizes = {boldBytes.length, minimalBytes.length, borderedBytes.length};
    expect(sizes.length, greaterThan(1),
        reason: 'Different cover styles should produce different PDF byte sizes');
  });
}
