import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/pdf_branding.dart';
import 'pdf_font_registry.dart';

class PdfBrandTokens {
  PdfBrandTokens._();

  static final _fonts = PdfFontRegistry.instance;

  // ── Colours ──

  static PdfColor primary(PdfBranding b) => _parseHex(b.primaryColour);
  static PdfColor accent(PdfBranding b) => _parseHex(b.accentColour);

  static const PdfColor white = PdfColors.white;
  static const PdfColor fg1 = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor fg2 = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor border = PdfColor.fromInt(0xFFE8E5DE);
  static const PdfColor bgAlt = PdfColor.fromInt(0xFFFAFAF7);

  // ── Cover text styles ──

  static pw.TextStyle coverEyebrow(PdfBranding b) {
    final onDark = b.coverStyle == CoverStyle.bold;
    return pw.TextStyle(
      font: _fonts.interBold,
      fontSize: 10,
      letterSpacing: 1.4,
      color: onDark
          ? const PdfColor.fromInt(0x99FFFFFF)
          : accent(b),
    );
  }

  static pw.TextStyle coverTitle(PdfBranding b) {
    final onDark = b.coverStyle == CoverStyle.bold;
    return pw.TextStyle(
      font: _fonts.outfitDisplay,
      fontSize: 34,
      letterSpacing: -0.8,
      lineSpacing: 2,
      color: onDark ? white : primary(b),
    );
  }

  static pw.TextStyle coverSubtitle(PdfBranding b) {
    final onDark = b.coverStyle == CoverStyle.bold;
    return pw.TextStyle(
      font: _fonts.interMedium,
      fontSize: 14,
      color: onDark
          ? const PdfColor.fromInt(0xBFFFFFFF)
          : fg2,
    );
  }

  static pw.TextStyle coverCompanyName(PdfBranding b) {
    final onDark = b.coverStyle == CoverStyle.bold;
    return pw.TextStyle(
      font: _fonts.interBold,
      fontSize: 16,
      color: onDark ? white : primary(b),
    );
  }

  static pw.TextStyle coverMetaLabel(PdfBranding b) {
    final onDark = b.coverStyle == CoverStyle.bold;
    return pw.TextStyle(
      font: _fonts.interBold,
      fontSize: 10,
      letterSpacing: 0.4,
      color: onDark
          ? const PdfColor.fromInt(0x80FFFFFF)
          : fg2,
    );
  }

  static pw.TextStyle coverMetaValue(PdfBranding b) {
    final onDark = b.coverStyle == CoverStyle.bold;
    return pw.TextStyle(
      font: _fonts.interSemibold,
      fontSize: 14,
      color: onDark ? white : fg1,
    );
  }

  // ── Section styles ──

  static pw.TextStyle sectionEyebrow(PdfBranding b) => pw.TextStyle(
        font: _fonts.interBold,
        fontSize: 10,
        letterSpacing: 1.2,
        color: accent(b),
      );

  static pw.TextStyle sectionTitle(PdfBranding b) => pw.TextStyle(
        font: _fonts.outfitDisplay,
        fontSize: 22,
        letterSpacing: -0.5,
        color: primary(b),
      );

  // ── Body styles ──

  static pw.TextStyle bodyRegular(PdfBranding b) => pw.TextStyle(
        font: _fonts.interRegular,
        fontSize: 10,
        color: fg1,
      );

  static pw.TextStyle bodyMedium(PdfBranding b) => pw.TextStyle(
        font: _fonts.interMedium,
        fontSize: 10,
        color: fg1,
      );

  static pw.TextStyle bodySemibold(PdfBranding b) => pw.TextStyle(
        font: _fonts.interSemibold,
        fontSize: 10,
        color: fg1,
      );

  static pw.TextStyle bodyBold(PdfBranding b) => pw.TextStyle(
        font: _fonts.interBold,
        fontSize: 10,
        color: fg1,
      );

  static pw.TextStyle label(PdfBranding b) => pw.TextStyle(
        font: _fonts.interSemibold,
        fontSize: 9,
        letterSpacing: 0.3,
        color: fg2,
      );

  static pw.TextStyle mono(PdfBranding b) => pw.TextStyle(
        font: _fonts.mono,
        fontSize: 9,
        color: fg2,
      );

  // ── Header styles ──

  static pw.TextStyle headerCompanyName(PdfBranding b) {
    final onDark = b.headerStyle == HeaderStyle.solid;
    return pw.TextStyle(
      font: _fonts.interBold,
      fontSize: 14,
      color: onDark ? white : primary(b),
    );
  }

  static pw.TextStyle headerMeta(PdfBranding b) {
    final color = switch (b.headerStyle) {
      HeaderStyle.solid => const PdfColor.fromInt(0xB3FFFFFF),
      HeaderStyle.minimal => PdfColor.fromInt(
          (primary(b).toInt() & 0x00FFFFFF) | 0xB3000000),
      HeaderStyle.bordered => fg2,
    };
    return pw.TextStyle(
      font: _fonts.interMedium,
      fontSize: 11,
      color: color,
    );
  }

  // ── Footer styles ──

  static pw.TextStyle footerText(PdfBranding b) {
    final onDark = b.footerStyle == FooterStyle.coloured;
    return pw.TextStyle(
      font: _fonts.interMedium,
      fontSize: 10,
      letterSpacing: 0.3,
      color: onDark
          ? const PdfColor.fromInt(0x99FFFFFF)
          : fg2,
    );
  }

  static pw.TextStyle footerBrand(PdfBranding b) {
    final onDark = b.footerStyle == FooterStyle.coloured;
    return pw.TextStyle(
      font: _fonts.interSemibold,
      fontSize: 10,
      color: onDark ? accent(b) : primary(b),
    );
  }

  // ── Logo mark initial ──

  static pw.TextStyle logoInitial(PdfBranding b, {double size = 22}) =>
      pw.TextStyle(
        font: _fonts.outfitDisplay,
        fontSize: size,
        color: primary(b),
      );

  // ── Helpers ──

  static PdfColor _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return PdfColor.fromInt(0xFF000000 | int.parse(clean, radix: 16));
  }
}
