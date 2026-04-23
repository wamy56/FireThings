import 'dart:convert';

enum CoverStyle { bold, minimal, bordered }

enum HeaderStyle { solid, minimal, bordered }

enum FooterStyle { light, minimal, coloured }

enum BrandingDocType { report, quote, invoice, jobsheet }

class BrandingCoverText {
  final String? eyebrow;
  final String? title;
  final String? subtitle;

  const BrandingCoverText({this.eyebrow, this.title, this.subtitle});

  Map<String, dynamic> toJson() => {
        if (eyebrow != null) 'eyebrow': eyebrow,
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
      };

  factory BrandingCoverText.fromJson(Map<String, dynamic> json) =>
      BrandingCoverText(
        eyebrow: json['eyebrow'] as String?,
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
      );
}

class PdfBranding {
  final String? logoUrl;
  final double logoMaxHeight;
  final String primaryColour;
  final String accentColour;
  final String fontDisplay;
  final String fontBody;
  final CoverStyle coverStyle;
  final BrandingCoverText? coverTextReport;
  final BrandingCoverText? coverTextQuote;
  final BrandingCoverText? coverTextInvoice;
  final BrandingCoverText? coverTextJobsheet;
  final HeaderStyle headerStyle;
  final bool headerShowCompanyName;
  final bool headerShowDocNumber;
  final FooterStyle footerStyle;
  final String footerText;
  final bool footerShowCompanyName;
  final bool footerShowPageNumbers;
  final Set<BrandingDocType> appliesTo;
  final String? lastUpdatedBy;
  final DateTime updatedAt;
  final DateTime lastModifiedAt;

  const PdfBranding({
    this.logoUrl,
    this.logoMaxHeight = 60,
    this.primaryColour = '#1A1A2E',
    this.accentColour = '#FFB020',
    this.fontDisplay = 'outfit',
    this.fontBody = 'inter',
    this.coverStyle = CoverStyle.bold,
    this.coverTextReport,
    this.coverTextQuote,
    this.coverTextInvoice,
    this.coverTextJobsheet,
    this.headerStyle = HeaderStyle.solid,
    this.headerShowCompanyName = true,
    this.headerShowDocNumber = true,
    this.footerStyle = FooterStyle.light,
    this.footerText = '',
    this.footerShowCompanyName = true,
    this.footerShowPageNumbers = true,
    this.appliesTo = const {
      BrandingDocType.report,
      BrandingDocType.quote,
      BrandingDocType.invoice,
      BrandingDocType.jobsheet,
    },
    this.lastUpdatedBy,
    required this.updatedAt,
    required this.lastModifiedAt,
  });

  BrandingCoverText? coverTextFor(BrandingDocType type) {
    switch (type) {
      case BrandingDocType.report:
        return coverTextReport;
      case BrandingDocType.quote:
        return coverTextQuote;
      case BrandingDocType.invoice:
        return coverTextInvoice;
      case BrandingDocType.jobsheet:
        return coverTextJobsheet;
    }
  }

  bool appliesToDocType(BrandingDocType type) => appliesTo.contains(type);

  Map<String, dynamic> toJson() => {
        if (logoUrl != null) 'logoUrl': logoUrl,
        'logoMaxHeight': logoMaxHeight,
        'primaryColour': primaryColour,
        'accentColour': accentColour,
        'fontDisplay': fontDisplay,
        'fontBody': fontBody,
        'coverStyle': coverStyle.name,
        if (coverTextReport != null)
          'coverTextReport': coverTextReport!.toJson(),
        if (coverTextQuote != null) 'coverTextQuote': coverTextQuote!.toJson(),
        if (coverTextInvoice != null)
          'coverTextInvoice': coverTextInvoice!.toJson(),
        if (coverTextJobsheet != null)
          'coverTextJobsheet': coverTextJobsheet!.toJson(),
        'headerStyle': headerStyle.name,
        'headerShowCompanyName': headerShowCompanyName,
        'headerShowDocNumber': headerShowDocNumber,
        'footerStyle': footerStyle.name,
        'footerText': footerText,
        'footerShowCompanyName': footerShowCompanyName,
        'footerShowPageNumbers': footerShowPageNumbers,
        'appliesTo': appliesTo.map((e) => e.name).toList(),
        if (lastUpdatedBy != null) 'lastUpdatedBy': lastUpdatedBy,
        'updatedAt': updatedAt.toIso8601String(),
        'lastModifiedAt': lastModifiedAt.toIso8601String(),
      };

  factory PdfBranding.fromJson(Map<String, dynamic> json) => PdfBranding(
        logoUrl: json['logoUrl'] as String?,
        logoMaxHeight: (json['logoMaxHeight'] as num?)?.toDouble() ?? 60,
        primaryColour: json['primaryColour'] as String? ?? '#1A1A2E',
        accentColour: json['accentColour'] as String? ?? '#FFB020',
        fontDisplay: json['fontDisplay'] as String? ?? 'outfit',
        fontBody: json['fontBody'] as String? ?? 'inter',
        coverStyle: CoverStyle.values.firstWhere(
          (e) => e.name == json['coverStyle'],
          orElse: () => CoverStyle.bold,
        ),
        coverTextReport: json['coverTextReport'] != null
            ? BrandingCoverText.fromJson(
                json['coverTextReport'] as Map<String, dynamic>)
            : null,
        coverTextQuote: json['coverTextQuote'] != null
            ? BrandingCoverText.fromJson(
                json['coverTextQuote'] as Map<String, dynamic>)
            : null,
        coverTextInvoice: json['coverTextInvoice'] != null
            ? BrandingCoverText.fromJson(
                json['coverTextInvoice'] as Map<String, dynamic>)
            : null,
        coverTextJobsheet: json['coverTextJobsheet'] != null
            ? BrandingCoverText.fromJson(
                json['coverTextJobsheet'] as Map<String, dynamic>)
            : null,
        headerStyle: HeaderStyle.values.firstWhere(
          (e) => e.name == json['headerStyle'],
          orElse: () => HeaderStyle.solid,
        ),
        headerShowCompanyName:
            json['headerShowCompanyName'] as bool? ?? true,
        headerShowDocNumber: json['headerShowDocNumber'] as bool? ?? true,
        footerStyle: FooterStyle.values.firstWhere(
          (e) => e.name == json['footerStyle'],
          orElse: () => FooterStyle.light,
        ),
        footerText: json['footerText'] as String? ?? '',
        footerShowCompanyName:
            json['footerShowCompanyName'] as bool? ?? true,
        footerShowPageNumbers:
            json['footerShowPageNumbers'] as bool? ?? true,
        appliesTo: json['appliesTo'] != null
            ? (json['appliesTo'] as List)
                .map((e) => BrandingDocType.values.firstWhere(
                      (d) => d.name == e,
                      orElse: () => BrandingDocType.report,
                    ))
                .toSet()
            : const {
                BrandingDocType.report,
                BrandingDocType.quote,
                BrandingDocType.invoice,
                BrandingDocType.jobsheet,
              },
        lastUpdatedBy: json['lastUpdatedBy'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        lastModifiedAt: json['lastModifiedAt'] != null
            ? DateTime.parse(json['lastModifiedAt'] as String)
            : DateTime.now(),
      );

  PdfBranding copyWith({
    String? logoUrl,
    bool clearLogoUrl = false,
    double? logoMaxHeight,
    String? primaryColour,
    String? accentColour,
    String? fontDisplay,
    String? fontBody,
    CoverStyle? coverStyle,
    BrandingCoverText? coverTextReport,
    bool clearCoverTextReport = false,
    BrandingCoverText? coverTextQuote,
    bool clearCoverTextQuote = false,
    BrandingCoverText? coverTextInvoice,
    bool clearCoverTextInvoice = false,
    BrandingCoverText? coverTextJobsheet,
    bool clearCoverTextJobsheet = false,
    HeaderStyle? headerStyle,
    bool? headerShowCompanyName,
    bool? headerShowDocNumber,
    FooterStyle? footerStyle,
    String? footerText,
    bool? footerShowCompanyName,
    bool? footerShowPageNumbers,
    Set<BrandingDocType>? appliesTo,
    String? lastUpdatedBy,
    bool clearLastUpdatedBy = false,
    DateTime? updatedAt,
    DateTime? lastModifiedAt,
  }) =>
      PdfBranding(
        logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
        logoMaxHeight: logoMaxHeight ?? this.logoMaxHeight,
        primaryColour: primaryColour ?? this.primaryColour,
        accentColour: accentColour ?? this.accentColour,
        fontDisplay: fontDisplay ?? this.fontDisplay,
        fontBody: fontBody ?? this.fontBody,
        coverStyle: coverStyle ?? this.coverStyle,
        coverTextReport: clearCoverTextReport
            ? null
            : (coverTextReport ?? this.coverTextReport),
        coverTextQuote: clearCoverTextQuote
            ? null
            : (coverTextQuote ?? this.coverTextQuote),
        coverTextInvoice: clearCoverTextInvoice
            ? null
            : (coverTextInvoice ?? this.coverTextInvoice),
        coverTextJobsheet: clearCoverTextJobsheet
            ? null
            : (coverTextJobsheet ?? this.coverTextJobsheet),
        headerStyle: headerStyle ?? this.headerStyle,
        headerShowCompanyName:
            headerShowCompanyName ?? this.headerShowCompanyName,
        headerShowDocNumber: headerShowDocNumber ?? this.headerShowDocNumber,
        footerStyle: footerStyle ?? this.footerStyle,
        footerText: footerText ?? this.footerText,
        footerShowCompanyName:
            footerShowCompanyName ?? this.footerShowCompanyName,
        footerShowPageNumbers:
            footerShowPageNumbers ?? this.footerShowPageNumbers,
        appliesTo: appliesTo ?? this.appliesTo,
        lastUpdatedBy: clearLastUpdatedBy
            ? null
            : (lastUpdatedBy ?? this.lastUpdatedBy),
        updatedAt: updatedAt ?? this.updatedAt,
        lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      );

  String toJsonString() => jsonEncode(toJson());

  factory PdfBranding.fromJsonString(String jsonString) =>
      PdfBranding.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  static PdfBranding defaultBranding() => PdfBranding(
        updatedAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
      );
}
