import 'dart:convert';

import 'pdf_colour_scheme_v2.dart';
import 'pdf_content_block.dart';
import 'pdf_font_config.dart';
import 'pdf_header_config.dart' show LogoSize;
import 'pdf_layout_template.dart';
import 'pdf_variable.dart';

/// Unified PDF branding configuration.
///
/// Replaces the separate [PdfHeaderConfig] + [PdfFooterConfig] +
/// [PdfColourScheme] with a single composable model. Each document type
/// (jobsheet, invoice) gets its own instance.
class PdfBrandingConfig {
  final int schemaVersion;

  // ── Header ──
  final HeaderLayoutTemplate headerTemplate;
  final List<ContentBlock> headerLeftBlocks;
  final List<ContentBlock> headerCentreBlocks;
  final List<ContentBlock> headerRightBlocks;
  final LogoSize logoSize;

  // ── Footer ──
  final FooterLayoutTemplate footerTemplate;
  final List<ContentBlock> footerLeftBlocks;
  final List<ContentBlock> footerCentreBlocks;
  final List<ContentBlock> footerRightBlocks;

  // ── Styling ──
  final PdfColourSchemeV2 colourScheme;
  final PdfFontConfig fontConfig;

  const PdfBrandingConfig({
    this.schemaVersion = 2,
    this.headerTemplate = HeaderLayoutTemplate.logoLeftTextRight,
    this.headerLeftBlocks = const [],
    this.headerCentreBlocks = const [],
    this.headerRightBlocks = const [],
    this.logoSize = LogoSize.medium,
    this.footerTemplate = FooterLayoutTemplate.leftTextRightPages,
    this.footerLeftBlocks = const [],
    this.footerCentreBlocks = const [],
    this.footerRightBlocks = const [],
    required this.colourScheme,
    this.fontConfig = const PdfFontConfig(),
  });

  /// Default config matching the current v1 layout.
  factory PdfBrandingConfig.defaults() => PdfBrandingConfig(
        headerTemplate: HeaderLayoutTemplate.logoLeftTextRight,
        headerLeftBlocks: [
          ContentBlock.variable(
            variable: PdfVariable.companyName,
            fontSize: 18,
            bold: true,
            uppercase: true,
            spacingAfter: 4,
          ),
          ContentBlock.variable(
            variable: PdfVariable.tagline,
            fontSize: 10,
            bold: true,
            spacingAfter: 2,
          ),
          ContentBlock.variable(
            variable: PdfVariable.address,
            fontSize: 9,
            spacingAfter: 2,
          ),
          ContentBlock.variable(
            variable: PdfVariable.phone,
            fontSize: 9,
            spacingAfter: 0,
          ),
        ],
        headerCentreBlocks: const [],
        headerRightBlocks: const [],
        logoSize: LogoSize.medium,
        footerTemplate: FooterLayoutTemplate.leftTextRightPages,
        footerLeftBlocks: [
          ContentBlock.variable(
            variable: PdfVariable.companyName,
            fontSize: 7,
            spacingAfter: 0,
          ),
        ],
        footerCentreBlocks: const [],
        footerRightBlocks: const [],
        colourScheme: PdfColourSchemeV2.defaults(),
        fontConfig: const PdfFontConfig(),
      );

  // ── Serialisation ──

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'headerTemplate': headerTemplate.name,
        'headerLeftBlocks':
            headerLeftBlocks.map((b) => b.toJson()).toList(),
        'headerCentreBlocks':
            headerCentreBlocks.map((b) => b.toJson()).toList(),
        'headerRightBlocks':
            headerRightBlocks.map((b) => b.toJson()).toList(),
        'logoSize': logoSize.name,
        'footerTemplate': footerTemplate.name,
        'footerLeftBlocks':
            footerLeftBlocks.map((b) => b.toJson()).toList(),
        'footerCentreBlocks':
            footerCentreBlocks.map((b) => b.toJson()).toList(),
        'footerRightBlocks':
            footerRightBlocks.map((b) => b.toJson()).toList(),
        'colourScheme': colourScheme.toJson(),
        'fontConfig': fontConfig.toJson(),
      };

  factory PdfBrandingConfig.fromJson(Map<String, dynamic> json) =>
      PdfBrandingConfig(
        schemaVersion: json['schemaVersion'] as int? ?? 2,
        headerTemplate: HeaderLayoutTemplate.fromName(
            json['headerTemplate'] as String? ?? 'logoLeftTextRight'),
        headerLeftBlocks: _blocksFromJson(json['headerLeftBlocks']),
        headerCentreBlocks: _blocksFromJson(json['headerCentreBlocks']),
        headerRightBlocks: _blocksFromJson(json['headerRightBlocks']),
        logoSize: LogoSize.values.firstWhere(
          (e) => e.name == (json['logoSize'] as String? ?? 'medium'),
          orElse: () => LogoSize.medium,
        ),
        footerTemplate: FooterLayoutTemplate.fromName(
            json['footerTemplate'] as String? ?? 'leftTextRightPages'),
        footerLeftBlocks: _blocksFromJson(json['footerLeftBlocks']),
        footerCentreBlocks: _blocksFromJson(json['footerCentreBlocks']),
        footerRightBlocks: _blocksFromJson(json['footerRightBlocks']),
        colourScheme: json['colourScheme'] != null
            ? PdfColourSchemeV2.fromJson(
                json['colourScheme'] as Map<String, dynamic>)
            : PdfColourSchemeV2.defaults(),
        fontConfig: json['fontConfig'] != null
            ? PdfFontConfig.fromJson(
                json['fontConfig'] as Map<String, dynamic>)
            : const PdfFontConfig(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfBrandingConfig.fromJsonString(String jsonString) =>
      PdfBrandingConfig.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>);

  PdfBrandingConfig copyWith({
    int? schemaVersion,
    HeaderLayoutTemplate? headerTemplate,
    List<ContentBlock>? headerLeftBlocks,
    List<ContentBlock>? headerCentreBlocks,
    List<ContentBlock>? headerRightBlocks,
    LogoSize? logoSize,
    FooterLayoutTemplate? footerTemplate,
    List<ContentBlock>? footerLeftBlocks,
    List<ContentBlock>? footerCentreBlocks,
    List<ContentBlock>? footerRightBlocks,
    PdfColourSchemeV2? colourScheme,
    PdfFontConfig? fontConfig,
  }) =>
      PdfBrandingConfig(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        headerTemplate: headerTemplate ?? this.headerTemplate,
        headerLeftBlocks: headerLeftBlocks ?? this.headerLeftBlocks,
        headerCentreBlocks: headerCentreBlocks ?? this.headerCentreBlocks,
        headerRightBlocks: headerRightBlocks ?? this.headerRightBlocks,
        logoSize: logoSize ?? this.logoSize,
        footerTemplate: footerTemplate ?? this.footerTemplate,
        footerLeftBlocks: footerLeftBlocks ?? this.footerLeftBlocks,
        footerCentreBlocks: footerCentreBlocks ?? this.footerCentreBlocks,
        footerRightBlocks: footerRightBlocks ?? this.footerRightBlocks,
        colourScheme: colourScheme ?? this.colourScheme,
        fontConfig: fontConfig ?? this.fontConfig,
      );

  static List<ContentBlock> _blocksFromJson(dynamic json) {
    if (json == null) return [];
    return (json as List<dynamic>)
        .map((e) => ContentBlock.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
