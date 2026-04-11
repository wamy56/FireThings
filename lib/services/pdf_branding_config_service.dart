import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pdf_branding_config.dart';
import '../models/pdf_header_config.dart' show PdfDocumentType;
import 'firestore_sync_service.dart';
import 'pdf_branding_migration.dart';
import 'pdf_colour_scheme_service.dart';
import 'pdf_footer_config_service.dart';
import 'pdf_header_config_service.dart';

/// Unified service for loading/saving [PdfBrandingConfig].
///
/// Replaces the separate [PdfHeaderConfigService], [PdfFooterConfigService],
/// and [PdfColourSchemeService] with a single service. Auto-migrates from
/// v1 on first access.
class PdfBrandingConfigService {
  PdfBrandingConfigService._();

  static const _keyPrefix = 'pdf_branding_config_v2';
  static const _migrationKey = 'pdf_branding_v2_migrated';

  static String _keyForType(PdfDocumentType type) =>
      '${_keyPrefix}_${type.name}';

  /// Load the branding config for [type], auto-migrating from v1 if needed.
  static Future<PdfBrandingConfig> getConfig(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();

    // Auto-migrate from v1 if not done yet
    if (prefs.getBool(_migrationKey) != true) {
      await _migrateFromV1(prefs);
    }

    final jsonString = prefs.getString(_keyForType(type));
    if (jsonString != null) {
      try {
        return PdfBrandingConfig.fromJsonString(jsonString);
      } catch (e) {
        debugPrint('PdfBrandingConfigService: parse error for ${type.name}: $e');
      }
    }
    return PdfBrandingConfig.defaults();
  }

  /// Save the branding config for [type] and sync to Firestore.
  static Future<void> saveConfig(
    PdfBrandingConfig config,
    PdfDocumentType type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = config.toJsonString();
    await prefs.setString(_keyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfBrandingConfig(jsonString, type);
  }

  /// Migrate existing v1 configs (header + footer + colour scheme) to v2.
  static Future<void> _migrateFromV1(SharedPreferences prefs) async {
    try {
      for (final type in [PdfDocumentType.jobsheet, PdfDocumentType.invoice]) {
        // Skip if v2 config already exists for this type
        if (prefs.containsKey(_keyForType(type))) continue;

        final oldHeader = await PdfHeaderConfigService.getConfig(type);
        final oldFooter = await PdfFooterConfigService.getConfig(type);
        final oldColour = await PdfColourSchemeService.getScheme(type);

        final config = PdfBrandingMigration.migrate(
          header: oldHeader,
          footer: oldFooter,
          colour: oldColour,
        );

        await prefs.setString(_keyForType(type), config.toJsonString());
      }
    } catch (e) {
      debugPrint('PdfBrandingConfigService: v1 migration error: $e');
    }
    await prefs.setBool(_migrationKey, true);
  }
}
