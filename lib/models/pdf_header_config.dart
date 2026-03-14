import 'dart:convert';

enum PdfDocumentType { jobsheet, invoice }

enum LogoZone { left, centre, none }

enum LogoSize {
  small(40),
  medium(60),
  large(80);

  final double pixels;
  const LogoSize(this.pixels);
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

  const PdfHeaderConfig({
    required this.logoZone,
    required this.logoSize,
    required this.leftLines,
    required this.centreLines,
  });

  /// Default config matching the current hardcoded layout
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
      );

  Map<String, dynamic> toJson() => {
        'logoZone': logoZone.name,
        'logoSize': logoSize.name,
        'leftLines': leftLines.map((l) => l.toJson()).toList(),
        'centreLines': centreLines.map((l) => l.toJson()).toList(),
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
                ?.map((e) =>
                    HeaderTextLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        centreLines: (json['centreLines'] as List<dynamic>?)
                ?.map((e) =>
                    HeaderTextLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfHeaderConfig.fromJsonString(String jsonString) =>
      PdfHeaderConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfHeaderConfig copyWith({
    LogoZone? logoZone,
    LogoSize? logoSize,
    List<HeaderTextLine>? leftLines,
    List<HeaderTextLine>? centreLines,
  }) =>
      PdfHeaderConfig(
        logoZone: logoZone ?? this.logoZone,
        logoSize: logoSize ?? this.logoSize,
        leftLines: leftLines ?? this.leftLines,
        centreLines: centreLines ?? this.centreLines,
      );
}
