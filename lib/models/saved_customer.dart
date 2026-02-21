/// Represents a saved customer for quick invoice creation
class SavedCustomer {
  final String id;
  final String engineerId;
  final String customerName;
  final String customerAddress;
  final String? email;
  final String? notes;
  final DateTime createdAt;

  SavedCustomer({
    required this.id,
    required this.engineerId,
    required this.customerName,
    required this.customerAddress,
    this.email,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'engineerId': engineerId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'email': email,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedCustomer.fromJson(Map<String, dynamic> json) {
    return SavedCustomer(
      id: json['id'] as String,
      engineerId: json['engineerId'] as String,
      customerName: json['customerName'] as String,
      customerAddress: json['customerAddress'] as String,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  SavedCustomer copyWith({
    String? id,
    String? engineerId,
    String? customerName,
    String? customerAddress,
    String? email,
    String? notes,
    DateTime? createdAt,
  }) {
    return SavedCustomer(
      id: id ?? this.id,
      engineerId: engineerId ?? this.engineerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
