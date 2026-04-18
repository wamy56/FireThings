/// Status lifecycle for quotes
enum QuoteStatus { draft, sent, approved, declined, converted }

/// Represents a line item on a quote
class QuoteItem {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final String? category; // labour, parts, materials

  QuoteItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.category,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'category': category,
    };
  }

  factory QuoteItem.fromJson(Map<String, dynamic> json) {
    return QuoteItem(
      id: json['id'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      category: json['category'] as String?,
    );
  }

  QuoteItem copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
    String? category,
  }) {
    return QuoteItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      category: category ?? this.category,
    );
  }
}

/// Represents a quote, optionally linked to a defect
class Quote {
  final String id;
  final String quoteNumber;
  final String engineerId;
  final String engineerName;
  final String? companyId;

  // Customer
  final String customerName;
  final String customerAddress;
  final String? customerEmail;
  final String? customerPhone;

  // Site
  final String siteId;
  final String siteName;

  // Source defect
  final String? defectId;
  final String? defectDescription;
  final String? defectSeverity;

  // Quote content
  final List<QuoteItem> items;
  final String? notes;
  final bool includeVat;

  // Status & dates
  final QuoteStatus status;
  final DateTime validUntil;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final DateTime? sentAt;
  final DateTime? respondedAt;

  // Conversion
  final String? convertedJobId;
  final bool useCompanyBranding;

  Quote({
    required this.id,
    required this.quoteNumber,
    required this.engineerId,
    required this.engineerName,
    this.companyId,
    required this.customerName,
    required this.customerAddress,
    this.customerEmail,
    this.customerPhone,
    required this.siteId,
    required this.siteName,
    this.defectId,
    this.defectDescription,
    this.defectSeverity,
    required this.items,
    this.notes,
    this.includeVat = false,
    this.status = QuoteStatus.draft,
    required this.validUntil,
    required this.createdAt,
    this.lastModifiedAt,
    this.sentAt,
    this.respondedAt,
    this.convertedJobId,
    this.useCompanyBranding = false,
  });

  double get subtotal => items.fold(0, (acc, item) => acc + item.total);
  double get vatAmount => includeVat ? subtotal * 0.20 : 0;
  double get total => subtotal + vatAmount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quoteNumber': quoteNumber,
      'engineerId': engineerId,
      'engineerName': engineerName,
      'companyId': companyId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'siteId': siteId,
      'siteName': siteName,
      'defectId': defectId,
      'defectDescription': defectDescription,
      'defectSeverity': defectSeverity,
      'items': items.map((item) => item.toJson()).toList(),
      'notes': notes,
      'includeVat': includeVat,
      'status': status.name,
      'validUntil': validUntil.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'convertedJobId': convertedJobId,
      'useCompanyBranding': useCompanyBranding ? 1 : 0,
    };
  }

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      quoteNumber: json['quoteNumber'] as String,
      engineerId: json['engineerId'] as String,
      engineerName: json['engineerName'] as String? ?? '',
      companyId: json['companyId'] as String?,
      customerName: json['customerName'] as String,
      customerAddress: json['customerAddress'] as String,
      customerEmail: json['customerEmail'] as String?,
      customerPhone: json['customerPhone'] as String?,
      siteId: json['siteId'] as String,
      siteName: json['siteName'] as String,
      defectId: json['defectId'] as String?,
      defectDescription: json['defectDescription'] as String?,
      defectSeverity: json['defectSeverity'] as String?,
      items: (json['items'] as List)
          .map((item) => QuoteItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      includeVat: json['includeVat'] == 1 || json['includeVat'] == true,
      status: QuoteStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QuoteStatus.draft,
      ),
      validUntil: DateTime.parse(json['validUntil'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'] as String)
          : null,
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'] as String)
          : null,
      convertedJobId: json['convertedJobId'] as String?,
      useCompanyBranding:
          json['useCompanyBranding'] == 1 || json['useCompanyBranding'] == true,
    );
  }

  Quote copyWith({
    String? id,
    String? quoteNumber,
    String? engineerId,
    String? engineerName,
    String? companyId,
    String? customerName,
    String? customerAddress,
    String? customerEmail,
    String? customerPhone,
    String? siteId,
    String? siteName,
    String? defectId,
    String? defectDescription,
    String? defectSeverity,
    List<QuoteItem>? items,
    String? notes,
    bool? includeVat,
    QuoteStatus? status,
    DateTime? validUntil,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    DateTime? sentAt,
    DateTime? respondedAt,
    String? convertedJobId,
    bool? useCompanyBranding,
  }) {
    return Quote(
      id: id ?? this.id,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      engineerId: engineerId ?? this.engineerId,
      engineerName: engineerName ?? this.engineerName,
      companyId: companyId ?? this.companyId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      defectId: defectId ?? this.defectId,
      defectDescription: defectDescription ?? this.defectDescription,
      defectSeverity: defectSeverity ?? this.defectSeverity,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      includeVat: includeVat ?? this.includeVat,
      status: status ?? this.status,
      validUntil: validUntil ?? this.validUntil,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      sentAt: sentAt ?? this.sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      convertedJobId: convertedJobId ?? this.convertedJobId,
      useCompanyBranding: useCompanyBranding ?? this.useCompanyBranding,
    );
  }
}
