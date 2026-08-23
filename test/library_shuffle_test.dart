import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/core/audio/player_service.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/core/scrobble/scrobbler.dart';
import 'package:tunebox/data/audio_cache.dart';
import 'package:tunebox/data/downloads.dart';
import 'package:tunebox/data/likes.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/play_history.dart';
import 'package:tunebox/data/resume_point.dart';
import 'package:tunebox/data/settings.dart';
import 'package:tunebox/features/shared/sorted_songs.dart';
import 'package:tunebox/l10n/app_localizations.dart';
import 'package:tunebox/main.dart' as app;

import 'fake_audio_platform.dart';
import 'temp_directory.dart';

/// The lists in the library are pages of a much longer list, so shuffling the
/// rows a screen holds shuffles its first hundred and never the rest. YouTube
/// shuffles the whole thing itself for the surfaces that have an id for it —
/// `LM` for the likes and `MLCT` for the library's songs — and the rest, which
/// live on this device, are shuffled here.
class _StubInnertube extends InnertubeClient {
  /// What [shuffledCollection] answers. Empty means YouTube would not shuffle
  /// this one, which is the fallback the caller has to take.
  List<Song> draw = const [];

  /// Every id [shuffledCollection] was asked to shuffle.
  final shuffles = <String>[];

  @override
  Future<({List<Song> songs, String? continuation})> shuffledCollection(
    String playlistId,
  ) async {
    shuffles.add(playlistId);
    return (songs: draw, continuation: null);
  }

  @override
  Future<AudioStream> resolveStream(String videoId, {int passes = 2}) async =>
      AudioStream(
        url: 'https://example.invalid/$videoId',
        bitrate: 128000,
        mimeType: 'audio/mp4',
        userAgent: 'test',
        cpn: 'cpn',
      );

  @override
  Future<List<AudioStream>> resolveStreams(
    String videoId, {
    int passes = 2,
  }) async =>
      [await resolveStream(videoId, passes: passes)];

  @override
  Future<void> reportPlayback(AudioStream stream) async {}

  @override
  Future<void> reportWatchtime(AudioStream stream, Duration position) async {}

  @override
  Future<List<Song>> radio(String videoId) async => const [];
}

Song _song(String id) => Song(
      videoId: id,
      title: id.toUpperCase(),
      subtitle: 'test',
      duration: const Duration(minutes: 3),
    );

void main() {
  late Directory temp;
  late _StubInnertube innertube;

  // The app's long-lived objects are `late final` globals, so they are built
  // once for the whole file; only what a test looks at is put back between
  // tests.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    JustAudioPlatform.instance = FakeJustAudio();
    temp = await Directory.systemTemp.createTemp('tunebox_shuffle');

    innertube = _StubInnertube();
    final settings = Settings()..cacheEnabled = false;
    app.playerService = PlayerService(
      innertube,
      PlayHistory(file: File('${temp.path}/history.json')),
      settings,
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
        radio: 'Radio',
      ),
    );
  });

  setUp(() async {
    innertube.draw = const [];
    innertube.shuffles.clear();
    await app.playerService.setShuffleMode(AudioServiceShuffleMode.none);
    await app.playerService.setQueue(const []);
  });

  tearDownAll(() async {
    await app.playerService.stop();
    // The writes the player started on its way out still have to land before
    // the directory under them disappears.
    await removeWhenSettled(temp);
  });

  Future<void> open(
    WidgetTester tester, {
    required List<Song> songs,
    String? shuffleId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SortedSongs(songs: songs, shuffleId: shuffleId),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pressing it is real work — a request, a queue, a track resolved — and
  /// none of that can land inside the fake clock a widget test runs on, so the
  /// press happens in [WidgetTester.runAsync] and the queue is waited for.
  Future<void> pressShuffle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      for (var i = 0; i < 200 && app.playerService.songs.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // The queue is published before the press is over — the shuffle mode it
      // reports goes out after — so the rest of it is waited for too.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('the library songs are shuffled on YouTube, whole', (
    tester,
  ) async {
    innertube.draw = [_song('z'), _song('a')];
    await open(tester, songs: [_song('a'), _song('b')], shuffleId: 'MLCT');

    await pressShuffle(tester);

    expect(innertube.shuffles, ['MLCT']);
    // The draw as it arrived: shuffling it here would undo the one thing the
    // server was asked for, a draw over the whole list — 'z' is a track this
    // screen had never listed.
    expect(
      app.playerService.songs.map((song) => song.videoId).toList(),
      ['z', 'a'],
    );
    expect(
      app.playerService.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.all,
    );
  });

  testWidgets('a list of this device is shuffled here', (tester) async {
    await open(tester, songs: [_song('a'), _song('b'), _song('c')]);

    await pressShuffle(tester);

    expect(innertube.shuffles, isEmpty);
    expect(
      app.playerService.songs.map((song) => song.videoId).toSet(),
      {'a', 'b', 'c'},
    );
    expect(
      app.playerService.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.all,
    );
  });

  testWidgets('a draw YouTube refuses falls back to what the screen holds', (
    tester,
  ) async {
    innertube.draw = const [];
    await open(tester, songs: [_song('a'), _song('b')], shuffleId: 'LM');

    await pressShuffle(tester);

    expect(innertube.shuffles, ['LM']);
    // Nothing came back, so the rows on screen are the whole queue rather
    // than a button that did nothing.
    expect(
      app.playerService.songs.map((song) => song.videoId).toSet(),
      {'a', 'b'},
    );
  });

  testWidgets('an empty list has nothing to shuffle', (tester) async {
    await open(tester, songs: const [], shuffleId: 'LM');

    expect(
      tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.shuffle_rounded),
        matching: find.byType(IconButton),
      )).onPressed,
      isNull,
    );
  });
}
