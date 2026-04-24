import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firethings/services/pdf_widgets/pdf_font_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = PdfFontRegistry.instance;

  test('ensureLoaded registers all seven fonts', () async {
    await registry.ensureLoaded();

    expect(registry.outfitDisplay, isA<pw.Font>());
    expect(registry.outfitBold, isA<pw.Font>());
    expect(registry.interRegular, isA<pw.Font>());
    expect(registry.interMedium, isA<pw.Font>());
    expect(registry.interSemibold, isA<pw.Font>());
    expect(registry.interBold, isA<pw.Font>());
    expect(registry.mono, isA<pw.Font>());
  });

  test('generates a one-page PDF with each font weight', () async {
    await registry.ensureLoaded();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Outfit ExtraBold (800)', style: pw.TextStyle(font: registry.outfitDisplay, fontSize: 24)),
            pw.SizedBox(height: 8),
            pw.Text('Outfit Bold (700)', style: pw.TextStyle(font: registry.outfitBold, fontSize: 24)),
            pw.SizedBox(height: 8),
            pw.Text('Inter Regular (400)', style: pw.TextStyle(font: registry.interRegular, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Inter Medium (500)', style: pw.TextStyle(font: registry.interMedium, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Inter SemiBold (600)', style: pw.TextStyle(font: registry.interSemibold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Inter Bold (700)', style: pw.TextStyle(font: registry.interBold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('JetBrains Mono Medium (500)', style: pw.TextStyle(font: registry.mono, fontSize: 12)),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    expect(bytes.length, greaterThan(0));
  });
}
