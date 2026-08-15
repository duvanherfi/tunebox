import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../data/models/song.dart';

/// Reports listens to the services that keep a listening history properly.
///
/// This exists because YouTube's own history will not accept what this app
/// reports — measured, documented, and not for want of trying. Last.fm and
/// ListenBrainz both will, and both have been doing exactly this job for
/// longer than YouTube Music has existed.
///
/// Either can be connected, both, or neither; nothing else in the app knows or
/// cares which.
class Scrobbler extends ChangeNotifier {
  Scrobbler({http.Client? httpClient, FlutterSecureStorage? storage})
      : _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _listenBrainzKey = 'listenbrainz_token';
  static const _lastFmKeyKey = 'lastfm_api_key';
  static const _lastFmSecretKey = 'lastfm_api_secret';
  static const _lastFmSessionKey = 'lastfm_session';

  static const _listenBrainz = 'https://api.listenbrainz.org/1';
  static const _lastFm = 'https://ws.audioscrobbler.com/2.0/';

  final http.Client _http;

  /// Tokens are credentials: they go where the account cookie goes, not into
  /// preferences.
  final FlutterSecureStorage _storage;

  String? _listenBrainzToken;
  String? _lastFmApiKey;
  String? _lastFmSecret;
  String? _lastFmSession;

  bool get listenBrainzConnected => _listenBrainzToken != null;
  bool get lastFmConnected => _lastFmSession != null;
  bool get lastFmConfigured => _lastFmApiKey != null && _lastFmSecret != null;

  Future<void> load() async {
    _listenBrainzToken = await _storage.read(key: _listenBrainzKey);
    _lastFmApiKey = await _storage.read(key: _lastFmKeyKey);
    _lastFmSecret = await _storage.read(key: _lastFmSecretKey);
    _lastFmSession = await _storage.read(key: _lastFmSessionKey);
    notifyListeners();
  }

  Future<void> setListenBrainzToken(String? token) async {
    _listenBrainzToken = (token?.trim().isEmpty ?? true) ? null : token!.trim();
    await _write(_listenBrainzKey, _listenBrainzToken);
    notifyListeners();
  }

  /// Stores the Last.fm application credentials.
  ///
  /// They belong to whoever runs this build, not to Tunebox: Last.fm issues a
  /// key per application, and shipping one inside an open source app would mean
  /// shipping a secret in public.
  Future<void> setLastFmCredentials(String? apiKey, String? secret) async {
    _lastFmApiKey = _blankToNull(apiKey);
    _lastFmSecret = _blankToNull(secret);
    await _write(_lastFmKeyKey, _lastFmApiKey);
    await _write(_lastFmSecretKey, _lastFmSecret);
    notifyListeners();
  }

  Future<void> disconnectLastFm() async {
    _lastFmSession = null;
    await _write(_lastFmSessionKey, null);
    notifyListeners();
  }

  /// Step one of Last.fm's desktop flow: a request token, and the page where
  /// the listener approves it.
  Future<({String token, Uri approvalUrl})> beginLastFmAuth() async {
    final json = await _lastFmCall({'method': 'auth.getToken'});
    final token = json['token'] as String;
    return (
      token: token,
      approvalUrl: Uri.parse(
        'https://www.last.fm/api/auth/?api_key=$_lastFmApiKey&token=$token',
      ),
    );
  }

  /// Step two, once they have approved it: trade the token for a session key
  /// that does not expire.
  Future<void> completeLastFmAuth(String token) async {
    final json = await _lastFmCall(
      {'method': 'auth.getSession', 'token': token},
      signed: true,
    );
    final key = json['session']?['key'];
    if (key is! String) throw Exception('Last.fm no devolvió una sesión');
    _lastFmSession = key;
    await _write(_lastFmSessionKey, key);
    notifyListeners();
  }

  /// Announces what is playing right now. Both services treat this as a
  /// transient status, not a listen: it is never counted.
  Future<void> nowPlaying(Song song) async {
    final artist = song.artist;
    if (artist == null || artist.isEmpty) return;

    await Future.wait([
      _listenBrainzSubmit('playing_now', song, artist, null),
      _lastFmScrobble(song, artist, null),
    ]);
  }

  /// Records a listen, timestamped when the track started.
  ///
  /// Called once a track has been playing long enough to count, which is the
  /// caller's judgement — both services expect roughly half a track or four
  /// minutes, and neither wants a scrobble for something skipped.
  Future<void> scrobble(Song song, DateTime startedAt) async {
    final artist = song.artist;
    if (artist == null || artist.isEmpty) return;

    await Future.wait([
      _listenBrainzSubmit('single', song, artist, startedAt),
      _lastFmScrobble(song, artist, startedAt),
    ]);
  }

  Future<void> _listenBrainzSubmit(
    String type,
    Song song,
    String artist,
    DateTime? startedAt,
  ) async {
    final token = _listenBrainzToken;
    if (token == null) return;

    try {
      await _http.post(
        Uri.parse('$_listenBrainz/submit-listens'),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'listen_type': type,
          'payload': [
            {
              if (startedAt != null)
                'listened_at': startedAt.millisecondsSinceEpoch ~/ 1000,
              'track_metadata': {
                'artist_name': artist,
                'track_name': song.title,
                'additional_info': {
                  'media_player': 'Tunebox',
                  'music_service': 'music.youtube.com',
                  'origin_url':
                      'https://music.youtube.com/watch?v=${song.videoId}',
                },
              },
            },
          ],
        }),
      );
    } catch (_) {
      // A listen that did not reach the server is not worth interrupting the
      // music for. Neither service offers a queue this app could retry into.
    }
  }

  Future<void> _lastFmScrobble(
    Song song,
    String artist,
    DateTime? startedAt,
  ) async {
    if (_lastFmSession == null) return;

    try {
      await _lastFmCall(
        {
          'method': startedAt == null
              ? 'track.updateNowPlaying'
              : 'track.scrobble',
          'artist': artist,
          'track': song.title,
          'sk': _lastFmSession!,
          if (startedAt != null)
            'timestamp': '${startedAt.millisecondsSinceEpoch ~/ 1000}',
        },
        signed: true,
      );
    } catch (_) {
      // As above: reported or not, the music keeps playing.
    }
  }

  /// Last.fm signs every authenticated call with an MD5 of the parameters in
  /// alphabetical order, concatenated name-then-value, with the shared secret
  /// on the end. Their design, not ours.
  Future<Map<String, dynamic>> _lastFmCall(
    Map<String, String> params, {
    bool signed = false,
  }) async {
    final key = _lastFmApiKey;
    final secret = _lastFmSecret;
    if (key == null || secret == null) {
      throw Exception('Falta la clave de la API de Last.fm');
    }

    final all = {...params, 'api_key': key};
    if (signed) {
      final ordered = all.keys.toList()..sort();
      final signature = ordered.map((k) => '$k${all[k]}').join() + secret;
      all['api_sig'] = md5.convert(utf8.encode(signature)).toString();
    }
    all['format'] = 'json';

    final response = await _http.post(Uri.parse(_lastFm), body: all);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['error'] != null) {
      throw Exception('Last.fm: ${json['message'] ?? json['error']}');
    }
    return json;
  }

  Future<void> _write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);

  static String? _blankToNull(String? value) =>
      (value?.trim().isEmpty ?? true) ? null : value!.trim();
}
