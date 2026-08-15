import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/scrobble/scrobbler.dart';
import 'package:tunebox/data/models/song.dart';

/// The scrobbler talks to two services with different rules; these check the
/// shapes both of them insist on, since neither answers usefully when wrong.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  const song = Song(
    videoId: 'abc',
    title: 'Glory Box',
    subtitle: 'Portishead',
    artist: 'Portishead',
  );

  test('sends a ListenBrainz listen with its timestamp and token', () async {
    late http.Request captured;
    final scrobbler = Scrobbler(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
    );
    await scrobbler.setListenBrainzToken('secret-token');

    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    await scrobbler.scrobble(song, at);

    expect(captured.headers['Authorization'], 'Token secret-token');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['listen_type'], 'single');
    final listen = (body['payload'] as List).single as Map<String, dynamic>;
    expect(listen['listened_at'], 1700000000);
    expect(listen['track_metadata']['artist_name'], 'Portishead');
  });

  test('leaves a track with no artist alone', () async {
    var calls = 0;
    final scrobbler = Scrobbler(
      httpClient: MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await scrobbler.setListenBrainzToken('secret-token');

    await scrobbler.scrobble(
      const Song(videoId: 'x', title: 'Untitled', subtitle: ''),
      DateTime.now(),
    );

    expect(calls, 0, reason: 'neither service accepts a listen without one');
  });

  test('signs Last.fm calls the way Last.fm asks', () async {
    late http.Request captured;
    final scrobbler = Scrobbler(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{"session":{"key":"sk-1"}}', 200);
      }),
    );
    await scrobbler.setLastFmCredentials('KEY', 'SECRET');
    await scrobbler.completeLastFmAuth('T');

    final params = Uri.splitQueryString(captured.body);
    final signed = {
      'api_key': 'KEY',
      'method': 'auth.getSession',
      'token': 'T',
    };
    final expected = md5
        .convert(utf8.encode(
          (signed.keys.toList()..sort())
                  .map((k) => '$k${signed[k]}')
                  .join() +
              'SECRET',
        ))
        .toString();

    expect(params['api_sig'], expected);
    expect(params['format'], 'json');
    expect(scrobbler.lastFmConnected, isTrue);
  });
}
