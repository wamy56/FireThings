import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_header_config.dart';

class BrandingService {
  static const _oldKeyLogoPath = 'branding_logo_path';
  static bool _migrated = false;

  static String _keyForType(PdfDocumentType type) =>
      'branding_logo_path_${type.name}';

  static String _fileNameForType(PdfDocumentType type) =>
      'logo_${type.name}.png';

  /// Migrate old single-logo storage to per-type storage (once per app session).
  static Future<void> _migrateIfNeeded() async {
    if (_migrated) return;
    _migrated = true;

    final prefs = await SharedPreferences.getInstance();
    final oldPath = prefs.getString(_oldKeyLogoPath);
    if (oldPath == null) return;

    // Only migrate if neither typed key exists yet
    final jobsheetKey = _keyForType(PdfDocumentType.jobsheet);
    final invoiceKey = _keyForType(PdfDocumentType.invoice);
    if (prefs.containsKey(jobsheetKey) || prefs.containsKey(invoiceKey)) return;

    final oldFile = File(oldPath);
    if (!await oldFile.exists()) {
      await prefs.remove(_oldKeyLogoPath);
      return;
    }

    final dir = oldFile.parent.path;
    for (final type in PdfDocumentType.values) {
      final newPath = '$dir/${_fileNameForType(type)}';
      await oldFile.copy(newPath);
      await prefs.setString(_keyForType(type), newPath);
    }

    await oldFile.delete();
    await prefs.remove(_oldKeyLogoPath);
  }

  static Future<void> saveLogo(String sourceFilePath, PdfDocumentType type) async {
    await _migrateIfNeeded();
    final appDir = await getApplicationDocumentsDirectory();
    final brandingDir = Directory('${appDir.path}/branding');
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }

    final destPath = '${brandingDir.path}/${_fileNameForType(type)}';
    await File(sourceFilePath).copy(destPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForType(type), destPath);
  }

  static Future<String?> getLogoPath(PdfDocumentType type) async {
    await _migrateIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyForType(type));
    if (path != null && await File(path).exists()) {
      return path;
    }
    return null;
  }

  static Future<Uint8List?> getLogoBytes(PdfDocumentType type) async {
    final path = await getLogoPath(type);
    if (path == null) return null;
    return await File(path).readAsBytes();
  }

  static Future<void> removeLogo(PdfDocumentType type) async {
    await _migrateIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyForType(type));
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(_keyForType(type));
  }

  static Future<bool> hasLogo(PdfDocumentType type) async {
    final path = await getLogoPath(type);
    return path != null;
  }
}
