import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/features/shared/collection_menu.dart';

/// The two collection-level calls the playlist page needs. Both are shaped by
/// ids YouTube builds by hand — a radio id is a prefix glued onto a playlist
/// id, and the write endpoints refuse the browse form — so what goes on the
/// wire is the only thing worth pinning.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<Session> signedIn() async {
    final session = Session();
    await session.signIn('SAPISID=secret123; LOGIN_INFO=xyz');
    return session;
  }

  group('collectionRadio', () {
    test('asks for the radio of the whole list, not of one track', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await innertube.collectionRadio('PL123');

      expect(captured.url.path, endsWith('/next'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['playlistId'], 'RDAMPLPL123');
      expect(body.containsKey('videoId'), isFalse);
    });

    test('drops the VL prefix a library id carries', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await innertube.collectionRadio('VLPL123');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['playlistId'], 'RDAMPLPL123');
    });

    test('leaves an id that is already a radio alone', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await innertube.collectionRadio('RDAMPLPL123');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['playlistId'], 'RDAMPLPL123');
    });

    test('leaves an artist radio alone too', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      // An artist's mix is an `RDEM` id, and gluing `RDAMPL` in front of it
      // asks for a playlist radio that does not exist.
      await innertube.collectionRadio('RDEMabc');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['playlistId'], 'RDEMabc');
    });
  });

  group('addAllToPlaylist', () {
    test('adds every track in a single edit', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.addAllToPlaylist('VLPL9', const ['a', 'b']);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['playlistId'], 'PL9');
      expect(body['actions'], [
        {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': 'a'},
        {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': 'b'},
      ]);
    });

    test('says nothing at all when there is nothing to add', () async {
      var calls = 0;
      final innertube = InnertubeClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.addAllToPlaylist('PL9', const []);

      expect(calls, 0);
    });
  });

  group('setCollectionSaved', () {
    test('saves a playlist to the account by its bare id', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.setCollectionSaved('VLPL123', true);

      expect(captured.url.path, endsWith('/like/like'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['target'], {'playlistId': 'PL123'});
    });

    test('removes it through the other endpoint', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.setCollectionSaved('PL123', false);

      expect(captured.url.path, endsWith('/like/removelike'));
    });

    test('refuses to write without a session', () async {
      var calls = 0;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => innertube.setCollectionSaved('PL123', true),
        throwsA(isA<InnertubeException>()),
      );
      expect(calls, 0);
    });
  });

  // A link that opens nothing is worse than no link, and albums and playlists
  // live on different paths.
  group('collectionLink', () {
    test('points an album at its browse page', () {
      expect(
        collectionLink('MPREb_123'),
        'https://music.youtube.com/browse/MPREb_123',
      );
    });

    test('points a playlist at its list page, without the VL prefix', () {
      expect(
        collectionLink('VLPL123'),
        'https://music.youtube.com/playlist?list=PL123',
      );
    });

    test('points an artist at their channel', () {
      expect(
        collectionLink('UC123'),
        'https://music.youtube.com/channel/UC123',
      );
    });
  });

  // A single pick loses the track when the player refuses that one format, so
  // the client hands back every stream the answering client offered — same
  // nonce, same identity — for the caller to walk.
  group('resolveStreams', () {
    test('returns every playable format, best first, sharing one nonce',
        () async {
      final innertube = InnertubeClient(
        preferMp4: false,
        httpClient: MockClient((request) async {
          if (request.method == 'GET') return http.Response('', 206);
          return http.Response(
            jsonEncode({
              'playabilityStatus': {'status': 'OK'},
              'streamingData': {
                'adaptiveFormats': [
                  {
                    'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
                    'url': 'https://example.invalid/m4a',
                    'bitrate': 128000,
                  },
                  {
                    'mimeType': 'audio/webm; codecs="opus"',
                    'url': 'https://example.invalid/opus',
                    'bitrate': 160000,
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final streams = await innertube.resolveStreams('abc');

      expect(streams, hasLength(2));
      expect(streams.first.url, startsWith('https://example.invalid/opus'));
      expect(streams.last.url, startsWith('https://example.invalid/m4a'));
      expect(streams.first.cpn, streams.last.cpn);
      expect(streams.first.userAgent, isNotEmpty);
    });
  });

  group('likedSongIds', () {
    test('reads the Liked Music playlist, not the library\'s songs', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await innertube.likedSongIds();

      expect(captured.url.path, endsWith('/browse'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      // Measured against a real account: this browse id answers with the songs
      // in the library — 598 of them, most from saved albums — while the likes
      // are the 183 of the LM auto-playlist. Reading the wrong one fills in
      // hearts for tracks nobody liked.
      expect(body['browseId'], 'VLLM');
      expect(body['browseId'], isNot('FEmusic_liked_videos'));
    });

    test('a continuation names the place, not the list', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await innertube.likedSongIds(continuation: 'token-1');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['continuation'], 'token-1');
      expect(body.containsKey('browseId'), isFalse);
    });
  });
}
