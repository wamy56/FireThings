import 'dart:typed_data';

/// DTO for passing jobsheet PDF data into a background isolate.
/// All fields are isolate-safe primitive types.
class JobsheetPdfData {
  final Map<String, dynamic> jobsheetJson;
  final Uint8List? logoBytes;
  final Map<String, dynamic> brandingJson;
  final Map<String, Uint8List>? brandedFontBytes;
  final String companyName;
  final List<Map<String, dynamic>>? assetServiceRecords;
  final Map<String, dynamic>? bs5839VisitJson;

  JobsheetPdfData({
    required this.jobsheetJson,
    this.logoBytes,
    required this.brandingJson,
    this.brandedFontBytes,
    required this.companyName,
    this.assetServiceRecords,
    this.bs5839VisitJson,
  });
}

/// DTO for passing invoice PDF data into a background isolate.
class InvoicePdfData {
  final Map<String, dynamic> invoiceJson;
  final Map<String, String> paymentDetailsMap;
  final Uint8List? logoBytes;
  final Map<String, dynamic> brandingJson;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final Map<String, Uint8List>? brandedFontBytes;
  final String companyName;

  InvoicePdfData({
    required this.invoiceJson,
    required this.paymentDetailsMap,
    this.logoBytes,
    required this.brandingJson,
    this.regularFontBytes,
    this.boldFontBytes,
    this.brandedFontBytes,
    required this.companyName,
  });
}

/// DTO for passing quote PDF data into a background isolate.
class QuotePdfData {
  final Map<String, dynamic> quoteJson;
  final Uint8List? logoBytes;
  final Map<String, dynamic> brandingJson;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final Map<String, Uint8List>? brandedFontBytes;
  final String companyName;

  QuotePdfData({
    required this.quoteJson,
    this.logoBytes,
    required this.brandingJson,
    this.regularFontBytes,
    this.boldFontBytes,
    this.brandedFontBytes,
    required this.companyName,
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
  final Map<String, Uint8List> resolvedFileBytes;
  final Uint8List? logoBytes;
  final Map<String, dynamic> brandingJson;
  final Map<String, Uint8List>? brandedFontBytes;
  final String companyName;

  TemplatePdfData({
    required this.templateJson,
    required this.fieldValues,
    required this.engineerName,
    required this.jobReference,
    required this.debugMode,
    this.regularFontBytes,
    this.boldFontBytes,
    required this.resolvedFileBytes,
    this.logoBytes,
    required this.brandingJson,
    this.brandedFontBytes,
    required this.companyName,
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
  final Map<String, dynamic> headerConfigJson;
  final Map<String, dynamic> footerConfigJson;
  final int colourSchemeValue;
  final int? secondaryColourValue;
  final Map<String, dynamic>? sectionStyleJson;
  final Map<String, dynamic>? typographyJson;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final List<Map<String, dynamic>> assetsJson;
  final List<Map<String, dynamic>> assetTypesJson;
  final List<Map<String, dynamic>> serviceRecordsJson;
  final List<Map<String, dynamic>> floorPlansJson;
  final Map<String, Uint8List> floorPlanImages;
  final Map<String, Uint8List> defectPhotos;
  final List<Map<String, dynamic>> defectsJson;
  final int rectifiedCount;
  final String? lastReportDateStr;
  final String? bs5839LastDeclaration;
  final bool bs5839ModeEnabled;
  final Map<String, dynamic>? brandingJson;
  final Map<String, Uint8List>? brandedFontBytes;

  ComplianceReportPdfData({
    required this.siteName,
    required this.siteAddress,
    required this.engineerName,
    required this.companyName,
    required this.reportDate,
    this.logoBytes,
    required this.headerConfigJson,
    required this.footerConfigJson,
    required this.colourSchemeValue,
    this.secondaryColourValue,
    this.sectionStyleJson,
    this.typographyJson,
    this.regularFontBytes,
    this.boldFontBytes,
    required this.assetsJson,
    required this.assetTypesJson,
    required this.serviceRecordsJson,
    required this.floorPlansJson,
    required this.floorPlanImages,
    required this.defectPhotos,
    this.defectsJson = const [],
    this.rectifiedCount = 0,
    this.lastReportDateStr,
    this.bs5839LastDeclaration,
    this.bs5839ModeEnabled = false,
    this.brandingJson,
    this.brandedFontBytes,
  });
}

class Bs5839ReportPdfData {
  final String siteName;
  final String siteAddress;
  final String engineerName;
  final String companyName;
  final Uint8List? logoBytes;
  final Map<String, dynamic> headerConfigJson;
  final int colourSchemeValue;
  final Map<String, dynamic>? sectionStyleJson;
  final Map<String, dynamic>? typographyJson;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;

  final Map<String, dynamic> configJson;
  final Map<String, dynamic> visitJson;
  final List<Map<String, dynamic>> serviceRecordsJson;
  final List<Map<String, dynamic>> assetsJson;
  final List<Map<String, dynamic>> assetTypesJson;
  final List<Map<String, dynamic>> causeEffectTestsJson;
  final List<Map<String, dynamic>> variationsJson;
  final List<Map<String, dynamic>> logbookEntriesJson;
  final Map<String, dynamic>? competencyJson;
  final List<Map<String, dynamic>> defectsJson;
  final List<Map<String, dynamic>> floorPlansJson;
  final Map<String, Uint8List> floorPlanImages;
  final Map<String, Uint8List> defectPhotos;
  final Map<String, dynamic> brandingJson;
  final Map<String, Uint8List>? brandedFontBytes;

  Bs5839ReportPdfData({
    required this.siteName,
    required this.siteAddress,
    required this.engineerName,
    required this.companyName,
    this.logoBytes,
    required this.headerConfigJson,
    required this.colourSchemeValue,
    this.sectionStyleJson,
    this.typographyJson,
    this.regularFontBytes,
    this.boldFontBytes,
    required this.configJson,
    required this.visitJson,
    required this.serviceRecordsJson,
    required this.assetsJson,
    required this.assetTypesJson,
    required this.causeEffectTestsJson,
    required this.variationsJson,
    required this.logbookEntriesJson,
    this.competencyJson,
    this.defectsJson = const [],
    required this.floorPlansJson,
    required this.floorPlanImages,
    required this.defectPhotos,
    required this.brandingJson,
    this.brandedFontBytes,
  });
}
