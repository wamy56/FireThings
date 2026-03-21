import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pdf_header_config.dart';
import '../models/pdf_footer_config.dart';
import '../models/pdf_colour_scheme.dart';
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

  /// Clear cached config (e.g. on company change)
  void clearCache() {
    _headerCache.clear();
    _footerCache.clear();
    _colourCache.clear();
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
