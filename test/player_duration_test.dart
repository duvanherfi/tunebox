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

/// Serves any track, so these tests reach the moment the stream opens without
/// touching the network.
class _PlainInnertube extends InnertubeClient {
  @override
  Future<List<AudioStream>> resolveStreams(
    String videoId, {
    int passes = 2,
  }) async => [await resolveStream(videoId, passes: passes)];

  @override
  Future<AudioStream> resolveStream(String videoId, {int passes = 2}) async =>
      AudioStream(
        url: 'https://example.invalid/$videoId.m4a',
        bitrate: 128000,
        mimeType: 'audio/mp4',
        userAgent: 'test',
        cpn: 'cpn',
      );

  @override
  Future<void> reportPlayback(AudioStream stream) async {}

  @override
  Future<void> reportWatchtime(AudioStream stream, Duration position) async {}

  @override
  Future<List<Song>> radio(String videoId) async => const [];
}

/// A row as YouTube lists plenty of them: a video or a mix, with no length on
/// it. The player is the only one who will ever know how long it is.
Song _unmeasured(String id) =>
    Song(videoId: id, title: id.toUpperCase(), subtitle: 'test');

void main() {
  late Directory temp;
  late FakeJustAudio platform;
  late PlayerService player;

  Future<PlayerService> build({ResumePoint? resume}) async {
    final settings = Settings()..cacheEnabled = false;
    final innertube = _PlainInnertube();
    return player = PlayerService(
      innertube,
      PlayHistory(file: File('${temp.path}/history.json')),
      settings,
      Downloads(directory: Directory('${temp.path}/downloads')),
      AudioCache(directory: Directory('${temp.path}/cache')),
      Scrobbler(),
      Likes(innertube),
      resume ?? ResumePoint(file: File('${temp.path}/resume.json')),
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

  /// A resume point written by a previous run, holding [song] at [position].
  Future<ResumePoint> left(Song song, Duration position) async {
    final file = File('${temp.path}/resume.json');
    await ResumePoint(file: file).save(
      songs: [song],
      index: 0,
      position: position,
      shuffled: false,
      repeatMode: 0,
    );
    final restored = ResumePoint(file: file);
    await restored.load();
    return restored;
  }

  /// The last position the player put on screen.
  Future<Duration> shown() async {
    final seen = <Duration>[];
    final subscription = player.shownPosition.listen(seen.add);
    await pumpEventQueue();
    await subscription.cancel();
    return seen.last;
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('tunebox_duration');
    platform = FakeJustAudio();
    JustAudioPlatform.instance = platform;
  });

  tearDown(() async {
    await player.stop();
    await removeWhenSettled(temp);
  });

  test(
    'a track listed without a length keeps the one the player measured',
    () async {
      await build();
      await player.setQueue([_unmeasured('a')]);
      await pumpEventQueue();

      // The listing said nothing; the open stream says three minutes. Written
      // back, that length reaches the queue, the car and the resume point.
      expect(player.songs.single.duration, platform.player.duration);
    },
  );

  test('the measured length survives a shuffle', () async {
    await build();
    await player.setQueue([_unmeasured('a'), _unmeasured('b')]);
    await pumpEventQueue();

    await player.setShuffleMode(AudioServiceShuffleMode.all);
    await player.setShuffleMode(AudioServiceShuffleMode.none);

    expect(
      player.songs.firstWhere((song) => song.videoId == 'a').duration,
      platform.player.duration,
      reason: 'unshuffling rebuilt the queue from songs nobody measured',
    );
  });

  test('a restored track of unknown length shows no position', () async {
    await build(
      resume: await left(
        _unmeasured('a'),
        const Duration(minutes: 1, seconds: 13),
      ),
    );
    await player.restore();

    // Both labels have to talk about the same track. With no length to draw a
    // bar against, the right one reads 0:00, and a left one reading 1:13 next
    // to it is two answers to one question.
    expect(player.shownDuration, isNull);
    expect(await shown(), Duration.zero);
  });

  test('a restored track of known length shows where it will resume', () async {
    final measured = Song(
      videoId: 'a',
      title: 'A',
      subtitle: 'test',
      duration: const Duration(minutes: 3),
    );
    await build(
      resume: await left(measured, const Duration(minutes: 1, seconds: 13)),
    );
    await player.restore();

    expect(await shown(), const Duration(minutes: 1, seconds: 13));
  });
}
