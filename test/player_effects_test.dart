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

/// Answers with two formats for every track, as a real response does.
class _TwoFormatInnertube extends InnertubeClient {
  @override
  Future<List<AudioStream>> resolveStreams(
    String videoId, {
    int passes = 2,
  }) async =>
      [
        AudioStream(
          url: 'https://example.invalid/$videoId.webm',
          bitrate: 160000,
          mimeType: 'audio/webm; codecs="opus"',
          userAgent: 'test',
          cpn: 'cpn',
        ),
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

/// Answers with one format, stating its length — or leaving it out.
class _DeclaredDurationInnertube extends InnertubeClient {
  _DeclaredDurationInnertube(this._duration);

  final Duration? _duration;

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
          duration: _duration,
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

/// The equalizer and the loudness enhancer are Android's own, and just_audio
/// activates every effect in the pipeline whatever the platform — so carrying
/// them elsewhere makes each track throw MissingPluginException on load and the
/// queue steps over the whole list in silence. Measured on macOS.
///
/// This cannot be caught by playing a track in a test: the fake platform
/// answers `androidEqualizerGetParameters` on every host, so the double is more
/// capable than the real thing. What is pinned here is the decision itself.
void main() {
  late Directory temp;
  late FakeJustAudio platform;
  late PlayerService player;

  PlayerService build([InnertubeClient? client]) {
    final innertube = client ?? InnertubeClient();
    return player = PlayerService(
      innertube,
      PlayHistory(file: File('${temp.path}/history.json')),
      Settings(),
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
    temp = await Directory.systemTemp.createTemp('tunebox_effects');
    platform = FakeJustAudio();
    JustAudioPlatform.instance = platform;
  });

  tearDown(() async {
    await player.stop();
    // The writes the player started on its way out still have to land before
    // the directory under them disappears.
    await removeWhenSettled(temp);
  });

  test('carries no Android audio effects off Android', () {
    build();

    expect(PlayerService.supportsEqualizer, Platform.isAndroid);
    expect(player.equalizer, Platform.isAndroid ? isNotNull : isNull);
  });

  // Same shape of problem, other end of the pipeline: just_audio's caching
  // source reaches the platform through its own stream source, and AVFoundation
  // answers AVErrorFileFormatNotRecognized (-11828) to every track that arrives
  // that way — mp4 included. Measured on macOS: with caching off the same track
  // plays. The fake platform loads anything, so what is pinned is the decision.
  test('caches while streaming only where that has been measured to work', () {
    expect(PlayerService.supportsStreamCaching, Platform.isAndroid);
  });

  // The point of carrying alternates: a container this player cannot open is
  // not a track it has to lose. Measured on macOS, where AVFoundation refuses
  // WebM outright and the queue used to skip the whole list.
  test('falls back to the next format when the player refuses one', () async {
    build(_TwoFormatInnertube());

    platform.rejectLoads = 1;

    await player.setQueue(const [
      Song(videoId: 'abc', title: 'ABC', subtitle: 'test'),
    ]);

    expect(
      platform.player.loaded,
      hasLength(2),
      reason: 'the refused format is tried first, then the one that opens',
    );
    expect(
      player.mediaItem.value?.id,
      'abc',
      reason: 'and the track is the one that was asked for, not a skip',
    );
  });

  // AVFoundation reads YouTube's fragmented mp4 audio as exactly twice its
  // length: `g06C6_UZ-vY` runs 4:53 and arrives as 9:46, `RtWEqRH0dBE` runs
  // 3:55 and arrives as 7:50. The music therefore stops halfway along the bar
  // and the counter goes on through silence for as long again before the queue
  // moves. Clipping to the length the server declared fixes both at once: the
  // platform reports the clip as the duration, and it ends the item there, so
  // no separate watchdog has to notice.
  test('stops a track where the server says it ends', () async {
    build(_DeclaredDurationInnertube(const Duration(minutes: 3, seconds: 55)));

    await player.setQueue(const [
      Song(videoId: 'abc', title: 'ABC', subtitle: 'test'),
    ]);

    expect(
      platform.player.clippedTo,
      [const Duration(minutes: 3, seconds: 55)],
      reason: 'the player is told to stop at the real end, not at its own',
    );
  });

  // Nothing to clip to is not a reason to refuse a track: a stream whose length
  // the server left out plays whole, the way it did before any of this.
  test('plays a stream of unstated length whole', () async {
    build(_DeclaredDurationInnertube(null));

    await player.setQueue(const [
      Song(videoId: 'abc', title: 'ABC', subtitle: 'test'),
    ]);

    expect(platform.player.clippedTo, [null]);
    expect(platform.player.loaded, hasLength(1));
  });
}
