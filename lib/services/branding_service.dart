import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrandingService {
  static const _keyLogoPath = 'branding_logo_path';

  static Future<void> saveLogo(String sourceFilePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final brandingDir = Directory('${appDir.path}/branding');
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }

    final destPath = '${brandingDir.path}/logo.png';
    await File(sourceFilePath).copy(destPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogoPath, destPath);
  }

  static Future<String?> getLogoPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyLogoPath);
    if (path != null && await File(path).exists()) {
      return path;
    }
    return null;
  }

  static Future<Uint8List?> getLogoBytes() async {
    final path = await getLogoPath();
    if (path == null) return null;
    return await File(path).readAsBytes();
  }

  static Future<void> removeLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyLogoPath);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(_keyLogoPath);
  }

  static Future<bool> hasLogo() async {
    final path = await getLogoPath();
    return path != null;
  }
}
