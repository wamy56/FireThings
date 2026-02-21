import 'dart:convert';
import 'pdf_header_config.dart';

class PdfFooterConfig {
  final List<HeaderTextLine> leftLines;
  final List<HeaderTextLine> centreLines;

  const PdfFooterConfig({
    required this.leftLines,
    required this.centreLines,
  });

  factory PdfFooterConfig.defaults() => const PdfFooterConfig(
        leftLines: [
          HeaderTextLine(key: 'companyDetails', fontSize: 7),
        ],
        centreLines: [],
      );

  Map<String, dynamic> toJson() => {
        'leftLines': leftLines.map((l) => l.toJson()).toList(),
        'centreLines': centreLines.map((l) => l.toJson()).toList(),
      };

  factory PdfFooterConfig.fromJson(Map<String, dynamic> json) =>
      PdfFooterConfig(
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

  factory PdfFooterConfig.fromJsonString(String jsonString) =>
      PdfFooterConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfFooterConfig copyWith({
    List<HeaderTextLine>? leftLines,
    List<HeaderTextLine>? centreLines,
  }) =>
      PdfFooterConfig(
        leftLines: leftLines ?? this.leftLines,
        centreLines: centreLines ?? this.centreLines,
      );
}
