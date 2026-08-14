import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../auth/session.dart';
import 'parsers.dart';

/// Client identities accepted by InnerTube.
///
/// IMPORTANT: `version` is the single most fragile value in this codebase.
/// YouTube retires old client builds, and when it does the player endpoint
/// starts answering HTTP 400 or `LOGIN_REQUIRED` for every request. That is
/// not a ban and not a cookie problem — it just means the number below went
/// stale. Bump it to a current app release and everything works again.
class _ClientProfile {
  const _ClientProfile({
    required this.name,
    required this.version,
    required this.userAgent,
    this.extra = const {},
  });

  final String name;
  final String version;
  final String userAgent;
  final Map<String, Object> extra;

  Map<String, Object> context(String hl, String gl) => {
        'clientName': name,
        'clientVersion': version,
        'hl': hl,
        'gl': gl,
        ...extra,
      };
}

/// Browsing, search and library metadata. The YouTube Music web client returns
/// the richest catalogue data, but it will not hand out audio URLs.
const _webRemix = _ClientProfile(
  name: 'WEB_REMIX',
  version: '1.20240403.01.00',
  userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
);

/// Audio stream resolution. The iOS client is the one that still returns
/// ready-to-play URLs with no signature cipher and no proof-of-origin token,
/// which is what keeps playback a single request instead of a JS interpreter.
const _ios = _ClientProfile(
  name: 'IOS',
  version: '20.10.4',
  userAgent:
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X)',
  extra: {
    'deviceMake': 'Apple',
    'deviceModel': 'iPhone16,2',
    'osName': 'iPhone',
    'osVersion': '18.3.2.22D82',
  },
);

class InnertubeException implements Exception {
  InnertubeException(this.message);
  final String message;
  @override
  String toString() => 'InnertubeException: $message';
}

/// Talks to YouTube's internal API. Pure Dart on top of `http`, so it runs
/// unchanged on Android, iOS and desktop, and can be unit tested against
/// recorded JSON without a Flutter binding.
class InnertubeClient {
  InnertubeClient({
    http.Client? httpClient,
    this.session,
    this.hl = 'es',
    this.gl = 'CO',
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// When signed in, supplies the cookie and signature headers that unlock
  /// library, likes and playlists. Null or signed out leaves every call
  /// anonymous, which is exactly how search and playback already work.
  final Session? session;

  final String hl;
  final String gl;

  static const _base = 'https://youtubei.googleapis.com/youtubei/v1';
  static const _musicBase = 'https://music.youtube.com/youtubei/v1';

  Map<String, String> authHeaders() => session?.headers() ?? const {};

  Future<Map<String, dynamic>> _post(
    String base,
    String endpoint,
    _ClientProfile profile,
    Map<String, Object?> body,
  ) async {
    final response = await _http.post(
      Uri.parse('$base/$endpoint?prettyPrint=false'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': profile.userAgent,
        'Origin': 'https://music.youtube.com',
        ...authHeaders(),
      },
      body: jsonEncode({
        'context': {'client': profile.context(hl, gl)},
        ...body,
      }),
    );

    if (response.statusCode != 200) {
      throw InnertubeException(
        '$endpoint responded ${response.statusCode}. If this is the player '
        'endpoint, the client version is probably stale.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Full-text search across YouTube Music.
  Future<List<Song>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final json = await _post(_musicBase, 'search', _webRemix, {'query': query});
    return parseSearchResults(json);
  }

  /// Raw browse call. Every library surface is the same endpoint with a
  /// different id, so the typed helpers below are thin wrappers.
  Future<Map<String, dynamic>> browse(String browseId) =>
      _post(_musicBase, 'browse', _webRemix, {'browseId': browseId});

  /// Songs the account has liked.
  Future<List<Song>> likedSongs() async =>
      parseSongList(await browse('FEmusic_liked_videos'));

  /// Recently played tracks.
  Future<List<Song>> history() async =>
      parseSongList(await browse('FEmusic_history'));

  /// Playlists the account created or saved.
  Future<List<Playlist>> savedPlaylists() async =>
      parsePlaylists(await browse('FEmusic_liked_playlists'));

  /// Tracks inside a playlist. InnerTube addresses playlist contents by
  /// prefixing the playlist id with `VL`.
  Future<List<Song>> playlistSongs(String playlistId) async {
    final id = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    return parseSongList(await browse(id));
  }

  /// Resolves the highest-bitrate audio stream for a track.
  ///
  /// The returned URL is signed and expires within a few minutes, so it is
  /// fetched at playback time and never cached.
  Future<AudioStream> resolveStream(String videoId) async {
    final json = await _post(_base, 'player', _ios, {
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    });

    final status = readPath(json, ['playabilityStatus', 'status']) as String?;
    if (status != null && status != 'OK') {
      final reason = readPath(json, ['playabilityStatus', 'reason']) as String?;
      throw InnertubeException(reason ?? 'No reproducible ($status)');
    }

    final stream = parseBestAudioStream(json);
    if (stream == null) {
      throw InnertubeException('Sin pistas de audio disponibles');
    }
    return stream;
  }

  void dispose() => _http.close();
}
