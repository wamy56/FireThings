/// Enum defining all possible field types in a template
enum FieldType { text, number, dropdown, checkbox, date, multiline }

/// Extension to convert FieldType to/from string for JSON serialization
extension FieldTypeExtension on FieldType {
  String toJson() {
    return toString().split('.').last;
  }

  static FieldType fromJson(String value) {
    return FieldType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => FieldType.text,
    );
  }
}
