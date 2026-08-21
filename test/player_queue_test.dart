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
import 'temp_directory.dart';

/// An [InnertubeClient] that resolves whatever it is told to and refuses the
/// rest, which is what a real liked-songs playlist looks like: most tracks
/// play, a few are not served to anyone.
class _StubInnertube extends InnertubeClient {
  _StubInnertube({this.unplayable = const {}});

  final Set<String> unplayable;

  /// Every track this was asked to resolve, in order.
  final asked = <String>[];

  @override
  Future<List<AudioStream>> resolveStreams(
    String videoId, {
    int passes = 2,
  }) async =>
      [await resolveStream(videoId, passes: passes)];

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
    // The writes the player started on its way out still have to land before
    // the directory under them disappears.
    await removeWhenSettled(temp);
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

  group('shuffle', () {
    // Twenty is enough that a track staying at the front twenty times running
    // is a rule rather than luck: one in twenty to the twentieth.
    List<Song> twenty() => [
      for (var i = 0; i < 20; i++) _song('s$i'),
    ];

    test('does not lift the playing track to the front', () async {
      await build();
      await player.setQueue(twenty());
      expect(player.currentSong?.videoId, 's0');

      var everOffTheFront = false;
      for (var attempt = 0; attempt < 20 && !everOffTheFront; attempt++) {
        await player.setShuffleMode(AudioServiceShuffleMode.all);

        // The music does not stop to be shuffled: whatever was on is still on.
        expect(player.currentSong?.videoId, 's0');
        expect(player.songs, hasLength(20));

        if (player.currentIndex != 0) everOffTheFront = true;
      }

      expect(
        everOffTheFront,
        isTrue,
        reason: 'shuffling kept opening on the track already playing',
      );
    });

    test('a collection shuffled does not always open on track one', () async {
      final opened = <String?>{};
      for (var attempt = 0; attempt < 20; attempt++) {
        await build();
        await player.setShuffleMode(AudioServiceShuffleMode.all);
        // No track asked for: this is the shuffle button on a playlist, which
        // hands over the list and no opinion about where to begin.
        await player.setQueue(twenty());
        opened.add(player.currentSong?.videoId);
      }

      expect(opened, hasLength(greaterThan(1)));
    });

    test('shuffling a playlist while something else plays still opens at '
        'random', () async {
      final opened = <String?>{};
      for (var attempt = 0; attempt < 20; attempt++) {
        await build();
        // Something else is on, from somewhere else. Pressing shuffle on a
        // playlist means that playlist, from wherever the shuffle decides —
        // what was playing was another list, not this one's first track.
        await player.setQueue([_song('elsewhere')]);
        expect(player.currentSong?.videoId, 'elsewhere');

        await player.setShuffleMode(AudioServiceShuffleMode.all);
        await player.setQueue(twenty());
        opened.add(player.currentSong?.videoId);
      }

      expect(opened, isNot(contains('elsewhere')));
      expect(opened, hasLength(greaterThan(1)));
    });

    test('a track tapped while shuffled is the one that plays', () async {
      await build();
      await player.setShuffleMode(AudioServiceShuffleMode.all);
      await player.setQueue(twenty(), startIndex: 7);

      // Tapping a row means "play this one", shuffled or not. What changes is
      // the order of everything else.
      expect(player.currentSong?.videoId, 's7');
      expect(player.songs[player.currentIndex].videoId, 's7');
    });

    test('turning it off restores the order with the track still current',
        () async {
      await build();
      await player.setQueue(twenty());
      await player.setShuffleMode(AudioServiceShuffleMode.all);
      final playing = player.currentSong?.videoId;

      await player.setShuffleMode(AudioServiceShuffleMode.none);

      expect(player.songs.map((song) => song.videoId).toList(), [
        for (var i = 0; i < 20; i++) 's$i',
      ]);
      expect(player.currentSong?.videoId, playing);
    });
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
