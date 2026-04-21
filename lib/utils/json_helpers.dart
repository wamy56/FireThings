import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? jsonDateOptional(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime jsonDateRequired(dynamic value, {DateTime? fallback}) {
  return jsonDateOptional(value) ?? fallback ?? DateTime.now();
}

String? jsonStringOptional(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}
