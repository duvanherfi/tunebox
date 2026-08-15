import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which theme the user picked.
///
/// Defaults to following the system, which is the right answer for most people
/// most of the time — but only most: plenty of listeners want the app dark at
/// noon, and that preference should survive a restart.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';
  static const _dynamicKey = 'theme_dynamic';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Whether the app takes its colours from the cover that is playing.
  bool _dynamic = false;
  bool get dynamicColors => _dynamic;

  /// The palettes derived from the current artwork, or null while nothing has
  /// been derived — which is also what "off" looks like.
  ColorScheme? lightFromArtwork;
  ColorScheme? darkFromArtwork;

  String? _artworkSource;

  /// Offered in this order: the two explicit choices first, then the default.
  /// Labels live in the UI layer, where the translations are.
  static const options = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _decode(prefs.getString(_key));
    _dynamic = prefs.getBool(_dynamicKey) ?? false;
    notifyListeners();
  }

  Future<void> setDynamicColors(bool value) async {
    if (value == _dynamic) return;
    _dynamic = value;
    if (!value) _clearArtwork();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dynamicKey, value);
  }

  /// Repaints the app around the cover now playing.
  ///
  /// Both palettes are derived, not just the one on screen: the phone can flip
  /// to its dark theme while a track plays, and rebuilding then would mean a
  /// visible lag between the two.
  Future<void> adoptArtwork(String? url) async {
    if (!_dynamic) return;
    if (url == null) return _clearArtwork();
    if (url == _artworkSource) return;
    _artworkSource = url;

    try {
      final image = NetworkImage(url);
      final light = await ColorScheme.fromImageProvider(
        provider: image,
        brightness: Brightness.light,
      );
      final dark = await ColorScheme.fromImageProvider(
        provider: image,
        brightness: Brightness.dark,
      );
      // Guard against a slower track's colours landing after a faster one's.
      if (_artworkSource != url) return;
      lightFromArtwork = light;
      darkFromArtwork = dark;
      notifyListeners();
    } catch (_) {
      // An unreadable cover just leaves the previous colours in place.
    }
  }

  void _clearArtwork() {
    _artworkSource = null;
    lightFromArtwork = null;
    darkFromArtwork = null;
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
