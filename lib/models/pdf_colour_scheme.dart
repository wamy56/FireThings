import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'pdf_branding.dart';

class PdfColourScheme {
  final int primaryColorValue;
  final int? secondaryColorValue;
  final bool useAutoSecondary;

  const PdfColourScheme({
    required this.primaryColorValue,
    this.secondaryColorValue,
    this.useAutoSecondary = true,
  });

  // ── Primary colour getters ──

  /// The main primary colour used for section headers, borders, badges, etc.
  PdfColor get primaryColor => PdfColor.fromInt(primaryColorValue);

  /// A light tint (10% opacity) of the primary for backgrounds like Payment Details.
  PdfColor get primaryLight {
    return _blendWithWhite(primaryColorValue, 0.9);
  }

  /// A medium tint (40% opacity) for section borders.
  PdfColor get primaryMedium {
    return _blendWithWhite(primaryColorValue, 0.6);
  }

  /// Very light tint for subtle backgrounds (95% white blend)
  PdfColor get primarySoft {
    return _blendWithWhite(primaryColorValue, 0.95);
  }

  /// Darker variant for depth (20% black blend)
  PdfColor get primaryDark {
    return _blendWithBlack(primaryColorValue, 0.2);
  }

  // ── Secondary/accent colour getters ──

  /// Secondary/accent color - user-defined or auto-computed
  PdfColor get secondaryColor {
    if (secondaryColorValue != null) {
      return PdfColor.fromInt(secondaryColorValue!);
    }
    if (useAutoSecondary) {
      return _computeComplementary(primaryColorValue);
    }
    return primaryColor;
  }

  PdfColor get secondaryLight {
    final secValue =
        secondaryColorValue ?? _computeComplementaryValue(primaryColorValue);
    return _blendWithWhite(secValue, 0.9);
  }

  // ── Text colours ──

  PdfColor get textPrimary => const PdfColor.fromInt(0xFF212121);
  PdfColor get textSecondary => const PdfColor.fromInt(0xFF757575);
  PdfColor get textMuted => const PdfColor.fromInt(0xFF9E9E9E);
  PdfColor get textOnPrimary => PdfColors.white;

  // ── Background colours ──

  PdfColor get cardBackground => PdfColors.white;
  PdfColor get pageBackground => const PdfColor.fromInt(0xFFFAFAFA);

  // ── Helper methods ──

  static PdfColor _blendWithWhite(int colorValue, double factor) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    final lr = (r * (1 - factor) + 255 * factor).round();
    final lg = (g * (1 - factor) + 255 * factor).round();
    final lb = (b * (1 - factor) + 255 * factor).round();
    return PdfColor.fromInt(0xFF000000 | (lr << 16) | (lg << 8) | lb);
  }

  static PdfColor _blendWithBlack(int colorValue, double factor) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    final dr = (r * (1 - factor)).round();
    final dg = (g * (1 - factor)).round();
    final db = (b * (1 - factor)).round();
    return PdfColor.fromInt(0xFF000000 | (dr << 16) | (dg << 8) | db);
  }

  /// Compute complementary color (opposite on color wheel)
  static PdfColor _computeComplementary(int colorValue) {
    return PdfColor.fromInt(_computeComplementaryValue(colorValue));
  }

  static int _computeComplementaryValue(int colorValue) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;

    // Convert to HSL, rotate hue by 180, convert back
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    final l = (max + min) / 2 / 255;

    if (max == min) {
      // Grayscale - use orange accent
      return 0xFFE67E22;
    }

    final d = (max - min) / 255;
    final s =
        l > 0.5 ? d / (2 - max / 255 - min / 255) : d / (max / 255 + min / 255);

    double h;
    if (max == r) {
      h = ((g - b) / (max - min) + (g < b ? 6 : 0)) / 6;
    } else if (max == g) {
      h = ((b - r) / (max - min) + 2) / 6;
    } else {
      h = ((r - g) / (max - min) + 4) / 6;
    }

    // Rotate hue by 180 degrees
    h = (h + 0.5) % 1.0;

    // Convert back to RGB
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    int hueToRgb(double p, double q, double t) {
      var tt = t;
      if (tt < 0) tt += 1;
      if (tt > 1) tt -= 1;
      if (tt < 1 / 6) return ((p + (q - p) * 6 * tt) * 255).round();
      if (tt < 1 / 2) return (q * 255).round();
      if (tt < 2 / 3) return ((p + (q - p) * (2 / 3 - tt) * 6) * 255).round();
      return (p * 255).round();
    }

    final nr = hueToRgb(p, q, h + 1 / 3);
    final ng = hueToRgb(p, q, h);
    final nb = hueToRgb(p, q, h - 1 / 3);

    return 0xFF000000 | (nr << 16) | (ng << 8) | nb;
  }

  // ── Defaults and serialization ──

  static PdfColourScheme defaults() => const PdfColourScheme(
        primaryColorValue: 0xFF1E3A5F,
        secondaryColorValue: 0xFFE67E22,
        useAutoSecondary: false,
      );

  Map<String, dynamic> toJson() => {
        'primaryColorValue': primaryColorValue,
        'secondaryColorValue': secondaryColorValue,
        'useAutoSecondary': useAutoSecondary,
      };

  factory PdfColourScheme.fromJson(Map<String, dynamic> json) => PdfColourScheme(
        primaryColorValue: json['primaryColorValue'] as int? ?? 0xFF1E3A5F,
        secondaryColorValue: json['secondaryColorValue'] as int?,
        useAutoSecondary: json['useAutoSecondary'] as bool? ?? true,
      );

  factory PdfColourScheme.fromBranding(PdfBranding branding) {
    final primary = _parseHex(branding.primaryColour);
    final accent = _parseHex(branding.accentColour);
    return PdfColourScheme(
      primaryColorValue: primary,
      secondaryColorValue: accent,
      useAutoSecondary: false,
    );
  }

  static int _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return 0xFF000000 | int.parse(clean, radix: 16);
  }

  String toJsonString() => jsonEncode(toJson());

  factory PdfColourScheme.fromJsonString(String jsonString) =>
      PdfColourScheme.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfColourScheme copyWith({
    int? primaryColorValue,
    int? secondaryColorValue,
    bool? useAutoSecondary,
    bool clearSecondary = false,
  }) =>
      PdfColourScheme(
        primaryColorValue: primaryColorValue ?? this.primaryColorValue,
        secondaryColorValue:
            clearSecondary ? null : (secondaryColorValue ?? this.secondaryColorValue),
        useAutoSecondary: useAutoSecondary ?? this.useAutoSecondary,
      );

  // ── Preset schemes with secondary colours ──

  static const navy = PdfColourScheme(
    primaryColorValue: 0xFF1E3A5F,
    secondaryColorValue: 0xFFE67E22,
  );

  static const teal = PdfColourScheme(
    primaryColorValue: 0xFF0D7377,
    secondaryColorValue: 0xFFE74C3C,
  );

  static const crimson = PdfColourScheme(
    primaryColorValue: 0xFF8B1A1A,
    secondaryColorValue: 0xFF3498DB,
  );

  static const forestGreen = PdfColourScheme(
    primaryColorValue: 0xFF2E5A3A,
    secondaryColorValue: 0xFFD4AC0D,
  );

  static const charcoal = PdfColourScheme(
    primaryColorValue: 0xFF3C3C3C,
    secondaryColorValue: 0xFF27AE60,
  );

  static const royalPurple = PdfColourScheme(
    primaryColorValue: 0xFF5B2C8E,
    secondaryColorValue: 0xFFF39C12,
  );

  static const steelBlue = PdfColourScheme(
    primaryColorValue: 0xFF4682B4,
    secondaryColorValue: 0xFFE74C3C,
  );

  static const burntOrange = PdfColourScheme(
    primaryColorValue: 0xFFCC5500,
    secondaryColorValue: 0xFF2980B9,
  );

  static const List<({String label, PdfColourScheme scheme})> presets = [
    (label: 'Navy', scheme: navy),
    (label: 'Teal', scheme: teal),
    (label: 'Crimson', scheme: crimson),
    (label: 'Forest Green', scheme: forestGreen),
    (label: 'Charcoal', scheme: charcoal),
    (label: 'Royal Purple', scheme: royalPurple),
    (label: 'Steel Blue', scheme: steelBlue),
    (label: 'Burnt Orange', scheme: burntOrange),
  ];
}
