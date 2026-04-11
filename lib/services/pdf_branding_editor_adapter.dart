import 'dart:typed_data';

import '../models/pdf_branding_config.dart';
import '../models/pdf_header_config.dart' show PdfDocumentType;
import 'branding_service.dart';
import 'company_pdf_config_service.dart';
import 'pdf_branding_config_service.dart';

/// Abstracts whether we are editing personal or company PDF branding.
///
/// Both personal and company editors use the same UI with different
/// adapters, eliminating code duplication.
abstract class PdfBrandingEditorAdapter {
  Future<PdfBrandingConfig> loadConfig(PdfDocumentType type);
  Future<void> saveConfig(PdfBrandingConfig config, PdfDocumentType type);
  Future<Uint8List?> loadLogo(PdfDocumentType type);
  Future<void> saveLogo(Uint8List bytes, PdfDocumentType type);
  Future<void> removeLogo(PdfDocumentType type);
  String get title;
}

/// Adapter for personal (per-user) branding config.
///
/// Uses [PdfBrandingConfigService] for config and [BrandingService] for logos.
class PersonalBrandingAdapter implements PdfBrandingEditorAdapter {
  const PersonalBrandingAdapter();

  @override
  String get title => 'PDF Branding';

  @override
  Future<PdfBrandingConfig> loadConfig(PdfDocumentType type) =>
      PdfBrandingConfigService.getConfig(type);

  @override
  Future<void> saveConfig(PdfBrandingConfig config, PdfDocumentType type) =>
      PdfBrandingConfigService.saveConfig(config, type);

  @override
  Future<Uint8List?> loadLogo(PdfDocumentType type) =>
      BrandingService.getLogoBytes(type);

  @override
  Future<void> saveLogo(Uint8List bytes, PdfDocumentType type) async {
    // BrandingService expects a file path, but we have bytes.
    // For the adapter we save bytes via the service's file mechanism.
    // This requires writing to a temp file first.
    // For now, delegate to BrandingService which handles file storage.
    // The actual logo save flow goes through the UI's image picker
    // which provides a file path — this method is here for interface
    // completeness but the UI calls BrandingService.saveLogo() directly
    // with the picked file path.
    throw UnimplementedError(
      'Personal logo save requires a file path. '
      'Use BrandingService.saveLogo(filePath, type) directly from the UI.',
    );
  }

  @override
  Future<void> removeLogo(PdfDocumentType type) =>
      BrandingService.removeLogo(type);
}

/// Adapter for company-level branding config.
///
/// Uses [CompanyPdfConfigService] for both config and logos (Firestore Blobs).
class CompanyBrandingAdapter implements PdfBrandingEditorAdapter {
  final String companyId;

  const CompanyBrandingAdapter(this.companyId);

  @override
  String get title => 'Company PDF Branding';

  @override
  Future<PdfBrandingConfig> loadConfig(PdfDocumentType type) async {
    final config = await CompanyPdfConfigService.instance
        .getBrandingConfig(companyId, type);
    return config ?? PdfBrandingConfig.defaults();
  }

  @override
  Future<void> saveConfig(PdfBrandingConfig config, PdfDocumentType type) =>
      CompanyPdfConfigService.instance
          .saveBrandingConfig(companyId, config, type);

  @override
  Future<Uint8List?> loadLogo(PdfDocumentType type) =>
      CompanyPdfConfigService.instance.getCompanyLogoBytes(companyId, type);

  @override
  Future<void> saveLogo(Uint8List bytes, PdfDocumentType type) =>
      CompanyPdfConfigService.instance.saveCompanyLogo(companyId, bytes, type);

  @override
  Future<void> removeLogo(PdfDocumentType type) =>
      CompanyPdfConfigService.instance.removeCompanyLogo(companyId, type);
}
