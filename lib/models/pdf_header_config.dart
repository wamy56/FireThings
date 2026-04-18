import 'dart:convert';

enum PdfDocumentType { jobsheet, invoice, quote }

enum LogoZone { left, none }

enum LogoSize {
  small(40),
  medium(60),
  large(80);

  final double pixels;
  const LogoSize(this.pixels);
}

/// Header visual style
enum HeaderStyle {
  classic, // Bottom border only, white background
  minimal, // No border, clean separation with extra padding
}

/// Corner radius options for modern header
enum HeaderCornerRadius {
  none(0),
  small(8),
  medium(12),
  large(16);

  final double pixels;
  const HeaderCornerRadius(this.pixels);
}

class HeaderTextLine {
  final String key;
  final String value;
  final double fontSize;
  final bool bold;

  const HeaderTextLine({
    required this.key,
    this.value = '',
    this.fontSize = 10,
    this.bold = false,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'fontSize': fontSize,
        'bold': bold,
      };

  factory HeaderTextLine.fromJson(Map<String, dynamic> json) => HeaderTextLine(
        key: json['key'] as String,
        value: json['value'] as String? ?? '',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 10,
        bold: json['bold'] as bool? ?? false,
      );

  HeaderTextLine copyWith({
    String? key,
    String? value,
    double? fontSize,
    bool? bold,
  }) =>
      HeaderTextLine(
        key: key ?? this.key,
        value: value ?? this.value,
        fontSize: fontSize ?? this.fontSize,
        bold: bold ?? this.bold,
      );
}

class PdfHeaderConfig {
  final LogoZone logoZone;
  final LogoSize logoSize;
  final List<HeaderTextLine> leftLines;
  final List<HeaderTextLine> centreLines;
  final HeaderStyle headerStyle;
  final HeaderCornerRadius cornerRadius;
  final double verticalPadding;
  final double horizontalPadding;

  const PdfHeaderConfig({
    required this.logoZone,
    required this.logoSize,
    required this.leftLines,
    required this.centreLines,
    this.headerStyle = HeaderStyle.classic,
    this.cornerRadius = HeaderCornerRadius.medium,
    this.verticalPadding = 16,
    this.horizontalPadding = 24,
  });

  /// Default config with modern styling
  factory PdfHeaderConfig.defaults() => const PdfHeaderConfig(
        logoZone: LogoZone.left,
        logoSize: LogoSize.medium,
        leftLines: [
          HeaderTextLine(key: 'companyName', fontSize: 18, bold: true),
          HeaderTextLine(key: 'tagline', fontSize: 10, bold: true),
          HeaderTextLine(key: 'address', fontSize: 9),
          HeaderTextLine(key: 'phone', fontSize: 9),
        ],
        centreLines: [],
        headerStyle: HeaderStyle.classic,
        cornerRadius: HeaderCornerRadius.medium,
        verticalPadding: 16,
        horizontalPadding: 24,
      );

  Map<String, dynamic> toJson() => {
        'logoZone': logoZone.name,
        'logoSize': logoSize.name,
        'leftLines': leftLines.map((l) => l.toJson()).toList(),
        'centreLines': centreLines.map((l) => l.toJson()).toList(),
        'headerStyle': headerStyle.name,
        'cornerRadius': cornerRadius.name,
        'verticalPadding': verticalPadding,
        'horizontalPadding': horizontalPadding,
      };

  factory PdfHeaderConfig.fromJson(Map<String, dynamic> json) =>
      PdfHeaderConfig(
        logoZone: LogoZone.values.firstWhere(
          (e) => e.name == json['logoZone'],
          orElse: () => LogoZone.left,
        ),
        logoSize: LogoSize.values.firstWhere(
          (e) => e.name == json['logoSize'],
          orElse: () => LogoSize.medium,
        ),
        leftLines: (json['leftLines'] as List<dynamic>?)
                ?.map((e) => HeaderTextLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        centreLines: (json['centreLines'] as List<dynamic>?)
                ?.map((e) => HeaderTextLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        headerStyle: HeaderStyle.values.firstWhere(
          (e) => e.name == json['headerStyle'],
          orElse: () => HeaderStyle.classic,
        ),
        cornerRadius: HeaderCornerRadius.values.firstWhere(
          (e) => e.name == json['cornerRadius'],
          orElse: () => HeaderCornerRadius.medium,
        ),
        verticalPadding: (json['verticalPadding'] as num?)?.toDouble() ?? 16,
        horizontalPadding: (json['horizontalPadding'] as num?)?.toDouble() ?? 24,
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfHeaderConfig.fromJsonString(String jsonString) =>
      PdfHeaderConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfHeaderConfig copyWith({
    LogoZone? logoZone,
    LogoSize? logoSize,
    List<HeaderTextLine>? leftLines,
    List<HeaderTextLine>? centreLines,
    HeaderStyle? headerStyle,
    HeaderCornerRadius? cornerRadius,
    double? verticalPadding,
    double? horizontalPadding,
  }) =>
      PdfHeaderConfig(
        logoZone: logoZone ?? this.logoZone,
        logoSize: logoSize ?? this.logoSize,
        leftLines: leftLines ?? this.leftLines,
        centreLines: centreLines ?? this.centreLines,
        headerStyle: headerStyle ?? this.headerStyle,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        verticalPadding: verticalPadding ?? this.verticalPadding,
        horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      );
}
