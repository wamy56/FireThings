/// A single item in an asset inspection checklist.
class ChecklistItem {
  final String id;
  final String label;
  final String? description;
  final bool isRequired;
  final String resultType; // "pass_fail", "text", "number", "yes_no"

  ChecklistItem({
    required this.id,
    required this.label,
    this.description,
    this.isRequired = true,
    this.resultType = 'pass_fail',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'isRequired': isRequired,
      'resultType': resultType,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      isRequired: json['isRequired'] as bool? ?? true,
      resultType: json['resultType'] as String? ?? 'pass_fail',
    );
  }

  ChecklistItem copyWith({
    String? id,
    String? label,
    String? description,
    bool? isRequired,
    String? resultType,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      isRequired: isRequired ?? this.isRequired,
      resultType: resultType ?? this.resultType,
    );
  }

  @override
  String toString() => 'ChecklistItem(id: $id, label: $label, resultType: $resultType)';
}
