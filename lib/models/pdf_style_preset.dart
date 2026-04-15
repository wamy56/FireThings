import 'pdf_header_config.dart';
import 'pdf_section_style_config.dart';
import 'pdf_colour_scheme.dart';

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
        return 'Solid header, subtle shadows, clean typography';
      case PdfStylePreset.classic:
        return 'Traditional borders, familiar layout';
      case PdfStylePreset.minimal:
        return 'Clean and simple, no visual clutter';
      case PdfStylePreset.bold:
        return 'High contrast, strong visual presence';
    }
  }

  PdfHeaderConfig get headerConfig {
    switch (this) {
      case PdfStylePreset.modern:
        return PdfHeaderConfig.defaults().copyWith(
          headerStyle: HeaderStyle.modern,
          cornerRadius: HeaderCornerRadius.medium,
        );
      case PdfStylePreset.classic:
        return PdfHeaderConfig.defaults().copyWith(
          headerStyle: HeaderStyle.classic,
          cornerRadius: HeaderCornerRadius.none,
        );
      case PdfStylePreset.minimal:
        return PdfHeaderConfig.defaults().copyWith(
          headerStyle: HeaderStyle.minimal,
          cornerRadius: HeaderCornerRadius.none,
        );
      case PdfStylePreset.bold:
        return PdfHeaderConfig.defaults().copyWith(
          headerStyle: HeaderStyle.modern,
          cornerRadius: HeaderCornerRadius.large,
        );
    }
  }

  PdfSectionStyleConfig get sectionStyleConfig {
    switch (this) {
      case PdfStylePreset.modern:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.shadowed,
          cornerRadius: SectionCornerRadius.medium,
          headerStyle: SectionHeaderStyle.fullWidth,
        );
      case PdfStylePreset.classic:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.bordered,
          cornerRadius: SectionCornerRadius.small,
          headerStyle: SectionHeaderStyle.fullWidth,
        );
      case PdfStylePreset.minimal:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.flat,
          cornerRadius: SectionCornerRadius.small,
          headerStyle: SectionHeaderStyle.underlined,
        );
      case PdfStylePreset.bold:
        return const PdfSectionStyleConfig(
          cardStyle: SectionCardStyle.elevated,
          cornerRadius: SectionCornerRadius.large,
          headerStyle: SectionHeaderStyle.fullWidth,
        );
    }
  }

  PdfColourScheme get colourScheme {
    switch (this) {
      case PdfStylePreset.modern:
        return PdfColourScheme.navy;
      case PdfStylePreset.classic:
        return PdfColourScheme.charcoal;
      case PdfStylePreset.minimal:
        return PdfColourScheme.steelBlue;
      case PdfStylePreset.bold:
        return PdfColourScheme.crimson;
    }
  }
}
