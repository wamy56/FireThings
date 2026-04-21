/// Defines a type of fire safety asset with its properties.
class AssetType {
  final String id;
  final String name;
  final String? category;
  final String iconName;
  final String defaultColor; // hex colour for pins
  final List<String> variants;
  final int? defaultLifespanYears;
  final int? defaultServiceIntervalMonths;
  final List<String> commonFaults;
  final bool isBuiltIn;
  final int checklistVersion;

  AssetType({
    required this.id,
    required this.name,
    this.category,
    required this.iconName,
    required this.defaultColor,
    this.variants = const [],
    this.defaultLifespanYears,
    this.defaultServiceIntervalMonths,
    this.commonFaults = const [],
    this.isBuiltIn = false,
    this.checklistVersion = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'iconName': iconName,
      'defaultColor': defaultColor,
      'variants': variants,
      'defaultLifespanYears': defaultLifespanYears,
      'defaultServiceIntervalMonths': defaultServiceIntervalMonths,
      'commonFaults': commonFaults,
      'isBuiltIn': isBuiltIn,
      'checklistVersion': checklistVersion,
    };
  }

  factory AssetType.fromJson(Map<String, dynamic> json) {
    return AssetType(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      iconName: json['iconName'] as String,
      defaultColor: json['defaultColor'] as String,
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => v as String)
              .toList() ??
          [],
      defaultLifespanYears: json['defaultLifespanYears'] as int?,
      defaultServiceIntervalMonths: json['defaultServiceIntervalMonths'] as int?,
      commonFaults: (json['commonFaults'] as List<dynamic>?)
              ?.map((f) => f as String)
              .toList() ??
          [],
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      checklistVersion: json['checklistVersion'] as int? ?? 1,
    );
  }

  AssetType copyWith({
    String? id,
    String? name,
    String? category,
    String? iconName,
    String? defaultColor,
    List<String>? variants,
    int? defaultLifespanYears,
    int? defaultServiceIntervalMonths,
    List<String>? commonFaults,
    bool? isBuiltIn,
    int? checklistVersion,
  }) {
    return AssetType(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      defaultColor: defaultColor ?? this.defaultColor,
      variants: variants ?? this.variants,
      defaultLifespanYears: defaultLifespanYears ?? this.defaultLifespanYears,
      defaultServiceIntervalMonths: defaultServiceIntervalMonths ?? this.defaultServiceIntervalMonths,
      commonFaults: commonFaults ?? this.commonFaults,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      checklistVersion: checklistVersion ?? this.checklistVersion,
    );
  }

  @override
  String toString() => 'AssetType(id: $id, name: $name, category: $category)';
}
