import 'dart:convert';

/// Available font families for PDF generation.
///
/// All fonts are loaded via Google Fonts on demand — not bundled in the APK.
enum PdfFontFamily {
  roboto('Roboto'),
  inter('Inter'),
  lato('Lato'),
  merriweather('Merriweather');

  final String displayName;
  const PdfFontFamily(this.displayName);

  /// Whether this is a serif font (affects preview styling).
  bool get isSerif => this == merriweather;

  static PdfFontFamily fromName(String name) =>
      PdfFontFamily.values.firstWhere(
        (e) => e.name == name,
        orElse: () => PdfFontFamily.roboto,
      );
}

/// Font configuration for PDF branding.
class PdfFontConfig {
  final PdfFontFamily family;

  const PdfFontConfig({this.family = PdfFontFamily.roboto});

  static PdfFontConfig defaults() => const PdfFontConfig();

  Map<String, dynamic> toJson() => {'family': family.name};

  factory PdfFontConfig.fromJson(Map<String, dynamic> json) => PdfFontConfig(
        family: PdfFontFamily.fromName(json['family'] as String? ?? 'roboto'),
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfFontConfig.fromJsonString(String jsonString) =>
      PdfFontConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfFontConfig copyWith({PdfFontFamily? family}) =>
      PdfFontConfig(family: family ?? this.family);
}
