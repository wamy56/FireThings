import 'field_types.dart';

/// Represents a single field in a job template
class TemplateField {
  final String id;
  final String label;
  final FieldType type;
  final bool required;
  final List<String>? options; // For dropdown fields
  final String? defaultValue;

  TemplateField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options,
    this.defaultValue,
  });

  /// Convert TemplateField to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.toJson(),
      'required': required,
      'options': options,
      'defaultValue': defaultValue,
    };
  }

  /// Create TemplateField from JSON map
  factory TemplateField.fromJson(Map<String, dynamic> json) {
    return TemplateField(
      id: json['id'] as String,
      label: json['label'] as String,
      type: FieldTypeExtension.fromJson(json['type'] as String),
      required: json['required'] as bool? ?? false,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      defaultValue: json['defaultValue'] as String?,
    );
  }

  /// Create a copy of this field with some values changed
  TemplateField copyWith({
    String? id,
    String? label,
    FieldType? type,
    bool? required,
    List<String>? options,
    String? defaultValue,
  }) {
    return TemplateField(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? this.options,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  @override
  String toString() {
    return 'TemplateField(id: $id, label: $label, type: $type, required: $required)';
  }
}
