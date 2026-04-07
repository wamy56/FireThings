import 'dart:convert';
import 'pdf_section_layout_config.dart';

/// Status of a jobsheet
enum JobsheetStatus { draft, completed }

/// Represents a complete jobsheet with all data
class Jobsheet {
  final String id;
  final String engineerId;
  final String engineerName;
  final DateTime date;
  final String customerName;
  final String siteAddress;
  final String jobNumber;
  final String systemCategory;
  final String templateType; // Name of the template used
  final Map<String, dynamic> formData; // Dynamic fields based on template
  final Map<String, String> fieldLabels; // Maps fieldId -> fieldLabel for PDF
  final String? engineerSignature; // Base64 encoded image
  final String? customerSignature; // Base64 encoded image
  final String? customerSignatureName;
  final String notes;
  final List<String> defects;
  final DateTime createdAt;
  final JobsheetStatus status;
  final PdfSectionLayoutConfig? sectionLayout;
  final DateTime? lastModifiedAt;
  final String? dispatchedJobId;
  final String? siteId;
  final bool useCompanyBranding;

  Jobsheet({
    required this.id,
    required this.engineerId,
    required this.engineerName,
    required this.date,
    required this.customerName,
    required this.siteAddress,
    required this.jobNumber,
    required this.systemCategory,
    required this.templateType,
    required this.formData,
    this.fieldLabels = const {},
    this.engineerSignature,
    this.customerSignature,
    this.customerSignatureName,
    this.notes = '',
    this.defects = const [],
    required this.createdAt,
    this.status = JobsheetStatus.draft,
    this.sectionLayout,
    this.lastModifiedAt,
    this.dispatchedJobId,
    this.siteId,
    this.useCompanyBranding = false,
  });

  /// Convert Jobsheet to JSON map (for database storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'engineerId': engineerId,
      'engineerName': engineerName,
      'date': date.toIso8601String(),
      'customerName': customerName,
      'siteAddress': siteAddress,
      'jobNumber': jobNumber,
      'systemCategory': systemCategory,
      'templateType': templateType,
      'formData': jsonEncode(formData), // Convert map to JSON string
      'fieldLabels': jsonEncode(fieldLabels),
      'engineerSignature': engineerSignature,
      'customerSignature': customerSignature,
      'customerSignatureName': customerSignatureName,
      'notes': notes,
      'defects': jsonEncode(defects), // Convert list to JSON string
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'sectionLayout': sectionLayout?.toJsonString(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'dispatchedJobId': dispatchedJobId,
      'siteId': siteId,
      'useCompanyBranding': useCompanyBranding ? 1 : 0,
    };
  }

  /// Create Jobsheet from JSON map (from database)
  factory Jobsheet.fromJson(Map<String, dynamic> json) {
    return Jobsheet(
      id: json['id'] as String,
      engineerId: json['engineerId'] as String,
      engineerName: json['engineerName'] as String,
      date: DateTime.parse(json['date'] as String),
      customerName: json['customerName'] as String,
      siteAddress: json['siteAddress'] as String,
      jobNumber: json['jobNumber'] as String,
      systemCategory: json['systemCategory'] as String,
      templateType: json['templateType'] as String,
      formData: json['formData'] is String
          ? jsonDecode(json['formData'] as String) as Map<String, dynamic>
          : json['formData'] as Map<String, dynamic>,
      fieldLabels: json['fieldLabels'] != null
          ? Map<String, String>.from(
              json['fieldLabels'] is String
                  ? jsonDecode(json['fieldLabels'] as String) as Map
                  : json['fieldLabels'] as Map)
          : {},
      engineerSignature: json['engineerSignature'] as String?,
      customerSignature: json['customerSignature'] as String?,
      customerSignatureName: json['customerSignatureName'] as String?,
      notes: json['notes'] as String? ?? '',
      defects: json['defects'] is String
          ? List<String>.from(jsonDecode(json['defects'] as String) as List)
          : List<String>.from(json['defects'] as List? ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: JobsheetStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => JobsheetStatus.completed,
      ),
      sectionLayout: json['sectionLayout'] != null &&
              (json['sectionLayout'] as String).isNotEmpty
          ? PdfSectionLayoutConfig.fromJsonString(
              json['sectionLayout'] as String)
          : null,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
      dispatchedJobId: json['dispatchedJobId'] as String?,
      siteId: json['siteId'] as String?,
      useCompanyBranding: json['useCompanyBranding'] == 1 || json['useCompanyBranding'] == true,
    );
  }

  /// Create a copy of this jobsheet with some values changed
  Jobsheet copyWith({
    String? id,
    String? engineerId,
    String? engineerName,
    DateTime? date,
    String? customerName,
    String? siteAddress,
    String? jobNumber,
    String? systemCategory,
    String? templateType,
    Map<String, dynamic>? formData,
    Map<String, String>? fieldLabels,
    String? engineerSignature,
    String? customerSignature,
    String? customerSignatureName,
    String? notes,
    List<String>? defects,
    DateTime? createdAt,
    JobsheetStatus? status,
    PdfSectionLayoutConfig? sectionLayout,
    DateTime? lastModifiedAt,
    String? dispatchedJobId,
    String? siteId,
    bool? useCompanyBranding,
  }) {
    return Jobsheet(
      id: id ?? this.id,
      engineerId: engineerId ?? this.engineerId,
      engineerName: engineerName ?? this.engineerName,
      date: date ?? this.date,
      customerName: customerName ?? this.customerName,
      siteAddress: siteAddress ?? this.siteAddress,
      jobNumber: jobNumber ?? this.jobNumber,
      systemCategory: systemCategory ?? this.systemCategory,
      templateType: templateType ?? this.templateType,
      formData: formData ?? this.formData,
      fieldLabels: fieldLabels ?? this.fieldLabels,
      engineerSignature: engineerSignature ?? this.engineerSignature,
      customerSignature: customerSignature ?? this.customerSignature,
      customerSignatureName:
          customerSignatureName ?? this.customerSignatureName,
      notes: notes ?? this.notes,
      defects: defects ?? this.defects,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      sectionLayout: sectionLayout ?? this.sectionLayout,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      dispatchedJobId: dispatchedJobId ?? this.dispatchedJobId,
      siteId: siteId ?? this.siteId,
      useCompanyBranding: useCompanyBranding ?? this.useCompanyBranding,
    );
  }

  @override
  String toString() {
    return 'Jobsheet(id: $id, customer: $customerName, date: ${date.toIso8601String()})';
  }
}
