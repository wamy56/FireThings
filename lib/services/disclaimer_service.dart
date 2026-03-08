import 'package:shared_preferences/shared_preferences.dart';

class DisclaimerService {
  DisclaimerService._();
  static final DisclaimerService instance = DisclaimerService._();

  static const int currentDisclaimerVersion = 1;
  static const String _key = 'accepted_disclaimer_version';

  Future<bool> hasAcceptedCurrentDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getInt(_key) ?? 0;
    return accepted >= currentDisclaimerVersion;
  }

  Future<void> acceptDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, currentDisclaimerVersion);
  }

  Future<void> resetAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
