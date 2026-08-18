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
import 'package:tunebox/data/models/playlist.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/play_history.dart';
import 'package:tunebox/data/resume_point.dart';
import 'package:tunebox/data/settings.dart';

import 'fake_audio_platform.dart';

/// The account a car is browsing, with the network either answering or not.
class _LibraryInnertube extends InnertubeClient {
  _LibraryInnertube({this.offline = false});

  /// Whether every library call fails, as it does in a tunnel.
  final bool offline;

  @override
  Future<List<Song>> likedSongs() async => _maybe([
        _song('like1'),
        _song('like2'),
        _song('like3'),
      ]);

  @override
  Future<List<Playlist>> savedPlaylists() async => _maybe(const [
        Playlist(browseId: 'PL1', title: 'Road trip', subtitle: '20 tracks'),
      ]);

  @override
  Future<List<Song>> playlistSongs(String playlistId) async =>
      _maybe([_song('$playlistId-a'), _song('$playlistId-b')]);

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
  Future<void> reportPlayback(AudioStream stream) async {}

  List<T> _maybe<T>(List<T> value) {
    if (offline) throw InnertubeException('no route to host');
    return value;
  }
}

/// Signed in, so the account shelves are offered.
class _SignedIn extends Likes {
  _SignedIn(super.innertube);

  @override
  bool get canLike => true;
}

Song _song(String id) => Song(
      videoId: id,
      title: id.toUpperCase(),
      subtitle: 'test',
      duration: const Duration(minutes: 3),
    );

void main() {
  late Directory temp;
  late PlayerService player;

  PlayerService build({bool offline = false}) {
    final innertube = _LibraryInnertube(offline: offline);
    return player = PlayerService(
      innertube,
      PlayHistory(file: File('${temp.path}/history.json')),
      Settings()..cacheEnabled = false,
      Downloads(directory: Directory('${temp.path}/downloads')),
      AudioCache(directory: Directory('${temp.path}/cache')),
      Scrobbler(),
      _SignedIn(innertube),
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
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('tunebox_car');
    JustAudioPlatform.instance = FakeJustAudio();
  });

  tearDown(() async {
    await player.stop();
    await pumpEventQueue();
    await temp.delete(recursive: true);
  });

  test('a signed-in car is offered the whole library', () async {
    build();
    final root = await player.getChildren(AudioService.browsableRootId);

    expect(root.map((item) => item.id), [
      'likes',
      'playlists',
      'albums',
      'artists',
      'downloads',
      'history',
    ]);
    // Every shelf carries an icon and a layout, which is what turns a car's
    // plain list into rows a driver can recognise at a glance.
    for (final item in root) {
      expect(item.playable, isFalse);
      expect(item.artUri, isNotNull, reason: '${item.id} has no icon');
      expect(item.extras?[AndroidContentStyle.supportedKey], isTrue);
    }
  });

  test('a car with no account is still offered what is on the phone', () async {
    final innertube = _LibraryInnertube();
    player = PlayerService(
      innertube,
      PlayHistory(file: File('${temp.path}/history.json')),
      Settings()..cacheEnabled = false,
      Downloads(directory: Directory('${temp.path}/downloads')),
      AudioCache(directory: Directory('${temp.path}/cache')),
      Scrobbler(),
      Likes(innertube), // canLike is false without a session
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

    final root = await player.getChildren(AudioService.browsableRootId);
    expect(root.map((item) => item.id), ['downloads', 'history']);
  });

  test('tapping a liked song plays the liked songs from there', () async {
    build();
    final liked = await player.getChildren('likes');
    expect(liked.map((item) => item.id),
        ['likes/like1', 'likes/like2', 'likes/like3']);

    await player.playFromMediaId('likes/like2');

    expect(player.currentSong?.videoId, 'like2');
    // The rest of the shelf came along, which is the whole point: a car has no
    // way to say "this one and then those".
    expect(player.songs.map((song) => song.videoId),
        ['like1', 'like2', 'like3']);
  });

  test('a playlist opens onto its own tracks and queues from there', () async {
    build();
    final playlists = await player.getChildren('playlists');
    expect(playlists.single.id, 'playlists/PL1');
    expect(playlists.single.playable, isFalse);

    final songs = await player.getChildren('playlists/PL1');
    expect(songs.map((item) => item.id),
        ['playlists/PL1/PL1-a', 'playlists/PL1/PL1-b']);

    await player.playFromMediaId('playlists/PL1/PL1-b');
    expect(player.currentSong?.videoId, 'PL1-b');
    expect(player.songs.length, 2);
  });

  test('a shelf the network refuses comes back empty, not thrown', () async {
    build(offline: true);

    // A dialog a driver has to dismiss is the wrong answer to a tunnel.
    expect(await player.getChildren('likes'), isEmpty);
    expect(await player.getChildren('playlists'), isEmpty);
  });

  test('the car can shuffle, repeat and start a radio', () async {
    build();
    await player.setQueue([_song('a'), _song('b')]);

    await player.customAction('shuffle');
    expect(player.playbackState.value.shuffleMode, AudioServiceShuffleMode.all);

    await player.customAction('repeat');
    expect(player.playbackState.value.repeatMode, AudioServiceRepeatMode.all);
    await player.customAction('repeat');
    expect(player.playbackState.value.repeatMode, AudioServiceRepeatMode.one);
    await player.customAction('repeat');
    expect(player.playbackState.value.repeatMode, AudioServiceRepeatMode.none);
  });
}
