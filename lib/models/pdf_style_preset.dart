import 'pdf_header_config.dart';
import 'pdf_section_style_config.dart';
import 'pdf_typography_config.dart';

enum PdfStylePreset {
  modern,
  classic,
  minimal,
  bold,
}

extension PdfStylePresetExtension on PdfStylePreset {
  String get label {
    switch (this) {
      case PdfStylePreset.modern:
        return 'Modern';
      case PdfStylePreset.classic:
        return 'Classic';
      case PdfStylePreset.minimal:
        return 'Minimal';
      case PdfStylePreset.bold:
        return 'Bold';
    }
  }

  String get description {
    switch (this) {
      case PdfStylePreset.modern:
        return 'Clean and professional with subtle shadows';
      case PdfStylePreset.classic:
        return 'Traditional borders, familiar layout';
      case PdfStylePreset.minimal:
        return 'Understated, maximum readability';
      case PdfStylePreset.bold:
        return 'High impact, strong visual hierarchy';
    }
  }

  /// Header style settings for this preset (only style/radius/padding — not logo or text lines)
  HeaderStyle get headerStyle {
    switch (this) {
      case PdfStylePreset.modern:
        return HeaderStyle.modern;
      case PdfStylePreset.classic:
        return HeaderStyle.classic;
      case PdfStylePreset.minimal:
        return HeaderStyle.minimal;
      case PdfStylePreset.bold:
        return HeaderStyle.modern;
    }
  }

  HeaderCornerRadius get headerCornerRadius {
    switch (this) {
      case PdfStylePreset.modern:
        return HeaderCornerRadius.medium;
      case PdfStylePreset.classic:
        return HeaderCornerRadius.none;
      case PdfStylePreset.minimal:
        return HeaderCornerRadius.none;
      case PdfStylePreset.bold:
        return HeaderCornerRadius.large;
    }
  }

  double get headerVerticalPadding {
    switch (this) {
      case PdfStylePreset.modern:
        return 16;
      case PdfStylePreset.classic:
        return 12;
      case PdfStylePreset.minimal:
        return 20;
      case PdfStylePreset.bold:
        return 20;
    }
  }

  double get headerHorizontalPadding {
    switch (this) {
      case PdfStylePreset.modern:
        return 24;
      case PdfStylePreset.classic:
        return 20;
      case PdfStylePreset.minimal:
        return 24;
      case PdfStylePreset.bold:
        return 28;
    }
  }

  PdfSectionStyleConfig get sectionStyleConfig {
    switch (this) {
      case PdfStylePreset.modern:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.shadowed,
          cornerRadius: SectionCornerRadius.medium,
          headerStyle: SectionHeaderStyle.fullWidth,
          sectionSpacing: 12,
          innerPadding: 12,
          headerFontSize: 11,
        );
      case PdfStylePreset.classic:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.bordered,
          cornerRadius: SectionCornerRadius.small,
          headerStyle: SectionHeaderStyle.fullWidth,
          sectionSpacing: 10,
          innerPadding: 10,
          headerFontSize: 10,
        );
      case PdfStylePreset.minimal:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.flat,
          cornerRadius: SectionCornerRadius.small,
          headerStyle: SectionHeaderStyle.underlined,
          sectionSpacing: 14,
          innerPadding: 14,
          headerFontSize: 10,
        );
      case PdfStylePreset.bold:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.elevated,
          cornerRadius: SectionCornerRadius.large,
          headerStyle: SectionHeaderStyle.leftAccent,
          sectionSpacing: 14,
          innerPadding: 14,
          headerFontSize: 12,
        );
    }
  }

  PdfTypographyConfig get typographyConfig {
    switch (this) {
      case PdfStylePreset.modern:
        return const PdfTypographyConfig(
          documentTitleSize: 24,
          sectionHeaderSize: 11,
          fieldLabelSize: 8,
          fieldValueSize: 10,
          tableHeaderSize: 9,
          tableBodySize: 9,
          footerSize: 8,
        );
      case PdfStylePreset.classic:
        return const PdfTypographyConfig(
          documentTitleSize: 22,
          sectionHeaderSize: 10,
          fieldLabelSize: 8,
          fieldValueSize: 9,
          tableHeaderSize: 8,
          tableBodySize: 8,
          footerSize: 7,
        );
      case PdfStylePreset.minimal:
        return const PdfTypographyConfig(
          documentTitleSize: 22,
          sectionHeaderSize: 10,
          fieldLabelSize: 7,
          fieldValueSize: 9,
          tableHeaderSize: 8,
          tableBodySize: 8,
          footerSize: 7,
        );
      case PdfStylePreset.bold:
        return const PdfTypographyConfig(
          documentTitleSize: 26,
          sectionHeaderSize: 12,
          fieldLabelSize: 9,
          fieldValueSize: 11,
          tableHeaderSize: 10,
          tableBodySize: 10,
          footerSize: 8,
        );
    }
  }

  /// Apply this preset's header settings to an existing header config,
  /// preserving logo and text line settings.
  PdfHeaderConfig applyToHeaderConfig(PdfHeaderConfig existing) {
    return existing.copyWith(
      headerStyle: headerStyle,
      cornerRadius: headerCornerRadius,
      verticalPadding: headerVerticalPadding,
      horizontalPadding: headerHorizontalPadding,
    );
  }

  /// Try to match current configs to a preset. Returns null if no match.
  static PdfStylePreset? matchFromConfigs({
    required PdfHeaderConfig header,
    required PdfSectionStyleConfig sectionStyle,
    required PdfTypographyConfig typography,
  }) {
    for (final preset in PdfStylePreset.values) {
      if (header.headerStyle == preset.headerStyle &&
          header.cornerRadius == preset.headerCornerRadius &&
          sectionStyle.cardStyle == preset.sectionStyleConfig.cardStyle &&
          sectionStyle.cornerRadius ==
              preset.sectionStyleConfig.cornerRadius &&
          sectionStyle.headerStyle ==
              preset.sectionStyleConfig.headerStyle &&
          typography.sectionHeaderSize ==
              preset.typographyConfig.sectionHeaderSize &&
          typography.fieldValueSize ==
              preset.typographyConfig.fieldValueSize) {
        return preset;
      }
    }
    return null;
  }
}
