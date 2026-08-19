import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shapes a background wash can take.
/// How much of the app shows through the mini player and the navigation bar.
///
/// They float over the content all day, so this trades two things against each
/// other: seeing the list move behind them, and reading their labels when what
/// moves behind is a bright cover. Which one matters more is taste, and on a
/// slow device the blur has a price, so it is offered rather than decided.
enum BarBackground {
  /// The surface colour, opaque. What the app has always looked like.
  solid,

  /// Translucent with the content blurred behind it: the list shows through and
  /// the labels stay readable over anything.
  glass,

  /// Translucent with nothing behind it done: cheap, and muddy over a busy
  /// cover.
  translucent,

  /// No background at all — just the text and the icons.
  clear;

  /// How opaque the bar is when the player sheet is [t] of the way open.
  ///
  /// Always opaque by the time it is a full screen: a now-playing view with the
  /// queue showing through it is not a view.
  double opacityAt(double t) {
    final collapsed = switch (this) {
      BarBackground.solid => 1.0,
      BarBackground.glass => 0.72,
      BarBackground.translucent => 0.55,
      BarBackground.clear => 0.0,
    };
    return collapsed + (1 - collapsed) * t;
  }

  /// Whether what is behind is blurred.
  bool get blurs => this == BarBackground.glass;
}

enum AppGradient {
  /// A flat surface, which is what Material expects and what reads best behind
  /// dense lists.
  none,

  /// Top to bottom.
  linear,

  /// Out from the middle.
  radial,

  /// Whatever angle was chosen.
  custom,
}

/// Remembers which theme the user picked.
///
/// Defaults to following the system, which is the right answer for most people
/// most of the time — but only most: plenty of listeners want the app dark at
/// noon, and that preference should survive a restart.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';
  static const _dynamicKey = 'theme_dynamic';
  static const _seedKey = 'theme_seed';
  static const _gradientKey = 'theme_gradient';
  static const _barBackgroundKey = 'theme_bar_background';
  static const _gradientColoursKey = 'theme_gradient_colours';
  static const _gradientAngleKey = 'theme_gradient_angle';

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

  /// The colour the whole interface is generated from when it is not taking
  /// one from the artwork. Null means the app's own raspberry.
  int? _seed;
  int? get seed => _seed;

  /// A short row rather than a colour wheel: every one of these is a seed
  /// Material can build a readable scheme from, which is not true of an
  /// arbitrary pick.
  static const seeds = <int>[
    0xFFC2185B, // the app's own
    0xFF6750A4,
    0xFF1565C0,
    0xFF00897B,
    0xFF2E7D32,
    0xFFF9A825,
    0xFFE64A19,
    0xFF5D4037,
    0xFF455A64,
  ];

  /// Whether the app sits on a flat colour or a wash, and of what shape.
  AppGradient gradient = AppGradient.none;

  /// How much shows through the bars that float over everything.
  BarBackground barBackground = BarBackground.solid;

  Future<void> setBarBackground(BarBackground value) async {
    barBackground = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_barBackgroundKey, value.name);
  }

  /// The colours the wash runs through, in order. Two or more; anything less
  /// is a flat colour, which is what [AppGradient.none] is for.
  List<int> gradientColours = const [];

  /// Where a linear wash points, in turns: 0 is downward, 0.25 is to the left.
  /// Only read for [AppGradient.custom].
  double gradientAngle = 0;

  Future<void> setGradient(AppGradient value) async {
    gradient = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gradientKey, value.name);
  }

  Future<void> setGradientColours(List<int> values) async {
    gradientColours = List.of(values);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _gradientColoursKey,
      [for (final value in values) '$value'],
    );
  }

  Future<void> setGradientAngle(double value) async {
    gradientAngle = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_gradientAngleKey, value);
  }

  Future<void> setSeed(int? value) async {
    _seed = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_seedKey);
    } else {
      await prefs.setInt(_seedKey, value);
    }
  }

  /// Offered in this order: the two explicit choices first, then the default.
  /// Labels live in the UI layer, where the translations are.
  static const options = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _decode(prefs.getString(_key));
    _dynamic = prefs.getBool(_dynamicKey) ?? false;
    _seed = prefs.getInt(_seedKey);
    barBackground = BarBackground.values.firstWhere(
      (kind) => kind.name == prefs.getString(_barBackgroundKey),
      orElse: () => BarBackground.solid,
    );
    gradient = AppGradient.values.firstWhere(
      (kind) => kind.name == prefs.getString(_gradientKey),
      orElse: () => AppGradient.none,
    );
    gradientColours = prefs
            .getStringList(_gradientColoursKey)
            ?.map((value) => int.tryParse(value) ?? 0)
            .where((value) => value != 0)
            .toList() ??
        const [];
    gradientAngle = prefs.getDouble(_gradientAngleKey) ?? 0;
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
