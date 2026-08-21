import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/core/audio/player_service.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/core/scrobble/scrobbler.dart';
import 'package:tunebox/data/audio_cache.dart';
import 'package:tunebox/data/downloads.dart';
import 'package:tunebox/data/likes.dart';
import 'package:tunebox/data/play_history.dart';
import 'package:tunebox/data/resume_point.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/settings.dart';

import 'fake_audio_platform.dart';
import 'temp_directory.dart';

/// Answers with one playable format and nothing else, so a test can get to the
/// fades without the queue reaching for the network.
class _PlainInnertube extends InnertubeClient {
  @override
  Future<List<AudioStream>> resolveStreams(
    String videoId, {
    int passes = 2,
  }) async =>
      [
        AudioStream(
          url: 'https://example.invalid/$videoId.m4a',
          bitrate: 128000,
          mimeType: 'audio/mp4; codecs="mp4a.40.2"',
          userAgent: 'test',
          cpn: 'cpn',
        ),
      ];

  @override
  Future<AudioStream> resolveStream(String videoId, {int passes = 2}) async =>
      (await resolveStreams(videoId)).first;

  @override
  Future<void> reportPlayback(AudioStream stream) async {}

  @override
  Future<void> reportWatchtime(AudioStream stream, Duration position) async {}

  @override
  Future<List<Song>> radio(String videoId) async => const [];
}

/// The fade lowers the volume towards the end of a track, and only the start of
/// the *next* track ever puts it back. Anything that returns the playhead to
/// the body of the same track therefore used to leave the rest of it playing
/// under a volume meant for its last second: the counter runs, the bar moves,
/// and nothing is heard.
void main() {
  late Directory temp;
  late FakeJustAudio platform;
  late Settings settings;
  late PlayerService player;

  PlayerService build() {
    final innertube = _PlainInnertube();
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

  /// Starts a track and waits out the fade-in, so what a test measures after
  /// this is the fade-out and nothing else.
  Future<void> playOneTrack() async {
    await player.setQueue(const [
      Song(videoId: 'abc', title: 'ABC', subtitle: 'test'),
    ]);
    await Future<void>.delayed(
      Duration(milliseconds: settings.fadeSeconds * 1000 + 400),
    );
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('tunebox_fade');
    platform = FakeJustAudio();
    JustAudioPlatform.instance = platform;
    settings = Settings()..fadeSeconds = 1;
  });

  tearDown(() async {
    await player.stop();
    // The writes the player started on its way out still have to land before
    // the directory under them disappears.
    await removeWhenSettled(temp);
  });

  test('raises the volume to full over the fade-in', () async {
    build();
    await playOneTrack();

    expect(platform.player.volume, 1);
  });

  test('puts the volume back when a seek leaves the fade-out behind', () async {
    build();
    await playOneTrack();

    // Inside the last second of a three-minute track: the fade-out has the
    // volume now, on its way down.
    platform.player.moveTo(const Duration(minutes: 2, seconds: 59, milliseconds: 500));
    await pumpEventQueue();
    expect(
      platform.player.volume,
      lessThan(1),
      reason: 'the fade-out is what this test is about; it has to have run',
    );

    // Dragged back into the body of the track.
    platform.player.moveTo(const Duration(minutes: 1));
    await pumpEventQueue();

    expect(
      platform.player.volume,
      1,
      reason: 'a track being played from the middle again has to be audible',
    );
  });

  test('puts the volume back when the fade-out interrupted the fade-in',
      () async {
    build();

    await player.setQueue(const [
      Song(videoId: 'abc', title: 'ABC', subtitle: 'test'),
    ]);
    // Halfway up the fade-in ramp rather than after it: a seek to the end here
    // hands the volume to the fade-out mid-climb, which is what used to strand
    // the fade-in for good.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    platform.player.moveTo(const Duration(minutes: 2, seconds: 59, milliseconds: 500));
    await pumpEventQueue();

    platform.player.moveTo(const Duration(minutes: 1));
    await pumpEventQueue();
    // Long enough that an abandoned fade-in ramp would have finished had it
    // still been running.
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    expect(
      platform.player.volume,
      1,
      reason: 'no path back into the track may leave it playing under a fade',
    );
  });
}
