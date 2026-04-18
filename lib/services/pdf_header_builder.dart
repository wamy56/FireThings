import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pdf_header_config.dart';

class PdfHeaderBuilder {
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF1E3A5F);
  static const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);

  /// Builds the left and centre zones of the PDF header based on config.
  ///
  /// [fallbackValues] maps line keys to default display values when the
  /// line's own value is empty. e.g. {'companyName': 'ACME Corp', 'tagline': 'Quality first'}
  static pw.Widget buildLeftAndCentre({
    required PdfHeaderConfig config,
    Uint8List? logoBytes,
    Map<String, String> fallbackValues = const {},
    PdfColor? primaryColor,
  }) {
    final effectivePrimary = primaryColor ?? _primaryColor;
    final leftChildren = <pw.Widget>[];
    final centreChildren = <pw.Widget>[];

    // Build logo widget
    pw.Widget? logoWidget;
    if (logoBytes != null && config.logoZone != LogoZone.none) {
      final size = config.logoSize.pixels;
      logoWidget = pw.Container(
        width: size,
        height: size,
        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
      );
    }

    // Left zone
    if (config.logoZone == LogoZone.left && logoWidget != null) {
      leftChildren.add(logoWidget);
      leftChildren.add(pw.SizedBox(width: 10));
    }

    final leftTextLines = _buildTextLines(config.leftLines, fallbackValues, effectivePrimary);
    if (leftTextLines.isNotEmpty) {
      leftChildren.add(
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: leftTextLines,
          ),
        ),
      );
    } else if (leftChildren.isEmpty) {
      // Ensure left zone takes space even if empty
      leftChildren.add(pw.Expanded(child: pw.SizedBox()));
    }

    // Centre zone text (logo centre is handled separately above the row)
    final centreTextLines = _buildTextLines(config.centreLines, fallbackValues, effectivePrimary);
    if (centreTextLines.isNotEmpty) {
      centreChildren.add(
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreTextLines,
          ),
        ),
      );
    }

    // Build the combined row
    final rowChildren = <pw.Widget>[];

    // Left zone as a row
    rowChildren.add(
      pw.Expanded(
        flex: 3,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: leftChildren,
        ),
      ),
    );

    // Centre zone (only if it has content)
    if (centreChildren.isNotEmpty) {
      rowChildren.add(pw.SizedBox(width: 12));
      rowChildren.add(
        pw.Expanded(
          flex: 2,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreChildren,
          ),
        ),
      );
    }

    final contentRow = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rowChildren,
    );

    return contentRow;
  }

  static List<pw.Widget> _buildTextLines(
    List<HeaderTextLine> lines,
    Map<String, String> fallbackValues,
    PdfColor primaryColorOverride,
  ) {
    final widgets = <pw.Widget>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.value.isNotEmpty
          ? line.value
          : (fallbackValues[line.key] ?? '');
      if (text.isEmpty) continue;

      if (i > 0) {
        // Small spacing between lines - slightly more after first line
        widgets.add(pw.SizedBox(height: i == 1 ? 4 : 2));
      }

      final isCompanyName = line.key == 'companyName';
      widgets.add(
        pw.Text(
          isCompanyName ? text.toUpperCase() : text,
          style: pw.TextStyle(
            fontSize: line.fontSize,
            fontWeight: line.bold ? pw.FontWeight.bold : null,
            color: isCompanyName ? primaryColorOverride : _darkGray,
          ),
        ),
      );
    }
    return widgets;
  }
}
