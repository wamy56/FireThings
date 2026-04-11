import 'dart:convert';

import 'package:pdf/pdf.dart';

/// Extended colour scheme with primary and optional secondary colours.
///
/// Replaces the single-colour [PdfColourScheme] with a two-colour model.
/// When [secondaryColorValue] is null, [secondary] derives from [primary].
class PdfColourSchemeV2 {
  final int primaryColorValue;
  final int? secondaryColorValue;
  final int schemaVersion;

  const PdfColourSchemeV2({
    required this.primaryColorValue,
    this.secondaryColorValue,
    this.schemaVersion = 2,
  });

  // ── Primary colour derivations ──

  PdfColor get primaryColor => PdfColor.fromInt(primaryColorValue);

  /// 10% tint — alternating row backgrounds, payment details, signature boxes.
  PdfColor get primaryLight => _tint(primaryColorValue, 0.1);

  /// 40% tint — section borders.
  PdfColor get primaryMedium => _tint(primaryColorValue, 0.4);

  // ── Secondary colour derivations ──

  /// Falls back to primary when not explicitly set.
  PdfColor get secondaryColor => secondaryColorValue != null
      ? PdfColor.fromInt(secondaryColorValue!)
      : primaryColor;

  PdfColor get secondaryLight => secondaryColorValue != null
      ? _tint(secondaryColorValue!, 0.1)
      : primaryLight;

  PdfColor get secondaryMedium => secondaryColorValue != null
      ? _tint(secondaryColorValue!, 0.4)
      : primaryMedium;

  /// Whether a secondary colour has been explicitly configured.
  bool get hasSecondary => secondaryColorValue != null;

  // ── Defaults & presets ──

  factory PdfColourSchemeV2.defaults() => const PdfColourSchemeV2(
        primaryColorValue: 0xFF1E3A5F,
      );

  /// Upgrade from a v1 scheme (single primary colour).
  factory PdfColourSchemeV2.fromV1(int primaryColorValue) => PdfColourSchemeV2(
        primaryColorValue: primaryColorValue,
      );

  static const navy = PdfColourSchemeV2(
    primaryColorValue: 0xFF1E3A5F,
    secondaryColorValue: 0xFF4682B4,
  );
  static const teal = PdfColourSchemeV2(
    primaryColorValue: 0xFF0D7377,
    secondaryColorValue: 0xFF2FADB2,
  );
  static const crimson = PdfColourSchemeV2(
    primaryColorValue: 0xFF8B1A1A,
    secondaryColorValue: 0xFFCC5500,
  );
  static const forestGreen = PdfColourSchemeV2(
    primaryColorValue: 0xFF2E5A3A,
    secondaryColorValue: 0xFF5B8C5A,
  );
  static const charcoal = PdfColourSchemeV2(
    primaryColorValue: 0xFF3C3C3C,
    secondaryColorValue: 0xFF6B6B6B,
  );
  static const royalPurple = PdfColourSchemeV2(
    primaryColorValue: 0xFF5B2C8E,
    secondaryColorValue: 0xFF8E5BC2,
  );
  static const steelBlue = PdfColourSchemeV2(
    primaryColorValue: 0xFF4682B4,
    secondaryColorValue: 0xFF1E3A5F,
  );
  static const burntOrange = PdfColourSchemeV2(
    primaryColorValue: 0xFFCC5500,
    secondaryColorValue: 0xFF8B6914,
  );

  static const List<({String label, PdfColourSchemeV2 scheme})> presets = [
    (label: 'Navy', scheme: navy),
    (label: 'Teal', scheme: teal),
    (label: 'Crimson', scheme: crimson),
    (label: 'Forest Green', scheme: forestGreen),
    (label: 'Charcoal', scheme: charcoal),
    (label: 'Royal Purple', scheme: royalPurple),
    (label: 'Steel Blue', scheme: steelBlue),
    (label: 'Burnt Orange', scheme: burntOrange),
  ];

  // ── Serialisation ──

  Map<String, dynamic> toJson() => {
        'primaryColorValue': primaryColorValue,
        if (secondaryColorValue != null)
          'secondaryColorValue': secondaryColorValue,
        'schemaVersion': schemaVersion,
      };

  factory PdfColourSchemeV2.fromJson(Map<String, dynamic> json) =>
      PdfColourSchemeV2(
        primaryColorValue: json['primaryColorValue'] as int? ?? 0xFF1E3A5F,
        secondaryColorValue: json['secondaryColorValue'] as int?,
        schemaVersion: json['schemaVersion'] as int? ?? 2,
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfColourSchemeV2.fromJsonString(String jsonString) =>
      PdfColourSchemeV2.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);

  PdfColourSchemeV2 copyWith({
    int? primaryColorValue,
    int? secondaryColorValue,
    bool clearSecondary = false,
  }) =>
      PdfColourSchemeV2(
        primaryColorValue: primaryColorValue ?? this.primaryColorValue,
        secondaryColorValue: clearSecondary
            ? null
            : (secondaryColorValue ?? this.secondaryColorValue),
      );

  // ── Internal ──

  /// Blend a colour with white at the given [opacity] (0.0–1.0).
  static PdfColor _tint(int colorValue, double opacity) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    final lr = (r * opacity + 255 * (1 - opacity)).round();
    final lg = (g * opacity + 255 * (1 - opacity)).round();
    final lb = (b * opacity + 255 * (1 - opacity)).round();
    return PdfColor.fromInt(0xFF000000 | (lr << 16) | (lg << 8) | lb);
  }
}
