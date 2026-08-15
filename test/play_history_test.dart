import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/play_history.dart';

Song _song(String id, {String? artist}) =>
    Song(videoId: id, title: 'Track $id', subtitle: 'x', artist: artist);

void main() {
  late Directory directory;

  PlayHistory history({int limit = 5000}) => PlayHistory(
        limit: limit,
        file: File('${directory.path}/play_log.json'),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('tunebox_history');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('puts the newest play first', () async {
    final log = history();
    await log.load();

    await log.record(_song('a'));
    await log.record(_song('b'));

    expect(log.songs.map((song) => song.videoId), ['b', 'a']);
  });

  test('shows a repeated track once, at its latest play', () async {
    final log = history();
    await log.load();

    await log.record(_song('a'));
    await log.record(_song('b'));
    await log.record(_song('a'));

    expect(log.songs.map((song) => song.videoId), ['a', 'b']);
    expect(log.plays, hasLength(3), reason: 'every play is still counted');
  });

  test('survives a restart', () async {
    final first = history();
    await first.load();
    await first.record(const Song(
      videoId: 'a',
      title: 'Prayer',
      subtitle: 'Huun-Huur-Tu',
      duration: Duration(minutes: 4),
    ));

    final second = history();
    await second.load();

    expect(second.songs.single.title, 'Prayer');
    expect(second.songs.single.duration, const Duration(minutes: 4));
  });

  test('drops the oldest once it is full', () async {
    final log = history(limit: 2);
    await log.load();

    await log.record(_song('a'));
    await log.record(_song('b'));
    await log.record(_song('c'));

    expect(log.songs.map((song) => song.videoId), ['c', 'b']);
  });

  test('ranks what was played most', () async {
    final log = history();
    await log.load();

    await log.record(_song('a', artist: 'Portishead'));
    await log.record(_song('b', artist: 'Portishead'));
    await log.record(_song('a', artist: 'Portishead'));
    await log.record(_song('c', artist: 'Massive Attack'));

    final since = DateTime.now().subtract(const Duration(days: 1));
    expect(log.topSongs(since).first.song.videoId, 'a');
    expect(log.topSongs(since).first.plays, 2);
    expect(log.topArtists(since).first.artist, 'Portishead');
    expect(log.topArtists(since).first.plays, 3);
    expect(log.countSince(since), 4);
  });

  test('ignores plays from before the window', () async {
    final log = history();
    await log.load();
    await log.record(_song('a'));

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(log.topSongs(tomorrow), isEmpty);
    expect(log.countSince(tomorrow), 0);
  });

  test('carries over the history written before it was a log', () async {
    SharedPreferences.setMockInitialValues({
      'play_history': [
        '{"videoId":"old","title":"Older","subtitle":"","artist":"Someone"}',
      ],
    });

    final log = history();
    await log.load();

    expect(log.songs.single.videoId, 'old');
    expect(
      (await SharedPreferences.getInstance()).getStringList('play_history'),
      isNull,
      reason: 'the old copy is cleared once it has been carried over',
    );
  });
}
