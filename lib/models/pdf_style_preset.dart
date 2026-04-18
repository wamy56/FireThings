import 'pdf_header_config.dart';
import 'pdf_section_style_config.dart';
import 'pdf_typography_config.dart';

enum PdfStylePreset {
  classic,
  minimal,
}

extension PdfStylePresetExtension on PdfStylePreset {
  String get label {
    switch (this) {
      case PdfStylePreset.classic:
        return 'Classic';
      case PdfStylePreset.minimal:
        return 'Minimal';
    }
  }

  String get description {
    switch (this) {
      case PdfStylePreset.classic:
        return 'Traditional borders, familiar layout';
      case PdfStylePreset.minimal:
        return 'Understated, maximum readability';
    }
  }

  HeaderStyle get headerStyle {
    switch (this) {
      case PdfStylePreset.classic:
        return HeaderStyle.classic;
      case PdfStylePreset.minimal:
        return HeaderStyle.minimal;
    }
  }

  HeaderCornerRadius get headerCornerRadius {
    switch (this) {
      case PdfStylePreset.classic:
        return HeaderCornerRadius.none;
      case PdfStylePreset.minimal:
        return HeaderCornerRadius.none;
    }
  }

  double get headerVerticalPadding {
    switch (this) {
      case PdfStylePreset.classic:
        return 12;
      case PdfStylePreset.minimal:
        return 20;
    }
  }

  double get headerHorizontalPadding {
    switch (this) {
      case PdfStylePreset.classic:
        return 20;
      case PdfStylePreset.minimal:
        return 24;
    }
  }

  PdfSectionStyleConfig get sectionStyleConfig {
    switch (this) {
      case PdfStylePreset.classic:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.bordered,
          cornerRadius: SectionCornerRadius.small,
          headerStyle: SectionHeaderStyle.fullWidth,
          sectionSpacing: 10,
          innerPadding: 10,
          headerFontSize: 8,
        );
      case PdfStylePreset.minimal:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.flat,
          cornerRadius: SectionCornerRadius.small,
          headerStyle: SectionHeaderStyle.underlined,
          sectionSpacing: 14,
          innerPadding: 14,
          headerFontSize: 8,
        );
    }
  }

  PdfTypographyConfig get typographyConfig {
    switch (this) {
      case PdfStylePreset.classic:
        return const PdfTypographyConfig(
          documentTitleSize: 22,
          sectionHeaderSize: 8,
          fieldLabelSize: 8,
          fieldValueSize: 9,
          tableHeaderSize: 8,
          tableBodySize: 8,
          footerSize: 7,
        );
      case PdfStylePreset.minimal:
        return const PdfTypographyConfig(
          documentTitleSize: 22,
          sectionHeaderSize: 8,
          fieldLabelSize: 7,
          fieldValueSize: 9,
          tableHeaderSize: 8,
          tableBodySize: 8,
          footerSize: 7,
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
