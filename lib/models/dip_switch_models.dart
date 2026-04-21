import '../utils/json_helpers.dart';

// ============================================================================
// DIP SWITCH MODELS
// ============================================================================

class DipSwitchConfiguration {
  final String manufacturer;
  final String panelType;
  final String description;
  final int switchCount;
  final List<String> switchLabels;
  final String calculationType; // 'address', 'zone', 'combined'
  final Map<String, dynamic> calculationRules;
  final String notes;

  DipSwitchConfiguration({
    required this.manufacturer,
    required this.panelType,
    required this.description,
    required this.switchCount,
    required this.switchLabels,
    required this.calculationType,
    required this.calculationRules,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'manufacturer': manufacturer,
      'panelType': panelType,
      'description': description,
      'switchCount': switchCount,
      'switchLabels': switchLabels,
      'calculationType': calculationType,
      'calculationRules': calculationRules,
      'notes': notes,
    };
  }

  factory DipSwitchConfiguration.fromJson(Map<String, dynamic> json) {
    return DipSwitchConfiguration(
      manufacturer: json['manufacturer'],
      panelType: json['panelType'],
      description: json['description'],
      switchCount: json['switchCount'],
      switchLabels: List<String>.from(json['switchLabels']),
      calculationType: json['calculationType'],
      calculationRules: Map<String, dynamic>.from(json['calculationRules']),
      notes: json['notes'] ?? '',
    );
  }
}

// ============================================================================
// SAVED DIP CONFIGURATION
// ============================================================================

class SavedDipConfiguration {
  final String id;
  final String name;
  final String manufacturer;
  final String panelType;
  final List<bool> switchStates;
  final int address;
  final String zone;
  final DateTime dateCreated;

  SavedDipConfiguration({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.panelType,
    required this.switchStates,
    required this.address,
    required this.zone,
    required this.dateCreated,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'manufacturer': manufacturer,
      'panelType': panelType,
      'switchStates': switchStates.map((s) => s ? 1 : 0).toList(),
      'address': address,
      'zone': zone,
      'dateCreated': dateCreated.toIso8601String(),
    };
  }

  factory SavedDipConfiguration.fromJson(Map<String, dynamic> json) {
    return SavedDipConfiguration(
      id: json['id'],
      name: json['name'],
      manufacturer: json['manufacturer'],
      panelType: json['panelType'],
      switchStates: (json['switchStates'] as List).map((s) => s == 1).toList(),
      address: json['address'],
      zone: json['zone'] ?? '',
      dateCreated: jsonDateRequired(json['dateCreated']),
    );
  }
}
