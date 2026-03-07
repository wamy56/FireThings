import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_colour_scheme.dart';
import 'firestore_sync_service.dart';

class PdfColourSchemeService {
  static const _key = 'pdf_colour_scheme';

  static Future<PdfColourScheme> getScheme() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      return PdfColourScheme.fromJsonString(jsonString);
    }
    return PdfColourScheme.defaults();
  }

  static Future<void> saveScheme(PdfColourScheme scheme) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = scheme.toJsonString();
    await prefs.setString(_key, jsonString);
    FirestoreSyncService.instance.syncPdfColourScheme(jsonString);
  }
}
