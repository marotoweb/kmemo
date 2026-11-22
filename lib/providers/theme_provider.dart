// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _autoWrap = true;
  bool _strikethroughChecked = true;
  bool _showLinkPreviews = true;
  double _widgetBgOpacity = 1.0;
  double _widgetCardOpacity = 1.0;
  bool _showLastSyncHint = true;


  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  bool get autoWrap => _autoWrap;
  bool get strikethroughChecked => _strikethroughChecked;
  bool get showLinkPreviews => _showLinkPreviews;
  double get widgetBgOpacity => _widgetBgOpacity;
  double get widgetCardOpacity => _widgetCardOpacity;
  bool get showLastSyncHint => _showLastSyncHint;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    final lang = prefs.getString('language_code');
    _autoWrap = prefs.getBool('auto_wrap') ?? true;
    _strikethroughChecked = prefs.getBool('strikethrough_checked') ?? true;
    _showLinkPreviews = prefs.getBool('show_link_previews') ?? true;
    _widgetBgOpacity = prefs.getDouble('widget_bg_opacity') ?? 1.0;
    _widgetCardOpacity = prefs.getDouble('widget_card_opacity') ?? 1.0;
    _showLastSyncHint = prefs.getBool('show_last_sync_hint') ?? true;
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

  /// Puts every setting back to the value of a fresh install.
  ///
  /// The caller clears the stored preferences (the "delete all app data"
  /// action); this only resets the in-memory state and writes nothing back, so
  /// the stored state stays empty like on a new install.
  void resetToDefaults() {
    _themeMode = ThemeMode.system;
    _locale = null;
    _autoWrap = true;
    _strikethroughChecked = true;
    _showLinkPreviews = true;
    _widgetBgOpacity = 1.0;
    _widgetCardOpacity = 1.0;
    _showLastSyncHint = true;
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

  Future<void> setShowLinkPreviews(bool value) async {
    _showLinkPreviews = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_link_previews', value);
  }

  Future<void> setWidgetBgOpacity(double value) async {
    _widgetBgOpacity = value.clamp(0.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('widget_bg_opacity', _widgetBgOpacity);
  }

  Future<void> setShowLastSyncHint(bool value) async {
    _showLastSyncHint = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_last_sync_hint', value);
  }

  Future<void> setWidgetCardOpacity(double value) async {
    _widgetCardOpacity = value.clamp(0.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('widget_card_opacity', _widgetCardOpacity);
  }
}
