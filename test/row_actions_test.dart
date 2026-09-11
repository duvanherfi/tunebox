import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';

/// The writes a row's menu can make on the account.
///
/// Every one of these asserts the body as well as the path, and that is the
/// point of the file rather than a formality: three of them go to the *same*
/// endpoint carrying an opaque token, so a mistake does not fail — it quietly
/// makes a different edit on someone's account. Taking a track out of the
/// history through the library's token would take it out of the library.
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

  /// A client whose requests are captured instead of sent.
  Future<(InnertubeClient, List<http.Request>)> client({
    String response = '{}',
  }) async {
    final captured = <http.Request>[];
    return (
      InnertubeClient(
        httpClient: MockClient((request) async {
          captured.add(request);
          return http.Response(response, 200);
        }),
        session: await signedIn(),
      ),
      captured,
    );
  }

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  group('removeFromHistory', () {
    test('posts the row\'s token to the feedback endpoint', () async {
      final (innertube, captured) = await client();

      await innertube.removeFromHistory('AB9zfpHISTORY');

      expect(captured.single.url.path, endsWith('/feedback'));
      expect(bodyOf(captured.single)['feedbackTokens'], ['AB9zfpHISTORY']);
    });

    test('refuses without a session rather than writing anonymously', () async {
      var posted = false;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          posted = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        innertube.removeFromHistory('AB9zfpHISTORY'),
        throwsA(isA<InnertubeException>()),
      );
      expect(posted, isFalse);
    });
  });

  group('setPinnedToRecap', () {
    test('sends the token the row handed over', () async {
      final (innertube, captured) = await client();

      await innertube.setPinnedToRecap('AB9zfpPIN');

      expect(captured.single.url.path, endsWith('/feedback'));
      expect(bodyOf(captured.single)['feedbackTokens'], ['AB9zfpPIN']);
    });
  });

  group('removeFromPlaylist', () {
    test('names the row rather than the track', () async {
      final (innertube, captured) = await client();

      await innertube.removeFromPlaylist(
        'VLPL123',
        videoId: 'abc',
        setVideoId: 'DEF456',
      );

      expect(captured.single.url.path, endsWith('/browse/edit_playlist'));
      final body = bodyOf(captured.single);
      expect(body['playlistId'], 'PL123',
          reason: 'the edit endpoint wants the bare id, not the VL browse '
              'form a library shelf hands out');
      expect(body['actions'], [
        {
          'action': 'ACTION_REMOVE_VIDEO',
          'removedVideoId': 'abc',
          'setVideoId': 'DEF456',
        },
      ]);
    });
  });

  group('renamePlaylist', () {
    test('sets the name through the playlist editor', () async {
      final (innertube, captured) = await client();

      await innertube.renamePlaylist('VLPL123', 'Domingo');

      expect(captured.single.url.path, endsWith('/browse/edit_playlist'));
      final body = bodyOf(captured.single);
      expect(body['playlistId'], 'PL123');
      expect(body['actions'], [
        {'action': 'ACTION_SET_PLAYLIST_NAME', 'playlistName': 'Domingo'},
      ]);
    });
  });

  group('deletePlaylist', () {
    test('asks the delete endpoint, not the editor', () async {
      final (innertube, captured) = await client();

      await innertube.deletePlaylist('VLPL123');

      expect(captured.single.url.path, endsWith('/playlist/delete'));
      expect(bodyOf(captured.single)['playlistId'], 'PL123');
    });
  });

  group('setEpisodePlayed', () {
    test("posts the episode's own token, not the pin's", () async {
      final (innertube, captured) = await client();

      await innertube.setEpisodePlayed('AB9zfpPLAYED');

      expect(captured.single.url.path, endsWith('/feedback'));
      expect(bodyOf(captured.single)['feedbackTokens'], ['AB9zfpPLAYED']);
    });
  });

  group('setQueuedForLater', () {
    // The list is `SE` and the edit is spelled out rather than tokenised, so
    // this is the one write in the app whose body is built here instead of
    // passed through. It is the body YouTube's own menu carries, recorded
    // against the real account on 11 September 2026.
    test('adds to the list YouTube keeps in listening order', () async {
      final (innertube, captured) = await client();

      await innertube.setQueuedForLater('GF-B5r4Myl0', true);

      final body = bodyOf(captured.single);
      expect(captured.single.url.path, endsWith('/browse/edit_playlist'));
      expect(body['playlistId'], 'SE');
      expect(body['params'], 'YAFwZA%3D%3D');
      expect(body['actions'], [
        {'action': 'ACTION_REMOVE_WATCHED_VIDEOS', 'suppressSuccessToast': true},
        {
          'action': 'ACTION_ADD_VIDEO',
          'addedVideoId': 'GF-B5r4Myl0',
          'dedupeOption': 'DEDUPE_OPTION_CHECK',
          'addedVideoPositionIfManualSort': 0,
        },
      ]);
    });

    // By video id, which an ordinary playlist cannot do: that one may hold the
    // same track twice and names the row instead.
    test('removes by video id, with no setVideoId', () async {
      final (innertube, captured) = await client();

      await innertube.setQueuedForLater('GF-B5r4Myl0', false);

      final body = bodyOf(captured.single);
      expect(body['playlistId'], 'SE');
      expect(body['params'], 'cGQ%3D');
      expect(body['actions'], [
        {
          'action': 'ACTION_REMOVE_VIDEO_BY_VIDEO_ID',
          'removedVideoId': 'GF-B5r4Myl0',
        },
        {'action': 'ACTION_REMOVE_WATCHED_VIDEOS', 'suppressSuccessToast': true},
      ]);
    });

    test('refuses without a session rather than writing anonymously', () async {
      var posted = false;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          posted = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        innertube.setQueuedForLater('GF-B5r4Myl0', true),
        throwsA(isA<InnertubeException>()),
      );
      expect(posted, isFalse);
    });
  });
}
