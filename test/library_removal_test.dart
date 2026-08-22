import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';

/// Taking a track out of the library is not the write the rest of the app
/// makes. It goes to `feedback` with a token the row handed over — not to
/// `edit_playlist`, which is how tracks go *in*, and not to `like/removelike`,
/// which is the heart. Sending it to either would take away the like, which is
/// the whole thing this action exists not to do.
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

  group('removeFromLibrary', () {
    test('posts the row\'s token to the feedback endpoint', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
        session: await signedIn(),
      );

      await innertube.removeFromLibrary('AB9zfpTOKEN');

      expect(captured.url.path, endsWith('/feedback'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['feedbackTokens'], ['AB9zfpTOKEN']);
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
        innertube.removeFromLibrary('AB9zfpTOKEN'),
        throwsA(isA<InnertubeException>()),
      );
      expect(posted, isFalse);
    });
  });
}
