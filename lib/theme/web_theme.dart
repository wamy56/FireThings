/// FireThings Web Portal — Design Tokens
///
/// Drop this file at `lib/theme/web_theme.dart`. All web screens under
/// `lib/screens/web/` should import from this file rather than using
/// hard-coded colours, font sizes, or spacing values.
///
/// Do NOT modify `lib/utils/theme.dart` — that's shared with the mobile
/// app. This file is web-only.
///
/// Fonts are loaded via `google_fonts` package:
///   GoogleFonts.inter(...)
///   GoogleFonts.outfit(...)
///   GoogleFonts.jetBrainsMono(...)
///
/// Add `google_fonts` to pubspec.yaml if it isn't already there.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════
// Colours
// ═══════════════════════════════════════════════════════════════════════

class FtColors {
  FtColors._();

  // Primary
  static const Color primary      = Color(0xFF1A1A2E);
  static const Color primaryDark  = Color(0xFF12121F);
  static const Color primarySoft  = Color(0xFF2A2A4E);

  // Accent (amber-gold)
  static const Color accent       = Color(0xFFFFB020);
  static const Color accentHover  = Color(0xFFE69D1C);
  static const Color accentSoft   = Color(0xFFFFF6E5);

  // Brand
  static const Color brandRed     = Color(0xFFDC2626);

  // Semantic
  static const Color success      = Color(0xFF4CAF50);
  static const Color successSoft  = Color(0xFFE8F5E9);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningSoft  = Color(0xFFFEF3C7);
  static const Color danger       = Color(0xFFDC2626);
  static const Color dangerSoft   = Color(0xFFFEE2E2);
  static const Color info         = Color(0xFF2563EB);
  static const Color infoSoft     = Color(0xFFDBEAFE);

  // Text (foreground)
  static const Color fg1          = Color(0xFF1F2937); // primary text
  static const Color fg2          = Color(0xFF6B7280); // secondary text
  static const Color hint         = Color(0xFF9CA3AF); // tertiary/hint text

  // Surface (background)
  static const Color bg           = Color(0xFFFFFFFF);
  static const Color bgAlt        = Color(0xFFFAFAF7); // warm off-white
  static const Color bgSunken     = Color(0xFFF3F4F1);
  static const Color bgHover      = Color(0xFFECEBE3);

  // Borders
  static const Color border       = Color(0xFFE8E5DE);
  static const Color borderStrong = Color(0xFFD4D1C7);

  // Convenience — amber gradient for featured surfaces
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primarySoft],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandRed, accent],
  );
}

// ═══════════════════════════════════════════════════════════════════════
// Typography
// ═══════════════════════════════════════════════════════════════════════
//
// Use the pre-built text styles below. If you genuinely need a custom
// size, build it from the `inter()`, `outfit()`, or `mono()` helpers
// so the font family is always correct.

class FtText {
  FtText._();

  // ── Fonts as helpers (use these to build one-off styles) ──

  static TextStyle inter({
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle outfit({
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({
    double? size,
    FontWeight? weight,
    Color? color,
  }) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  // ── Preset styles ──
  // Use these by default. Only build custom styles if none of these fit.

  /// Hero page title — used ONCE per page at the top. e.g. "Good morning, Chris".
  static TextStyle get pageTitle => outfit(
        size: 40,
        weight: FontWeight.w800,
        color: FtColors.primary,
        height: 1.05,
        letterSpacing: -1.2,
      );

  /// Document title — slightly smaller page title for detail pages.
  static TextStyle get documentTitle => outfit(
        size: 34,
        weight: FontWeight.w800,
        color: FtColors.primary,
        height: 1.1,
        letterSpacing: -0.8,
      );

  /// Section heading inside a page. Used on card headers, section tops.
  static TextStyle get sectionTitle => inter(
        size: 18,
        weight: FontWeight.w700,
        color: FtColors.primary,
        letterSpacing: -0.3,
      );

  /// Card header title.
  static TextStyle get cardTitle => inter(
        size: 16,
        weight: FontWeight.w700,
        color: FtColors.fg1,
        letterSpacing: -0.2,
      );

  /// Body text.
  static TextStyle get body => inter(
        size: 14,
        weight: FontWeight.w500,
        color: FtColors.fg1,
        height: 1.5,
      );

  /// Secondary body text (for meta info, descriptions).
  static TextStyle get bodySoft => inter(
        size: 14,
        weight: FontWeight.w500,
        color: FtColors.fg2,
        height: 1.5,
      );

  /// Small helper text under inputs, captions.
  static TextStyle get helper => inter(
        size: 12,
        weight: FontWeight.w500,
        color: FtColors.fg2,
      );

  /// Uppercase label — used on key-value pairs, KPI labels, column headers.
  static TextStyle get label => inter(
        size: 11,
        weight: FontWeight.w600,
        color: FtColors.fg2,
        letterSpacing: 0.3,
      );

  /// Strong label for important metadata.
  static TextStyle get labelStrong => inter(
        size: 12,
        weight: FontWeight.w700,
        color: FtColors.fg2,
        letterSpacing: 0.4,
      );

  /// KPI value — large numeric display.
  static TextStyle get kpiValue => outfit(
        size: 36,
        weight: FontWeight.w800,
        color: FtColors.primary,
        height: 1,
        letterSpacing: -1.2,
      );

  /// Button label.
  static TextStyle get button => inter(
        size: 14,
        weight: FontWeight.w600,
        letterSpacing: 0,
      );

  /// Nav item label in the sidebar.
  static TextStyle get navItem => inter(
        size: 14,
        weight: FontWeight.w500,
        color: FtColors.fg2,
      );

  /// Mono text for job references, SLA timers, currency in tables.
  static TextStyle get monoSmall => mono(
        size: 12,
        weight: FontWeight.w600,
        color: FtColors.fg2,
      );

  static TextStyle get monoRegular => mono(
        size: 13,
        weight: FontWeight.w500,
        color: FtColors.fg1,
      );
}

// ═══════════════════════════════════════════════════════════════════════
// Spacing
// ═══════════════════════════════════════════════════════════════════════

class FtSpacing {
  FtSpacing._();

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double base = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 40;
  static const double huge = 48;

  /// Standard card body padding.
  static const EdgeInsets cardBody = EdgeInsets.all(22);

  /// Card header padding.
  static const EdgeInsets cardHeader = EdgeInsets.fromLTRB(22, 18, 22, 18);

  /// Section body padding.
  static const EdgeInsets sectionBody = EdgeInsets.all(24);

  /// Page horizontal padding (main content).
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: 40);
}

// ═══════════════════════════════════════════════════════════════════════
// Radii
// ═══════════════════════════════════════════════════════════════════════

class FtRadii {
  FtRadii._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double xl = 20;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

// ═══════════════════════════════════════════════════════════════════════
// Shadows
// ═══════════════════════════════════════════════════════════════════════

class FtShadows {
  FtShadows._();

  /// Subtle shadow for hover states on cards.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A1A1A2E), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0F1A1A2E), offset: Offset(0, 1), blurRadius: 3),
  ];

  /// Medium shadow for lifted cards (KPI hover, interactive surfaces).
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x141A1A2E), offset: Offset(0, 4), blurRadius: 12),
    BoxShadow(color: Color(0x0A1A1A2E), offset: Offset(0, 2), blurRadius: 4),
  ];

  /// Large shadow for floating surfaces (modals, tooltips, feature cards).
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x141A1A2E), offset: Offset(0, 20), blurRadius: 40),
    BoxShadow(color: Color(0x0A1A1A2E), offset: Offset(0, 4), blurRadius: 12),
  ];

  /// Amber glow — use on primary action buttons.
  static const List<BoxShadow> amber = [
    BoxShadow(color: Color(0x59FFB020), offset: Offset(0, 8), blurRadius: 24),
  ];

  /// Navy glow for sidebar active state.
  static const List<BoxShadow> navyDepth = [
    BoxShadow(color: Color(0x2E1A1A2E), offset: Offset(0, 4), blurRadius: 12),
  ];
}

// ═══════════════════════════════════════════════════════════════════════
// Duration
// ═══════════════════════════════════════════════════════════════════════

class FtMotion {
  FtMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 150);
  static const Duration slow = Duration(milliseconds: 200);

  static const Curve standardCurve = Curves.easeOutCubic;
}

// ═══════════════════════════════════════════════════════════════════════
// Common decorations
// ═══════════════════════════════════════════════════════════════════════
//
// Helpers for the most common surface styles — use these to avoid
// duplicating `BoxDecoration` boilerplate across screens.

class FtDecorations {
  FtDecorations._();

  /// Standard card surface — white, bordered, 16px radius.
  static BoxDecoration card({bool hovered = false}) => BoxDecoration(
        color: FtColors.bg,
        borderRadius: FtRadii.lgAll,
        border: Border.all(color: FtColors.border, width: 1.5),
        boxShadow: hovered ? FtShadows.sm : null,
      );

  /// Featured (navy) card surface with gradient and amber radial glow.
  /// Use sparingly — one per screen region.
  static BoxDecoration cardFeatured() => BoxDecoration(
        gradient: FtColors.primaryGradient,
        borderRadius: FtRadii.lgAll,
      );

  /// Input field decoration — white bg, 1.5px border.
  static InputDecoration input({String? label, String? hint, Widget? prefix, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: FtColors.bg,
        border: OutlineInputBorder(
          borderRadius: FtRadii.mdAll,
          borderSide: const BorderSide(color: FtColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FtRadii.mdAll,
          borderSide: const BorderSide(color: FtColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FtRadii.mdAll,
          borderSide: const BorderSide(color: FtColors.primary, width: 1.5),
        ),
        hintStyle: FtText.body.copyWith(color: FtColors.hint),
        labelStyle: FtText.label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      );
}
