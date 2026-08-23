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
  _StubInnertube({this.unplayable = const {}, this.mix = const []});

  final Set<String> unplayable;

  /// What [radio] answers, which is how a queue running dry is exercised.
  final List<Song> mix;

  /// Every seed [radio] was asked about.
  final radios = <String>[];

  /// What [shuffledCollection] answers, a page at a time. Empty means YouTube
  /// would not shuffle this one, which is the fallback the caller has to take.
  List<List<Song>> shuffledPages = const [];

  /// Every collection [shuffledCollection] was asked to shuffle.
  final shuffles = <String>[];

  @override
  Future<({List<Song> songs, String? continuation})> shuffledCollection(
    String playlistId,
  ) async {
    shuffles.add(playlistId);
    if (shuffledPages.isEmpty) return (songs: <Song>[], continuation: null);
    return _page(0);
  }

  @override
  Future<({List<Song> songs, String? continuation})> watchQueueAfter(
    String continuation,
  ) async =>
      _page(int.parse(continuation));

  ({List<Song> songs, String? continuation}) _page(int at) => (
        songs: shuffledPages[at],
        continuation:
            at + 1 < shuffledPages.length ? '${at + 1}' : null,
      );

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
  Future<List<Song>> radio(String videoId) async {
    radios.add(videoId);
    return mix.where((song) => song.videoId != videoId).toList();
  }
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
  late Settings settings;
  late PlayerService player;

  Future<PlayerService> build({
    Set<String> unplayable = const {},
    List<Song> mix = const [],
  }) async {
    innertube = _StubInnertube(unplayable: unplayable, mix: mix);
    settings = Settings()
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

    test('turning it on leaves the whole rest of the queue still to come',
        () async {
      await build();
      await player.setQueue(twenty());
      await player.skipToNext();
      await pumpEventQueue();
      expect(player.currentSong?.videoId, 's1');

      await player.setShuffleMode(AudioServiceShuffleMode.all);

      // The music does not stop to be shuffled: whatever was on is still on.
      expect(player.currentSong?.videoId, 's1');
      expect(player.songs, hasLength(20));

      // And nothing unheard was shuffled behind it. Landing the playing track
      // at a random place is what used to happen, and it made everything that
      // fell above it unreachable for the rest of the pass: shuffling a
      // hundred tracks from the second one played, on average, fifty.
      final ahead = player.songs
          .sublist(player.currentIndex + 1)
          .map((song) => song.videoId)
          .toSet();
      expect(ahead, {for (var i = 2; i < 20; i++) 's$i'});
    });

    test('what is still to come really is shuffled', () async {
      var everReordered = false;
      for (var attempt = 0; attempt < 20 && !everReordered; attempt++) {
        await build();
        await player.setQueue(twenty());
        await player.setShuffleMode(AudioServiceShuffleMode.all);
        final order = player.songs.map((song) => song.videoId).join(',');
        if (order != [for (var i = 0; i < 20; i++) 's$i'].join(',')) {
          everReordered = true;
        }
      }

      expect(everReordered, isTrue, reason: 'the queue came back in order');
    });

    test('each lap with repeat on is a new order', () async {
      await build();
      await player.setShuffleMode(AudioServiceShuffleMode.all);
      await player.setQueue(twenty());
      await player.setRepeatMode(AudioServiceRepeatMode.all);

      final firstLap = player.songs.map((song) => song.videoId).toList();
      for (var i = 0; i < 20; i++) {
        await player.skipToNext();
        await pumpEventQueue();
      }
      final secondLap = player.songs.map((song) => song.videoId).toList();

      // Twenty tracks have 20! orders; coming back identical is not luck.
      expect(secondLap, isNot(firstLap));
      expect(secondLap.toSet(), firstLap.toSet());
    });

    test('the radio that keeps the music going arrives shuffled too', () async {
      final mix = [for (var i = 0; i < 20; i++) _song('r$i')];
      var everReordered = false;
      for (var attempt = 0; attempt < 20 && !everReordered; attempt++) {
        await build(mix: mix);
        await player.setShuffleMode(AudioServiceShuffleMode.all);
        await player.setQueue([_song('seed')]);

        platform.player.reachTheEnd();
        await pumpEventQueue();

        final added = player.songs
            .where((song) => song.videoId.startsWith('r'))
            .map((song) => song.videoId)
            .toList();
        expect(added, hasLength(20));
        if (added.join(',') != [for (var i = 0; i < 20; i++) 'r$i'].join(',')) {
          everReordered = true;
        }
      }

      expect(
        everReordered,
        isTrue,
        reason: 'the radio was appended in the order YouTube listed it',
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

  test('a queue that runs out carries on with a radio', () async {
    await build(mix: [_song('r0'), _song('r1')]);
    await player.setQueue([_song('a')]);
    expect(player.currentSong?.videoId, 'a');

    platform.player.reachTheEnd();
    await pumpEventQueue();

    expect(innertube.radios, ['a']);
    expect(player.songs.map((song) => song.videoId).toList(),
        containsAll(['r0', 'r1']));
    expect(player.currentSong?.videoId, isIn(['r0', 'r1']));
    expect(player.playbackState.value.playing, isTrue);
  });

  test('a queue that runs out again asks for another radio', () async {
    await build(mix: [_song('r0')]);
    await player.setQueue([_song('a')]);

    platform.player.reachTheEnd();
    await pumpEventQueue();
    expect(player.currentSong?.videoId, 'r0');

    // The mix is one track long, so the second ending finds the queue dry
    // again. Silence here is the queue stopping to expand after one go.
    platform.player.reachTheEnd();
    await pumpEventQueue();

    expect(innertube.radios, ['a', 'r0']);
  });

  test('turning autoplay off lets the queue end', () async {
    await build(mix: [_song('r0')]);
    settings.autoplay = false;
    await player.setQueue([_song('a')]);

    platform.player.reachTheEnd();
    await pumpEventQueue();

    expect(innertube.radios, isEmpty);
    expect(player.songs, hasLength(1));
  });

  group('a collection YouTube shuffles itself', () {
    test('plays the order the server gave, untouched', () async {
      await build();
      innertube.shuffledPages = [
        [_song('c'), _song('a'), _song('b')],
      ];

      final done = await player.shuffleCollection(
        'VLPL123',
        inOrder: [_song('a'), _song('b'), _song('c')],
      );

      expect(done, isTrue);
      expect(innertube.shuffles, ['VLPL123']);
      // Shuffling it again here would be shuffling a shuffle, and would undo
      // the one thing the server was asked for: a draw over the whole list.
      expect(player.songs.map((song) => song.videoId).toList(),
          ['c', 'a', 'b']);
      expect(player.currentSong?.videoId, 'c');
      expect(
        player.playbackState.value.shuffleMode,
        AudioServiceShuffleMode.all,
      );
    });

    test('the rest of the draw lands behind the music', () async {
      await build();
      innertube.shuffledPages = [
        [_song('c'), _song('a')],
        [_song('e'), _song('d')],
      ];

      await player.shuffleCollection('PL123');
      await pumpEventQueue();

      expect(player.songs.map((song) => song.videoId).toList(),
          ['c', 'a', 'e', 'd']);
      // And the music never waited for it.
      expect(player.currentSong?.videoId, 'c');
    });

    test('turning shuffle off goes back to the list, whole', () async {
      await build();
      innertube.shuffledPages = [
        [_song('c'), _song('z'), _song('a')],
      ];

      // 'z' is one the shuffle drew from past the pages the screen holds.
      await player.shuffleCollection(
        'PL123',
        inOrder: [_song('a'), _song('b'), _song('c')],
      );
      await player.setShuffleMode(AudioServiceShuffleMode.none);

      // The screen's order first, and what it had never listed kept on the
      // end. Dropping 'z' would make turning shuffle off shorten the queue.
      expect(player.songs.map((song) => song.videoId).toList(),
          ['a', 'c', 'z']);
    });

    test('the rest of the draw does not double what the list already had',
        () async {
      await build();
      // The second page brings back tracks the screen had listed all along —
      // which is the normal case, since the shuffle draws from the same list.
      innertube.shuffledPages = [
        [_song('c'), _song('z')],
        [_song('a'), _song('b')],
      ];

      await player.shuffleCollection(
        'PL123',
        inOrder: [_song('a'), _song('b'), _song('c')],
      );
      await pumpEventQueue();
      await player.setShuffleMode(AudioServiceShuffleMode.none);

      // Each of them once. Kept in both lists without checking, a track the
      // screen had and the draw brought back was counted twice, and the queue
      // came out longer than the playlist it came from.
      expect(player.songs.map((song) => song.videoId).toList(),
          ['a', 'b', 'c', 'z']);
    });

    test('a collection YouTube will not shuffle is left to the caller',
        () async {
      await build();
      innertube.shuffledPages = const [];

      expect(await player.shuffleCollection('PL123'), isFalse);
      expect(player.songs, isEmpty);
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
