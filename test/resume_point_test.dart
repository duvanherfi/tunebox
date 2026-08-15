import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/resume_point.dart';

Song _song(String id) => Song(videoId: id, title: 'Track $id', subtitle: '');

void main() {
  late Directory directory;

  ResumePoint point() =>
      ResumePoint(file: File('${directory.path}/resume.json'));

  setUp(() => directory = Directory.systemTemp.createTempSync('tunebox_resume'));
  tearDown(() => directory.deleteSync(recursive: true));

  test('remembers the queue, the track and the second it stopped on', () async {
    await point().save(
      songs: [_song('a'), _song('b'), _song('c')],
      index: 1,
      position: const Duration(minutes: 2, seconds: 13),
      shuffled: true,
      repeatMode: 2,
    );

    final restored = point();
    await restored.load();

    expect(restored.song?.videoId, 'b');
    expect(restored.position, const Duration(minutes: 2, seconds: 13));
    expect(restored.shuffled, isTrue);
    expect(restored.repeatMode, 2);
  });

  test('has nothing to restore before anything has played', () async {
    final fresh = point();
    await fresh.load();

    expect(fresh.isEmpty, isTrue);
    expect(fresh.song, isNull);
  });

  test('keeps the current track when a long radio is trimmed', () async {
    final long = [for (var i = 0; i < 500; i++) _song('$i')];

    await point().save(
      songs: long,
      index: 300,
      position: Duration.zero,
      shuffled: false,
      repeatMode: 0,
    );

    final restored = point();
    await restored.load();

    expect(restored.song?.videoId, '300',
        reason: 'trimming a queue must not drop what is playing');
  });

  test('survives a file that is not a resume point', () async {
    File('${directory.path}/resume.json').writeAsStringSync('not json');

    final restored = point();
    await restored.load();

    expect(restored.isEmpty, isTrue);
  });
}
