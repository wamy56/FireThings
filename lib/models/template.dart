import 'template_field.dart';
import 'pdf_section_layout_config.dart';

/// Represents a complete job template with all its fields
class JobTemplate {
  final String id;
  final String name;
  final String description;
  final List<TemplateField> fields;
  final bool isShared; // Whether this template is shared with other engineers
  final String? creatorId; // Engineer who created this template
  final DateTime? createdAt;
  final PdfSectionLayoutConfig? sectionLayout; // null = default layout

  JobTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    this.isShared = false,
    this.creatorId,
    this.createdAt,
    this.sectionLayout,
  });

  /// Convert JobTemplate to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'fields': fields.map((f) => f.toJson()).toList(),
      'isShared': isShared,
      'creatorId': creatorId,
      'createdAt': createdAt?.toIso8601String(),
      if (sectionLayout != null) 'sectionLayout': sectionLayout!.toJson(),
    };
  }

  /// Create JobTemplate from JSON map
  factory JobTemplate.fromJson(Map<String, dynamic> json) {
    return JobTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      fields: (json['fields'] as List)
          .map((f) => TemplateField.fromJson(f as Map<String, dynamic>))
          .toList(),
      isShared: json['isShared'] as bool? ?? false,
      creatorId: json['creatorId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      sectionLayout: json['sectionLayout'] != null
          ? PdfSectionLayoutConfig.fromJson(
              json['sectionLayout'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Create a copy of this template with some values changed
  JobTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<TemplateField>? fields,
    bool? isShared,
    String? creatorId,
    DateTime? createdAt,
    PdfSectionLayoutConfig? sectionLayout,
  }) {
    return JobTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      fields: fields ?? this.fields,
      isShared: isShared ?? this.isShared,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      sectionLayout: sectionLayout ?? this.sectionLayout,
    );
  }

  @override
  String toString() {
    return 'JobTemplate(id: $id, name: $name, fields: ${fields.length})';
  }
}
