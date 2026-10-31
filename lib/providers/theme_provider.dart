// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _autoWrap = false;
  bool _strikethroughChecked = true;


  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  bool get autoWrap => _autoWrap;
  bool get strikethroughChecked => _strikethroughChecked;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    final lang = prefs.getString('language_code');
    _autoWrap = prefs.getBool('auto_wrap') ?? false;
    _strikethroughChecked = prefs.getBool('strikethrough_checked') ?? true;
    if (lang != null && lang.isNotEmpty) {
      _locale = Locale(lang);
    }
    if (themeIndex == 1) {
      _themeMode = ThemeMode.light;
    } else if (themeIndex == 2) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    int themeIndex = 0;
    if (mode == ThemeMode.light) themeIndex = 1;
    if (mode == ThemeMode.dark) themeIndex = 2;
    await prefs.setInt('theme_mode', themeIndex);
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove('language_code');
    } else {
      await prefs.setString('language_code', locale.languageCode);
    }
  }

  Future<void> setAutoWrap(bool value) async {
    _autoWrap = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_wrap', value);
  }

  Future<void> setStrikethroughChecked(bool value) async {
    _strikethroughChecked = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('strikethrough_checked', value);
  }
}
