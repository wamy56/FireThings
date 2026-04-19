/// Represents a line item on an invoice
class InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }
}

/// Invoice status
enum InvoiceStatus { draft, sent, paid }

/// Represents an invoice
class Invoice {
  final String id;
  final String invoiceNumber;
  final String engineerId;
  final String engineerName;
  final String? companyId;
  final String customerName;
  final String customerAddress;
  final String? customerEmail;
  final DateTime date;
  final DateTime dueDate;
  final List<InvoiceItem> items;
  final String? notes;
  final bool includeVat;
  final InvoiceStatus status;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final bool useCompanyBranding;
  final String? linkedJobsheetId;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.engineerId,
    required this.engineerName,
    this.companyId,
    required this.customerName,
    required this.customerAddress,
    this.customerEmail,
    required this.date,
    required this.dueDate,
    required this.items,
    this.notes,
    this.includeVat = false,
    this.status = InvoiceStatus.draft,
    required this.createdAt,
    this.lastModifiedAt,
    this.useCompanyBranding = false,
    this.linkedJobsheetId,
  });

  double get subtotal => items.fold(0, (acc, item) => acc + item.total);
  double get tax => includeVat ? subtotal * 0.20 : 0.0;
  double get total => subtotal + tax;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'engineerId': engineerId,
      'engineerName': engineerName,
      'companyId': companyId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerEmail': customerEmail,
      'date': date.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'notes': notes,
      'includeVat': includeVat,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'useCompanyBranding': useCompanyBranding ? 1 : 0,
      'linkedJobsheetId': linkedJobsheetId,
    };
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      engineerId: json['engineerId'] as String,
      engineerName: json['engineerName'] as String? ?? '',
      companyId: json['companyId'] as String?,
      customerName: json['customerName'] as String,
      customerAddress: json['customerAddress'] as String,
      customerEmail: json['customerEmail'] as String?,
      date: DateTime.parse(json['date'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      items: (json['items'] as List)
          .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      includeVat: json['includeVat'] as bool? ?? false,
      status: InvoiceStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
      useCompanyBranding: json['useCompanyBranding'] == 1 || json['useCompanyBranding'] == true,
      linkedJobsheetId: json['linkedJobsheetId'] as String?,
    );
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? engineerId,
    String? engineerName,
    String? companyId,
    String? customerName,
    String? customerAddress,
    String? customerEmail,
    DateTime? date,
    DateTime? dueDate,
    List<InvoiceItem>? items,
    String? notes,
    bool? includeVat,
    InvoiceStatus? status,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    bool? useCompanyBranding,
    String? linkedJobsheetId,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      engineerId: engineerId ?? this.engineerId,
      engineerName: engineerName ?? this.engineerName,
      companyId: companyId ?? this.companyId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerEmail: customerEmail ?? this.customerEmail,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      includeVat: includeVat ?? this.includeVat,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      useCompanyBranding: useCompanyBranding ?? this.useCompanyBranding,
      linkedJobsheetId: linkedJobsheetId ?? this.linkedJobsheetId,
    );
  }
}
