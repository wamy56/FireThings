/// Defines a type of fire safety asset with its properties.
class AssetType {
  final String id;
  final String name;
  final String? category;
  final String iconName;
  final String defaultColor; // hex colour for pins
  final List<String> variants;
  final int? defaultLifespanYears;
  final List<String> commonFaults;
  final bool isBuiltIn;

  AssetType({
    required this.id,
    required this.name,
    this.category,
    required this.iconName,
    required this.defaultColor,
    this.variants = const [],
    this.defaultLifespanYears,
    this.commonFaults = const [],
    this.isBuiltIn = false,
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
      'commonFaults': commonFaults,
      'isBuiltIn': isBuiltIn,
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
      commonFaults: (json['commonFaults'] as List<dynamic>?)
              ?.map((f) => f as String)
              .toList() ??
          [],
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
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
    List<String>? commonFaults,
    bool? isBuiltIn,
  }) {
    return AssetType(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      defaultColor: defaultColor ?? this.defaultColor,
      variants: variants ?? this.variants,
      defaultLifespanYears: defaultLifespanYears ?? this.defaultLifespanYears,
      commonFaults: commonFaults ?? this.commonFaults,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  String toString() => 'AssetType(id: $id, name: $name, category: $category)';
}
