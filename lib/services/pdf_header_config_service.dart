import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_header_config.dart';

class PdfHeaderConfigService {
  static const _configKey = 'pdf_header_config_v1';
  static const _migratedKey = 'pdf_header_config_migrated';

  // Old keys from JobsheetSettingsService
  static const _oldCompanyName = 'jobsheet_company_name';
  static const _oldTagline = 'jobsheet_tagline';
  static const _oldAddress = 'jobsheet_address';
  static const _oldPhone = 'jobsheet_phone';

  static Future<PdfHeaderConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();

    // Attempt migration from old settings if not done yet
    if (prefs.getBool(_migratedKey) != true) {
      await _migrateFromOldSettings(prefs);
    }

    final jsonString = prefs.getString(_configKey);
    if (jsonString != null) {
      return PdfHeaderConfig.fromJsonString(jsonString);
    }
    return PdfHeaderConfig.defaults();
  }

  static Future<void> saveConfig(PdfHeaderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, config.toJsonString());
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
      await prefs.setString(_configKey, config.toJsonString());
    }

    await prefs.setBool(_migratedKey, true);
  }
}
