import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/core/innertube/parsers.dart';

/// What an artist's page offers beyond the music: the mix YouTube builds around
/// them, and following them.
///
/// The header is hand-built here rather than recorded because only two values
/// matter and both sit behind renderer names — the point of the test is that
/// they are found wherever YouTube decides to hang them.
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

  Map<String, dynamic> artistHeader({
    String radioId = 'RDEMabc',
    bool subscribed = false,
  }) => {
    'header': {
      'musicImmersiveHeaderRenderer': {
        'title': {
          'runs': [
            {'text': 'Daft Punk'},
          ],
        },
        'playButton': {
          'buttonRenderer': {
            'navigationEndpoint': {
              'watchEndpoint': {'videoId': 'v1', 'playlistId': 'OLAK5uy_top'},
            },
          },
        },
        'startRadioButton': {
          'buttonRenderer': {
            'navigationEndpoint': {
              'watchEndpoint': {'videoId': 'v1', 'playlistId': radioId},
            },
          },
        },
        'subscriptionButton': {
          'subscribeButtonRenderer': {
            'subscribed': subscribed,
            'channelId': 'UC123',
          },
        },
      },
    },
  };

  group('parseArtistDetails', () {
    test('reads the radio of the artist, not of their top tracks', () {
      final details = parseArtistDetails(artistHeader());

      expect(details.radioPlaylistId, 'RDEMabc');
    });

    test('falls back to any radio id on the page', () {
      final page = {
        'contents': {
          'watchEndpoint': {'playlistId': 'RDEMfallback'},
        },
      };

      expect(parseArtistDetails(page).radioPlaylistId, 'RDEMfallback');
    });

    test('reads whether the account already follows them', () {
      expect(parseArtistDetails(artistHeader()).subscribed, isFalse);
      expect(
        parseArtistDetails(artistHeader(subscribed: true)).subscribed,
        isTrue,
      );
      expect(parseArtistDetails(artistHeader()).channelId, 'UC123');
    });

    test('answers nulls for a page that has neither', () {
      final details = parseArtistDetails({'contents': <String, dynamic>{}});

      expect(details.radioPlaylistId, isNull);
      expect(details.subscribed, isNull);
      expect(details.channelId, isNull);
    });
  });

  group('setArtistSubscribed', () {
    test('subscribes through the subscription endpoint', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.setArtistSubscribed('UC123', true);

      expect(captured.url.path, endsWith('/subscription/subscribe'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['channelIds'], ['UC123']);
    });

    test('unsubscribes through the other one', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.setArtistSubscribed('UC123', false);

      expect(captured.url.path, endsWith('/subscription/unsubscribe'));
    });

    test('refuses to write without a session', () async {
      var calls = 0;
      final innertube = InnertubeClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => innertube.setArtistSubscribed('UC123', true),
        throwsA(isA<InnertubeException>()),
      );
      expect(calls, 0);
    });
  });

  // Keeping an artist is subscribing to their channel; YouTube has no notion of
  // "liking" one, and the like endpoint answers 400 for a channel id.
  group('setCollectionSaved', () {
    test('routes a channel to the subscription endpoint', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.setCollectionSaved('UC123', true);

      expect(captured.url.path, endsWith('/subscription/subscribe'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['channelIds'], ['UC123']);
    });
  });
}
