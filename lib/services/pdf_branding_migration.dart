import 'package:uuid/uuid.dart';

import '../models/pdf_branding_config.dart';
import '../models/pdf_colour_scheme.dart';
import '../models/pdf_colour_scheme_v2.dart';
import '../models/pdf_content_block.dart';
import '../models/pdf_font_config.dart';
import '../models/pdf_footer_config.dart';
import '../models/pdf_header_config.dart';
import '../models/pdf_layout_template.dart';
import '../models/pdf_variable.dart';

/// Converts legacy v1 PDF configs (separate header, footer, colour scheme)
/// into the unified [PdfBrandingConfig] format.
class PdfBrandingMigration {
  PdfBrandingMigration._();

  /// Convert legacy configs into a unified [PdfBrandingConfig].
  static PdfBrandingConfig migrate({
    required PdfHeaderConfig header,
    required PdfFooterConfig footer,
    required PdfColourScheme colour,
  }) {
    // Map LogoZone → HeaderLayoutTemplate
    final headerTemplate = switch (header.logoZone) {
      LogoZone.left => HeaderLayoutTemplate.logoLeftTextRight,
      LogoZone.centre => HeaderLayoutTemplate.centeredLogoAboveText,
      LogoZone.none => HeaderLayoutTemplate.textOnly,
    };

    // Convert header text lines → content blocks
    final headerLeftBlocks =
        header.leftLines.map(_migrateHeaderTextLine).toList();
    final headerCentreBlocks =
        header.centreLines.map(_migrateHeaderTextLine).toList();

    // Convert footer text lines → content blocks
    final footerLeftBlocks =
        footer.leftLines.map(_migrateFooterTextLine).toList();
    final footerCentreBlocks =
        footer.centreLines.map(_migrateFooterTextLine).toList();

    // Determine footer template
    final footerTemplate = footer.centreLines.isNotEmpty
        ? FooterLayoutTemplate.threeColumn
        : FooterLayoutTemplate.leftTextRightPages;

    return PdfBrandingConfig(
      schemaVersion: 2,
      headerTemplate: headerTemplate,
      headerLeftBlocks: headerLeftBlocks,
      headerCentreBlocks: headerCentreBlocks,
      headerRightBlocks: const [],
      logoSize: header.logoSize,
      footerTemplate: footerTemplate,
      footerLeftBlocks: footerLeftBlocks,
      footerCentreBlocks: footerCentreBlocks,
      footerRightBlocks: const [],
      colourScheme: PdfColourSchemeV2.fromV1(colour.primaryColorValue),
      fontConfig: const PdfFontConfig(),
    );
  }

  /// Map a header [HeaderTextLine] key to a [PdfVariable].
  static PdfVariable? _variableForKey(String key) => switch (key) {
        'companyName' => PdfVariable.companyName,
        'tagline' => PdfVariable.tagline,
        'address' => PdfVariable.address,
        'phone' => PdfVariable.phone,
        'engineerName' => PdfVariable.engineerName,
        'companyDetails' => PdfVariable.companyName,
        'contactInfo' => PdfVariable.phone,
        'website' => PdfVariable.website,
        'email' => PdfVariable.email,
        _ => null, // 'custom' or unknown → plain text
      };

  static ContentBlock _migrateHeaderTextLine(HeaderTextLine line) {
    final variable = _variableForKey(line.key);

    return ContentBlock(
      id: const Uuid().v4(),
      type: ContentBlockType.text,
      text: line.value.isEmpty ? null : line.value,
      variable: variable,
      fontSize: line.fontSize,
      bold: line.bold,
      uppercase: line.key == 'companyName',
      spacingAfter: line.key == 'companyName' ? 4 : 2,
    );
  }

  static ContentBlock _migrateFooterTextLine(HeaderTextLine line) {
    final variable = _variableForKey(line.key);

    return ContentBlock(
      id: const Uuid().v4(),
      type: ContentBlockType.text,
      text: line.value.isEmpty ? null : line.value,
      variable: variable,
      fontSize: line.fontSize,
      bold: line.bold,
      spacingAfter: 0,
    );
  }
}
