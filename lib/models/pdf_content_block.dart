import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'pdf_variable.dart';

/// The type of content a block represents.
enum ContentBlockType {
  text,
  logo,
  divider,
  spacer;

  static ContentBlockType fromName(String name) =>
      ContentBlockType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ContentBlockType.text,
      );
}

/// Text alignment within a content block.
enum TextAlignment {
  left,
  center,
  right;

  static TextAlignment fromName(String name) => TextAlignment.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TextAlignment.left,
      );
}

/// A composable content block for PDF headers and footers.
///
/// Replaces the old [HeaderTextLine] with richer styling and variable support.
/// Each block has a unique [id] for stable identity during reordering.
class ContentBlock {
  final String id;
  final ContentBlockType type;

  // Text content
  final String? text;
  final PdfVariable? variable;

  // Typography
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool uppercase;
  final TextAlignment alignment;
  final int? colorValue;
  final String? fontFamily;
  final double spacingAfter;

  // Logo-specific
  final double? logoWidth;
  final double? logoHeight;

  // Divider-specific
  final double? dividerThickness;
  final int? dividerColorValue;

  const ContentBlock({
    required this.id,
    required this.type,
    this.text,
    this.variable,
    this.fontSize = 10,
    this.bold = false,
    this.italic = false,
    this.uppercase = false,
    this.alignment = TextAlignment.left,
    this.colorValue,
    this.fontFamily,
    this.spacingAfter = 2,
    this.logoWidth,
    this.logoHeight,
    this.dividerThickness,
    this.dividerColorValue,
  });

  /// Create a text block with a dynamic variable.
  factory ContentBlock.variable({
    required PdfVariable variable,
    String? customText,
    double fontSize = 10,
    bool bold = false,
    bool italic = false,
    bool uppercase = false,
    TextAlignment alignment = TextAlignment.left,
    int? colorValue,
    double spacingAfter = 2,
  }) =>
      ContentBlock(
        id: const Uuid().v4(),
        type: ContentBlockType.text,
        variable: variable,
        text: customText,
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        uppercase: uppercase,
        alignment: alignment,
        colorValue: colorValue,
        spacingAfter: spacingAfter,
      );

  /// Create a plain text block with custom content.
  factory ContentBlock.text({
    required String text,
    double fontSize = 10,
    bool bold = false,
    bool italic = false,
    bool uppercase = false,
    TextAlignment alignment = TextAlignment.left,
    int? colorValue,
    double spacingAfter = 2,
  }) =>
      ContentBlock(
        id: const Uuid().v4(),
        type: ContentBlockType.text,
        text: text,
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        uppercase: uppercase,
        alignment: alignment,
        colorValue: colorValue,
        spacingAfter: spacingAfter,
      );

  /// Create a logo placeholder block.
  factory ContentBlock.logo({
    double? width,
    double? height,
    double spacingAfter = 4,
  }) =>
      ContentBlock(
        id: const Uuid().v4(),
        type: ContentBlockType.logo,
        logoWidth: width,
        logoHeight: height,
        spacingAfter: spacingAfter,
      );

  /// Create a horizontal divider block.
  factory ContentBlock.divider({
    double thickness = 1,
    int? colorValue,
    double spacingAfter = 4,
  }) =>
      ContentBlock(
        id: const Uuid().v4(),
        type: ContentBlockType.divider,
        dividerThickness: thickness,
        dividerColorValue: colorValue,
        spacingAfter: spacingAfter,
      );

  /// Create a vertical spacer block.
  factory ContentBlock.spacer({double height = 8}) => ContentBlock(
        id: const Uuid().v4(),
        type: ContentBlockType.spacer,
        spacingAfter: height,
      );

  /// The resolved display text for this block, using the variable token
  /// or custom text as appropriate.
  String get displayText {
    if (variable != null && variable != PdfVariable.custom) {
      return text?.isNotEmpty == true ? text! : variable!.token;
    }
    return text ?? '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        if (text != null) 'text': text,
        if (variable != null) 'variable': variable!.name,
        'fontSize': fontSize,
        'bold': bold,
        'italic': italic,
        'uppercase': uppercase,
        'alignment': alignment.name,
        if (colorValue != null) 'colorValue': colorValue,
        if (fontFamily != null) 'fontFamily': fontFamily,
        'spacingAfter': spacingAfter,
        if (logoWidth != null) 'logoWidth': logoWidth,
        if (logoHeight != null) 'logoHeight': logoHeight,
        if (dividerThickness != null) 'dividerThickness': dividerThickness,
        if (dividerColorValue != null) 'dividerColorValue': dividerColorValue,
      };

  factory ContentBlock.fromJson(Map<String, dynamic> json) => ContentBlock(
        id: json['id'] as String? ?? const Uuid().v4(),
        type: ContentBlockType.fromName(json['type'] as String? ?? 'text'),
        text: json['text'] as String?,
        variable: json['variable'] != null
            ? PdfVariable.values.firstWhere(
                (e) => e.name == json['variable'],
                orElse: () => PdfVariable.custom,
              )
            : null,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 10,
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        uppercase: json['uppercase'] as bool? ?? false,
        alignment:
            TextAlignment.fromName(json['alignment'] as String? ?? 'left'),
        colorValue: json['colorValue'] as int?,
        fontFamily: json['fontFamily'] as String?,
        spacingAfter: (json['spacingAfter'] as num?)?.toDouble() ?? 2,
        logoWidth: (json['logoWidth'] as num?)?.toDouble(),
        logoHeight: (json['logoHeight'] as num?)?.toDouble(),
        dividerThickness: (json['dividerThickness'] as num?)?.toDouble(),
        dividerColorValue: json['dividerColorValue'] as int?,
      );

  String toJsonString() => jsonEncode(toJson());

  factory ContentBlock.fromJsonString(String jsonString) =>
      ContentBlock.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  ContentBlock copyWith({
    String? id,
    ContentBlockType? type,
    String? text,
    PdfVariable? variable,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? uppercase,
    TextAlignment? alignment,
    int? colorValue,
    bool clearColorValue = false,
    String? fontFamily,
    bool clearFontFamily = false,
    double? spacingAfter,
    double? logoWidth,
    double? logoHeight,
    double? dividerThickness,
    int? dividerColorValue,
    bool clearDividerColorValue = false,
  }) =>
      ContentBlock(
        id: id ?? this.id,
        type: type ?? this.type,
        text: text ?? this.text,
        variable: variable ?? this.variable,
        fontSize: fontSize ?? this.fontSize,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        uppercase: uppercase ?? this.uppercase,
        alignment: alignment ?? this.alignment,
        colorValue: clearColorValue ? null : (colorValue ?? this.colorValue),
        fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
        spacingAfter: spacingAfter ?? this.spacingAfter,
        logoWidth: logoWidth ?? this.logoWidth,
        logoHeight: logoHeight ?? this.logoHeight,
        dividerThickness: dividerThickness ?? this.dividerThickness,
        dividerColorValue: clearDividerColorValue
            ? null
            : (dividerColorValue ?? this.dividerColorValue),
      );
}
