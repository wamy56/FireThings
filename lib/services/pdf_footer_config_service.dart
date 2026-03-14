import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_footer_config.dart';
import '../models/pdf_header_config.dart';
import 'firestore_sync_service.dart';

class PdfFooterConfigService {
  static const _oldConfigKey = 'pdf_footer_config_v1';
  static const _migratedKey = 'pdf_footer_config_migrated';
  static const _typeMigratedKey = 'pdf_footer_config_type_migrated';

  // Old keys from JobsheetSettingsService
  static const _oldFooterLine1 = 'jobsheet_footer_line1';
  static const _oldFooterLine2 = 'jobsheet_footer_line2';

  static String _configKeyForType(PdfDocumentType type) =>
      'pdf_footer_config_v1_${type.name}';

  static Future<PdfFooterConfig> getConfig(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();

    // Attempt migration from old settings if not done yet
    if (prefs.getBool(_migratedKey) != true) {
      await _migrateFromOldSettings(prefs);
    }

    // Migrate from untyped key to typed keys
    if (prefs.getBool(_typeMigratedKey) != true) {
      await _migrateToTypedKeys(prefs);
    }

    final jsonString = prefs.getString(_configKeyForType(type));
    if (jsonString != null) {
      return PdfFooterConfig.fromJsonString(jsonString);
    }
    return PdfFooterConfig.defaults();
  }

  static Future<void> saveConfig(PdfFooterConfig config, PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = config.toJsonString();
    await prefs.setString(_configKeyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfFooterConfig(jsonString, type);
  }

  static Future<void> _migrateFromOldSettings(SharedPreferences prefs) async {
    final line1 = prefs.getString(_oldFooterLine1) ?? '';
    final line2 = prefs.getString(_oldFooterLine2) ?? '';

    final hasOldData = line1.isNotEmpty || line2.isNotEmpty;

    if (hasOldData) {
      final leftLines = <HeaderTextLine>[];
      if (line1.isNotEmpty) {
        leftLines.add(HeaderTextLine(key: 'custom', value: line1, fontSize: 7));
      }
      if (line2.isNotEmpty) {
        leftLines.add(HeaderTextLine(key: 'custom', value: line2, fontSize: 7));
      }
      final config = PdfFooterConfig(
        leftLines: leftLines,
        centreLines: [],
      );
      await prefs.setString(_oldConfigKey, config.toJsonString());
    }

    await prefs.setBool(_migratedKey, true);
  }

  /// Migrate untyped key to both jobsheet and invoice typed keys.
  static Future<void> _migrateToTypedKeys(SharedPreferences prefs) async {
    final existing = prefs.getString(_oldConfigKey);
    if (existing != null) {
      await prefs.setString(_configKeyForType(PdfDocumentType.jobsheet), existing);
      await prefs.setString(_configKeyForType(PdfDocumentType.invoice), existing);
      await prefs.remove(_oldConfigKey);
    }
    await prefs.setBool(_typeMigratedKey, true);
  }
}
