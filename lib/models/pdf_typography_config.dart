import 'dart:convert';

class PdfTypographyConfig {
  final double documentTitleSize;
  final double sectionHeaderSize;
  final double fieldLabelSize;
  final double fieldValueSize;
  final double tableHeaderSize;
  final double tableBodySize;
  final double footerSize;

  const PdfTypographyConfig({
    this.documentTitleSize = 24,
    this.sectionHeaderSize = 9,
    this.fieldLabelSize = 8,
    this.fieldValueSize = 10,
    this.tableHeaderSize = 9,
    this.tableBodySize = 9,
    this.footerSize = 8,
  });

  factory PdfTypographyConfig.defaults() => const PdfTypographyConfig();

  Map<String, dynamic> toJson() => {
        'documentTitleSize': documentTitleSize,
        'sectionHeaderSize': sectionHeaderSize,
        'fieldLabelSize': fieldLabelSize,
        'fieldValueSize': fieldValueSize,
        'tableHeaderSize': tableHeaderSize,
        'tableBodySize': tableBodySize,
        'footerSize': footerSize,
      };

  factory PdfTypographyConfig.fromJson(Map<String, dynamic> json) =>
      PdfTypographyConfig(
        documentTitleSize:
            (json['documentTitleSize'] as num?)?.toDouble() ?? 24,
        sectionHeaderSize:
            (json['sectionHeaderSize'] as num?)?.toDouble() ?? 9,
        fieldLabelSize: (json['fieldLabelSize'] as num?)?.toDouble() ?? 8,
        fieldValueSize: (json['fieldValueSize'] as num?)?.toDouble() ?? 10,
        tableHeaderSize: (json['tableHeaderSize'] as num?)?.toDouble() ?? 9,
        tableBodySize: (json['tableBodySize'] as num?)?.toDouble() ?? 9,
        footerSize: (json['footerSize'] as num?)?.toDouble() ?? 8,
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfTypographyConfig.fromJsonString(String jsonString) =>
      PdfTypographyConfig.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);

  PdfTypographyConfig copyWith({
    double? documentTitleSize,
    double? sectionHeaderSize,
    double? fieldLabelSize,
    double? fieldValueSize,
    double? tableHeaderSize,
    double? tableBodySize,
    double? footerSize,
  }) =>
      PdfTypographyConfig(
        documentTitleSize: documentTitleSize ?? this.documentTitleSize,
        sectionHeaderSize: sectionHeaderSize ?? this.sectionHeaderSize,
        fieldLabelSize: fieldLabelSize ?? this.fieldLabelSize,
        fieldValueSize: fieldValueSize ?? this.fieldValueSize,
        tableHeaderSize: tableHeaderSize ?? this.tableHeaderSize,
        tableBodySize: tableBodySize ?? this.tableBodySize,
        footerSize: footerSize ?? this.footerSize,
      );
}
