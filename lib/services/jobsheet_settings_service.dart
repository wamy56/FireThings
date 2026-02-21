import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage jobsheet PDF header/footer settings that persist across sessions
class JobsheetSettingsService {
  // Header fields
  static const _keyCompanyName = 'jobsheet_company_name';
  static const _keyTagline = 'jobsheet_tagline';
  static const _keyAddress = 'jobsheet_address';
  static const _keyPhone = 'jobsheet_phone';

  // Footer fields
  static const _keyFooterLine1 = 'jobsheet_footer_line1';
  static const _keyFooterLine2 = 'jobsheet_footer_line2';

  /// Get jobsheet header/footer settings
  static Future<JobsheetHeaderFooter> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return JobsheetHeaderFooter(
      companyName: prefs.getString(_keyCompanyName) ?? '',
      tagline: prefs.getString(_keyTagline) ?? '',
      address: prefs.getString(_keyAddress) ?? '',
      phone: prefs.getString(_keyPhone) ?? '',
      footerLine1: prefs.getString(_keyFooterLine1) ?? '',
      footerLine2: prefs.getString(_keyFooterLine2) ?? '',
    );
  }

  /// Save jobsheet header/footer settings
  static Future<void> saveSettings(JobsheetHeaderFooter settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompanyName, settings.companyName);
    await prefs.setString(_keyTagline, settings.tagline);
    await prefs.setString(_keyAddress, settings.address);
    await prefs.setString(_keyPhone, settings.phone);
    await prefs.setString(_keyFooterLine1, settings.footerLine1);
    await prefs.setString(_keyFooterLine2, settings.footerLine2);
  }

  /// Check if settings have been configured
  static Future<bool> hasSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString(_keyCompanyName);
    return companyName != null && companyName.isNotEmpty;
  }
}

/// Model class for jobsheet header/footer settings
class JobsheetHeaderFooter {
  final String companyName;
  final String tagline;
  final String address;
  final String phone;
  final String footerLine1;
  final String footerLine2;

  JobsheetHeaderFooter({
    required this.companyName,
    required this.tagline,
    required this.address,
    required this.phone,
    required this.footerLine1,
    required this.footerLine2,
  });

  bool get isEmpty =>
      companyName.isEmpty &&
      tagline.isEmpty &&
      address.isEmpty &&
      phone.isEmpty &&
      footerLine1.isEmpty &&
      footerLine2.isEmpty;

  /// Get company name (pass-through, fallback handled at call-site)
  String get companyNameOrDefault => companyName;

  /// Get tagline (pass-through, empty = not shown)
  String get taglineOrDefault => tagline;

  /// Get address (pass-through, empty = not shown)
  String get addressOrDefault => address;

  /// Get phone (pass-through, empty = not shown)
  String get phoneOrDefault => phone;

  /// Get footer line 1 (empty = not shown)
  String get footerLine1OrDefault => footerLine1;

  /// Get footer line 2 (empty = not shown)
  String get footerLine2OrDefault => footerLine2;
}
