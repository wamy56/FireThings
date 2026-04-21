import 'dart:convert';

import '../utils/json_helpers.dart';

enum VariationStatus {
  active,
  rectified,
  supersededByModification;

  String get displayLabel {
    switch (this) {
      case VariationStatus.active:
        return 'Active';
      case VariationStatus.rectified:
        return 'Rectified';
      case VariationStatus.supersededByModification:
        return 'Superseded by Modification';
    }
  }

  static VariationStatus fromString(String? value) {
    if (value == null) return VariationStatus.active;
    for (final s in VariationStatus.values) {
      if (s.name == value) return s;
    }
    return VariationStatus.active;
  }
}

class Bs5839Variation {
  final String id;
  final String siteId;
  final String clauseReference;
  final String description;
  final String justification;
  final bool isProhibited;
  final String? prohibitedRuleId;
  final VariationStatus status;
  final String? agreedByName;
  final String? agreedByRole;
  final DateTime? dateAgreed;
  final String? loggedByEngineerId;
  final String? loggedByEngineerName;
  final DateTime loggedAt;
  final DateTime? rectifiedAt;
  final String? rectifiedByVisitId;
  final List<String> evidencePhotoUrls;

  Bs5839Variation({
    required this.id,
    required this.siteId,
    required this.clauseReference,
    required this.description,
    required this.justification,
    this.isProhibited = false,
    this.prohibitedRuleId,
    this.status = VariationStatus.active,
    this.agreedByName,
    this.agreedByRole,
    this.dateAgreed,
    this.loggedByEngineerId,
    this.loggedByEngineerName,
    required this.loggedAt,
    this.rectifiedAt,
    this.rectifiedByVisitId,
    this.evidencePhotoUrls = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'clauseReference': clauseReference,
      'description': description,
      'justification': justification,
      'isProhibited': isProhibited,
      'prohibitedRuleId': prohibitedRuleId,
      'status': status.name,
      'agreedByName': agreedByName,
      'agreedByRole': agreedByRole,
      'dateAgreed': dateAgreed?.toIso8601String(),
      'loggedByEngineerId': loggedByEngineerId,
      'loggedByEngineerName': loggedByEngineerName,
      'loggedAt': loggedAt.toIso8601String(),
      'rectifiedAt': rectifiedAt?.toIso8601String(),
      'rectifiedByVisitId': rectifiedByVisitId,
      'evidencePhotoUrls': evidencePhotoUrls,
    };
  }

  factory Bs5839Variation.fromJson(Map<String, dynamic> json) {
    return Bs5839Variation(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      clauseReference: json['clauseReference'] as String? ?? '',
      description: json['description'] as String? ?? '',
      justification: json['justification'] as String? ?? '',
      isProhibited: json['isProhibited'] as bool? ?? false,
      prohibitedRuleId: json['prohibitedRuleId'] as String?,
      status: VariationStatus.fromString(json['status'] as String?),
      agreedByName: json['agreedByName'] as String?,
      agreedByRole: json['agreedByRole'] as String?,
      dateAgreed: jsonDateOptional(json['dateAgreed']),
      loggedByEngineerId: json['loggedByEngineerId'] as String?,
      loggedByEngineerName: json['loggedByEngineerName'] as String?,
      loggedAt: jsonDateRequired(json['loggedAt']),
      rectifiedAt: jsonDateOptional(json['rectifiedAt']),
      rectifiedByVisitId: json['rectifiedByVisitId'] as String?,
      evidencePhotoUrls: _parsePhotoUrls(json['evidencePhotoUrls']),
    );
  }

  static List<String> _parsePhotoUrls(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      try {
        return List<String>.from(jsonDecode(value) as List);
      } catch (_) {
        return const [];
      }
    }
    if (value is List) return value.map((e) => e as String).toList();
    return const [];
  }

  Bs5839Variation copyWith({
    String? id,
    String? siteId,
    String? clauseReference,
    String? description,
    String? justification,
    bool? isProhibited,
    String? prohibitedRuleId,
    VariationStatus? status,
    String? agreedByName,
    String? agreedByRole,
    DateTime? dateAgreed,
    String? loggedByEngineerId,
    String? loggedByEngineerName,
    DateTime? loggedAt,
    DateTime? rectifiedAt,
    String? rectifiedByVisitId,
    List<String>? evidencePhotoUrls,
  }) {
    return Bs5839Variation(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      clauseReference: clauseReference ?? this.clauseReference,
      description: description ?? this.description,
      justification: justification ?? this.justification,
      isProhibited: isProhibited ?? this.isProhibited,
      prohibitedRuleId: prohibitedRuleId ?? this.prohibitedRuleId,
      status: status ?? this.status,
      agreedByName: agreedByName ?? this.agreedByName,
      agreedByRole: agreedByRole ?? this.agreedByRole,
      dateAgreed: dateAgreed ?? this.dateAgreed,
      loggedByEngineerId: loggedByEngineerId ?? this.loggedByEngineerId,
      loggedByEngineerName:
          loggedByEngineerName ?? this.loggedByEngineerName,
      loggedAt: loggedAt ?? this.loggedAt,
      rectifiedAt: rectifiedAt ?? this.rectifiedAt,
      rectifiedByVisitId: rectifiedByVisitId ?? this.rectifiedByVisitId,
      evidencePhotoUrls: evidencePhotoUrls ?? this.evidencePhotoUrls,
    );
  }
}
