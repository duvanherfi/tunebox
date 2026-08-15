import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which theme the user picked.
///
/// Defaults to following the system, which is the right answer for most people
/// most of the time — but only most: plenty of listeners want the app dark at
/// noon, and that preference should survive a restart.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Offered in this order: the two explicit choices first, then the default.
  /// Labels live in the UI layer, where the translations are.
  static const options = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _decode(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> select(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Anything unreadable falls back to the system setting rather than to a
  /// guess, so a corrupted value cannot leave the app stuck in a theme.
  static ThemeMode _decode(String? stored) {
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
