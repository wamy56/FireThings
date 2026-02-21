import 'dart:typed_data';

/// DTO for passing jobsheet PDF data into a background isolate.
/// All fields are isolate-safe primitive types.
class JobsheetPdfData {
  final Map<String, dynamic> jobsheetJson;
  final Uint8List? logoBytes;
  final Map<String, dynamic> headerConfigJson;
  final Map<String, dynamic> footerConfigJson;
  final int colourSchemeValue;
  final String settingsCompanyName;
  final String settingsTagline;
  final String settingsAddress;
  final String settingsPhone;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;

  JobsheetPdfData({
    required this.jobsheetJson,
    required this.logoBytes,
    required this.headerConfigJson,
    required this.footerConfigJson,
    required this.colourSchemeValue,
    required this.settingsCompanyName,
    required this.settingsTagline,
    required this.settingsAddress,
    required this.settingsPhone,
    this.regularFontBytes,
    this.boldFontBytes,
  });
}

/// DTO for passing invoice PDF data into a background isolate.
class InvoicePdfData {
  final Map<String, dynamic> invoiceJson;
  final Map<String, String> paymentDetailsMap;
  final Uint8List? logoBytes;
  final Map<String, dynamic> headerConfigJson;
  final Map<String, dynamic> footerConfigJson;
  final int colourSchemeValue;
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;

  InvoicePdfData({
    required this.invoiceJson,
    required this.paymentDetailsMap,
    required this.logoBytes,
    required this.headerConfigJson,
    required this.footerConfigJson,
    required this.colourSchemeValue,
    this.regularFontBytes,
    this.boldFontBytes,
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
