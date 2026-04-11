import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pdf_branding_config.dart';
import '../models/pdf_header_config.dart';
import '../models/pdf_footer_config.dart';
import '../models/pdf_colour_scheme.dart';
import 'branding_service.dart';
import 'pdf_branding_config_service.dart';
import 'pdf_header_config_service.dart';
import 'pdf_footer_config_service.dart';
import 'pdf_colour_scheme_service.dart';
import 'user_profile_service.dart';

/// Service for reading/writing company-level PDF config from Firestore.
/// Falls back to personal config when company config doesn't exist.
class CompanyPdfConfigService {
  static final CompanyPdfConfigService instance = CompanyPdfConfigService._();
  CompanyPdfConfigService._();

  final _firestore = FirebaseFirestore.instance;

  // In-memory cache
  final Map<String, PdfHeaderConfig> _headerCache = {};
  final Map<String, PdfFooterConfig> _footerCache = {};
  final Map<String, PdfColourScheme> _colourCache = {};
  final Map<String, Uint8List> _logoCache = {};
  final Map<String, PdfBrandingConfig> _brandingCache = {};

  String _cacheKey(String companyId, PdfDocumentType type) =>
      '${companyId}_${type.name}';

  DocumentReference _configDoc(String companyId, String docId) =>
      _firestore.collection('companies').doc(companyId).collection('pdf_config').doc(docId);

  String _headerDocId(PdfDocumentType type) => 'header_${type.name}';
  String _footerDocId(PdfDocumentType type) => 'footer_${type.name}';
  String _colourDocId(PdfDocumentType type) => 'colour_scheme_${type.name}';

  // --- Header ---

  Future<PdfHeaderConfig?> getHeaderConfig(String companyId, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    if (_headerCache.containsKey(key)) return _headerCache[key];

    try {
      final doc = await _configDoc(companyId, _headerDocId(type)).get();
      if (doc.exists) {
        final jsonString = doc.data() as Map<String, dynamic>?;
        if (jsonString != null && jsonString['config'] is String) {
          final config = PdfHeaderConfig.fromJsonString(jsonString['config'] as String);
          _headerCache[key] = config;
          return config;
        }
      }
    } catch (e) {
      debugPrint('CompanyPdfConfigService: getHeaderConfig failed: $e');
    }
    return null;
  }

  Future<void> saveHeaderConfig(String companyId, PdfHeaderConfig config, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    _headerCache[key] = config;
    await _configDoc(companyId, _headerDocId(type)).set({
      'config': config.toJsonString(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // --- Footer ---

  Future<PdfFooterConfig?> getFooterConfig(String companyId, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    if (_footerCache.containsKey(key)) return _footerCache[key];

    try {
      final doc = await _configDoc(companyId, _footerDocId(type)).get();
      if (doc.exists) {
        final jsonString = doc.data() as Map<String, dynamic>?;
        if (jsonString != null && jsonString['config'] is String) {
          final config = PdfFooterConfig.fromJsonString(jsonString['config'] as String);
          _footerCache[key] = config;
          return config;
        }
      }
    } catch (e) {
      debugPrint('CompanyPdfConfigService: getFooterConfig failed: $e');
    }
    return null;
  }

  Future<void> saveFooterConfig(String companyId, PdfFooterConfig config, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    _footerCache[key] = config;
    await _configDoc(companyId, _footerDocId(type)).set({
      'config': config.toJsonString(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // --- Colour Scheme ---

  Future<PdfColourScheme?> getColourScheme(String companyId, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    if (_colourCache.containsKey(key)) return _colourCache[key];

    try {
      final doc = await _configDoc(companyId, _colourDocId(type)).get();
      if (doc.exists) {
        final jsonString = doc.data() as Map<String, dynamic>?;
        if (jsonString != null && jsonString['config'] is String) {
          final config = PdfColourScheme.fromJsonString(jsonString['config'] as String);
          _colourCache[key] = config;
          return config;
        }
      }
    } catch (e) {
      debugPrint('CompanyPdfConfigService: getColourScheme failed: $e');
    }
    return null;
  }

  Future<void> saveColourScheme(String companyId, PdfColourScheme scheme, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    _colourCache[key] = scheme;
    await _configDoc(companyId, _colourDocId(type)).set({
      'config': scheme.toJsonString(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // --- Company Logo ---

  String _logoDocId(PdfDocumentType type) => 'logo_${type.name}';
  String _logoCacheKey(String companyId, PdfDocumentType type) =>
      '${companyId}_${type.name}';

  /// Upload logo bytes to Firestore per document type
  Future<void> saveCompanyLogo(String companyId, Uint8List bytes, PdfDocumentType type) async {
    await _configDoc(companyId, _logoDocId(type))
      .set({'bytes': Blob(bytes), 'updatedAt': FieldValue.serverTimestamp()});
    _logoCache[_logoCacheKey(companyId, type)] = bytes;
  }

  /// Get company logo bytes for a specific document type (cached).
  /// Migrates from old single 'logo' doc if typed doc doesn't exist.
  Future<Uint8List?> getCompanyLogoBytes(String companyId, PdfDocumentType type) async {
    final cacheKey = _logoCacheKey(companyId, type);
    if (_logoCache.containsKey(cacheKey)) return _logoCache[cacheKey];
    try {
      final doc = await _configDoc(companyId, _logoDocId(type)).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final blob = data?['bytes'] as Blob?;
        if (blob != null) {
          _logoCache[cacheKey] = blob.bytes;
          return blob.bytes;
        }
      }
      // Migration: check old single 'logo' doc
      final oldDoc = await _configDoc(companyId, 'logo').get();
      if (oldDoc.exists) {
        final oldData = oldDoc.data() as Map<String, dynamic>?;
        final oldBlob = oldData?['bytes'] as Blob?;
        if (oldBlob != null) {
          // Copy to both typed docs and delete old
          for (final t in PdfDocumentType.values) {
            await _configDoc(companyId, _logoDocId(t))
              .set({'bytes': Blob(oldBlob.bytes), 'updatedAt': FieldValue.serverTimestamp()});
            _logoCache[_logoCacheKey(companyId, t)] = oldBlob.bytes;
          }
          await _configDoc(companyId, 'logo').delete();
          return oldBlob.bytes;
        }
      }
      return null;
    } catch (e) {
      debugPrint('CompanyPdfConfigService: getCompanyLogoBytes failed: $e');
      return null;
    }
  }

  /// Remove company logo for a specific document type
  Future<void> removeCompanyLogo(String companyId, PdfDocumentType type) async {
    await _configDoc(companyId, _logoDocId(type)).delete();
    _logoCache.remove(_logoCacheKey(companyId, type));
  }

  /// Resolve logo bytes: company first (if useCompanyBranding), then personal fallback
  Future<Uint8List?> getEffectiveLogoBytes({
    bool useCompanyBranding = false,
    required PdfDocumentType type,
  }) async {
    if (useCompanyBranding) {
      final companyId = UserProfileService.instance.companyId;
      if (companyId != null) {
        final companyLogo = await getCompanyLogoBytes(companyId, type);
        if (companyLogo != null) return companyLogo;
      }
    }
    return BrandingService.getLogoBytes(type);
  }

  // --- Branding Config V2 ---

  String _brandingDocId(PdfDocumentType type) => 'branding_v2_${type.name}';

  Future<PdfBrandingConfig?> getBrandingConfig(String companyId, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    if (_brandingCache.containsKey(key)) return _brandingCache[key];

    try {
      final doc = await _configDoc(companyId, _brandingDocId(type)).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['config'] is String) {
          final config = PdfBrandingConfig.fromJsonString(data['config'] as String);
          _brandingCache[key] = config;
          return config;
        }
      }
    } catch (e) {
      debugPrint('CompanyPdfConfigService: getBrandingConfig failed: $e');
    }
    return null;
  }

  Future<void> saveBrandingConfig(String companyId, PdfBrandingConfig config, PdfDocumentType type) async {
    final key = _cacheKey(companyId, type);
    _brandingCache[key] = config;
    await _configDoc(companyId, _brandingDocId(type)).set({
      'config': config.toJsonString(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get effective branding config: company config if applicable, else personal.
  Future<PdfBrandingConfig> getEffectiveBrandingConfig(
    PdfDocumentType type, {
    bool useCompanyBranding = false,
  }) async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId != null && useCompanyBranding) {
      final companyConfig = await getBrandingConfig(companyId, type);
      if (companyConfig != null) return companyConfig;
    }
    return PdfBrandingConfigService.getConfig(type);
  }

  /// Clear cached config (e.g. on company change)
  void clearCache() {
    _headerCache.clear();
    _footerCache.clear();
    _colourCache.clear();
    _logoCache.clear();
    _brandingCache.clear();
  }

  // --- B2: Effective config resolution ---

  /// Get effective header config: company config if applicable, else personal.
  /// Use company config when: jobsheet has dispatchedJobId AND user has companyId,
  /// OR invoice has useCompanyBranding AND user has companyId.
  Future<PdfHeaderConfig> getEffectiveHeaderConfig(
    PdfDocumentType type, {
    bool useCompanyBranding = false,
  }) async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId != null && useCompanyBranding) {
      final companyConfig = await getHeaderConfig(companyId, type);
      if (companyConfig != null) return companyConfig;
    }
    return PdfHeaderConfigService.getConfig(type);
  }

  /// Get effective footer config.
  Future<PdfFooterConfig> getEffectiveFooterConfig(
    PdfDocumentType type, {
    bool useCompanyBranding = false,
  }) async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId != null && useCompanyBranding) {
      final companyConfig = await getFooterConfig(companyId, type);
      if (companyConfig != null) return companyConfig;
    }
    return PdfFooterConfigService.getConfig(type);
  }

  /// Get effective colour scheme.
  Future<PdfColourScheme> getEffectiveColourScheme(
    PdfDocumentType type, {
    bool useCompanyBranding = false,
  }) async {
    final companyId = UserProfileService.instance.companyId;
    if (companyId != null && useCompanyBranding) {
      final companyConfig = await getColourScheme(companyId, type);
      if (companyConfig != null) return companyConfig;
    }
    return PdfColourSchemeService.getScheme(type);
  }
}
