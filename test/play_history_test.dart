import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/play_history.dart';

Song _song(String id) => Song(videoId: id, title: 'Track $id', subtitle: 'x');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('puts the newest play first', () async {
    final history = PlayHistory();
    await history.load();

    await history.record(_song('a'));
    await history.record(_song('b'));

    expect(history.songs.map((song) => song.videoId), ['b', 'a']);
  });

  test('moves a repeated track instead of listing it twice', () async {
    final history = PlayHistory();
    await history.load();

    await history.record(_song('a'));
    await history.record(_song('b'));
    await history.record(_song('a'));

    expect(history.songs.map((song) => song.videoId), ['a', 'b']);
  });

  test('survives a restart', () async {
    final first = PlayHistory();
    await first.load();
    await first.record(const Song(
      videoId: 'a',
      title: 'Prayer',
      subtitle: 'Huun-Huur-Tu',
      duration: Duration(minutes: 4),
    ));

    final second = PlayHistory();
    await second.load();

    expect(second.songs.single.title, 'Prayer');
    expect(second.songs.single.duration, const Duration(minutes: 4));
  });

  test('drops the oldest once it is full', () async {
    final history = PlayHistory(limit: 2);
    await history.load();

    await history.record(_song('a'));
    await history.record(_song('b'));
    await history.record(_song('c'));

    expect(history.songs.map((song) => song.videoId), ['c', 'b']);
  });
}
