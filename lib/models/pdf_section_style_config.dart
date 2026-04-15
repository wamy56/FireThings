import 'dart:convert';

/// Visual style for section cards
enum SectionCardStyle {
  bordered, // Light gray border (current look)
  shadowed, // Subtle drop shadow, no border
  elevated, // Stronger shadow for more depth
  flat, // No border or shadow, just padding
}

/// Corner radius for section cards
enum SectionCornerRadius {
  small(4),
  medium(8),
  large(12);

  final double pixels;
  const SectionCornerRadius(this.pixels);
}

/// Style for section headers
enum SectionHeaderStyle {
  fullWidth, // Full-width colored bar (current look)
  leftAccent, // Left border accent only
  underlined, // Text with underline
}

class PdfSectionStyleConfig {
  final SectionCardStyle cardStyle;
  final SectionCornerRadius cornerRadius;
  final SectionHeaderStyle headerStyle;
  final double sectionSpacing;
  final double innerPadding;
  final double headerFontSize;

  const PdfSectionStyleConfig({
    this.cardStyle = SectionCardStyle.shadowed,
    this.cornerRadius = SectionCornerRadius.medium,
    this.headerStyle = SectionHeaderStyle.fullWidth,
    this.sectionSpacing = 12,
    this.innerPadding = 12,
    this.headerFontSize = 11,
  });

  factory PdfSectionStyleConfig.defaults() => const PdfSectionStyleConfig();

  Map<String, dynamic> toJson() => {
        'cardStyle': cardStyle.name,
        'cornerRadius': cornerRadius.name,
        'headerStyle': headerStyle.name,
        'sectionSpacing': sectionSpacing,
        'innerPadding': innerPadding,
        'headerFontSize': headerFontSize,
      };

  factory PdfSectionStyleConfig.fromJson(Map<String, dynamic> json) =>
      PdfSectionStyleConfig(
        cardStyle: SectionCardStyle.values.firstWhere(
          (e) => e.name == json['cardStyle'],
          orElse: () => SectionCardStyle.shadowed,
        ),
        cornerRadius: SectionCornerRadius.values.firstWhere(
          (e) => e.name == json['cornerRadius'],
          orElse: () => SectionCornerRadius.medium,
        ),
        headerStyle: SectionHeaderStyle.values.firstWhere(
          (e) => e.name == json['headerStyle'],
          orElse: () => SectionHeaderStyle.fullWidth,
        ),
        sectionSpacing: (json['sectionSpacing'] as num?)?.toDouble() ?? 12,
        innerPadding: (json['innerPadding'] as num?)?.toDouble() ?? 12,
        headerFontSize: (json['headerFontSize'] as num?)?.toDouble() ?? 11,
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfSectionStyleConfig.fromJsonString(String jsonString) =>
      PdfSectionStyleConfig.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);

  PdfSectionStyleConfig copyWith({
    SectionCardStyle? cardStyle,
    SectionCornerRadius? cornerRadius,
    SectionHeaderStyle? headerStyle,
    double? sectionSpacing,
    double? innerPadding,
    double? headerFontSize,
  }) =>
      PdfSectionStyleConfig(
        cardStyle: cardStyle ?? this.cardStyle,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        headerStyle: headerStyle ?? this.headerStyle,
        sectionSpacing: sectionSpacing ?? this.sectionSpacing,
        innerPadding: innerPadding ?? this.innerPadding,
        headerFontSize: headerFontSize ?? this.headerFontSize,
      );
}
