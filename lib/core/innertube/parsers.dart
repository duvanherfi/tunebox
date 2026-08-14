import '../../data/models/song.dart';

/// Reads a nested value, returning null instead of throwing when any hop is
/// missing. InnerTube responses are deeply nested and the shape varies between
/// result types, so absent keys are normal rather than exceptional.
Object? readPath(Object? node, List<Object> path) {
  var current = node;
  for (final key in path) {
    if (current is Map && key is String) {
      current = current[key];
    } else if (current is List && key is int && key < current.length) {
      current = current[key];
    } else {
      return null;
    }
  }
  return current;
}

/// Collects every value stored under [key], at any depth.
///
/// The rigid-path parsing that most InnerTube clients use breaks whenever
/// YouTube reorders a shelf or wraps results in a new container. Searching the
/// whole tree for the renderer we care about survives those reshuffles, which
/// is the difference between an app that keeps working for months and one that
/// needs a patch every few weeks.
List<Object?> findAll(Object? node, String key) {
  final results = <Object?>[];
  void walk(Object? current) {
    if (current is Map) {
      for (final entry in current.entries) {
        if (entry.key == key) {
          results.add(entry.value);
        } else {
          walk(entry.value);
        }
      }
    } else if (current is List) {
      current.forEach(walk);
    }
  }

  walk(node);
  return results;
}

Object? findFirst(Object? node, String key) {
  final all = findAll(node, key);
  return all.isEmpty ? null : all.first;
}

/// Joins the `runs` of a rich-text node into a plain string.
String _readRuns(Object? node) {
  final runs = readPath(node, ['runs']);
  if (runs is! List) return '';
  return runs
      .map((run) => readPath(run, ['text']))
      .whereType<String>()
      .join();
}

final _durationPattern = RegExp(r'(?:(\d+):)?(\d{1,2}):(\d{2})');

/// Finds a `h:mm:ss` or `m:ss` timestamp inside a metadata line.
///
/// YouTube separates the fields of a column with its own bullet character and
/// varies both the separator and the field order by result type, so the
/// timestamp is located by shape rather than by position. The last match wins:
/// when a title itself contains something clock-like, the real duration is
/// still the trailing value.
Duration? _parseDuration(String text) {
  final matches = _durationPattern.allMatches(text);
  if (matches.isEmpty) return null;
  final match = matches.last;
  return Duration(
    hours: int.tryParse(match.group(1) ?? '0') ?? 0,
    minutes: int.parse(match.group(2)!),
    seconds: int.parse(match.group(3)!),
  );
}

/// Turns a search response into playable tracks.
///
/// Items with no `videoId` — artist and album cards, "did you mean" rows — are
/// dropped, since this screen only offers things that can start playing.
List<Song> parseSearchResults(Map<String, dynamic> json) {
  final songs = <Song>[];
  final seen = <String>{};

  for (final item in findAll(json, 'musicResponsiveListItemRenderer')) {
    final videoId = findFirst(item, 'videoId');
    if (videoId is! String || !seen.add(videoId)) continue;

    final columns = readPath(item, ['flexColumns']);
    if (columns is! List || columns.isEmpty) continue;

    final texts = columns
        .map((column) => _readRuns(
            readPath(column, ['musicResponsiveListItemFlexColumnRenderer', 'text'])))
        .where((text) => text.isNotEmpty)
        .toList();
    if (texts.isEmpty) continue;

    final title = texts.first;
    final subtitle = texts.length > 1 ? texts.sublist(1).join(' · ') : '';

    final duration = _parseDuration(subtitle);

    final thumbnails = findFirst(item, 'thumbnails');
    String? thumbnailUrl;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
    }

    songs.add(Song(
      videoId: videoId,
      title: title,
      subtitle: subtitle,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
    ));
  }

  return songs;
}

/// Picks the best audio-only stream from a player response.
///
/// Only formats carrying a ready `url` are considered; anything behind a
/// `signatureCipher` would need a JavaScript interpreter to unscramble, and
/// the iOS client is used precisely so that never happens.
AudioStream? parseBestAudioStream(Map<String, dynamic> json) {
  final formats = readPath(json, ['streamingData', 'adaptiveFormats']);
  if (formats is! List) return null;

  AudioStream? best;
  for (final format in formats) {
    final mimeType = readPath(format, ['mimeType']);
    final url = readPath(format, ['url']);
    if (mimeType is! String || !mimeType.startsWith('audio') || url is! String) {
      continue;
    }
    final bitrate = (readPath(format, ['bitrate']) as num?)?.toInt() ?? 0;
    if (best == null || bitrate > best.bitrate) {
      best = AudioStream(url: url, bitrate: bitrate, mimeType: mimeType);
    }
  }
  return best;
}
