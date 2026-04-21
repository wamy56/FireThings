import 'dart:convert';
import '../utils/json_helpers.dart';

/// Enum for different PDF form field types
enum FormFieldDefinitionType {
  text,
  multilineText,
  checkbox,
  radioGroup,
  dropdown,
  datePicker,
  signature,
  image,
}

/// Represents a single form field in a PDF template
class FormFieldDefinition {
  final String id;
  final String label;
  final FormFieldDefinitionType type;
  final double x; // X position as percentage of page width (0-100)
  final double y; // Y position as percentage of page height (0-100)
  final double width; // Width as percentage of page width
  final double height; // Height as percentage of page height
  final int page; // Page number (0-indexed)
  final bool required;
  final String? defaultValue;
  final List<String>? options; // For dropdown and radio groups
  final String? groupName; // For radio buttons to group them
  final double? fontSize; // Optional font size for text fields

  FormFieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.page = 0,
    this.required = false,
    this.defaultValue,
    this.options,
    this.groupName,
    this.fontSize,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'page': page,
    'required': required,
    'defaultValue': defaultValue,
    'options': options,
    'groupName': groupName,
    'fontSize': fontSize,
  };

  factory FormFieldDefinition.fromJson(Map<String, dynamic> json) => FormFieldDefinition(
    id: json['id'] as String,
    label: json['label'] as String,
    type: FormFieldDefinitionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FormFieldDefinitionType.text,
    ),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    page: json['page'] as int? ?? 0,
    required: json['required'] as bool? ?? false,
    defaultValue: json['defaultValue'] as String?,
    options: (json['options'] as List<dynamic>?)?.cast<String>(),
    groupName: json['groupName'] as String?,
    fontSize: (json['fontSize'] as num?)?.toDouble(),
  );

  FormFieldDefinition copyWith({
    String? id,
    String? label,
    FormFieldDefinitionType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    int? page,
    bool? required,
    String? defaultValue,
    List<String>? options,
    String? groupName,
    double? fontSize,
  }) => FormFieldDefinition(
    id: id ?? this.id,
    label: label ?? this.label,
    type: type ?? this.type,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    page: page ?? this.page,
    required: required ?? this.required,
    defaultValue: defaultValue ?? this.defaultValue,
    options: options ?? this.options,
    groupName: groupName ?? this.groupName,
    fontSize: fontSize ?? this.fontSize,
  );
}

/// Represents a PDF form template with its PDF and form fields
class PdfFormTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final String pdfPath; // Asset path for bundled, file path for user-uploaded
  final bool isBundled; // True if pre-bundled, false if user-uploaded
  final List<FormFieldDefinition> fields;
  final int pageCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PdfFormTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.pdfPath,
    required this.isBundled,
    required this.fields,
    this.pageCount = 1,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'pdfPath': pdfPath,
    'isBundled': isBundled,
    'fields': jsonEncode(fields.map((f) => f.toJson()).toList()),
    'pageCount': pageCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory PdfFormTemplate.fromJson(Map<String, dynamic> json) {
    List<FormFieldDefinition> fieldsList = [];

    if (json['fields'] != null) {
      final fieldsData = json['fields'] is String
          ? jsonDecode(json['fields']) as List<dynamic>
          : json['fields'] as List<dynamic>;
      fieldsList = fieldsData
          .map((f) => FormFieldDefinition.fromJson(f as Map<String, dynamic>))
          .toList();
    }

    return PdfFormTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      pdfPath: json['pdfPath'] as String,
      isBundled: json['isBundled'] as bool? ?? false,
      fields: fieldsList,
      pageCount: json['pageCount'] as int? ?? 1,
      createdAt: jsonDateRequired(json['createdAt']),
      updatedAt: jsonDateOptional(json['updatedAt']),
    );
  }

  PdfFormTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? pdfPath,
    bool? isBundled,
    List<FormFieldDefinition>? fields,
    int? pageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PdfFormTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    category: category ?? this.category,
    pdfPath: pdfPath ?? this.pdfPath,
    isBundled: isBundled ?? this.isBundled,
    fields: fields ?? this.fields,
    pageCount: pageCount ?? this.pageCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Represents a filled PDF form (user's data for a template)
class FilledPdfForm {
  final String id;
  final String templateId;
  final String engineerId;
  final String engineerName;
  final String jobReference;
  final Map<String, dynamic> fieldValues; // fieldId -> value
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isComplete;
  final DateTime? lastModifiedAt;

  FilledPdfForm({
    required this.id,
    required this.templateId,
    required this.engineerId,
    required this.engineerName,
    required this.jobReference,
    required this.fieldValues,
    required this.createdAt,
    this.completedAt,
    this.isComplete = false,
    this.lastModifiedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'templateId': templateId,
    'engineerId': engineerId,
    'engineerName': engineerName,
    'jobReference': jobReference,
    'fieldValues': jsonEncode(fieldValues),
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'isComplete': isComplete ? 1 : 0,
    'lastModifiedAt': lastModifiedAt?.toIso8601String(),
  };

  factory FilledPdfForm.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> values = {};

    if (json['fieldValues'] != null) {
      values = json['fieldValues'] is String
          ? jsonDecode(json['fieldValues']) as Map<String, dynamic>
          : json['fieldValues'] as Map<String, dynamic>;
    }

    return FilledPdfForm(
      id: json['id'] as String,
      templateId: json['templateId'] as String,
      engineerId: json['engineerId'] as String,
      engineerName: json['engineerName'] as String? ?? '',
      jobReference: json['jobReference'] as String? ?? '',
      fieldValues: values,
      createdAt: jsonDateRequired(json['createdAt']),
      completedAt: jsonDateOptional(json['completedAt']),
      isComplete: json['isComplete'] == 1 || json['isComplete'] == true,
      lastModifiedAt: jsonDateOptional(json['lastModifiedAt']),
    );
  }

  FilledPdfForm copyWith({
    String? id,
    String? templateId,
    String? engineerId,
    String? engineerName,
    String? jobReference,
    Map<String, dynamic>? fieldValues,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isComplete,
    DateTime? lastModifiedAt,
  }) => FilledPdfForm(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    engineerId: engineerId ?? this.engineerId,
    engineerName: engineerName ?? this.engineerName,
    jobReference: jobReference ?? this.jobReference,
    fieldValues: fieldValues ?? this.fieldValues,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt ?? this.completedAt,
    isComplete: isComplete ?? this.isComplete,
    lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
  );
}
