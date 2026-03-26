/// The result of a single checklist item during an inspection.
class ChecklistResult {
  final String checklistItemId;
  final String label;
  final String result; // "pass", "fail", "n/a" or text/number value
  final String? note;

  ChecklistResult({
    required this.checklistItemId,
    required this.label,
    required this.result,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'checklistItemId': checklistItemId,
      'label': label,
      'result': result,
      'note': note,
    };
  }

  factory ChecklistResult.fromJson(Map<String, dynamic> json) {
    return ChecklistResult(
      checklistItemId: json['checklistItemId'] as String,
      label: json['label'] as String,
      result: json['result'] as String,
      note: json['note'] as String?,
    );
  }

  @override
  String toString() => 'ChecklistResult($label: $result)';
}

/// An immutable record of an asset inspection/service visit.
class ServiceRecord {
  final String id;
  final String assetId;
  final String siteId;
  final String? jobsheetId;
  final String? dispatchedJobId;
  final String engineerId;
  final String engineerName;
  final DateTime serviceDate;
  final String overallResult; // "pass", "fail"
  final List<ChecklistResult> checklistResults;
  final String? defectNote;
  final List<String> defectPhotoUrls;
  final String? defectSeverity; // "minor", "major", "critical"
  final String? defectAction; // "rectified_on_site", "quote_required", "replacement_needed"
  final String? notes;
  final DateTime createdAt;

  ServiceRecord({
    required this.id,
    required this.assetId,
    required this.siteId,
    this.jobsheetId,
    this.dispatchedJobId,
    required this.engineerId,
    required this.engineerName,
    required this.serviceDate,
    required this.overallResult,
    this.checklistResults = const [],
    this.defectNote,
    this.defectPhotoUrls = const [],
    this.defectSeverity,
    this.defectAction,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetId': assetId,
      'siteId': siteId,
      'jobsheetId': jobsheetId,
      'dispatchedJobId': dispatchedJobId,
      'engineerId': engineerId,
      'engineerName': engineerName,
      'serviceDate': serviceDate.toIso8601String(),
      'overallResult': overallResult,
      'checklistResults':
          checklistResults.map((r) => r.toJson()).toList(),
      'defectNote': defectNote,
      'defectPhotoUrls': defectPhotoUrls,
      'defectSeverity': defectSeverity,
      'defectAction': defectAction,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ServiceRecord.fromJson(Map<String, dynamic> json) {
    return ServiceRecord(
      id: json['id'] as String,
      assetId: json['assetId'] as String,
      siteId: json['siteId'] as String,
      jobsheetId: json['jobsheetId'] as String?,
      dispatchedJobId: json['dispatchedJobId'] as String?,
      engineerId: json['engineerId'] as String,
      engineerName: json['engineerName'] as String,
      serviceDate: DateTime.parse(json['serviceDate'] as String),
      overallResult: json['overallResult'] as String,
      checklistResults: (json['checklistResults'] as List<dynamic>?)
              ?.map((r) =>
                  ChecklistResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      defectNote: json['defectNote'] as String?,
      defectPhotoUrls: (json['defectPhotoUrls'] as List<dynamic>?)
              ?.map((u) => u as String)
              .toList() ??
          [],
      defectSeverity: json['defectSeverity'] as String?,
      defectAction: json['defectAction'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  String toString() =>
      'ServiceRecord(id: $id, assetId: $assetId, result: $overallResult)';
}
