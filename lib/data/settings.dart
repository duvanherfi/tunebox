import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the nightstand screen offers its transport controls.
enum NightstandControls {
  always,
  onTouch,
  never;

  /// Preferences outlive the code that wrote them, so a name this version does
  /// not know is version skew rather than corruption: fall back instead of
  /// throwing on a file the user cannot fix.
  static NightstandControls parse(String? name) => NightstandControls.values
      .firstWhere((mode) => mode.name == name, orElse: () => onTouch);
}

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
  static const _keepAwakeKey = 'keep_awake';
  static const _nightstandClockKey = 'nightstand_clock';
  static const _nightstandArtKey = 'nightstand_art';
  static const _nightstandTitleKey = 'nightstand_title';
  static const _nightstandProgressKey = 'nightstand_progress';
  static const _nightstandControlsKey = 'nightstand_controls';
  static const _nightstandDimKey = 'nightstand_dim';
  static const _nightstandBurnInKey = 'nightstand_burn_in';
  static const _nightstandIdleKey = 'nightstand_idle_seconds';
  static const _nightstandChargeKey = 'nightstand_on_charge';
  static const _updateCheckKey = 'update_check';
  static const _updateCheckedAtKey = 'update_checked_at';

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

  /// Whether the screen stays on while the full player is open — for a phone
  /// propped up as a now-playing display rather than carried in a pocket.
  bool keepAwake = false;

  /// Gain per equalizer band, in decibels, in the order the device reports its
  /// bands. Empty until the equalizer has been opened once — the number of
  /// bands is the device's to decide, not this app's.
  List<double> bandGains = const [];

  /// What the nightstand screen draws. Four separate switches rather than a
  /// handful of presets: a listener who wants a clock and nothing else and one
  /// who wants everything but the clock are both ordinary.
  bool nightstandClock = true;
  bool nightstandArt = true;
  bool nightstandTitle = true;
  bool nightstandProgress = true;

  NightstandControls nightstandControls = NightstandControls.onTouch;

  /// Screen brightness while the nightstand is up, as a percentage. Low enough
  /// to read the time at night without lighting the room.
  int nightstandDim = 20;

  /// Whether the content shifts a few pixels now and then, so a still screen
  /// left on all night does not mark an OLED.
  bool nightstandBurnIn = true;

  /// Seconds of no touching before the nightstand comes up on its own, with
  /// the player open and something playing. Zero means never.
  ///
  /// Off by default, like [nightstandOnCharge]: an app that walks itself to a
  /// black screen the first time it is left alone does not read as a mode, it
  /// reads as a fault. Both are turned on from their own door in settings,
  /// where the text says what they do.
  int nightstandIdleSeconds = 0;

  /// Whether plugging the phone in, with music playing, brings it up.
  bool nightstandOnCharge = false;

  /// Whether the app looks for a new release on its own.
  ///
  /// On by default, unlike the two nightstand switches above: there the
  /// automatic thing takes the screen, here it is a sheet that goes away with
  /// a tap, and an updater nobody turns on is an updater nobody has.
  bool updateCheck = true;

  /// When the last look was, in milliseconds since the epoch. Zero means
  /// never. Kept so the check happens once a day rather than once a launch.
  int updateCheckedAt = 0;

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
    keepAwake = prefs.getBool(_keepAwakeKey) ?? keepAwake;
    nightstandClock = prefs.getBool(_nightstandClockKey) ?? nightstandClock;
    nightstandArt = prefs.getBool(_nightstandArtKey) ?? nightstandArt;
    nightstandTitle = prefs.getBool(_nightstandTitleKey) ?? nightstandTitle;
    nightstandProgress =
        prefs.getBool(_nightstandProgressKey) ?? nightstandProgress;
    nightstandControls =
        NightstandControls.parse(prefs.getString(_nightstandControlsKey));
    nightstandDim = prefs.getInt(_nightstandDimKey) ?? nightstandDim;
    nightstandBurnIn = prefs.getBool(_nightstandBurnInKey) ?? nightstandBurnIn;
    nightstandIdleSeconds =
        prefs.getInt(_nightstandIdleKey) ?? nightstandIdleSeconds;
    nightstandOnCharge =
        prefs.getBool(_nightstandChargeKey) ?? nightstandOnCharge;
    updateCheck = prefs.getBool(_updateCheckKey) ?? updateCheck;
    updateCheckedAt = prefs.getInt(_updateCheckedAtKey) ?? updateCheckedAt;
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

  Future<void> setKeepAwake(bool value) =>
      _write(() => keepAwake = value, (p) => p.setBool(_keepAwakeKey, value));

  Future<void> setNightstandClock(bool value) => _write(
        () => nightstandClock = value,
        (p) => p.setBool(_nightstandClockKey, value),
      );

  Future<void> setNightstandArt(bool value) => _write(
        () => nightstandArt = value,
        (p) => p.setBool(_nightstandArtKey, value),
      );

  Future<void> setNightstandTitle(bool value) => _write(
        () => nightstandTitle = value,
        (p) => p.setBool(_nightstandTitleKey, value),
      );

  Future<void> setNightstandProgress(bool value) => _write(
        () => nightstandProgress = value,
        (p) => p.setBool(_nightstandProgressKey, value),
      );

  Future<void> setNightstandControls(NightstandControls value) => _write(
        () => nightstandControls = value,
        (p) => p.setString(_nightstandControlsKey, value.name),
      );

  Future<void> setNightstandDim(int value) => _write(
        () => nightstandDim = value,
        (p) => p.setInt(_nightstandDimKey, value),
      );

  Future<void> setNightstandBurnIn(bool value) => _write(
        () => nightstandBurnIn = value,
        (p) => p.setBool(_nightstandBurnInKey, value),
      );

  Future<void> setNightstandIdleSeconds(int value) => _write(
        () => nightstandIdleSeconds = value,
        (p) => p.setInt(_nightstandIdleKey, value),
      );

  Future<void> setNightstandOnCharge(bool value) => _write(
        () => nightstandOnCharge = value,
        (p) => p.setBool(_nightstandChargeKey, value),
      );

  Future<void> setUpdateCheck(bool value) => _write(
        () => updateCheck = value,
        (p) => p.setBool(_updateCheckKey, value),
      );

  Future<void> setUpdateCheckedAt(DateTime at) => _write(
        () => updateCheckedAt = at.millisecondsSinceEpoch,
        (p) => p.setInt(_updateCheckedAtKey, at.millisecondsSinceEpoch),
      );

  Future<void> _write(
    VoidCallback apply,
    Future<void> Function(SharedPreferences) store,
  ) async {
    apply();
    notifyListeners();
    await store(await SharedPreferences.getInstance());
  }
}
