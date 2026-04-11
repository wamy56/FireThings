import '../models/pdf_branding_config.dart';
import '../models/pdf_colour_scheme_v2.dart';
import '../models/pdf_content_block.dart';
import '../models/pdf_font_config.dart';
import '../models/pdf_header_config.dart' show LogoSize;
import '../models/pdf_layout_template.dart';
import '../models/pdf_variable.dart';

/// Built-in branding template presets that users can pick as starting points.
///
/// Each preset defines the structural layout, default content blocks, and
/// colour scheme. Users can then customise individual blocks after applying.
class PdfBrandingPresets {
  PdfBrandingPresets._();

  static const List<({String name, String description, PdfBrandingConfig config})>
      all = [
    (name: 'Classic', description: 'Traditional business layout', config: _classic),
    (name: 'Modern', description: 'Centered and clean', config: _modern),
    (name: 'Professional', description: 'Two-column with details', config: _professional),
    (name: 'Minimal', description: 'Simple and understated', config: _minimal),
    (name: 'Bold', description: 'Large logo, strong presence', config: _bold),
  ];

  // ── Classic ──
  // Matches the current default: logo left, company info right, standard footer.

  static const _classic = PdfBrandingConfig(
    headerTemplate: HeaderLayoutTemplate.logoLeftTextRight,
    headerLeftBlocks: [
      ContentBlock(
        id: 'preset_classic_h1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 18,
        bold: true,
        uppercase: true,
        spacingAfter: 4,
      ),
      ContentBlock(
        id: 'preset_classic_h2',
        type: ContentBlockType.text,
        variable: PdfVariable.tagline,
        fontSize: 10,
        bold: true,
        spacingAfter: 2,
      ),
      ContentBlock(
        id: 'preset_classic_h3',
        type: ContentBlockType.text,
        variable: PdfVariable.address,
        fontSize: 9,
        spacingAfter: 2,
      ),
      ContentBlock(
        id: 'preset_classic_h4',
        type: ContentBlockType.text,
        variable: PdfVariable.phone,
        fontSize: 9,
        spacingAfter: 0,
      ),
    ],
    logoSize: LogoSize.medium,
    footerTemplate: FooterLayoutTemplate.leftTextRightPages,
    footerLeftBlocks: [
      ContentBlock(
        id: 'preset_classic_f1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 7,
        spacingAfter: 0,
      ),
    ],
    colourScheme: PdfColourSchemeV2(primaryColorValue: 0xFF1E3A5F),
  );

  // ── Modern ──
  // Centered logo above centered text. Minimal footer.

  static const _modern = PdfBrandingConfig(
    headerTemplate: HeaderLayoutTemplate.centeredLogoAboveText,
    headerLeftBlocks: [
      ContentBlock(
        id: 'preset_modern_h1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 20,
        bold: true,
        uppercase: true,
        alignment: TextAlignment.center,
        spacingAfter: 4,
      ),
      ContentBlock(
        id: 'preset_modern_h2',
        type: ContentBlockType.text,
        variable: PdfVariable.tagline,
        fontSize: 10,
        alignment: TextAlignment.center,
        spacingAfter: 0,
      ),
    ],
    logoSize: LogoSize.large,
    footerTemplate: FooterLayoutTemplate.minimal,
    colourScheme: PdfColourSchemeV2(
      primaryColorValue: 0xFF0D7377,
      secondaryColorValue: 0xFF2FADB2,
    ),
    fontConfig: PdfFontConfig(family: PdfFontFamily.inter),
  );

  // ── Professional ──
  // Two-column: company + logo left, contact details right. Three-column footer.

  static const _professional = PdfBrandingConfig(
    headerTemplate: HeaderLayoutTemplate.twoColumn,
    headerLeftBlocks: [
      ContentBlock(
        id: 'preset_prof_h1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 16,
        bold: true,
        uppercase: true,
        spacingAfter: 4,
      ),
      ContentBlock(
        id: 'preset_prof_h2',
        type: ContentBlockType.text,
        variable: PdfVariable.tagline,
        fontSize: 9,
        bold: true,
        spacingAfter: 0,
      ),
    ],
    headerRightBlocks: [
      ContentBlock(
        id: 'preset_prof_h3',
        type: ContentBlockType.text,
        variable: PdfVariable.address,
        fontSize: 9,
        alignment: TextAlignment.right,
        spacingAfter: 2,
      ),
      ContentBlock(
        id: 'preset_prof_h4',
        type: ContentBlockType.text,
        variable: PdfVariable.phone,
        fontSize: 9,
        alignment: TextAlignment.right,
        spacingAfter: 2,
      ),
      ContentBlock(
        id: 'preset_prof_h5',
        type: ContentBlockType.text,
        variable: PdfVariable.email,
        fontSize: 9,
        alignment: TextAlignment.right,
        spacingAfter: 0,
      ),
    ],
    logoSize: LogoSize.medium,
    footerTemplate: FooterLayoutTemplate.threeColumn,
    footerLeftBlocks: [
      ContentBlock(
        id: 'preset_prof_f1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 7,
        spacingAfter: 0,
      ),
    ],
    footerCentreBlocks: [
      ContentBlock(
        id: 'preset_prof_f2',
        type: ContentBlockType.text,
        variable: PdfVariable.website,
        fontSize: 7,
        alignment: TextAlignment.center,
        spacingAfter: 0,
      ),
    ],
    colourScheme: PdfColourSchemeV2(
      primaryColorValue: 0xFF3C3C3C,
      secondaryColorValue: 0xFF6B6B6B,
    ),
    fontConfig: PdfFontConfig(family: PdfFontFamily.lato),
  );

  // ── Minimal ──
  // Company name only. Page numbers only footer.

  static const _minimal = PdfBrandingConfig(
    headerTemplate: HeaderLayoutTemplate.minimal,
    headerLeftBlocks: [
      ContentBlock(
        id: 'preset_min_h1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 14,
        bold: true,
        uppercase: true,
        alignment: TextAlignment.center,
        spacingAfter: 0,
      ),
    ],
    logoSize: LogoSize.small,
    footerTemplate: FooterLayoutTemplate.minimal,
    colourScheme: PdfColourSchemeV2(primaryColorValue: 0xFF3C3C3C),
  );

  // ── Bold ──
  // Large logo, large company name, strong secondary accent.

  static const _bold = PdfBrandingConfig(
    headerTemplate: HeaderLayoutTemplate.logoLeftTextRight,
    headerLeftBlocks: [
      ContentBlock(
        id: 'preset_bold_h1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 22,
        bold: true,
        uppercase: true,
        spacingAfter: 4,
      ),
      ContentBlock(
        id: 'preset_bold_h2',
        type: ContentBlockType.text,
        variable: PdfVariable.tagline,
        fontSize: 12,
        bold: true,
        italic: true,
        spacingAfter: 4,
      ),
      ContentBlock(
        id: 'preset_bold_h3',
        type: ContentBlockType.text,
        variable: PdfVariable.phone,
        fontSize: 10,
        bold: true,
        spacingAfter: 0,
      ),
    ],
    logoSize: LogoSize.large,
    footerTemplate: FooterLayoutTemplate.leftTextRightPages,
    footerLeftBlocks: [
      ContentBlock(
        id: 'preset_bold_f1',
        type: ContentBlockType.text,
        variable: PdfVariable.companyName,
        fontSize: 8,
        bold: true,
        spacingAfter: 1,
      ),
      ContentBlock(
        id: 'preset_bold_f2',
        type: ContentBlockType.text,
        variable: PdfVariable.website,
        fontSize: 7,
        spacingAfter: 0,
      ),
    ],
    colourScheme: PdfColourSchemeV2(
      primaryColorValue: 0xFF8B1A1A,
      secondaryColorValue: 0xFFCC5500,
    ),
    fontConfig: PdfFontConfig(family: PdfFontFamily.merriweather),
  );
}
