/// A song's words, timed when the source had timings.
class Lyrics {
  const Lyrics({this.plain = '', this.lines = const []});

  /// The whole text, for songs nobody has synchronised.
  final String plain;

  /// Timed lines, in order. Empty when only plain text was available.
  final List<LyricLine> lines;

  bool get isSynced => lines.isNotEmpty;
  bool get isEmpty => plain.isEmpty && lines.isEmpty;

  /// Which line is being sung at [position], or -1 before the first one.
  ///
  /// A linear scan: lyrics run to a few dozen lines, and this is called once a
  /// second at most. Anything cleverer would be harder to read for no gain.
  int indexAt(Duration position) {
    var current = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].at > position) break;
      current = i;
    }
    return current;
  }

  /// Reads the LRC format: one line per line, each stamped `[mm:ss.xx]`.
  ///
  /// Stamps without text are section markers and metadata tags like `[ar:]`;
  /// both are dropped, since neither is anything to sing along to.
  factory Lyrics.parse(String? synced, String? plain) {
    final lines = <LyricLine>[];
    final pattern = RegExp(r'^\[(\d+):(\d+)(?:[.:](\d+))?\]\s*(.*)$');

    for (final raw in (synced ?? '').split('\n')) {
      final match = pattern.firstMatch(raw.trim());
      if (match == null) continue;

      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;

      final fraction = match.group(3);
      lines.add(LyricLine(
        at: Duration(
          minutes: int.parse(match.group(1)!),
          seconds: int.parse(match.group(2)!),
          milliseconds: fraction == null
              ? 0
              // Two digits are hundredths, three are already milliseconds.
              : int.parse(fraction.padRight(3, '0').substring(0, 3)),
        ),
        text: text,
      ));
    }

    return Lyrics(plain: plain?.trim() ?? '', lines: lines);
  }
}

class LyricLine {
  const LyricLine({required this.at, required this.text});

  final Duration at;
  final String text;
}
