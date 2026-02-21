import 'dart:convert';
import 'package:pdf/pdf.dart';

class PdfColourScheme {
  final int primaryColorValue;

  const PdfColourScheme({required this.primaryColorValue});

  /// The main primary colour used for section headers, borders, badges, etc.
  PdfColor get primaryColor => PdfColor.fromInt(primaryColorValue);

  /// A light tint (10% opacity) of the primary for backgrounds like Payment Details.
  PdfColor get primaryLight {
    final r = (primaryColorValue >> 16) & 0xFF;
    final g = (primaryColorValue >> 8) & 0xFF;
    final b = primaryColorValue & 0xFF;
    // Blend with white at 10% opacity
    final lr = (r * 0.1 + 255 * 0.9).round();
    final lg = (g * 0.1 + 255 * 0.9).round();
    final lb = (b * 0.1 + 255 * 0.9).round();
    return PdfColor.fromInt(0xFF000000 | (lr << 16) | (lg << 8) | lb);
  }

  /// A medium tint (40% opacity) for section borders.
  PdfColor get primaryMedium {
    final r = (primaryColorValue >> 16) & 0xFF;
    final g = (primaryColorValue >> 8) & 0xFF;
    final b = primaryColorValue & 0xFF;
    final mr = (r * 0.4 + 255 * 0.6).round();
    final mg = (g * 0.4 + 255 * 0.6).round();
    final mb = (b * 0.4 + 255 * 0.6).round();
    return PdfColor.fromInt(0xFF000000 | (mr << 16) | (mg << 8) | mb);
  }

  static PdfColourScheme defaults() =>
      const PdfColourScheme(primaryColorValue: 0xFF1E3A5F);

  Map<String, dynamic> toJson() => {'primaryColorValue': primaryColorValue};

  factory PdfColourScheme.fromJson(Map<String, dynamic> json) =>
      PdfColourScheme(primaryColorValue: json['primaryColorValue'] as int);

  String toJsonString() => jsonEncode(toJson());

  factory PdfColourScheme.fromJsonString(String jsonString) =>
      PdfColourScheme.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // ── Preset schemes ──

  static const navy = PdfColourScheme(primaryColorValue: 0xFF1E3A5F);
  static const teal = PdfColourScheme(primaryColorValue: 0xFF0D7377);
  static const crimson = PdfColourScheme(primaryColorValue: 0xFF8B1A1A);
  static const forestGreen = PdfColourScheme(primaryColorValue: 0xFF2E5A3A);
  static const charcoal = PdfColourScheme(primaryColorValue: 0xFF3C3C3C);
  static const royalPurple = PdfColourScheme(primaryColorValue: 0xFF5B2C8E);
  static const steelBlue = PdfColourScheme(primaryColorValue: 0xFF4682B4);
  static const burntOrange = PdfColourScheme(primaryColorValue: 0xFFCC5500);

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
