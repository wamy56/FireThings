import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeStyle { classic, siteOps }

final ValueNotifier<ThemeStyle> themeStyleNotifier =
    ValueNotifier(ThemeStyle.classic);

Future<void> loadThemeStylePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('theme_style');
  if (value == 'siteOps') {
    themeStyleNotifier.value = ThemeStyle.siteOps;
  }
}

Future<void> saveThemeStylePreference(ThemeStyle style) async {
  final prefs = await SharedPreferences.getInstance();
  switch (style) {
    case ThemeStyle.classic:
      await prefs.remove('theme_style');
    case ThemeStyle.siteOps:
      await prefs.setString('theme_style', 'siteOps');
  }
}
