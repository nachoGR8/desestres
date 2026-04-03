import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ValueNotifier<ThemeMode> {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() : super(ThemeMode.light);

  static const _key = 'theme_mode';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    if (val == 'dark') value = ThemeMode.dark;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setString(_key, value == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => value == ThemeMode.dark;
}
