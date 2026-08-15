import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/song.dart';
import 'lyrics.dart';

/// Fetches lyrics from LRCLIB.
///
/// Chosen because it needs no account, no key and no attribution dance, and
/// because it holds timed lyrics rather than only text. YouTube has its own,
/// but only for some tracks and only through the watch page, which is a much
/// heavier request for a worse answer.
class LyricsClient {
  LyricsClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _base = 'https://lrclib.net/api';

  /// LRCLIB asks that clients identify themselves, and it is a volunteer
  /// project — the least this app can do is say who is calling.
  static const _userAgent = 'Tunebox (https://github.com/tunebox)';

  final http.Client _http;

  /// Lyrics kept for the tracks played this session. Reopening the panel on the
  /// same song is common; asking a small free service again for it is rude.
  final _cache = <String, Lyrics?>{};

  Future<Lyrics?> forSong(Song song) async {
    if (_cache.containsKey(song.videoId)) return _cache[song.videoId];
    final found = await _search(song);
    _cache[song.videoId] = found;
    return found;
  }

  Future<Lyrics?> _search(Song song) async {
    try {
      final response = await _http.get(
        Uri.parse('$_base/search').replace(queryParameters: {
          'track_name': song.title,
          if (song.artist != null) 'artist_name': song.artist!,
        }),
        headers: const {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return null;

      final results = jsonDecode(utf8.decode(response.bodyBytes));
      if (results is! List || results.isEmpty) return null;

      final best = _closest(results, song.duration);
      final lyrics = Lyrics.parse(
        best['syncedLyrics'] as String?,
        best['plainLyrics'] as String?,
      );
      return lyrics.isEmpty ? null : lyrics;
    } catch (_) {
      // No lyrics is a normal outcome, not an error worth surfacing.
      return null;
    }
  }

  /// Picks the version that runs as long as the track being played.
  ///
  /// A title and artist match several recordings — the album cut, a remaster, a
  /// live take — and their words are timed differently. Length is the one clue
  /// that tells them apart, and preferring a timed result over a plain one
  /// breaks the tie when two are equally close.
  Map<String, dynamic> _closest(List<dynamic> results, Duration? duration) {
    final rows = results.cast<Map<String, dynamic>>();
    if (duration == null) {
      return rows.firstWhere(
        (row) => row['syncedLyrics'] != null,
        orElse: () => rows.first,
      );
    }

    final target = duration.inSeconds;
    rows.sort((a, b) {
      final byLength = (_seconds(a) - target).abs().compareTo(
            (_seconds(b) - target).abs(),
          );
      if (byLength != 0) return byLength;
      return (b['syncedLyrics'] != null ? 1 : 0)
          .compareTo(a['syncedLyrics'] != null ? 1 : 0);
    });
    return rows.first;
  }

  static int _seconds(Map<String, dynamic> row) =>
      (row['duration'] as num?)?.round() ?? 0;
}
