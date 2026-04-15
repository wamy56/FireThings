# PDF Redesign - Complete Implementation Guide

> **Purpose**: This document provides step-by-step implementation details for transforming the PDF generation system into a modern, professional design with full user customization. Both personal and company PDFs are affected.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Phase 1: Model Layer Updates](#2-phase-1-model-layer-updates)
3. [Phase 2: PDF Widget Library](#3-phase-2-pdf-widget-library)
4. [Phase 3: Service Updates](#4-phase-3-service-updates)
5. [Phase 4: Customization Screens](#5-phase-4-customization-screens)
6. [Phase 5: Company PDF Support](#6-phase-5-company-pdf-support)
7. [Testing Checklist](#7-testing-checklist)
8. [Migration Strategy](#8-migration-strategy)

---

## 1. Architecture Overview

### Current System

```
Personal PDF Config:
├── PdfHeaderConfigService (SharedPreferences + Firestore sync)
├── PdfFooterConfigService (SharedPreferences + Firestore sync)
└── PdfColourSchemeService (SharedPreferences + Firestore sync)

Company PDF Config (Firestore only):
└── CompanyPdfConfigService
    ├── getEffectiveHeaderConfig() -> company ?? personal
    ├── getEffectiveFooterConfig() -> company ?? personal
    └── getEffectiveColourScheme() -> company ?? personal

PDF Generation:
├── pdf_service.dart -> Jobsheet PDFs
├── invoice_pdf_service.dart -> Invoice PDFs
├── template_pdf_service.dart -> Form template PDFs
└── compliance_report_service.dart -> Compliance report PDFs
```

### New System (After Redesign)

```
Personal PDF Config:
├── PdfHeaderConfigService (ENHANCED - new style options)
├── PdfFooterConfigService (UNCHANGED)
├── PdfColourSchemeService (ENHANCED - secondary color)
├── PdfSectionStyleService (NEW)
└── PdfTypographyService (NEW)

Company PDF Config:
└── CompanyPdfConfigService (ENHANCED)
    ├── getEffective* for all 5 config types
    └── Firestore paths for new configs

PDF Widgets (NEW):
└── lib/services/pdf_widgets/
    ├── pdf_style_helpers.dart
    ├── pdf_modern_header.dart
    ├── pdf_section_card.dart
    ├── pdf_field_row.dart
    ├── pdf_modern_table.dart
    └── pdf_signature_box.dart
```

---

## 2. Phase 1: Model Layer Updates

### 2.1 Enhance `PdfColourScheme`

**File:** `lib/models/pdf_colour_scheme.dart`

```dart
import 'dart:convert';
import 'package:pdf/pdf.dart';

class PdfColourScheme {
  final int primaryColorValue;
  final int? secondaryColorValue;    // NEW
  final bool useAutoSecondary;       // NEW - default true

  const PdfColourScheme({
    required this.primaryColorValue,
    this.secondaryColorValue,
    this.useAutoSecondary = true,
  });

  // ── Existing getters ──
  
  PdfColor get primaryColor => PdfColor.fromInt(primaryColorValue);

  PdfColor get primaryLight {
    return _blendWithWhite(primaryColorValue, 0.9);
  }

  PdfColor get primaryMedium {
    return _blendWithWhite(primaryColorValue, 0.6);
  }

  // ── NEW getters ──

  /// Very light tint for subtle backgrounds (95% white blend)
  PdfColor get primarySoft {
    return _blendWithWhite(primaryColorValue, 0.95);
  }

  /// Darker variant for depth (20% black blend)
  PdfColor get primaryDark {
    return _blendWithBlack(primaryColorValue, 0.2);
  }

  /// Secondary/accent color - user-defined or auto-computed
  PdfColor get secondaryColor {
    if (secondaryColorValue != null) {
      return PdfColor.fromInt(secondaryColorValue!);
    }
    if (useAutoSecondary) {
      return _computeComplementary(primaryColorValue);
    }
    return primaryColor;
  }

  PdfColor get secondaryLight {
    final secValue = secondaryColorValue ?? _computeComplementaryValue(primaryColorValue);
    return _blendWithWhite(secValue, 0.9);
  }

  // ── Text colors ──
  
  PdfColor get textPrimary => const PdfColor.fromInt(0xFF212121);
  PdfColor get textSecondary => const PdfColor.fromInt(0xFF757575);
  PdfColor get textMuted => const PdfColor.fromInt(0xFF9E9E9E);
  PdfColor get textOnPrimary => PdfColors.white;

  // ── Background colors ──
  
  PdfColor get cardBackground => PdfColors.white;
  PdfColor get pageBackground => const PdfColor.fromInt(0xFFFAFAFA);

  // ── Helper methods ──

  static PdfColor _blendWithWhite(int colorValue, double factor) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    final lr = (r * (1 - factor) + 255 * factor).round();
    final lg = (g * (1 - factor) + 255 * factor).round();
    final lb = (b * (1 - factor) + 255 * factor).round();
    return PdfColor.fromInt(0xFF000000 | (lr << 16) | (lg << 8) | lb);
  }

  static PdfColor _blendWithBlack(int colorValue, double factor) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    final dr = (r * (1 - factor)).round();
    final dg = (g * (1 - factor)).round();
    final db = (b * (1 - factor)).round();
    return PdfColor.fromInt(0xFF000000 | (dr << 16) | (dg << 8) | db);
  }

  /// Compute complementary color (opposite on color wheel)
  static PdfColor _computeComplementary(int colorValue) {
    return PdfColor.fromInt(_computeComplementaryValue(colorValue));
  }

  static int _computeComplementaryValue(int colorValue) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    
    // Convert to HSL, rotate hue by 180, convert back
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    final l = (max + min) / 2 / 255;
    
    if (max == min) {
      // Grayscale - use orange accent
      return 0xFFE67E22;
    }
    
    final d = (max - min) / 255;
    final s = l > 0.5 ? d / (2 - max / 255 - min / 255) : d / (max / 255 + min / 255);
    
    double h;
    if (max == r) {
      h = ((g - b) / (max - min) + (g < b ? 6 : 0)) / 6;
    } else if (max == g) {
      h = ((b - r) / (max - min) + 2) / 6;
    } else {
      h = ((r - g) / (max - min) + 4) / 6;
    }
    
    // Rotate hue by 180 degrees
    h = (h + 0.5) % 1.0;
    
    // Convert back to RGB
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    
    int hueToRgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return ((p + (q - p) * 6 * t) * 255).round();
      if (t < 1 / 2) return (q * 255).round();
      if (t < 2 / 3) return ((p + (q - p) * (2 / 3 - t) * 6) * 255).round();
      return (p * 255).round();
    }
    
    final nr = hueToRgb(p, q, h + 1 / 3);
    final ng = hueToRgb(p, q, h);
    final nb = hueToRgb(p, q, h - 1 / 3);
    
    return 0xFF000000 | (nr << 16) | (ng << 8) | nb;
  }

  // ── Defaults and Presets ──

  static PdfColourScheme defaults() => const PdfColourScheme(
    primaryColorValue: 0xFF1E3A5F,
    secondaryColorValue: 0xFFE67E22,
    useAutoSecondary: false,
  );

  // ── Updated presets with secondary colors ──
  
  static const navy = PdfColourScheme(
    primaryColorValue: 0xFF1E3A5F,
    secondaryColorValue: 0xFFE67E22, // Orange accent
  );
  
  static const teal = PdfColourScheme(
    primaryColorValue: 0xFF0D7377,
    secondaryColorValue: 0xFFE74C3C, // Red accent
  );
  
  static const crimson = PdfColourScheme(
    primaryColorValue: 0xFF8B1A1A,
    secondaryColorValue: 0xFF3498DB, // Blue accent
  );
  
  static const forestGreen = PdfColourScheme(
    primaryColorValue: 0xFF2E5A3A,
    secondaryColorValue: 0xFFD4AC0D, // Gold accent
  );
  
  static const charcoal = PdfColourScheme(
    primaryColorValue: 0xFF3C3C3C,
    secondaryColorValue: 0xFF27AE60, // Green accent
  );
  
  static const royalPurple = PdfColourScheme(
    primaryColorValue: 0xFF5B2C8E,
    secondaryColorValue: 0xFFF39C12, // Amber accent
  );
  
  static const steelBlue = PdfColourScheme(
    primaryColorValue: 0xFF4682B4,
    secondaryColorValue: 0xFFE74C3C, // Red accent
  );
  
  static const burntOrange = PdfColourScheme(
    primaryColorValue: 0xFFCC5500,
    secondaryColorValue: 0xFF2980B9, // Blue accent
  );

  static const List<({String label, PdfColourScheme scheme})> presets = [
    (label: 'Navy', scheme: navy),
    (label: 'Teal', scheme: teal),
    (label: 'Crimson', scheme: crimson),
    (label: 'Forest Green', scheme: forestGreen),
    (label: 'Charcoal', scheme: charcoal),
    (label: 'Royal Purple', scheme: royalPurple),
    (label: 'Steel Blue', scheme: steelBlue),
    (label: 'Burnt Orange', scheme: burntOrange),
  ];

  // ── Serialization ──

  Map<String, dynamic> toJson() => {
    'primaryColorValue': primaryColorValue,
    'secondaryColorValue': secondaryColorValue,
    'useAutoSecondary': useAutoSecondary,
  };

  factory PdfColourScheme.fromJson(Map<String, dynamic> json) => PdfColourScheme(
    primaryColorValue: json['primaryColorValue'] as int? ?? 0xFF1E3A5F,
    secondaryColorValue: json['secondaryColorValue'] as int?,
    useAutoSecondary: json['useAutoSecondary'] as bool? ?? true,
  );

  String toJsonString() => jsonEncode(toJson());

  factory PdfColourScheme.fromJsonString(String jsonString) =>
      PdfColourScheme.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfColourScheme copyWith({
    int? primaryColorValue,
    int? secondaryColorValue,
    bool? useAutoSecondary,
    bool clearSecondary = false,
  }) => PdfColourScheme(
    primaryColorValue: primaryColorValue ?? this.primaryColorValue,
    secondaryColorValue: clearSecondary ? null : (secondaryColorValue ?? this.secondaryColorValue),
    useAutoSecondary: useAutoSecondary ?? this.useAutoSecondary,
  );
}
```

### 2.2 Enhance `PdfHeaderConfig`

**File:** `lib/models/pdf_header_config.dart`

Add after existing enums:

```dart
/// Header visual style
enum HeaderStyle {
  classic,  // Bottom border only, white background (current look)
  modern,   // Solid primary background with rounded bottom corners
  minimal,  // No border, clean separation with extra padding
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
```

Update `PdfHeaderConfig` class:

```dart
class PdfHeaderConfig {
  final LogoZone logoZone;
  final LogoSize logoSize;
  final List<HeaderTextLine> leftLines;
  final List<HeaderTextLine> centreLines;
  
  // NEW fields
  final HeaderStyle headerStyle;
  final HeaderCornerRadius cornerRadius;
  final double verticalPadding;
  final double horizontalPadding;

  const PdfHeaderConfig({
    required this.logoZone,
    required this.logoSize,
    required this.leftLines,
    required this.centreLines,
    this.headerStyle = HeaderStyle.modern,      // NEW default
    this.cornerRadius = HeaderCornerRadius.medium,
    this.verticalPadding = 16,
    this.horizontalPadding = 24,
  });

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
    headerStyle: HeaderStyle.modern,
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

  factory PdfHeaderConfig.fromJson(Map<String, dynamic> json) => PdfHeaderConfig(
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
        .toList() ?? [],
    centreLines: (json['centreLines'] as List<dynamic>?)
        ?.map((e) => HeaderTextLine.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    // NEW fields with defaults for migration
    headerStyle: HeaderStyle.values.firstWhere(
      (e) => e.name == json['headerStyle'],
      orElse: () => HeaderStyle.modern,
    ),
    cornerRadius: HeaderCornerRadius.values.firstWhere(
      (e) => e.name == json['cornerRadius'],
      orElse: () => HeaderCornerRadius.medium,
    ),
    verticalPadding: (json['verticalPadding'] as num?)?.toDouble() ?? 16,
    horizontalPadding: (json['horizontalPadding'] as num?)?.toDouble() ?? 24,
  );

  PdfHeaderConfig copyWith({
    LogoZone? logoZone,
    LogoSize? logoSize,
    List<HeaderTextLine>? leftLines,
    List<HeaderTextLine>? centreLines,
    HeaderStyle? headerStyle,
    HeaderCornerRadius? cornerRadius,
    double? verticalPadding,
    double? horizontalPadding,
  }) => PdfHeaderConfig(
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
```

### 2.3 Create `PdfSectionStyleConfig` (NEW)

**File:** `lib/models/pdf_section_style_config.dart`

```dart
import 'dart:convert';

/// Visual style for section cards
enum SectionCardStyle {
  bordered,   // Light gray border (current look)
  shadowed,   // Subtle drop shadow, no border
  elevated,   // Stronger shadow for more depth
  flat,       // No border or shadow, just padding
}

/// Corner radius for section cards
enum SectionCornerRadius {
  small(4),
  medium(8),
  large(12);

  final double pixels;
  const SectionCornerRadius(this.pixels);
}

/// Style for section headers
enum SectionHeaderStyle {
  fullWidth,    // Full-width colored bar (current look)
  leftAccent,   // Left border accent only
  underlined,   // Text with underline
}

class PdfSectionStyleConfig {
  final SectionCardStyle cardStyle;
  final SectionCornerRadius cornerRadius;
  final SectionHeaderStyle headerStyle;
  final double sectionSpacing;
  final double innerPadding;
  final double headerFontSize;

  const PdfSectionStyleConfig({
    this.cardStyle = SectionCardStyle.shadowed,
    this.cornerRadius = SectionCornerRadius.medium,
    this.headerStyle = SectionHeaderStyle.fullWidth,
    this.sectionSpacing = 12,
    this.innerPadding = 12,
    this.headerFontSize = 11,
  });

  factory PdfSectionStyleConfig.defaults() => const PdfSectionStyleConfig();

  Map<String, dynamic> toJson() => {
    'cardStyle': cardStyle.name,
    'cornerRadius': cornerRadius.name,
    'headerStyle': headerStyle.name,
    'sectionSpacing': sectionSpacing,
    'innerPadding': innerPadding,
    'headerFontSize': headerFontSize,
  };

  factory PdfSectionStyleConfig.fromJson(Map<String, dynamic> json) =>
      PdfSectionStyleConfig(
        cardStyle: SectionCardStyle.values.firstWhere(
          (e) => e.name == json['cardStyle'],
          orElse: () => SectionCardStyle.shadowed,
        ),
        cornerRadius: SectionCornerRadius.values.firstWhere(
          (e) => e.name == json['cornerRadius'],
          orElse: () => SectionCornerRadius.medium,
        ),
        headerStyle: SectionHeaderStyle.values.firstWhere(
          (e) => e.name == json['headerStyle'],
          orElse: () => SectionHeaderStyle.fullWidth,
        ),
        sectionSpacing: (json['sectionSpacing'] as num?)?.toDouble() ?? 12,
        innerPadding: (json['innerPadding'] as num?)?.toDouble() ?? 12,
        headerFontSize: (json['headerFontSize'] as num?)?.toDouble() ?? 11,
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfSectionStyleConfig.fromJsonString(String jsonString) =>
      PdfSectionStyleConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfSectionStyleConfig copyWith({
    SectionCardStyle? cardStyle,
    SectionCornerRadius? cornerRadius,
    SectionHeaderStyle? headerStyle,
    double? sectionSpacing,
    double? innerPadding,
    double? headerFontSize,
  }) => PdfSectionStyleConfig(
    cardStyle: cardStyle ?? this.cardStyle,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    headerStyle: headerStyle ?? this.headerStyle,
    sectionSpacing: sectionSpacing ?? this.sectionSpacing,
    innerPadding: innerPadding ?? this.innerPadding,
    headerFontSize: headerFontSize ?? this.headerFontSize,
  );
}
```

### 2.4 Create `PdfTypographyConfig` (NEW)

**File:** `lib/models/pdf_typography_config.dart`

```dart
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
    this.sectionHeaderSize = 11,
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
        documentTitleSize: (json['documentTitleSize'] as num?)?.toDouble() ?? 24,
        sectionHeaderSize: (json['sectionHeaderSize'] as num?)?.toDouble() ?? 11,
        fieldLabelSize: (json['fieldLabelSize'] as num?)?.toDouble() ?? 8,
        fieldValueSize: (json['fieldValueSize'] as num?)?.toDouble() ?? 10,
        tableHeaderSize: (json['tableHeaderSize'] as num?)?.toDouble() ?? 9,
        tableBodySize: (json['tableBodySize'] as num?)?.toDouble() ?? 9,
        footerSize: (json['footerSize'] as num?)?.toDouble() ?? 8,
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfTypographyConfig.fromJsonString(String jsonString) =>
      PdfTypographyConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  PdfTypographyConfig copyWith({
    double? documentTitleSize,
    double? sectionHeaderSize,
    double? fieldLabelSize,
    double? fieldValueSize,
    double? tableHeaderSize,
    double? tableBodySize,
    double? footerSize,
  }) => PdfTypographyConfig(
    documentTitleSize: documentTitleSize ?? this.documentTitleSize,
    sectionHeaderSize: sectionHeaderSize ?? this.sectionHeaderSize,
    fieldLabelSize: fieldLabelSize ?? this.fieldLabelSize,
    fieldValueSize: fieldValueSize ?? this.fieldValueSize,
    tableHeaderSize: tableHeaderSize ?? this.tableHeaderSize,
    tableBodySize: tableBodySize ?? this.tableBodySize,
    footerSize: footerSize ?? this.footerSize,
  );
}
```

### 2.5 Create `PdfStylePreset` (NEW)

**File:** `lib/models/pdf_style_preset.dart`

```dart
import 'pdf_header_config.dart';
import 'pdf_section_style_config.dart';
import 'pdf_typography_config.dart';
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
```

### 2.6 Update `pdf_generation_data.dart`

**File:** `lib/services/pdf_generation_data.dart`

Add new fields to all PDF data classes:

```dart
class JobsheetPdfData {
  // ... existing fields ...
  
  // NEW fields
  final int? secondaryColourValue;
  final Map<String, dynamic>? sectionStyleJson;
  final Map<String, dynamic>? typographyJson;

  JobsheetPdfData({
    // ... existing params ...
    this.secondaryColourValue,
    this.sectionStyleJson,
    this.typographyJson,
  });
}

class InvoicePdfData {
  // ... existing fields ...
  
  // NEW fields
  final int? secondaryColourValue;
  final Map<String, dynamic>? sectionStyleJson;
  final Map<String, dynamic>? typographyJson;

  InvoicePdfData({
    // ... existing params ...
    this.secondaryColourValue,
    this.sectionStyleJson,
    this.typographyJson,
  });
}

class ComplianceReportPdfData {
  // ... existing fields ...
  
  // NEW fields
  final int? secondaryColourValue;
  final Map<String, dynamic>? sectionStyleJson;
  final Map<String, dynamic>? typographyJson;

  ComplianceReportPdfData({
    // ... existing params ...
    this.secondaryColourValue,
    this.sectionStyleJson,
    this.typographyJson,
  });
}
```

### 2.7 Update `models.dart` barrel

**File:** `lib/models/models.dart`

Add exports:

```dart
export 'pdf_section_style_config.dart';
export 'pdf_typography_config.dart';
export 'pdf_style_preset.dart';
```

---

## 3. Phase 2: PDF Widget Library

Create directory: `lib/services/pdf_widgets/`

### 3.1 `pdf_style_helpers.dart`

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_section_style_config.dart';

/// Common constants for PDF styling
const PdfColor pdfWhite = PdfColors.white;
const PdfColor pdfLightGray = PdfColor.fromInt(0xFFE0E0E0);
const PdfColor pdfDarkGray = PdfColor.fromInt(0xFF424242);

/// Build box decoration based on section card style
pw.BoxDecoration buildCardDecoration(
  PdfSectionStyleConfig style,
  PdfColourScheme colors,
) {
  switch (style.cardStyle) {
    case SectionCardStyle.bordered:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        border: pw.Border.all(color: pdfLightGray, width: 0.5),
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
      );
    case SectionCardStyle.shadowed:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
        boxShadow: [
          pw.BoxShadow(
            color: const PdfColor.fromInt(0x1A000000),
            blurRadius: 4,
            offset: const PdfPoint(0, 2),
          ),
        ],
      );
    case SectionCardStyle.elevated:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
        boxShadow: [
          pw.BoxShadow(
            color: const PdfColor.fromInt(0x33000000),
            blurRadius: 8,
            offset: const PdfPoint(0, 4),
          ),
        ],
      );
    case SectionCardStyle.flat:
      return pw.BoxDecoration(
        color: colors.cardBackground,
        borderRadius: pw.BorderRadius.circular(style.cornerRadius.pixels),
      );
  }
}

/// Get text style for labels
pw.TextStyle labelStyle(PdfColourScheme colors, {double fontSize = 8}) {
  return pw.TextStyle(
    fontSize: fontSize,
    color: colors.textSecondary,
    letterSpacing: 0.5,
  );
}

/// Get text style for values
pw.TextStyle valueStyle(PdfColourScheme colors, {double fontSize = 10, bool bold = true}) {
  return pw.TextStyle(
    fontSize: fontSize,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: colors.textPrimary,
  );
}
```

### 3.2 `pdf_modern_header.dart`

```dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_header_config.dart';
import '../../models/pdf_colour_scheme.dart';
import 'pdf_style_helpers.dart';

/// Builds the document header based on configured style
pw.Widget buildModernHeader({
  required PdfHeaderConfig config,
  required PdfColourScheme colors,
  required Uint8List? logoBytes,
  required String documentType,
  required String documentRef,
  Map<String, String> fallbackValues = const {},
}) {
  switch (config.headerStyle) {
    case HeaderStyle.modern:
      return _buildModernStyleHeader(config, colors, logoBytes, documentType, documentRef, fallbackValues);
    case HeaderStyle.classic:
      return _buildClassicStyleHeader(config, colors, logoBytes, documentType, documentRef, fallbackValues);
    case HeaderStyle.minimal:
      return _buildMinimalStyleHeader(config, colors, logoBytes, documentType, documentRef, fallbackValues);
  }
}

/// Modern style: Solid primary background with rounded bottom corners
pw.Widget _buildModernStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues,
) {
  return pw.Container(
    padding: pw.EdgeInsets.symmetric(
      horizontal: config.horizontalPadding,
      vertical: config.verticalPadding,
    ),
    decoration: pw.BoxDecoration(
      color: colors.primaryColor,
      borderRadius: pw.BorderRadius.only(
        bottomLeft: pw.Radius.circular(config.cornerRadius.pixels),
        bottomRight: pw.Radius.circular(config.cornerRadius.pixels),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Logo + Company info
        pw.Expanded(
          flex: 3,
          child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues, isModern: true),
        ),
        pw.SizedBox(width: 16),
        // Document badge
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0x26FFFFFF), // 15% white overlay
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                documentType.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfWhite,
                  letterSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'REF: $documentRef',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromInt(0xCCFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Classic style: White background with bottom border (current look)
pw.Widget _buildClassicStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues,
) {
  return pw.Container(
    padding: pw.EdgeInsets.only(bottom: 8),
    margin: pw.EdgeInsets.only(bottom: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: colors.primaryColor, width: 2),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues, isModern: false),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: pw.BoxDecoration(
            color: colors.primaryColor,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                documentType.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfWhite,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'REF: $documentRef',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromInt(0xCCFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Minimal style: Clean with extra spacing, no borders
pw.Widget _buildMinimalStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues,
) {
  return pw.Container(
    padding: pw.EdgeInsets.only(bottom: 16),
    margin: pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues, isModern: false),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              documentType.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: colors.primaryColor,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'REF: $documentRef',
              style: pw.TextStyle(
                fontSize: 10,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Build logo and company info section
pw.Widget _buildLogoAndInfo(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  Map<String, String> fallbackValues,
  {required bool isModern}
) {
  final textColor = isModern ? pdfWhite : colors.textPrimary;
  final secondaryTextColor = isModern ? PdfColor.fromInt(0xCCFFFFFF) : colors.textSecondary;
  
  final children = <pw.Widget>[];
  
  // Add logo if configured on left
  if (config.logoZone == LogoZone.left && logoBytes != null) {
    children.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(right: 12),
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          height: config.logoSize.pixels,
        ),
      ),
    );
  }
  
  // Add text lines
  final textWidgets = <pw.Widget>[];
  for (final line in config.leftLines) {
    final value = line.value.isNotEmpty ? line.value : fallbackValues[line.key] ?? '';
    if (value.isEmpty) continue;
    
    textWidgets.add(
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: line.fontSize,
          fontWeight: line.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: line.fontSize > 12 ? textColor : secondaryTextColor,
        ),
      ),
    );
    textWidgets.add(pw.SizedBox(height: 2));
  }
  
  if (textWidgets.isNotEmpty) {
    children.add(
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: textWidgets,
        ),
      ),
    );
  }
  
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: children,
  );
}
```

### 3.3 `pdf_section_card.dart`

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_section_style_config.dart';
import 'pdf_style_helpers.dart';

/// Builds a styled section card with header and content
pw.Widget buildSectionCard({
  required String title,
  required List<pw.Widget> children,
  required PdfColourScheme colors,
  required PdfSectionStyleConfig style,
  bool showHeader = true,
}) {
  return pw.Container(
    margin: pw.EdgeInsets.only(bottom: style.sectionSpacing),
    decoration: buildCardDecoration(style, colors),
    clipBehavior: pw.Clip.antiAlias,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (showHeader) _buildSectionHeader(title, colors, style),
        pw.Padding(
          padding: pw.EdgeInsets.all(style.innerPadding),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    ),
  );
}

/// Build section header based on style
pw.Widget _buildSectionHeader(
  String title,
  PdfColourScheme colors,
  PdfSectionStyleConfig style,
) {
  switch (style.headerStyle) {
    case SectionHeaderStyle.fullWidth:
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: colors.primaryColor,
          borderRadius: style.cardStyle == SectionCardStyle.flat
              ? null
              : pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(style.cornerRadius.pixels),
                  topRight: pw.Radius.circular(style.cornerRadius.pixels),
                ),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: style.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: pdfWhite,
            letterSpacing: 0.5,
          ),
        ),
      );
      
    case SectionHeaderStyle.leftAccent:
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: colors.primaryColor, width: 4),
          ),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: style.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: colors.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
      );
      
    case SectionHeaderStyle.underlined:
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(0, 8, 0, 6),
        margin: pw.EdgeInsets.symmetric(horizontal: style.innerPadding),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: colors.primaryMedium, width: 1),
          ),
        ),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: style.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: colors.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
      );
  }
}
```

### 3.4 `pdf_field_row.dart`

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_typography_config.dart';
import 'pdf_style_helpers.dart';

/// Builds a 2-column grid of label/value pairs
pw.Widget buildFieldGrid({
  required List<(String label, String value)> fields,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  bool alternatingBackground = true,
  bool twoColumn = true,
}) {
  if (!twoColumn) {
    return _buildSingleColumnLayout(fields, colors, typography, alternatingBackground);
  }
  
  final rows = <pw.Widget>[];
  
  for (int i = 0; i < fields.length; i += 2) {
    final isAlternate = (i ~/ 2).isOdd;
    final leftField = fields[i];
    final rightField = i + 1 < fields.length ? fields[i + 1] : null;
    
    rows.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: alternatingBackground && isAlternate ? colors.primarySoft : null,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildField(leftField, colors, typography)),
            if (rightField != null) ...[
              pw.SizedBox(width: 16),
              pw.Expanded(child: _buildField(rightField, colors, typography)),
            ] else
              pw.Expanded(child: pw.SizedBox()),
          ],
        ),
      ),
    );
  }
  
  return pw.Column(children: rows);
}

pw.Widget _buildSingleColumnLayout(
  List<(String label, String value)> fields,
  PdfColourScheme colors,
  PdfTypographyConfig typography,
  bool alternatingBackground,
) {
  return pw.Column(
    children: fields.asMap().entries.map((entry) {
      final isAlternate = entry.key.isOdd;
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: alternatingBackground && isAlternate ? colors.primarySoft : null,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: _buildField(entry.value, colors, typography),
      );
    }).toList(),
  );
}

pw.Widget _buildField(
  (String label, String value) field,
  PdfColourScheme colors,
  PdfTypographyConfig typography,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        field.$1.toUpperCase(),
        style: pw.TextStyle(
          fontSize: typography.fieldLabelSize,
          color: colors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        field.$2.isEmpty ? '-' : field.$2,
        style: pw.TextStyle(
          fontSize: typography.fieldValueSize,
          fontWeight: pw.FontWeight.bold,
          color: colors.textPrimary,
        ),
      ),
    ],
  );
}

/// Builds a compact inline field row (label: value)
pw.Widget buildCompactFieldRow({
  required String label,
  required String value,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  bool isAlternate = false,
  bool alternatingBackground = true,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: pw.BoxDecoration(
      color: alternatingBackground && isAlternate ? colors.primarySoft : null,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: typography.fieldLabelSize + 1,
              fontWeight: pw.FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isEmpty ? '-' : value,
            style: pw.TextStyle(
              fontSize: typography.fieldValueSize,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
```

### 3.5 `pdf_modern_table.dart`

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_typography_config.dart';
import 'pdf_style_helpers.dart';

/// Builds a modern styled table with colored header
pw.Widget buildModernTable({
  required List<String> headers,
  required List<List<String>> rows,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  List<int>? columnFlex,
  bool alternatingRows = true,
}) {
  final flexList = columnFlex ?? List.filled(headers.length, 1);
  
  return pw.Table(
    border: pw.TableBorder.all(
      color: colors.primaryMedium,
      width: 0.5,
    ),
    columnWidths: {
      for (var i = 0; i < headers.length; i++)
        i: pw.FlexColumnWidth(flexList[i].toDouble()),
    },
    children: [
      // Header row
      pw.TableRow(
        decoration: pw.BoxDecoration(color: colors.primaryColor),
        children: headers.map((h) => pw.Container(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            h.toUpperCase(),
            style: pw.TextStyle(
              fontSize: typography.tableHeaderSize,
              fontWeight: pw.FontWeight.bold,
              color: pdfWhite,
              letterSpacing: 0.3,
            ),
          ),
        )).toList(),
      ),
      // Data rows
      ...rows.asMap().entries.map((entry) {
        final isAlternate = entry.key.isOdd;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: alternatingRows && isAlternate ? colors.primarySoft : null,
          ),
          children: entry.value.map((cell) => pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              cell,
              style: pw.TextStyle(
                fontSize: typography.tableBodySize,
                color: colors.textPrimary,
              ),
            ),
          )).toList(),
        );
      }),
    ],
  );
}

/// Builds a simple table without header (for repeat groups etc.)
pw.Widget buildSimpleTable({
  required List<List<String>> rows,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  List<int>? columnFlex,
}) {
  final numCols = rows.isNotEmpty ? rows.first.length : 0;
  final flexList = columnFlex ?? List.filled(numCols, 1);
  
  return pw.Table(
    border: pw.TableBorder.all(
      color: pdfLightGray,
      width: 0.5,
    ),
    columnWidths: {
      for (var i = 0; i < numCols; i++)
        i: pw.FlexColumnWidth(flexList[i].toDouble()),
    },
    children: rows.asMap().entries.map((entry) {
      final isAlternate = entry.key.isOdd;
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: isAlternate ? colors.primarySoft : null,
        ),
        children: entry.value.map((cell) => pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            cell,
            style: pw.TextStyle(
              fontSize: typography.tableBodySize,
              color: colors.textPrimary,
            ),
          ),
        )).toList(),
      );
    }).toList(),
  );
}
```

### 3.6 `pdf_signature_box.dart`

```dart
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_colour_scheme.dart';
import '../../models/pdf_typography_config.dart';
import 'pdf_style_helpers.dart';

/// Builds improved signature section with two boxes side by side
pw.Widget buildSignatureSection({
  required String? engineerSignatureBase64,
  required String? customerSignatureBase64,
  required String engineerName,
  required String? customerName,
  required String date,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  double boxHeight = 60,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _buildSignatureBox(
          title: 'Engineer Signature',
          signatureBase64: engineerSignatureBase64,
          name: engineerName,
          date: date,
          colors: colors,
          typography: typography,
          boxHeight: boxHeight,
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: _buildSignatureBox(
          title: 'Customer / Site Representative',
          signatureBase64: customerSignatureBase64,
          name: customerName ?? '',
          date: date,
          colors: colors,
          typography: typography,
          boxHeight: boxHeight,
        ),
      ),
    ],
  );
}

pw.Widget _buildSignatureBox({
  required String title,
  required String? signatureBase64,
  required String name,
  required String date,
  required PdfColourScheme colors,
  required PdfTypographyConfig typography,
  required double boxHeight,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: typography.fieldLabelSize + 1,
          fontWeight: pw.FontWeight.bold,
          color: colors.textSecondary,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        height: boxHeight,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: colors.primarySoft,
          border: pw.Border.all(color: colors.primaryMedium, width: 0.5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: signatureBase64 != null && signatureBase64.isNotEmpty
            ? pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(base64Decode(signatureBase64)),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              )
            : pw.Center(
                child: pw.Text(
                  'Signature',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: colors.textMuted,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
      ),
      pw.SizedBox(height: 6),
      _buildNameDateRow(name, date, colors, typography),
    ],
  );
}

pw.Widget _buildNameDateRow(
  String name,
  String date,
  PdfColourScheme colors,
  PdfTypographyConfig typography,
) {
  return pw.Row(
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'NAME',
              style: pw.TextStyle(
                fontSize: typography.fieldLabelSize - 1,
                color: colors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            pw.Text(
              name.isEmpty ? '-' : name,
              style: pw.TextStyle(
                fontSize: typography.fieldValueSize - 1,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DATE',
            style: pw.TextStyle(
              fontSize: typography.fieldLabelSize - 1,
              color: colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          pw.Text(
            date,
            style: pw.TextStyle(
              fontSize: typography.fieldValueSize - 1,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    ],
  );
}
```

---

## 4. Phase 3: Service Updates

### 4.1 Create `PdfSectionStyleService` (NEW)

**File:** `lib/services/pdf_section_style_service.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_section_style_config.dart';
import '../models/pdf_header_config.dart';
import 'firestore_sync_service.dart';

class PdfSectionStyleService {
  static String _keyForType(PdfDocumentType type) =>
      'pdf_section_style_${type.name}';

  static Future<PdfSectionStyleConfig> getConfig(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyForType(type));
    if (jsonString != null) {
      return PdfSectionStyleConfig.fromJsonString(jsonString);
    }
    return PdfSectionStyleConfig.defaults();
  }

  static Future<void> saveConfig(PdfSectionStyleConfig config, PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = config.toJsonString();
    await prefs.setString(_keyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfSectionStyle(jsonString, type);
  }
}
```

### 4.2 Create `PdfTypographyService` (NEW)

**File:** `lib/services/pdf_typography_service.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_typography_config.dart';
import '../models/pdf_header_config.dart';
import 'firestore_sync_service.dart';

class PdfTypographyService {
  static String _keyForType(PdfDocumentType type) =>
      'pdf_typography_${type.name}';

  static Future<PdfTypographyConfig> getConfig(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyForType(type));
    if (jsonString != null) {
      return PdfTypographyConfig.fromJsonString(jsonString);
    }
    return PdfTypographyConfig.defaults();
  }

  static Future<void> saveConfig(PdfTypographyConfig config, PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = config.toJsonString();
    await prefs.setString(_keyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfTypography(jsonString, type);
  }
}
```

### 4.3 Update `CompanyPdfConfigService`

**File:** `lib/services/company_pdf_config_service.dart`

Add methods for new config types:

```dart
// Add to class:

final Map<String, PdfSectionStyleConfig> _sectionStyleCache = {};
final Map<String, PdfTypographyConfig> _typographyCache = {};

String _sectionStyleDocId(PdfDocumentType type) => 'section_style_${type.name}';
String _typographyDocId(PdfDocumentType type) => 'typography_${type.name}';

// --- Section Style ---

Future<PdfSectionStyleConfig?> getSectionStyleConfig(String companyId, PdfDocumentType type) async {
  final key = _cacheKey(companyId, type);
  if (_sectionStyleCache.containsKey(key)) return _sectionStyleCache[key];

  try {
    final doc = await _configDoc(companyId, _sectionStyleDocId(type)).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['config'] is String) {
        final config = PdfSectionStyleConfig.fromJsonString(data['config'] as String);
        _sectionStyleCache[key] = config;
        return config;
      }
    }
  } catch (e) {
    debugPrint('CompanyPdfConfigService: getSectionStyleConfig failed: $e');
  }
  return null;
}

Future<void> saveSectionStyleConfig(String companyId, PdfSectionStyleConfig config, PdfDocumentType type) async {
  final key = _cacheKey(companyId, type);
  _sectionStyleCache[key] = config;
  await _configDoc(companyId, _sectionStyleDocId(type)).set({
    'config': config.toJsonString(),
    'updatedAt': DateTime.now().toIso8601String(),
  });
}

Future<PdfSectionStyleConfig> getEffectiveSectionStyleConfig(
  PdfDocumentType type, {
  bool useCompanyBranding = false,
}) async {
  final companyId = UserProfileService.instance.companyId;
  if (companyId != null && useCompanyBranding) {
    final companyConfig = await getSectionStyleConfig(companyId, type);
    if (companyConfig != null) return companyConfig;
  }
  return PdfSectionStyleService.getConfig(type);
}

// --- Typography ---

Future<PdfTypographyConfig?> getTypographyConfig(String companyId, PdfDocumentType type) async {
  final key = _cacheKey(companyId, type);
  if (_typographyCache.containsKey(key)) return _typographyCache[key];

  try {
    final doc = await _configDoc(companyId, _typographyDocId(type)).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['config'] is String) {
        final config = PdfTypographyConfig.fromJsonString(data['config'] as String);
        _typographyCache[key] = config;
        return config;
      }
    }
  } catch (e) {
    debugPrint('CompanyPdfConfigService: getTypographyConfig failed: $e');
  }
  return null;
}

Future<void> saveTypographyConfig(String companyId, PdfTypographyConfig config, PdfDocumentType type) async {
  final key = _cacheKey(companyId, type);
  _typographyCache[key] = config;
  await _configDoc(companyId, _typographyDocId(type)).set({
    'config': config.toJsonString(),
    'updatedAt': DateTime.now().toIso8601String(),
  });
}

Future<PdfTypographyConfig> getEffectiveTypographyConfig(
  PdfDocumentType type, {
  bool useCompanyBranding = false,
}) async {
  final companyId = UserProfileService.instance.companyId;
  if (companyId != null && useCompanyBranding) {
    final companyConfig = await getTypographyConfig(companyId, type);
    if (companyConfig != null) return companyConfig;
  }
  return PdfTypographyService.getConfig(type);
}

// Update clearCache():
void clearCache() {
  _headerCache.clear();
  _footerCache.clear();
  _colourCache.clear();
  _logoCache.clear();
  _sectionStyleCache.clear();  // NEW
  _typographyCache.clear();     // NEW
}
```

### 4.4 Update `FirestoreSyncService`

**File:** `lib/services/firestore_sync_service.dart`

Add sync methods for new config types:

```dart
// Add to class:

Future<void> syncPdfSectionStyle(String jsonString, PdfDocumentType type) async {
  final userId = _auth.currentUser?.uid;
  if (userId == null) return;
  
  try {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('pdf_config')
        .doc('section_style_${type.name}')
        .set({
          'config': jsonString,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    debugPrint('FirestoreSyncService: syncPdfSectionStyle failed: $e');
  }
}

Future<void> syncPdfTypography(String jsonString, PdfDocumentType type) async {
  final userId = _auth.currentUser?.uid;
  if (userId == null) return;
  
  try {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('pdf_config')
        .doc('typography_${type.name}')
        .set({
          'config': jsonString,
          'lastModifiedAt': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    debugPrint('FirestoreSyncService: syncPdfTypography failed: $e');
  }
}
```

### 4.5 Major Refactor: `pdf_service.dart`

This is the largest change. Key updates:

1. **Import new widgets and models**
2. **Update `_buildJobsheetPdf` to load new configs**
3. **Replace section builders with new widget functions**
4. **Update header building to use `buildModernHeader`**

**Key sections to refactor:**

```dart
// At top of file, add imports:
import 'pdf_widgets/pdf_modern_header.dart';
import 'pdf_widgets/pdf_section_card.dart';
import 'pdf_widgets/pdf_field_row.dart';
import 'pdf_widgets/pdf_modern_table.dart';
import 'pdf_widgets/pdf_signature_box.dart';
import 'pdf_widgets/pdf_style_helpers.dart';
import '../models/pdf_section_style_config.dart';
import '../models/pdf_typography_config.dart';

// In _buildJobsheetPdf, reconstruct configs:
final sectionStyle = data.sectionStyleJson != null
    ? PdfSectionStyleConfig.fromJson(data.sectionStyleJson!)
    : PdfSectionStyleConfig.defaults();

final typography = data.typographyJson != null
    ? PdfTypographyConfig.fromJson(data.typographyJson!)
    : PdfTypographyConfig.defaults();

// Update colour scheme reconstruction:
final colourScheme = PdfColourScheme(
  primaryColorValue: data.colourSchemeValue,
  secondaryColorValue: data.secondaryColourValue,
);
```

**Replace `_buildHeader` with:**

```dart
pw.Widget _buildHeader(Jobsheet jobsheet, pw.Context context, _JobsheetSettings settings, 
    Uint8List? logoBytes, PdfHeaderConfig headerConfig, PdfColourScheme colors) {
  return buildModernHeader(
    config: headerConfig,
    colors: colors,
    logoBytes: logoBytes,
    documentType: jobsheet.templateType,
    documentRef: jobsheet.jobNumber,
    fallbackValues: {
      'companyName': settings.companyName.isNotEmpty ? settings.companyName : jobsheet.engineerName,
      'tagline': settings.tagline,
      'address': settings.address,
      'phone': settings.phone,
    },
  );
}
```

**Update section builders to use new widgets - example for Job Info:**

```dart
pw.Widget _buildJobInfoSection(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  return buildSectionCard(
    title: 'Job Information',
    colors: colors,
    style: sectionStyle,
    children: [
      buildFieldGrid(
        fields: [
          ('Date', dateFormat.format(jobsheet.date)),
          ('Time', timeFormat.format(jobsheet.date)),
          ('Job No', jobsheet.jobNumber),
          ('Category', jobsheet.systemCategory.isEmpty ? 'N/A' : jobsheet.systemCategory),
          ('Engineer', jobsheet.engineerName),
        ],
        colors: colors,
        typography: typography,
      ),
    ],
  );
}
```

---

## 5. Phase 4: Customization Screens

### 5.1 Update `pdf_colour_scheme_screen.dart`

Add secondary color picker:

```dart
// Add after primary color section:

const SizedBox(height: 32),

// Secondary colour section
Text(
  'ACCENT COLOUR',
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
    letterSpacing: 1,
  ),
),
const SizedBox(height: 12),

// Auto-secondary toggle
SwitchListTile(
  title: const Text('Auto-compute accent'),
  subtitle: Text(
    'Automatically choose a complementary accent colour',
    style: TextStyle(
      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
    ),
  ),
  value: _scheme.useAutoSecondary,
  onChanged: (value) {
    setState(() {
      _scheme = _scheme.copyWith(
        useAutoSecondary: value,
        clearSecondary: value,  // Clear custom when enabling auto
      );
    });
  },
),

// Manual secondary picker (shown when auto is off)
if (!_scheme.useAutoSecondary) ...[
  const SizedBox(height: 12),
  _buildColorButton(
    label: 'Choose Accent Colour',
    color: Color(_scheme.secondaryColor.toInt()),
    onTap: _openSecondaryPicker,
  ),
],
```

### 5.2 Update `pdf_header_designer_screen.dart`

Add header style section:

```dart
// Add a new tab or section for "Style":

// Header Style selector
Text('HEADER STYLE', style: ...),
const SizedBox(height: 8),
SegmentedButton<HeaderStyle>(
  segments: [
    ButtonSegment(
      value: HeaderStyle.modern,
      label: const Text('Modern'),
    ),
    ButtonSegment(
      value: HeaderStyle.classic,
      label: const Text('Classic'),
    ),
    ButtonSegment(
      value: HeaderStyle.minimal,
      label: const Text('Minimal'),
    ),
  ],
  selected: {_config.headerStyle},
  onSelectionChanged: (selected) {
    setState(() {
      _config = _config.copyWith(headerStyle: selected.first);
    });
  },
),

// Corner Radius (only for modern style)
if (_config.headerStyle == HeaderStyle.modern) ...[
  const SizedBox(height: 16),
  Text('CORNER RADIUS', style: ...),
  const SizedBox(height: 8),
  SegmentedButton<HeaderCornerRadius>(
    segments: HeaderCornerRadius.values.map((r) => ButtonSegment(
      value: r,
      label: Text(r.name.capitalize()),
    )).toList(),
    selected: {_config.cornerRadius},
    onSelectionChanged: (selected) {
      setState(() {
        _config = _config.copyWith(cornerRadius: selected.first);
      });
    },
  ),
],
```

### 5.3 Create `pdf_section_style_screen.dart` (NEW)

**File:** `lib/screens/settings/pdf_section_style_screen.dart`

Full screen for section styling - follows same pattern as other PDF screens.

### 5.4 Create `pdf_typography_screen.dart` (NEW)

**File:** `lib/screens/settings/pdf_typography_screen.dart`

Screen with sliders for each font size category.

### 5.5 Update `pdf_design_screen.dart`

Add preset selector and new navigation cards:

```dart
// Add at top of list:
_buildPresetSection(isDark),
const SizedBox(height: 24),

// Add new config cards after Colour Scheme:
_buildConfigCard(
  context,
  isDark,
  'Section Style',
  AppIcons.edit,
  'Customise card styles, corners, and spacing',
  () => Navigator.push(
    context,
    adaptivePageRoute(
      builder: (_) => PdfSectionStyleScreen(docType: type),
    ),
  ),
),
const SizedBox(height: 8),
_buildConfigCard(
  context,
  isDark,
  'Typography',
  AppIcons.text,
  'Adjust font sizes throughout the document',
  () => Navigator.push(
    context,
    adaptivePageRoute(
      builder: (_) => PdfTypographyScreen(docType: type),
    ),
  ),
),
```

---

## 6. Phase 5: Company PDF Support

### 6.1 Update `company_pdf_design_screen.dart`

Add new config cards for section style and typography (same pattern as personal).

### 6.2 Ensure Effective Config Resolution

All PDF generation must use `CompanyPdfConfigService.getEffective*` methods when `useCompanyBranding` is true:

```dart
// In PDFService.generateJobsheetPDF:

final useCompanyBranding = jobsheet.dispatchedJobId != null;

final headerConfig = await CompanyPdfConfigService.instance.getEffectiveHeaderConfig(
  PdfDocumentType.jobsheet,
  useCompanyBranding: useCompanyBranding,
);

final footerConfig = await CompanyPdfConfigService.instance.getEffectiveFooterConfig(
  PdfDocumentType.jobsheet,
  useCompanyBranding: useCompanyBranding,
);

final colourScheme = await CompanyPdfConfigService.instance.getEffectiveColourScheme(
  PdfDocumentType.jobsheet,
  useCompanyBranding: useCompanyBranding,
);

final sectionStyle = await CompanyPdfConfigService.instance.getEffectiveSectionStyleConfig(
  PdfDocumentType.jobsheet,
  useCompanyBranding: useCompanyBranding,
);

final typography = await CompanyPdfConfigService.instance.getEffectiveTypographyConfig(
  PdfDocumentType.jobsheet,
  useCompanyBranding: useCompanyBranding,
);

final logoBytes = await CompanyPdfConfigService.instance.getEffectiveLogoBytes(
  useCompanyBranding: useCompanyBranding,
  type: PdfDocumentType.jobsheet,
);
```

---

## 7. Testing Checklist

### Unit Tests
- [ ] `PdfColourScheme` serialization with new fields
- [ ] `PdfHeaderConfig` serialization with new fields
- [ ] `PdfSectionStyleConfig` serialization
- [ ] `PdfTypographyConfig` serialization
- [ ] Color blending helper functions
- [ ] Complementary color computation

### Visual Tests
- [ ] Jobsheet PDF with modern header (rounded bottom corners)
- [ ] Jobsheet PDF with classic header
- [ ] Jobsheet PDF with minimal header
- [ ] Invoice PDF with new styling
- [ ] All section card styles (bordered, shadowed, elevated, flat)
- [ ] All section header styles (fullWidth, leftAccent, underlined)
- [ ] Field grid 2-column layout
- [ ] Modern tables with colored headers
- [ ] Signature boxes with new styling
- [ ] Secondary color usage in PDFs

### Integration Tests
- [ ] Personal PDF config save/load for all types
- [ ] Company PDF config save/load for all types
- [ ] Effective config resolution (company -> personal fallback)
- [ ] Firestore sync for new config types
- [ ] Style preset application

### Migration Tests
- [ ] Fresh install gets modern defaults
- [ ] Existing configs without new fields get defaults applied
- [ ] No data loss during migration

### Cross-Platform
- [ ] Android PDF generation
- [ ] iOS PDF generation
- [ ] Web PDF generation
- [ ] Desktop PDF generation

---

## 8. Migration Strategy

### Auto-Apply Modern Style

Since user chose auto-apply, all defaults are set to modern:

```dart
// PdfHeaderConfig.defaults() uses:
headerStyle: HeaderStyle.modern

// PdfSectionStyleConfig.defaults() uses:
cardStyle: SectionCardStyle.shadowed
cornerRadius: SectionCornerRadius.medium
```

### Backwards Compatibility

All new JSON fields have defaults in `fromJson`:

```dart
factory PdfHeaderConfig.fromJson(Map<String, dynamic> json) => PdfHeaderConfig(
  // ... existing fields ...
  headerStyle: HeaderStyle.values.firstWhere(
    (e) => e.name == json['headerStyle'],
    orElse: () => HeaderStyle.modern,  // Default for existing configs
  ),
  // etc.
);
```

### No Breaking Changes

- All existing API contracts preserved
- All existing stored data remains valid
- New fields optional with sensible defaults

---

## Implementation Order

1. **Day 1**: Models (`pdf_colour_scheme.dart`, `pdf_header_config.dart`, new models)
2. **Day 2**: PDF widget library (all 6 files)
3. **Day 3**: Services (new services, update existing)
4. **Day 4**: Refactor `pdf_service.dart` 
5. **Day 5**: Refactor `invoice_pdf_service.dart`
6. **Day 6**: Customization screens
7. **Day 7**: Company PDF support + testing

---

## Notes

- Always use `pw.*` for PDF widgets (Flutter pdf package)
- All PDF generation runs in isolates - ensure all data is serializable
- Use existing patterns from codebase (services, screens, models)
- Follow `AppIcons.*` convention for icons
- Use `AppTheme.*` for UI theme colors
- Test on all platforms before marking complete
