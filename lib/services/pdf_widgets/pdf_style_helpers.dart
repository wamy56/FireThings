import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_section_style_config.dart';

/// Common constants for PDF styling
const PdfColor pdfWhite = PdfColors.white;
const PdfColor pdfLightGray = PdfColor.fromInt(0xFFE0E0E0);
const PdfColor pdfDarkGray = PdfColor.fromInt(0xFF424242);

/// Build box decoration based on section card style
pw.BoxDecoration buildCardDecoration(
  PdfSectionStyleConfig style,
  PdfColourScheme colors,
) {
  switch (style.cardStyle) {
    case SectionCardStyle.bordered:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        border: pw.Border.all(color: pdfLightGray, width: 0.5),
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
      );
    case SectionCardStyle.shadowed:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        border: pw.Border.all(color: pdfLightGray, width: 0.5),
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
      );
    case SectionCardStyle.elevated:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFBDBDBD),
          width: 1,
        ),
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
      );
    case SectionCardStyle.flat:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
      );
  }
}

/// Get text style for labels
pw.TextStyle labelStyle(PdfColourScheme colors, {double fontSize = 8}) {
  return pw.TextStyle(
    fontSize: fontSize,
    color: colors.textSecondary,
    letterSpacing: 0.5,
  );
}

/// Get text style for values
pw.TextStyle valueStyle(PdfColourScheme colors,
    {double fontSize = 10, bool bold = true}) {
  return pw.TextStyle(
    fontSize: fontSize,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: colors.textPrimary,
  );
}
