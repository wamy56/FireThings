import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_section_style_config.dart';
import '../models/pdf_header_config.dart';
import 'firestore_sync_service.dart';

class PdfSectionStyleService {
  static String _keyForType(PdfDocumentType type) =>
      'pdf_section_style_${type.name}';

  static Future<PdfSectionStyleConfig> getConfig(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyForType(type));
    if (jsonString != null) {
      return PdfSectionStyleConfig.fromJsonString(jsonString);
    }
    return PdfSectionStyleConfig.defaults();
  }

  static Future<void> saveConfig(
      PdfSectionStyleConfig config, PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = config.toJsonString();
    await prefs.setString(_keyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfSectionStyle(jsonString, type);
  }
}
