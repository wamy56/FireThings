import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_colour_scheme.dart';
import '../models/pdf_header_config.dart';
import 'firestore_sync_service.dart';

class PdfColourSchemeService {
  static const _oldKey = 'pdf_colour_scheme';
  static const _typeMigratedKey = 'pdf_colour_scheme_type_migrated';

  static String _keyForType(PdfDocumentType type) =>
      'pdf_colour_scheme_${type.name}';

  static Future<PdfColourScheme> getScheme(PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate from untyped key to typed keys
    if (prefs.getBool(_typeMigratedKey) != true) {
      await _migrateToTypedKeys(prefs);
    }

    final jsonString = prefs.getString(_keyForType(type));
    if (jsonString != null) {
      return PdfColourScheme.fromJsonString(jsonString);
    }
    return PdfColourScheme.defaults();
  }

  static Future<void> saveScheme(PdfColourScheme scheme, PdfDocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = scheme.toJsonString();
    await prefs.setString(_keyForType(type), jsonString);
    FirestoreSyncService.instance.syncPdfColourScheme(jsonString, type);
  }

  /// Migrate untyped key to both jobsheet and invoice typed keys.
  static Future<void> _migrateToTypedKeys(SharedPreferences prefs) async {
    final existing = prefs.getString(_oldKey);
    if (existing != null) {
      await prefs.setString(_keyForType(PdfDocumentType.jobsheet), existing);
      await prefs.setString(_keyForType(PdfDocumentType.invoice), existing);
      await prefs.remove(_oldKey);
    }
    await prefs.setBool(_typeMigratedKey, true);
  }
}
