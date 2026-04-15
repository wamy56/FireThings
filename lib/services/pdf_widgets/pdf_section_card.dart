import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_section_style_config.dart';
import 'pdf_style_helpers.dart';

/// Builds a styled section card with header and content
pw.Widget buildSectionCard({
  required String title,
  required List<pw.Widget> children,
  required PdfColourScheme colors,
  required PdfSectionStyleConfig style,
  bool showHeader = true,
}) {
  return pw.Container(
    margin: pw.EdgeInsets.only(bottom: style.sectionSpacing),
    decoration: buildCardDecoration(style, colors),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (showHeader) _buildSectionHeader(title, colors, style),
        pw.Padding(
          padding: pw.EdgeInsets.all(style.innerPadding),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    ),
  );
}

/// Build section header based on style
pw.Widget _buildSectionHeader(
  String title,
  PdfColourScheme colors,
  PdfSectionStyleConfig style,
) {
  switch (style.headerStyle) {
    case SectionHeaderStyle.fullWidth:
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: colors.primaryColor,
          borderRadius: style.cardStyle == SectionCardStyle.flat
              ? null
              : pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(style.cornerRadius.pixels),
                  topRight: pw.Radius.circular(style.cornerRadius.pixels),
                ),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: style.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: pdfWhite,
            letterSpacing: 0.5,
          ),
        ),
      );

    case SectionHeaderStyle.leftAccent:
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: colors.primaryColor, width: 4),
          ),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: style.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: colors.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
      );

    case SectionHeaderStyle.underlined:
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(0, 8, 0, 6),
        margin: pw.EdgeInsets.symmetric(horizontal: style.innerPadding),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: colors.primaryMedium, width: 1),
          ),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: style.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: colors.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
      );
  }
}
