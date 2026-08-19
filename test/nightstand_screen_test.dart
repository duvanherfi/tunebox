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

  // The app's long-lived objects are `late final` globals, so they are built
  // once for the whole file; only the knobs are put back between tests.
  setUpAll(() async {
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

  /// Written out rather than cleared, because `load` only fills in what the
  /// preferences hold: an empty store leaves whatever the last test set.
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'nightstand_clock': true,
      'nightstand_art': true,
      'nightstand_title': true,
      'nightstand_progress': true,
      'nightstand_controls': 'onTouch',
      'nightstand_dim': 20,
      'nightstand_burn_in': true,
      'nightstand_idle_seconds': 0,
      'nightstand_on_charge': false,
    });
    await app.settings.load();
  });

  tearDownAll(() async {
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
