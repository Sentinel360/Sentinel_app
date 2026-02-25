import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme mode options: dark, light, system
enum AppThemeMode { dark, light, system }

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';
  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'dark') {
      _mode = AppThemeMode.dark;
    } else if (saved == 'light') {
      _mode = AppThemeMode.light;
    } else {
      _mode = AppThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  // Resolves to actual dark/light given the system brightness
  bool isDark(BuildContext context) {
    if (_mode == AppThemeMode.dark) return true;
    if (_mode == AppThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }
}
