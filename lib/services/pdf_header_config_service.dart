import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_header_config.dart';
import 'firestore_sync_service.dart';

class PdfHeaderConfigService {
  static const _oldConfigKey = 'pdf_header_config_v1';
  static const _migratedKey = 'pdf_header_config_migrated';
  static const _typeMigratedKey = 'pdf_header_config_type_migrated';

  // Old keys from JobsheetSettingsService
  static const _oldCompanyName = 'jobsheet_company_name';
  static const _oldTagline = 'jobsheet_tagline';
  static const _oldAddress = 'jobsheet_address';
  static const _oldPhone = 'jobsheet_phone';

  static String _configKeyForType(PdfDocumentType type) =>
      'pdf_header_config_v1_${type.name}';

  static Future<PdfHeaderConfig> getConfig(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate from old JobsheetSettingsService keys if not done yet
    if (prefs.getBool(_migratedKey) != true) {
      await _migrateFromOldSettings(prefs);
    }

    // Migrate from untyped key to typed keys
    if (prefs.getBool(_typeMigratedKey) != true) {
      await _migrateToTypedKeys(prefs);
    }

    final jsonString = prefs.getString(_configKeyForType(type));
    if (jsonString != null) {
      return PdfHeaderConfig.fromJsonString(jsonString);
    }
    return PdfHeaderConfig.defaults();
  }

  static Future<void> saveConfig(PdfHeaderConfig config, PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = config.toJsonString();
    await prefs.setString(_configKeyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfHeaderConfig(jsonString, type);
  }

  static Future<void> _migrateFromOldSettings(SharedPreferences prefs) async {
    final companyName = prefs.getString(_oldCompanyName) ?? '';
    final tagline = prefs.getString(_oldTagline) ?? '';
    final address = prefs.getString(_oldAddress) ?? '';
    final phone = prefs.getString(_oldPhone) ?? '';

    // Only create a migrated config if there's actual old data
    final hasOldData = companyName.isNotEmpty ||
        tagline.isNotEmpty ||
        address.isNotEmpty ||
        phone.isNotEmpty;

    if (hasOldData) {
      final config = PdfHeaderConfig(
        logoZone: LogoZone.left,
        logoSize: LogoSize.medium,
        leftLines: [
          HeaderTextLine(key: 'companyName', value: companyName, fontSize: 18, bold: true),
          HeaderTextLine(key: 'tagline', value: tagline, fontSize: 10, bold: true),
          HeaderTextLine(key: 'address', value: address, fontSize: 9),
          HeaderTextLine(key: 'phone', value: phone, fontSize: 9),
        ],
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
