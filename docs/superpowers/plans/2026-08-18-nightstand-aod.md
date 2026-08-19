# Modo mesita de noche — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Una pantalla propia para el teléfono despierto en la mesita — reloj,
carátula, progreso y controles sobre negro — configurable en todo lo que pinta y
capaz de entrar sola por inactividad o al enchufar.

**Architecture:** Una ruta opaca a pantalla completa sobre el `rootNavigator`,
no un overlay dentro del armazón: el `PlayerSheet` ya es un `Positioned` con la
navegación debajo. Un único helper `openNightstand` es la puerta de entrada y el
dueño de los tres efectos laterales (wakelock, modo inmersivo, brillo), que
deshace en un `finally`. Los nueve mandos son escalares en `Settings`; las dos
activaciones automáticas son dos observadores pequeños y sin estado propio.

**Tech Stack:** Flutter, `shared_preferences`, `wakelock_plus` (ya en el
proyecto), `screen_brightness` y `battery_plus` (nuevas).

**Spec:** `docs/superpowers/specs/2026-08-18-nightstand-aod-design.md`

## Global Constraints

- Los comentarios de código y los mensajes de commit se escriben **en inglés**.
  Los comentarios explican *por qué*, no *qué*.
- `flutter analyze` tiene que salir limpio antes de cada commit.
- Toda cadena visible es una clave ARB: `lib/l10n/app_en.arb` es la plantilla y
  `lib/l10n/app_es.arb` gana las mismas claves. Después,
  `flutter gen-l10n --arb-dir=lib/l10n`.
- Los escalares van a `shared_preferences` vía `lib/data/settings.dart`. No se
  crea almacén nuevo.
- Ningún `drawable/` nuevo se nombra desde Dart, así que `res/raw/keep.xml` y
  `test/android_icon_resources_test.dart` no se tocan.
- Los widgets llegan a los objetos largos importando `lib/main.dart`. No hay
  contenedor de inyección y no se introduce uno.
- Verificación final en el emulador con captura, además de las pruebas.

---

### Task 1: Los nueve mandos

**Files:**
- Modify: `lib/data/settings.dart`
- Modify: `pubspec.yaml`
- Test: `test/nightstand_settings_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `enum NightstandControls { always, onTouch, never }` con
  `static NightstandControls parse(String? name)`; y en `Settings` los campos
  `bool nightstandClock`, `bool nightstandArt`, `bool nightstandTitle`,
  `bool nightstandProgress`, `NightstandControls nightstandControls`,
  `int nightstandDim`, `bool nightstandBurnIn`, `int nightstandIdleSeconds`,
  `bool nightstandOnCharge`, cada uno con su
  `Future<void> setNightstandX(valor)`.

- [ ] **Step 1: Añadir las dos dependencias**

```bash
flutter pub add screen_brightness battery_plus
flutter pub get
```

Después, en `pubspec.yaml`, mover las dos líneas junto a las demás sin
restricción y anotarlas, siguiendo el estilo del fichero:

```yaml
  # Real backlight, not a black veil over the page: on an OLED in a dark room
  # the difference is the whole point of the nightstand screen.
  screen_brightness:
  # The only way to know the phone is plugged in.
  battery_plus:
```

- [ ] **Step 2: Escribir la prueba que falla**

Crear `test/nightstand_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/data/settings.dart';

/// The nightstand is nine scalars and no store of its own. What is worth
/// testing is that they come back as they were left, and that the two which
/// take the app somewhere on their own are off until someone says otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts fully drawn and never enters by itself', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.load();

    expect(settings.nightstandClock, isTrue);
    expect(settings.nightstandArt, isTrue);
    expect(settings.nightstandTitle, isTrue);
    expect(settings.nightstandProgress, isTrue);
    expect(settings.nightstandControls, NightstandControls.onTouch);
    expect(settings.nightstandDim, 20);
    expect(settings.nightstandBurnIn, isTrue);
    expect(settings.nightstandIdleSeconds, 0);
    expect(settings.nightstandOnCharge, isFalse);
  });

  test('every knob survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final written = Settings();
    await written.load();

    await written.setNightstandClock(false);
    await written.setNightstandArt(false);
    await written.setNightstandTitle(false);
    await written.setNightstandProgress(false);
    await written.setNightstandControls(NightstandControls.always);
    await written.setNightstandDim(65);
    await written.setNightstandBurnIn(false);
    await written.setNightstandIdleSeconds(120);
    await written.setNightstandOnCharge(true);

    final read = Settings();
    await read.load();

    expect(read.nightstandClock, isFalse);
    expect(read.nightstandArt, isFalse);
    expect(read.nightstandTitle, isFalse);
    expect(read.nightstandProgress, isFalse);
    expect(read.nightstandControls, NightstandControls.always);
    expect(read.nightstandDim, 65);
    expect(read.nightstandBurnIn, isFalse);
    expect(read.nightstandIdleSeconds, 120);
    expect(read.nightstandOnCharge, isTrue);
  });

  test('a control mode this version does not know reads as onTouch', () async {
    SharedPreferences.setMockInitialValues({'nightstand_controls': 'sometimes'});
    final settings = Settings();
    await settings.load();

    expect(settings.nightstandControls, NightstandControls.onTouch);
  });
}
```

- [ ] **Step 3: Comprobar que falla**

Run: `flutter test test/nightstand_settings_test.dart`
Expected: FAIL — `NightstandControls` no existe y `Settings` no tiene esos
campos; el fichero ni siquiera compila.

- [ ] **Step 4: Implementar**

En `lib/data/settings.dart`, encima de `class Settings`:

```dart
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
```

Dentro de `Settings`, junto a las demás constantes de clave:

```dart
  static const _nightstandClockKey = 'nightstand_clock';
  static const _nightstandArtKey = 'nightstand_art';
  static const _nightstandTitleKey = 'nightstand_title';
  static const _nightstandProgressKey = 'nightstand_progress';
  static const _nightstandControlsKey = 'nightstand_controls';
  static const _nightstandDimKey = 'nightstand_dim';
  static const _nightstandBurnInKey = 'nightstand_burn_in';
  static const _nightstandIdleKey = 'nightstand_idle_seconds';
  static const _nightstandChargeKey = 'nightstand_on_charge';
```

Junto a los demás campos:

```dart
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
```

En `load()`:

```dart
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
```

Y los nueve setters, al final junto a los demás:

```dart
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
```

- [ ] **Step 5: Comprobar que pasa**

Run: `flutter test test/nightstand_settings_test.dart && flutter analyze`
Expected: PASS y análisis limpio.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/settings.dart test/nightstand_settings_test.dart
git commit -m "Give the nightstand its nine knobs

Both automatic ways in start off. An app that walks itself to a black
screen the first time it is left alone does not read as a mode.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: La puerta de entrada y la deriva

**Files:**
- Create: `lib/features/nightstand/nightstand.dart`
- Test: `test/nightstand_test.dart`

**Interfaces:**
- Consumes: `settings.nightstandDim`, `settings.keepAwake` de Task 1 y del
  fichero que ya existe.
- Produces: `Offset nightstandDrift(int tick)`,
  `Future<void> openNightstand(BuildContext context)`, `bool nightstandIsOpen`.
  Referencia a `NightstandScreen`, que llega en Task 3.

- [ ] **Step 1: Escribir la prueba que falla**

Crear `test/nightstand_test.dart`:

```dart
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/features/nightstand/nightstand.dart';

/// The drift is what keeps a still screen from marking an OLED. It is a pure
/// function precisely so it can be checked without lighting anything up.
void main() {
  test('walks four distinct places and returns to the first', () {
    final walked = <Offset>[
      for (var tick = 0; tick < 4; tick++) nightstandDrift(tick),
    ];

    expect(walked.toSet().length, 4);
    expect(nightstandDrift(4), nightstandDrift(0));
    expect(nightstandDrift(9), nightstandDrift(1));
  });

  test('never strays more than eight pixels', () {
    for (var tick = 0; tick < 40; tick++) {
      final offset = nightstandDrift(tick);
      expect(offset.dx.abs(), lessThanOrEqualTo(8));
      expect(offset.dy.abs(), lessThanOrEqualTo(8));
    }
  });
}
```

- [ ] **Step 2: Comprobar que falla**

Run: `flutter test test/nightstand_test.dart`
Expected: FAIL — no existe `lib/features/nightstand/nightstand.dart`.

- [ ] **Step 3: Implementar**

Crear `lib/features/nightstand/nightstand.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../main.dart';
import 'nightstand_screen.dart';

/// The four places the content sits, one step per cycle. Eight pixels is
/// enough to move a pixel off a lit neighbour and small enough that nobody
/// watching notices the screen crawling.
const _driftSteps = <Offset>[
  Offset(-8, -8),
  Offset(8, -8),
  Offset(8, 8),
  Offset(-8, 8),
];

/// Where the nightstand's content sits at [tick]. Pure so it can be checked
/// without a screen; Dart's modulo is never negative for a positive divisor,
/// so a tick that ever went backwards would still land inside the list.
Offset nightstandDrift(int tick) => _driftSteps[tick % _driftSteps.length];

bool _open = false;

/// Whether the nightstand is already up. Read by the watchers: with three ways
/// in, two of them can fire on the same second.
bool get nightstandIsOpen => _open;

/// The only way in.
///
/// It owns the three side effects — the wakelock, the immersive bars and the
/// brightness — and undoes them in a `finally` rather than in the screen's
/// `dispose`. The push completes however the route ends: our own chevron, the
/// back gesture, a pop from somewhere else. The `finally` also covers the case
/// where it never opened at all.
Future<void> openNightstand(BuildContext context) async {
  if (_open) return;
  _open = true;

  final navigator = Navigator.of(context, rootNavigator: true);

  try {
    // Unconditional, unlike the full player's: keeping the screen on is a
    // preference there and the entire point of the mode here.
    await WakelockPlus.enable();
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    await _setBrightness(settings.nightstandDim / 100);

    await navigator.push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => const NightstandScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  } finally {
    await _restoreBrightness();
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    // Back to whatever the player asked for: this returns to the expanded
    // player, which holds the lock itself when the listener wants it.
    if (!settings.keepAwake) await WakelockPlus.disable();
    _open = false;
  }
}

/// A platform that cannot dim is not a reason to refuse the screen — macOS and
/// the emulator both answer some of these with a failure.
Future<void> _setBrightness(double value) async {
  try {
    await ScreenBrightness.instance.setApplicationScreenBrightness(value);
  } on Exception {
    // Nothing to do about it, and nothing worth telling the listener.
  }
}

Future<void> _restoreBrightness() async {
  try {
    await ScreenBrightness.instance.resetApplicationScreenBrightness();
  } on Exception {
    // Same.
  }
}
```

> Si la versión que resuelve `flutter pub add` no expone `ScreenBrightness.instance`,
> las dos llamadas son `ScreenBrightness().setApplicationScreenBrightness(value)`
> y `ScreenBrightness().resetApplicationScreenBrightness()`. Comprobarlo con
> `grep -rn "class ScreenBrightness" ~/.pub-cache/hosted/pub.dev/screen_brightness-*/lib/`
> antes de escribir.

En este punto el fichero no compila todavía: importa `NightstandScreen`, que
llega en la tarea siguiente. Comentar el import y la línea del `pageBuilder`
para pasar la prueba de la deriva **no** es aceptable; en su lugar, crear ya el
esqueleto mínimo en `lib/features/nightstand/nightstand_screen.dart`:

```dart
import 'package:flutter/material.dart';

/// The phone awake on the nightstand. Filled in by the next task.
class NightstandScreen extends StatelessWidget {
  const NightstandScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.black);
}
```

- [ ] **Step 4: Comprobar que pasa**

Run: `flutter test test/nightstand_test.dart && flutter analyze`
Expected: PASS y análisis limpio.

- [ ] **Step 5: Commit**

```bash
git add lib/features/nightstand test/nightstand_test.dart
git commit -m "Open the nightstand through one door that cleans up after itself

The wakelock, the immersive bars and the brightness are undone in a
finally rather than in the screen's dispose, so every way the route can
end leaves the phone as it was found.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: La pantalla

**Files:**
- Modify: `lib/features/nightstand/nightstand_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- Test: `test/nightstand_screen_test.dart`

**Interfaces:**
- Consumes: `nightstandDrift`, `NightstandControls`, los cuatro interruptores de
  contenido, `playerService.mediaItem`, `playerService.playbackState`,
  `playerService.shownPosition`, `playerService.shownDuration`,
  `Artwork` de `core/theme/app_theme.dart`, `FullPlayer.format`.
- Produces: `class NightstandScreen extends StatefulWidget`.

- [ ] **Step 1: Añadir las claves que la pantalla necesita**

En `lib/l10n/app_en.arb`, antes del cierre:

```json
  "nightstandExit": "Leave the nightstand",
  "nightstandNothing": "Nothing playing",
```

En `lib/l10n/app_es.arb`, las mismas claves:

```json
  "nightstandExit": "Salir de la mesita",
  "nightstandNothing": "No suena nada",
```

Después: `flutter gen-l10n --arb-dir=lib/l10n`.

- [ ] **Step 2: Escribir la prueba que falla**

Crear `test/nightstand_screen_test.dart`:

```dart
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/core/audio/player_service.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/core/scrobble/scrobbler.dart';
import 'package:tunebox/core/theme/theme_controller.dart';
import 'package:tunebox/data/audio_cache.dart';
import 'package:tunebox/data/downloads.dart';
import 'package:tunebox/data/likes.dart';
import 'package:tunebox/data/play_history.dart';
import 'package:tunebox/data/resume_point.dart';
import 'package:tunebox/data/settings.dart';
import 'package:tunebox/features/nightstand/nightstand_screen.dart';
import 'package:tunebox/l10n/app_localizations.dart';
import 'package:tunebox/main.dart' as app;

import 'fake_audio_platform.dart';

/// Four switches decide what this screen draws, so what is worth testing is
/// that each one really removes its own thing and leaves the others alone.
void main() {
  late Directory temp;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    JustAudioPlatform.instance = FakeJustAudio();
    temp = await Directory.systemTemp.createTemp('tunebox_nightstand');

    app.settings = Settings();
    await app.settings.load();
    app.themeController = ThemeController();
    await app.themeController.load();

    final innertube = InnertubeClient();
    // Positional, in the order PlayerService declares them: innertube,
    // history, settings, downloads, cache, scrobbler, likes, resume, labels.
    app.playerService = PlayerService(
      innertube,
      PlayHistory(file: File('${temp.path}/history.json')),
      app.settings,
      Downloads(directory: Directory('${temp.path}/downloads')),
      AudioCache(directory: Directory('${temp.path}/cache')),
      Scrobbler(),
      Likes(innertube),
      ResumePoint(file: File('${temp.path}/resume.json')),
      (
        likes: 'Liked',
        playlists: 'Playlists',
        albums: 'Albums',
        artists: 'Artists',
        downloads: 'Downloads',
        history: 'History',
        shuffle: 'Shuffle',
        repeat: 'Repeat',
        radio: 'Start radio',
      ),
    );

    // The screen only reads the session; nothing has to actually decode.
    app.playerService.mediaItem.add(
      const MediaItem(
        id: 'v1',
        title: 'A song',
        artist: 'Someone',
        duration: Duration(minutes: 3),
      ),
    );
  });

  tearDown(() async {
    await app.playerService.stop();
    await pumpEventQueue();
    await temp.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NightstandScreen(),
      ),
    );
    await tester.pump();
  }

  testWidgets('draws the lot when every switch is on', (tester) async {
    await open(tester);

    expect(find.text('A song'), findsOneWidget);
    expect(find.text('Someone'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('a switch off removes its own thing and nothing else',
      (tester) async {
    await app.settings.setNightstandProgress(false);
    await app.settings.setNightstandTitle(false);
    await open(tester);

    expect(find.byType(Slider), findsNothing);
    expect(find.text('A song'), findsNothing);
    // The cover is still asked for, which is what "nothing else" means here.
    expect(find.byType(NightstandCover), findsOneWidget);
  });

  testWidgets('hidden controls turn any touch into the way out',
      (tester) async {
    await app.settings.setNightstandControls(NightstandControls.never);
    await open(tester);

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('controls asked for always are there without a touch',
      (tester) async {
    await app.settings.setNightstandControls(NightstandControls.always);
    await open(tester);

    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
  });
}
```

- [ ] **Step 3: Comprobar que falla**

Run: `flutter test test/nightstand_screen_test.dart`
Expected: FAIL — `NightstandCover` no existe y la pantalla está vacía.

- [ ] **Step 4: Implementar la pantalla**

Reemplazar `lib/features/nightstand/nightstand_screen.dart` entero:

```dart
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../player/full_player.dart' show FullPlayer;
import 'nightstand.dart';

/// The phone awake on the nightstand: a clock, a cover, and as little light as
/// the settings allow.
///
/// Everything is drawn on pure black and in plain white rather than in theme
/// colours. On an OLED a true black pixel is an unlit one, which is the whole
/// reason this screen exists; and a surface colour that follows the artwork
/// would light the room a different amount for every track.
class NightstandScreen extends StatefulWidget {
  const NightstandScreen({super.key});

  @override
  State<NightstandScreen> createState() => _NightstandScreenState();
}

class _NightstandScreenState extends State<NightstandScreen> {
  Timer? _clock;
  Timer? _drift;
  Timer? _controlsFade;

  /// Which step of the burn-in cycle the content is on.
  int _tick = 0;

  /// Whether a recent touch has brought the controls up.
  bool _awake = false;

  @override
  void initState() {
    super.initState();
    _scheduleClock();
    if (settings.nightstandBurnIn) {
      _drift = Timer.periodic(
        const Duration(minutes: 1),
        (_) => setState(() => _tick++),
      );
    }
  }

  /// Wakes on the minute rather than every second. A screen that is meant to
  /// be left on all night should not rebuild sixty times for each change it
  /// has to show.
  void _scheduleClock() {
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour,
        now.minute).add(const Duration(minutes: 1));
    _clock = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleClock();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _drift?.cancel();
    _controlsFade?.cancel();
    super.dispose();
  }

  void _touched() {
    switch (settings.nightstandControls) {
      case NightstandControls.never:
        Navigator.of(context).pop();
      case NightstandControls.onTouch:
        setState(() => _awake = true);
        _controlsFade?.cancel();
        _controlsFade = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _awake = false);
        });
      case NightstandControls.always:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _touched,
        child: StreamBuilder<MediaItem?>(
          stream: playerService.mediaItem,
          builder: (context, snapshot) => SafeArea(
            child: TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: Offset.zero,
                end: settings.nightstandBurnIn
                    ? nightstandDrift(_tick)
                    : Offset.zero,
              ),
              // Slow enough that the move is never the thing you notice.
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, offset, child) =>
                  Transform.translate(offset: offset, child: child),
              child: _layout(context, snapshot.data),
            ),
          ),
        ),
      ),
    );
  }

  /// Side by side once the screen is wider than it is tall, for the same
  /// reason the full player does it: stacking a square cover above the rest on
  /// a phone lying down leaves the cover a sliver.
  Widget _layout(BuildContext context, MediaItem? item) {
    final size = MediaQuery.sizeOf(context);
    final cover = settings.nightstandArt
        ? const Center(child: NightstandCover())
        : null;

    if (size.width > size.height && cover != null) {
      return Row(
        children: [
          Expanded(child: cover),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _panel(context, item),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cover != null) Flexible(child: cover),
        ..._panel(context, item),
      ],
    );
  }

  List<Widget> _panel(BuildContext context, MediaItem? item) {
    final l10n = AppLocalizations.of(context)!;
    final mode = settings.nightstandControls;
    final showing = mode == NightstandControls.always ||
        (mode == NightstandControls.onTouch && _awake);

    return [
      if (settings.nightstandClock) ...[
        const _Clock(),
        const SizedBox(height: 24),
      ],
      if (settings.nightstandTitle)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                item?.title ?? l10n.nightstandNothing,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item?.artist != null) ...[
                const SizedBox(height: 4),
                Text(
                  item!.artist!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      if (settings.nightstandProgress && item != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
          child: _Progress(total: item.duration ?? Duration.zero),
        ),
      // Kept in the tree at zero opacity rather than removed: a layout that
      // jumps every time the controls come and go is worse than a dim row.
      if (mode != NightstandControls.never)
        AnimatedOpacity(
          opacity: showing ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !showing,
            child: const _Controls(),
          ),
        ),
    ];
  }
}

/// The time as the phone itself writes it, so a listener who set their device
/// to 24 hours gets 24 hours without this screen owning a preference for it.
class _Clock extends StatelessWidget {
  const _Clock();

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();

    return Column(
      children: [
        Text(
          material.formatTimeOfDay(
            TimeOfDay.fromDateTime(now),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w200,
            letterSpacing: -2,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          material.formatMediumDate(now),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// The cover, sized from what it is given rather than from the screen, so the
/// same widget fits both layouts.
class NightstandCover extends StatelessWidget {
  const NightstandCover({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: playerService.mediaItem,
      builder: (context, snapshot) {
        final url = snapshot.data?.artUri?.toString();
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = [
              constraints.maxWidth,
              constraints.maxHeight,
              320.0,
            ].reduce((a, b) => a < b ? a : b);
            return Artwork(url: url, size: side, radius: 20);
          },
        );
      },
    );
  }
}

/// Driven by the player's own position stream rather than the media session,
/// so the handle moves smoothly instead of once per state broadcast.
class _Progress extends StatelessWidget {
  const _Progress({required this.total});

  final Duration total;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: playerService.shownPosition,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = playerService.shownDuration ?? total;
        final max = duration.inMilliseconds.toDouble();
        final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

        final labels = TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 12,
        );

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white.withValues(alpha: 0.8),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: max <= 0 ? 0 : value,
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0
                    ? null
                    : (next) => playerService.seek(
                          Duration(milliseconds: next.round()),
                        ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(FullPlayer.format(position), style: labels),
                Text(FullPlayer.format(duration), style: labels),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Transport, plus the way out. The chevron travels with the controls because
/// it is the same question: what can I press.
class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<PlaybackState>(
      stream: playerService.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 34,
                  color: Colors.white,
                  tooltip: l10n.tipPrevious,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: playerService.skipToPrevious,
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 44,
                  color: Colors.white,
                  tooltip: playing ? l10n.tipPause : l10n.tipPlay,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: playing ? playerService.pause : playerService.play,
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 34,
                  color: Colors.white,
                  tooltip: l10n.tipNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: playerService.skipToNext,
                ),
              ],
            ),
            IconButton(
              color: Colors.white.withValues(alpha: 0.5),
              tooltip: l10n.nightstandExit,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 5: Comprobar que pasa**

Run: `flutter test test/nightstand_screen_test.dart && flutter analyze`
Expected: PASS y análisis limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/features/nightstand lib/l10n test/nightstand_screen_test.dart
git commit -m "Draw the nightstand on true black

Plain white on pure black rather than theme colours: an unlit pixel is
the reason the screen exists, and a surface that followed the artwork
would light the room a different amount for every track.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: La sexta puerta

**Files:**
- Create: `lib/features/settings/nightstand_settings_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- Test: `test/settings_index_test.dart:60-80`

**Interfaces:**
- Consumes: los nueve mandos de Task 1, `SettingsLabel` de
  `features/settings/section_label.dart`.
- Produces: `class NightstandSettingsScreen extends StatelessWidget`.

- [ ] **Step 1: Añadir las claves**

En `lib/l10n/app_en.arb`:

```json
  "settingsNightstand": "Nightstand",
  "settingsNightstandBody": "A clock and the cover while the phone rests by the bed",
  "nightstandShows": "What it shows",
  "nightstandClock": "Clock",
  "nightstandArt": "Cover",
  "nightstandTrack": "Title and artist",
  "nightstandProgress": "Progress",
  "nightstandControlsLabel": "Controls",
  "nightstandControlsAlways": "Always",
  "nightstandControlsOnTouch": "On touch",
  "nightstandControlsNever": "Hidden",
  "nightstandControlsBody": "Hidden means any touch leaves for the player.",
  "nightstandScreenLabel": "Screen",
  "nightstandDim": "Brightness: {percent}%",
  "@nightstandDim": {"placeholders": {"percent": {"type": "int"}}},
  "nightstandBurnIn": "Move the content",
  "nightstandBurnInBody": "Shifts everything a few pixels every minute, so a still screen does not mark an OLED.",
  "nightstandEnters": "Coming up on its own",
  "nightstandIdle": "After doing nothing",
  "nightstandIdleNever": "Never",
  "nightstandIdleSeconds": "{seconds} s",
  "@nightstandIdleSeconds": {"placeholders": {"seconds": {"type": "int"}}},
  "nightstandIdleMinutes": "{minutes} min",
  "@nightstandIdleMinutes": {"placeholders": {"minutes": {"type": "int"}}},
  "nightstandIdleBody": "With the player open and something playing.",
  "nightstandOnCharge": "When it starts charging",
  "nightstandOnChargeBody": "With something playing and the phone plugged in.",
  "nightstandOpen": "Nightstand mode",
```

En `lib/l10n/app_es.arb`, las mismas claves:

```json
  "settingsNightstand": "Mesita de noche",
  "settingsNightstandBody": "Un reloj y la carátula mientras el teléfono descansa junto a la cama",
  "nightstandShows": "Qué se ve",
  "nightstandClock": "Reloj",
  "nightstandArt": "Carátula",
  "nightstandTrack": "Título y artista",
  "nightstandProgress": "Progreso",
  "nightstandControlsLabel": "Controles",
  "nightstandControlsAlways": "Siempre",
  "nightstandControlsOnTouch": "Al tocar",
  "nightstandControlsNever": "Ocultos",
  "nightstandControlsBody": "Ocultos significa que cualquier toque sale al reproductor.",
  "nightstandScreenLabel": "Pantalla",
  "nightstandDim": "Brillo: {percent} %",
  "@nightstandDim": {"placeholders": {"percent": {"type": "int"}}},
  "nightstandBurnIn": "Mover el contenido",
  "nightstandBurnInBody": "Desplaza todo unos píxeles cada minuto, para que una pantalla quieta no marque un OLED.",
  "nightstandEnters": "Entrar solo",
  "nightstandIdle": "Tras no hacer nada",
  "nightstandIdleNever": "Nunca",
  "nightstandIdleSeconds": "{seconds} s",
  "@nightstandIdleSeconds": {"placeholders": {"seconds": {"type": "int"}}},
  "nightstandIdleMinutes": "{minutes} min",
  "@nightstandIdleMinutes": {"placeholders": {"minutes": {"type": "int"}}},
  "nightstandIdleBody": "Con el reproductor abierto y algo sonando.",
  "nightstandOnCharge": "Al empezar a cargar",
  "nightstandOnChargeBody": "Con algo sonando y el teléfono enchufado.",
  "nightstandOpen": "Modo mesita de noche",
```

Después: `flutter gen-l10n --arb-dir=lib/l10n`.

- [ ] **Step 2: Escribir la prueba que falla**

En `test/settings_index_test.dart`, añadir el import:

```dart
import 'package:tunebox/features/settings/nightstand_settings_screen.dart';
```

Añadir la fila a la lista de la prueba `lists one row per domain`:

```dart
    expect(find.text('Nightstand'), findsOneWidget);
```

Y a la tabla de puertas:

```dart
    ('Nightstand', NightstandSettingsScreen),
```

- [ ] **Step 3: Comprobar que falla**

Run: `flutter test test/settings_index_test.dart`
Expected: FAIL — `NightstandSettingsScreen` no existe.

- [ ] **Step 4: Escribir la puerta y su pantalla**

Crear `lib/features/settings/nightstand_settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../data/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'section_label.dart';

/// Everything about the nightstand screen, since none of it belongs anywhere
/// else: what it draws, how bright it is, and whether it ever comes up on its
/// own.
class NightstandSettingsScreen extends StatelessWidget {
  const NightstandSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNightstand)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SettingsLabel(l10n.nightstandShows),
            SwitchListTile(
              title: Text(l10n.nightstandClock),
              value: settings.nightstandClock,
              onChanged: settings.setNightstandClock,
            ),
            SwitchListTile(
              title: Text(l10n.nightstandArt),
              value: settings.nightstandArt,
              onChanged: settings.setNightstandArt,
            ),
            SwitchListTile(
              title: Text(l10n.nightstandTrack),
              value: settings.nightstandTitle,
              onChanged: settings.setNightstandTitle,
            ),
            SwitchListTile(
              title: Text(l10n.nightstandProgress),
              value: settings.nightstandProgress,
              onChanged: settings.setNightstandProgress,
            ),
            SettingsLabel(l10n.nightstandControlsLabel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<NightstandControls>(
                segments: [
                  ButtonSegment(
                    value: NightstandControls.always,
                    label: Text(l10n.nightstandControlsAlways),
                  ),
                  ButtonSegment(
                    value: NightstandControls.onTouch,
                    label: Text(l10n.nightstandControlsOnTouch),
                  ),
                  ButtonSegment(
                    value: NightstandControls.never,
                    label: Text(l10n.nightstandControlsNever),
                  ),
                ],
                selected: {settings.nightstandControls},
                onSelectionChanged: (chosen) =>
                    settings.setNightstandControls(chosen.first),
              ),
            ),
            _Note(l10n.nightstandControlsBody),
            SettingsLabel(l10n.nightstandScreenLabel),
            ListTile(
              title: Text(l10n.nightstandDim(settings.nightstandDim)),
              subtitle: Slider(
                value: settings.nightstandDim.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                onChanged: (value) =>
                    settings.setNightstandDim(value.round()),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.nightstandBurnIn),
              subtitle: Text(l10n.nightstandBurnInBody),
              value: settings.nightstandBurnIn,
              onChanged: settings.setNightstandBurnIn,
            ),
            SettingsLabel(l10n.nightstandEnters),
            ListTile(
              title: Text(l10n.nightstandIdle),
              subtitle: Text(l10n.nightstandIdleBody),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final seconds in const [0, 30, 60, 120, 300])
                    ChoiceChip(
                      label: Text(_idleLabel(l10n, seconds)),
                      selected: settings.nightstandIdleSeconds == seconds,
                      onSelected: (_) =>
                          settings.setNightstandIdleSeconds(seconds),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: Text(l10n.nightstandOnCharge),
              subtitle: Text(l10n.nightstandOnChargeBody),
              value: settings.nightstandOnCharge,
              onChanged: settings.setNightstandOnCharge,
            ),
          ],
        ),
      ),
    );
  }

  String _idleLabel(AppLocalizations l10n, int seconds) => switch (seconds) {
        0 => l10n.nightstandIdleNever,
        < 60 => l10n.nightstandIdleSeconds(seconds),
        _ => l10n.nightstandIdleMinutes(seconds ~/ 60),
      };
}

/// The sentence under a control that a subtitle cannot carry, because the
/// control it explains is not a ListTile.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
```

En `lib/features/settings/settings_screen.dart`, añadir el import y la entrada
después de Apariencia y antes del bloque `if (Platform.isAndroid)`:

```dart
          _Entry(
            icon: Icons.bedtime_outlined,
            title: l10n.settingsNightstand,
            body: l10n.settingsNightstandBody,
            onTap: () => open(const NightstandSettingsScreen()),
          ),
```

- [ ] **Step 5: Comprobar que pasa**

Run: `flutter test test/settings_index_test.dart && flutter analyze`
Expected: PASS y análisis limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings lib/l10n test/settings_index_test.dart
git commit -m "Give the nightstand its own door

Nine knobs is more than fits under Appearance, and none of them is about
the theme. Sixth door, same as every other domain.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Entrar a mano

**Files:**
- Modify: `lib/features/player/playback_sheet.dart:36-56`

**Interfaces:**
- Consumes: `openNightstand` de Task 2, `l10n.nightstandOpen` de Task 4.
- Produces: nada que otras tareas usen.

- [ ] **Step 1: Añadir la entrada arriba de la hoja**

En `lib/features/player/playback_sheet.dart`, añadir el import:

```dart
import '../nightstand/nightstand.dart';
```

Y como primer hijo del `Column`, antes de `_Label(l10n.settingsSleep)`:

```dart
            // First because it is the one thing here that takes you somewhere
            // rather than turning a knob, and because it belongs beside the
            // sleep timer: both are what this sheet is opened for at night.
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: Text(l10n.nightstandOpen),
              onTap: () {
                Navigator.of(context).pop();
                openNightstand(context);
              },
            ),
            const Divider(height: 1),
```

> `Navigator.of(context).pop()` cierra la hoja antes de empujar la ruta.
> `openNightstand` toma el `rootNavigator`, que es el mismo que acaba de hacer
> el `pop`, así que el orden importa: empujar antes de cerrar dejaría la hoja
> por encima.

- [ ] **Step 2: Comprobar que compila y que nada se rompió**

Run: `flutter analyze && flutter test`
Expected: análisis limpio y toda la suite en verde.

- [ ] **Step 3: Commit**

```bash
git add lib/features/player/playback_sheet.dart
git commit -m "Reach the nightstand from the sheet the sleep timer lives in

Both are what this sheet gets opened for at night, and neither is a
setting anyone browses to.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Entrar por inactividad

**Files:**
- Create: `lib/features/nightstand/idle_watcher.dart`
- Modify: `lib/features/player/full_player.dart:53-100`
- Test: `test/nightstand_idle_test.dart`

**Interfaces:**
- Consumes: `openNightstand` de Task 2, `settings.nightstandIdleSeconds` de
  Task 1.
- Produces: `class IdleWatcher extends StatefulWidget` con
  `IdleWatcher({required int seconds, required bool enabled, required VoidCallback onIdle, required Widget child})`.

- [ ] **Step 1: Escribir la prueba que falla**

Crear `test/nightstand_idle_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/features/nightstand/idle_watcher.dart';

/// The watcher takes its two conditions as plain values rather than reading
/// settings and the player itself. That is what makes the rule — N seconds
/// untouched, and a touch starts the count again — checkable without a device.
void main() {
  Future<int Function()> pump(
    WidgetTester tester, {
    required int seconds,
    required bool enabled,
  }) async {
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: IdleWatcher(
          seconds: seconds,
          enabled: enabled,
          onIdle: () => fired++,
          child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        ),
      ),
    );
    return () => fired;
  }

  testWidgets('comes up once the time passes untouched', (tester) async {
    final fired = await pump(tester, seconds: 2, enabled: true);

    await tester.pump(const Duration(seconds: 1));
    expect(fired(), 0);

    await tester.pump(const Duration(seconds: 2));
    expect(fired(), 1);
  });

  testWidgets('a touch starts the count again', (tester) async {
    final fired = await pump(tester, seconds: 2, enabled: true);

    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(200, 300));

    // Would have fired here if the touch had not put it off.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(fired(), 0);

    await tester.pump(const Duration(seconds: 1));
    expect(fired(), 1);
  });

  testWidgets('never with nothing playing', (tester) async {
    final fired = await pump(tester, seconds: 1, enabled: false);

    await tester.pump(const Duration(seconds: 5));
    expect(fired(), 0);
  });

  testWidgets('never when the delay is off', (tester) async {
    final fired = await pump(tester, seconds: 0, enabled: true);

    await tester.pump(const Duration(seconds: 5));
    expect(fired(), 0);
  });
}
```

- [ ] **Step 2: Comprobar que falla**

Run: `flutter test test/nightstand_idle_test.dart`
Expected: FAIL — no existe `idle_watcher.dart`.

- [ ] **Step 3: Implementar el vigilante**

Crear `lib/features/nightstand/idle_watcher.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

/// Calls [onIdle] when [seconds] pass without a touch anywhere inside it.
///
/// It takes its conditions as plain values instead of reading the settings and
/// the player itself. That keeps the rule — this long untouched, and a touch
/// starts the count again — separable from where the two answers come from,
/// and testable without a device.
class IdleWatcher extends StatefulWidget {
  const IdleWatcher({
    super.key,
    required this.seconds,
    required this.enabled,
    required this.onIdle,
    required this.child,
  });

  /// How long untouched before [onIdle]. Zero means never.
  final int seconds;

  /// Whether the count runs at all.
  final bool enabled;

  final VoidCallback onIdle;
  final Widget child;

  @override
  State<IdleWatcher> createState() => _IdleWatcherState();
}

class _IdleWatcherState extends State<IdleWatcher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  /// Rearmed on every rebuild with new terms: a track that starts or a delay
  /// that changes has to take effect without the listener touching anything.
  @override
  void didUpdateWidget(IdleWatcher old) {
    super.didUpdateWidget(old);
    if (old.seconds != widget.seconds || old.enabled != widget.enabled) _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    if (!widget.enabled || widget.seconds <= 0) return;
    _timer = Timer(Duration(seconds: widget.seconds), widget.onIdle);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Translucent, not opaque: everything under this still has to be
      // pressable. The listener only wants to know that a finger arrived.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _arm(),
      child: widget.child,
    );
  }
}
```

- [ ] **Step 4: Comprobar que pasa**

Run: `flutter test test/nightstand_idle_test.dart`
Expected: PASS.

- [ ] **Step 5: Colgarlo del reproductor completo**

En `lib/features/player/full_player.dart`, añadir los imports:

```dart
import '../nightstand/idle_watcher.dart';
import '../nightstand/nightstand.dart';
```

Y envolver lo que devuelve `build`. El `Stack` que hoy es la raíz pasa a ser el
hijo de un `StreamBuilder` con el `IdleWatcher` dentro:

```dart
  @override
  Widget build(BuildContext context) {
    final art = widget.item.artUri?.toString();
    final size = MediaQuery.sizeOf(context);

    final sideBySide = size.width > size.height;

    // This widget is only built once the panel is past a quarter of its
    // travel, so "the player is open" — one of the two conditions for the
    // nightstand to come up by itself — comes free with being mounted.
    return StreamBuilder<PlaybackState>(
      stream: playerService.playbackState,
      builder: (context, snapshot) => IdleWatcher(
        seconds: settings.nightstandIdleSeconds,
        enabled: snapshot.data?.playing ?? false,
        onIdle: () => openNightstand(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ... el contenido actual, sin cambios
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 6: Comprobar que nada se rompió**

Run: `flutter analyze && flutter test`
Expected: análisis limpio y toda la suite en verde.

- [ ] **Step 7: Commit**

```bash
git add lib/features/nightstand/idle_watcher.dart lib/features/player/full_player.dart test/nightstand_idle_test.dart
git commit -m "Let the nightstand come up on its own after a quiet minute

The watcher hangs off the full player, which is only mounted once the
panel is a quarter of the way up — so "the player is open" costs nothing
to check.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Entrar al enchufar

**Files:**
- Create: `lib/features/nightstand/charge_watcher.dart`
- Modify: `lib/main.dart:37-53`, `lib/main.dart:175-187`, `lib/main.dart:211-240`
- Test: `test/nightstand_charge_test.dart`

**Interfaces:**
- Consumes: `openNightstand` y `nightstandIsOpen` de Task 2,
  `settings.nightstandOnCharge` de Task 1.
- Produces: `bool shouldEnterOnCharge({required BatteryState state, required bool enabled, required bool playing})`,
  `class ChargeWatcher` con `ChargeWatcher({required GlobalKey<NavigatorState> navigatorKey})`
  y `void start()`; y en `main.dart` los globales
  `final navigatorKey = GlobalKey<NavigatorState>()` y
  `late final ChargeWatcher chargeWatcher`.

- [ ] **Step 1: Escribir la prueba que falla**

Crear `test/nightstand_charge_test.dart`:

```dart
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/features/nightstand/charge_watcher.dart';

/// The plugin is not worth mocking; the rule it feeds is. Three conditions,
/// and the one that is easy to get wrong is that unplugging is a battery event
/// too.
void main() {
  test('plugged in, playing, and asked for', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.charging,
        enabled: true,
        playing: true,
      ),
      isTrue,
    );
  });

  test('a full battery still counts as plugged in', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.full,
        enabled: true,
        playing: true,
      ),
      isTrue,
    );
  });

  test('unplugging is an event too, and not one that opens anything', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.discharging,
        enabled: true,
        playing: true,
      ),
      isFalse,
    );
  });

  test('silence on the charger is just a phone on a charger', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.charging,
        enabled: true,
        playing: false,
      ),
      isFalse,
    );
  });

  test('off is off', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.charging,
        enabled: false,
        playing: true,
      ),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Comprobar que falla**

Run: `flutter test test/nightstand_charge_test.dart`
Expected: FAIL — no existe `charge_watcher.dart`.

- [ ] **Step 3: Implementar el vigilante**

Crear `lib/features/nightstand/charge_watcher.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import 'nightstand.dart';

/// Whether a battery event is the one that means "put the phone down for the
/// night". Pure, because the three conditions are the whole feature and the
/// plugin around them is not worth standing in for.
bool shouldEnterOnCharge({
  required BatteryState state,
  required bool enabled,
  required bool playing,
}) {
  if (!enabled || !playing) return false;
  return state == BatteryState.charging || state == BatteryState.full;
}

/// Brings the nightstand up when the phone is plugged in with music playing.
///
/// It holds the navigator key rather than a [BuildContext] because it is not
/// part of any widget: it outlives every screen and has to be able to push
/// from a stream callback.
class ChargeWatcher {
  ChargeWatcher({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  StreamSubscription<BatteryState>? _states;

  void start() {
    // The only two platforms where the question means anything: a laptop on
    // mains is not a phone on a nightstand.
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _states = Battery().onBatteryStateChanged.listen(_onState);
  }

  Future<void> dispose() async {
    await _states?.cancel();
    _states = null;
  }

  void _onState(BatteryState state) {
    if (nightstandIsOpen) return;
    final playing = playerService.playbackState.value.playing;
    if (!shouldEnterOnCharge(
      state: state,
      enabled: settings.nightstandOnCharge,
      playing: playing,
    )) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;
    unawaited(openNightstand(context));
  }
}
```

- [ ] **Step 4: Comprobar que pasa**

Run: `flutter test test/nightstand_charge_test.dart`
Expected: PASS.

- [ ] **Step 5: Conectarlo en `main.dart`**

Añadir el import:

```dart
import 'features/nightstand/charge_watcher.dart';
```

Junto a los demás globales (alrededor de la línea 53):

```dart
/// The navigator, reachable from things that are not widgets. The nightstand's
/// charge watcher is the first of them: it lives on a stream, not on a screen.
final navigatorKey = GlobalKey<NavigatorState>();

late final ChargeWatcher chargeWatcher;
```

En `main()`, después de `playerService.mediaItem.listen(...)` y antes de
`runApp`:

```dart
  // Started before the first frame; the key it holds is only read once a
  // battery event arrives, which is long after the navigator exists.
  chargeWatcher = ChargeWatcher(navigatorKey: navigatorKey)..start();
```

En `TuneboxApp.build`, dentro del `MaterialApp`:

```dart
        navigatorKey: navigatorKey,
```

- [ ] **Step 6: Comprobar que nada se rompió**

Run: `flutter analyze && flutter test`
Expected: análisis limpio y toda la suite en verde.

- [ ] **Step 7: Commit**

```bash
git add lib/features/nightstand/charge_watcher.dart lib/main.dart test/nightstand_charge_test.dart
git commit -m "Bring the nightstand up when the phone goes on the charger

The watcher holds the navigator key rather than a context: it lives on a
battery stream, not on a screen.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Verificar en el aparato y cerrar el ciclo

**Files:**
- Modify: `docs/pendientes.md`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: nada.

- [ ] **Step 1: Instalar y abrir**

```bash
flutter analyze && flutter test
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.tunebox.tunebox -c android.intent.category.LAUNCHER 1
```

- [ ] **Step 2: Recorrer las tres vías con captura**

Poner algo a sonar, y de cada paso una captura con
`adb exec-out screencap -p > shot.png` en el directorio de scratchpad de la sesión:

1. Reproductor completo → ⚙/🌙 → **Modo mesita de noche**. Comprobar: fondo
   negro, reloj con la hora del sistema, carátula, un toque trae los controles
   y a los cinco segundos se van, el chevron sale, atrás también sale.
2. Ajustes → **Mesita de noche**. Apagar el reloj y el progreso, volver a
   entrar, comprobar que faltan esos dos y están los otros dos. Poner los
   controles en *Ocultos* y comprobar que un toque sale.
3. Poner el retardo en 30 s, dejar el reproductor completo abierto sin tocar y
   comprobar que entra solo. Tocar antes de los 30 s y comprobar que no entra.
4. Con `nightstandOnCharge` puesto y algo sonando, `adb shell dumpsys battery
   set ac 1` y comprobar que entra; `adb shell dumpsys battery reset` después.
5. Salir y comprobar que **el brillo vuelve** a lo que era y que las barras de
   estado y navegación vuelven.

- [ ] **Step 3: Anotar lo que el emulador no puede contestar**

El brillo por aplicación y el estado de carga son de los que el emulador
contesta de forma distinta a un teléfono. Si alguno no se comporta, apuntarlo en
la sección **Suelto, sin diagnosticar** de `docs/pendientes.md` en vez de
retorcer el código contra el emulador.

- [ ] **Step 4: Mover el punto 1 a Hecho**

En `docs/pendientes.md`, borrar el punto 1 de **Pendiente**, renumerar los otros
dos, y añadir arriba de **Hecho** un párrafo que diga qué se construyó y qué
decisión no obvia lleva dentro: que las dos activaciones automáticas nacen
apagadas, y que esta pantalla no es el AOD del sistema sino su contraria — el
teléfono despierto, con el wakelock tomado.

- [ ] **Step 5: Commit**

```bash
git add docs/pendientes.md
git commit -m "Note that the nightstand is done

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Pedir el `/clear`**

El feature está cerrado y el estado vive en `docs/pendientes.md`. Resumir en dos
líneas y decir explícitamente que toca `/clear` antes del siguiente.
