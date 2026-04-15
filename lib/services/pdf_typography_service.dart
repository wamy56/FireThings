import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_typography_config.dart';
import '../models/pdf_header_config.dart';
import 'firestore_sync_service.dart';

class PdfTypographyService {
  static String _keyForType(PdfDocumentType type) =>
      'pdf_typography_${type.name}';

  static Future<PdfTypographyConfig> getConfig(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyForType(type));
    if (jsonString != null) {
      return PdfTypographyConfig.fromJsonString(jsonString);
    }
    return PdfTypographyConfig.defaults();
  }

  static Future<void> saveConfig(
      PdfTypographyConfig config, PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = config.toJsonString();
    await prefs.setString(_keyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfTypography(jsonString, type);
  }
}
