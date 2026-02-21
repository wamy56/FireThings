import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pdf_footer_config.dart';
import '../models/pdf_header_config.dart';

class PdfFooterBuilder {
  static const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);
  static const PdfColor _lightGray = PdfColor.fromInt(0xFFE0E0E0);

  /// Builds the PDF footer with left zone, optional centre zone, and page numbers.
  ///
  /// Uses explicit [pageNumber] and [pagesCount] params so it works for both
  /// `MultiPage` (jobsheet) and single `Page` (invoice).
  static pw.Widget buildFooter({
    required PdfFooterConfig config,
    required int pageNumber,
    required int pagesCount,
    Map<String, String> fallbackValues = const {},
    PdfColor? primaryColor,
  }) {
    final children = <pw.Widget>[];

    // Left zone
    final leftWidgets = _buildTextLines(config.leftLines, fallbackValues);
    children.add(
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: leftWidgets,
        ),
      ),
    );

    // Centre zone (only if lines exist)
    final centreWidgets = _buildTextLines(config.centreLines, fallbackValues);
    if (centreWidgets.isNotEmpty) {
      children.add(
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreWidgets,
          ),
        ),
      );
    }

    // Page numbers (right-aligned)
    children.add(
      pw.Text(
        'Page $pageNumber of $pagesCount',
        style: const pw.TextStyle(fontSize: 8, color: _darkGray),
      ),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: primaryColor ?? _lightGray, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static List<pw.Widget> _buildTextLines(
    List<HeaderTextLine> lines,
    Map<String, String> fallbackValues,
  ) {
    final widgets = <pw.Widget>[];
    for (final line in lines) {
      final text = line.value.isNotEmpty
          ? line.value
          : (fallbackValues[line.key] ?? '');
      if (text.isEmpty) continue;

      widgets.add(
        pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: line.fontSize,
            fontWeight: line.bold ? pw.FontWeight.bold : null,
            color: _darkGray,
          ),
        ),
      );
    }
    return widgets;
  }
}
