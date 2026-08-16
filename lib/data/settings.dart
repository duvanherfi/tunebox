import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The knobs a listener turns once and expects to stay turned.
///
/// Scalars only, which is why this is a preferences file rather than a
/// database: the things that grow — history, downloads, statistics — live
/// elsewhere. Every setter writes immediately, because a setting that survives
/// only a graceful shutdown is a setting that gets lost.
class Settings extends ChangeNotifier {
  static const _autoplayKey = 'autoplay';
  static const _speedKey = 'playback_speed';
  static const _skipSilenceKey = 'skip_silence';
  static const _normalizeKey = 'normalize_volume';
  static const _equalizerKey = 'equalizer_enabled';
  static const _bandsKey = 'equalizer_bands';
  static const _cacheKey = 'cache_enabled';
  static const _cacheLimitKey = 'cache_limit_mb';
  static const _fadeKey = 'fade_seconds';

  bool autoplay = true;
  double speed = 1;
  bool skipSilence = false;
  bool normalizeVolume = false;
  bool equalizerEnabled = false;

  /// Whether played tracks are kept for next time.
  bool cacheEnabled = true;

  /// How much of the phone this app may take for that, in megabytes.
  int cacheLimitMb = 512;

  /// Seconds of fade at each end of a track. Zero is a hard cut, which is what
  /// most listening wants and what this defaults to.
  int fadeSeconds = 0;

  /// Gain per equalizer band, in decibels, in the order the device reports its
  /// bands. Empty until the equalizer has been opened once — the number of
  /// bands is the device's to decide, not this app's.
  List<double> bandGains = const [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoplay = prefs.getBool(_autoplayKey) ?? autoplay;
    speed = prefs.getDouble(_speedKey) ?? speed;
    skipSilence = prefs.getBool(_skipSilenceKey) ?? skipSilence;
    normalizeVolume = prefs.getBool(_normalizeKey) ?? normalizeVolume;
    equalizerEnabled = prefs.getBool(_equalizerKey) ?? equalizerEnabled;
    cacheEnabled = prefs.getBool(_cacheKey) ?? cacheEnabled;
    cacheLimitMb = prefs.getInt(_cacheLimitKey) ?? cacheLimitMb;
    fadeSeconds = prefs.getInt(_fadeKey) ?? fadeSeconds;
    bandGains = prefs
            .getStringList(_bandsKey)
            ?.map((value) => double.tryParse(value) ?? 0.0)
            .toList() ??
        bandGains;
  }

  Future<void> setAutoplay(bool value) =>
      _write(() => autoplay = value, (p) => p.setBool(_autoplayKey, value));

  Future<void> setSpeed(double value) =>
      _write(() => speed = value, (p) => p.setDouble(_speedKey, value));

  Future<void> setSkipSilence(bool value) => _write(
        () => skipSilence = value,
        (p) => p.setBool(_skipSilenceKey, value),
      );

  Future<void> setNormalizeVolume(bool value) => _write(
        () => normalizeVolume = value,
        (p) => p.setBool(_normalizeKey, value),
      );

  Future<void> setEqualizerEnabled(bool value) => _write(
        () => equalizerEnabled = value,
        (p) => p.setBool(_equalizerKey, value),
      );

  Future<void> setBandGains(List<double> gains) => _write(
        () => bandGains = List.of(gains),
        (p) => p.setStringList(
          _bandsKey,
          gains.map((gain) => gain.toString()).toList(),
        ),
      );

  Future<void> setCacheEnabled(bool value) =>
      _write(() => cacheEnabled = value, (p) => p.setBool(_cacheKey, value));

  Future<void> setCacheLimitMb(int value) => _write(
        () => cacheLimitMb = value,
        (p) => p.setInt(_cacheLimitKey, value),
      );

  Future<void> setFadeSeconds(int value) =>
      _write(() => fadeSeconds = value, (p) => p.setInt(_fadeKey, value));

  Future<void> _write(
    VoidCallback apply,
    Future<void> Function(SharedPreferences) store,
  ) async {
    apply();
    notifyListeners();
    await store(await SharedPreferences.getInstance());
  }
}
