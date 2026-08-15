import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/lyrics/lyrics.dart';

void main() {
  const lrc = '''
[ar:Portishead]
[00:31.52] I'm so tired of playing
[00:35.62] Playing with this bow and arrow
[01:05.00]
[01:12.5] Give me a reason to love you
''';

  test('reads timed lines and drops tags and empty stamps', () {
    final lyrics = Lyrics.parse(lrc, null);

    expect(lyrics.isSynced, isTrue);
    expect(lyrics.lines, hasLength(3));
    expect(lyrics.lines.first.at, const Duration(seconds: 31, milliseconds: 520));
    expect(lyrics.lines.first.text, "I'm so tired of playing");
  });

  test('reads a single-digit fraction as tenths, not milliseconds', () {
    final lyrics = Lyrics.parse(lrc, null);

    expect(lyrics.lines.last.at, const Duration(minutes: 1, seconds: 12, milliseconds: 500));
  });

  test('finds the line being sung, and none before the first', () {
    final lyrics = Lyrics.parse(lrc, null);

    expect(lyrics.indexAt(const Duration(seconds: 10)), -1);
    expect(lyrics.indexAt(const Duration(seconds: 33)), 0);
    expect(lyrics.indexAt(const Duration(minutes: 2)), 2);
  });

  test('falls back to plain text when nothing is timed', () {
    final lyrics = Lyrics.parse(null, 'one\ntwo');

    expect(lyrics.isSynced, isFalse);
    expect(lyrics.isEmpty, isFalse);
    expect(lyrics.plain, 'one\ntwo');
  });
}
