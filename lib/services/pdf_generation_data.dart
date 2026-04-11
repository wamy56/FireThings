import 'dart:typed_data';

/// DTO for passing jobsheet PDF data into a background isolate.
/// All fields are isolate-safe primitive types.
class JobsheetPdfData {
  final Map<String, dynamic> jobsheetJson;
  final Uint8List? logoBytes;
  // V2 unified branding config (preferred when present)
  final Map<String, dynamic>? brandingConfigJson;
  // V1 legacy fields (kept for backward compat during transition)
  final Map<String, dynamic> headerConfigJson;
  final Map<String, dynamic> footerConfigJson;
  final int colourSchemeValue;
  final String settingsCompanyName;
  final String settingsTagline;
  final String settingsAddress;
  final String settingsPhone;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final Uint8List? italicFontBytes;
  final Uint8List? boldItalicFontBytes;
  final List<Map<String, dynamic>>? assetServiceRecords;

  JobsheetPdfData({
    required this.jobsheetJson,
    required this.logoBytes,
    this.brandingConfigJson,
    required this.headerConfigJson,
    required this.footerConfigJson,
    required this.colourSchemeValue,
    required this.settingsCompanyName,
    required this.settingsTagline,
    required this.settingsAddress,
    required this.settingsPhone,
    this.regularFontBytes,
    this.boldFontBytes,
    this.italicFontBytes,
    this.boldItalicFontBytes,
    this.assetServiceRecords,
  });
}

/// DTO for passing invoice PDF data into a background isolate.
class InvoicePdfData {
  final Map<String, dynamic> invoiceJson;
  final Map<String, String> paymentDetailsMap;
  final Uint8List? logoBytes;
  // V2 unified branding config (preferred when present)
  final Map<String, dynamic>? brandingConfigJson;
  // V1 legacy fields (kept for backward compat during transition)
  final Map<String, dynamic> headerConfigJson;
  final Map<String, dynamic> footerConfigJson;
  final int colourSchemeValue;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final Uint8List? italicFontBytes;
  final Uint8List? boldItalicFontBytes;

  InvoicePdfData({
    required this.invoiceJson,
    required this.paymentDetailsMap,
    required this.logoBytes,
    this.brandingConfigJson,
    required this.headerConfigJson,
    required this.footerConfigJson,
    required this.colourSchemeValue,
    this.regularFontBytes,
    this.boldFontBytes,
    this.italicFontBytes,
    this.boldItalicFontBytes,
  });
}

/// DTO for passing template filled-PDF data into a background isolate.
class TemplatePdfData {
  final Map<String, dynamic> templateJson;
  final Map<String, dynamic> fieldValues;
  final String engineerName;
  final String jobReference;
  final bool debugMode;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  /// Pre-loaded file bytes for signature/image fields. Maps field ID to bytes.
  final Map<String, Uint8List> resolvedFileBytes;

  TemplatePdfData({
    required this.templateJson,
    required this.fieldValues,
    required this.engineerName,
    required this.jobReference,
    required this.debugMode,
    this.regularFontBytes,
    this.boldFontBytes,
    required this.resolvedFileBytes,
  });
}

/// DTO for passing template overlay-PDF data into a background isolate.
class TemplateOverlayPdfData {
  final Map<String, dynamic> templateJson;
  final Map<String, dynamic> fieldValues;
  final bool debugMode;
  /// The base PDF bytes (loaded from asset or file on main thread).
  final Uint8List basePdfBytes;
  /// Pre-loaded file bytes for signature/image fields. Maps field ID to bytes.
  final Map<String, Uint8List> resolvedFileBytes;

  TemplateOverlayPdfData({
    required this.templateJson,
    required this.fieldValues,
    required this.debugMode,
    required this.basePdfBytes,
    required this.resolvedFileBytes,
  });
}

/// DTO for passing compliance report data into a background isolate.
class ComplianceReportPdfData {
  final String siteName;
  final String siteAddress;
  final String engineerName;
  final String companyName;
  final String reportDate;
  final Uint8List? logoBytes;
  // V2 unified branding config (preferred when present)
  final Map<String, dynamic>? brandingConfigJson;
  // V1 legacy fields (kept for backward compat during transition)
  final Map<String, dynamic> headerConfigJson;
  final Map<String, dynamic> footerConfigJson;
  final int colourSchemeValue;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final Uint8List? italicFontBytes;
  final Uint8List? boldItalicFontBytes;
  final List<Map<String, dynamic>> assetsJson;
  final List<Map<String, dynamic>> assetTypesJson;
  final List<Map<String, dynamic>> serviceRecordsJson;
  final List<Map<String, dynamic>> floorPlansJson;
  final Map<String, Uint8List> floorPlanImages;
  final Map<String, Uint8List> defectPhotos;
  final List<Map<String, dynamic>> defectsJson;
  final int rectifiedCount;
  final String? lastReportDateStr;

  ComplianceReportPdfData({
    required this.siteName,
    required this.siteAddress,
    required this.engineerName,
    required this.companyName,
    required this.reportDate,
    this.logoBytes,
    this.brandingConfigJson,
    required this.headerConfigJson,
    required this.footerConfigJson,
    required this.colourSchemeValue,
    this.regularFontBytes,
    this.boldFontBytes,
    this.italicFontBytes,
    this.boldItalicFontBytes,
    required this.assetsJson,
    required this.assetTypesJson,
    required this.serviceRecordsJson,
    required this.floorPlansJson,
    required this.floorPlanImages,
    required this.defectPhotos,
    this.defectsJson = const [],
    this.rectifiedCount = 0,
    this.lastReportDateStr,
  });
}
