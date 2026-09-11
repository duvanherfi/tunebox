import 'dart:io';

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
import 'package:tunebox/data/models/playlist.dart';
import 'package:tunebox/data/models/search.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/play_history.dart';
import 'package:tunebox/data/recent_searches.dart';
import 'package:tunebox/data/resume_point.dart';
import 'package:tunebox/data/settings.dart';
import 'package:tunebox/features/search/search_screen.dart';
import 'package:tunebox/l10n/app_localizations.dart';
import 'package:tunebox/main.dart' as app;

import 'fake_audio_platform.dart';
import 'temp_directory.dart';

/// Search results are ranked answers to a query, not a list anyone chose to
/// hear in order: playing one used to seed the queue with the other thirteen,
/// so the radio for the track that was actually tapped only started an hour
/// later, when they had all been played.
class _StubInnertube extends InnertubeClient {
  /// What [search] answers with.
  SearchResults results = const SearchResults();

  /// What [radio] answers with, and the seeds it was asked about.
  List<Song> related = const [];
  final seeds = <String>[];

  @override
  Future<SearchResults> search(String query, {String? params}) async => results;

  @override
  Future<List<String>> searchSuggestions(String query) async => const [];

  @override
  Future<List<Song>> radio(String videoId) async {
    seeds.add(videoId);
    return related;
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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    JustAudioPlatform.instance = FakeJustAudio();
    temp = await Directory.systemTemp.createTemp('tunebox_search_radio');

    innertube = _StubInnertube();
    app.innertube = innertube;
    app.recentSearches = RecentSearches();
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
    innertube.seeds.clear();
    await app.playerService.setQueue(const []);
  });

  tearDownAll(() async {
    await app.playerService.stop();
    await removeWhenSettled(temp);
  });

  /// Searching and playing are both real work — a request, a queue, a track
  /// resolved — and none of it lands inside the fake clock of a widget test,
  /// so both happen in [WidgetTester.runAsync].
  Future<void> search(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SearchScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'daft punk');
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String title) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(title));
      for (var i = 0; i < 200 && app.playerService.songs.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // The radio is fetched after the track is queued, so the rest of the tap
      // is waited for too.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('a result plays with its radio behind it, not the other results',
      (tester) async {
    innertube.results = SearchResults(
      results: [
        SearchResult.song(_song('one')),
        SearchResult.song(_song('two')),
        SearchResult.song(_song('three')),
      ],
    );
    innertube.related = [_song('after'), _song('later')];

    await search(tester);
    await tap(tester, 'ONE');

    expect(innertube.seeds, ['one']);
    expect(
      app.playerService.songs.map((song) => song.videoId).toList(),
      ['one', 'after', 'later'],
    );
  });

  testWidgets('a row that is a page is left where it is', (tester) async {
    innertube.results = SearchResults(
      results: [
        const SearchResult.collection(
          Playlist(
            browseId: 'MPREb_album',
            title: 'Discovery',
            subtitle: 'Album',
          ),
          CollectionKind.album,
        ),
        SearchResult.song(_song('one')),
      ],
    );
    innertube.related = [_song('after')];

    await search(tester);
    await tap(tester, 'ONE');

    // The album above it is not a track and never was part of the queue; what
    // follows the tapped track is the radio, seeded by that track alone.
    expect(innertube.seeds, ['one']);
    expect(
      app.playerService.songs.map((song) => song.videoId).toList(),
      ['one', 'after'],
    );
  });
}
