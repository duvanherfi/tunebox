import 'dart:io';

import 'package:audio_service/audio_service.dart';
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

import 'fake_audio_platform.dart';

/// An [InnertubeClient] that resolves whatever it is told to and refuses the
/// rest, which is what a real liked-songs playlist looks like: most tracks
/// play, a few are not served to anyone.
class _StubInnertube extends InnertubeClient {
  _StubInnertube({this.unplayable = const {}});

  final Set<String> unplayable;

  /// Every track this was asked to resolve, in order.
  final asked = <String>[];

  @override
  Future<AudioStream> resolveStream(String videoId, {int passes = 2}) async {
    asked.add(videoId);
    if (unplayable.contains(videoId)) {
      throw InnertubeException('Video unavailable');
    }
    return AudioStream(
      url: 'https://example.invalid/$videoId',
      bitrate: 128000,
      mimeType: 'audio/mp4',
      userAgent: 'test',
      cpn: 'cpn',
    );
  }

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
  late FakeJustAudio platform;
  late _StubInnertube innertube;
  late PlayerService player;

  Future<PlayerService> build({Set<String> unplayable = const {}}) async {
    innertube = _StubInnertube(unplayable: unplayable);
    final settings = Settings()
      // Straight to setUrl: the caching source would stand up just_audio's own
      // proxy, which has nothing to do with what these tests are about.
      ..cacheEnabled = false;
    return player = PlayerService(
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
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('tunebox_player');
    platform = FakeJustAudio();
    JustAudioPlatform.instance = platform;
  });

  tearDown(() async {
    await player.stop();
    // Writes the player started on its way out still have to land before the
    // directory under them disappears.
    await pumpEventQueue();
    await temp.delete(recursive: true);
  });

  test('plays the queue in order when every track resolves', () async {
    await build();
    await player.setQueue([_song('a'), _song('b'), _song('c')]);
    expect(player.currentSong?.videoId, 'a');

    platform.player.reachTheEnd();
    await pumpEventQueue();

    expect(player.currentSong?.videoId, 'b');
  });

  test('steps over a track no client will serve', () async {
    await build(unplayable: {'b'});
    await player.setQueue([_song('a'), _song('b'), _song('c')]);
    expect(player.currentSong?.videoId, 'a');

    platform.player.reachTheEnd();
    await pumpEventQueue();

    // 'b' was tried and refused, so the music has to be on 'c'. Stopping dead
    // at the end of 'a' is the bug this guards.
    expect(innertube.asked, ['a', 'b', 'c']);
    expect(player.currentSong?.videoId, 'c');
    expect(player.playbackState.value.playing, isTrue);
  });

  test('skipping forward by hand also steps over a refused track', () async {
    await build(unplayable: {'b'});
    await player.setQueue([_song('a'), _song('b'), _song('c')]);

    await player.skipToNext();
    await pumpEventQueue();

    expect(player.currentSong?.videoId, 'c');
  });

  test('starts the queue on the first track that will actually play', () async {
    await build(unplayable: {'a'});
    await player.setQueue([_song('a'), _song('b')]);
    await pumpEventQueue();

    expect(player.currentSong?.videoId, 'b');
  });

  test('gives up rather than spinning when nothing in the queue plays',
      () async {
    await build(unplayable: {'a', 'b', 'c'});
    await player.setQueue([_song('a'), _song('b'), _song('c')]);
    await pumpEventQueue();

    expect(player.playbackState.value.playing, isFalse);
    // Each track tried once, not over and over.
    expect(innertube.asked.length, lessThanOrEqualTo(4));
  });

  test('a queue that ran out with repeat on comes back to the top', () async {
    await build();
    await player.setQueue([_song('a'), _song('b')]);
    await player.setRepeatMode(AudioServiceRepeatMode.all);
    await player.skipToNext();
    await pumpEventQueue();
    expect(player.currentSong?.videoId, 'b');

    platform.player.reachTheEnd();
    await pumpEventQueue();

    expect(player.currentSong?.videoId, 'a');
  });

  test('repeat one plays the same track again', () async {
    await build();
    await player.setQueue([_song('a'), _song('b')]);
    await player.setRepeatMode(AudioServiceRepeatMode.one);

    platform.player.reachTheEnd();
    await pumpEventQueue();

    expect(player.currentSong?.videoId, 'a');
    expect(innertube.asked, ['a', 'a']);
  });
}
