import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/core/innertube/parsers.dart';

/// Who made the track, as YouTube files it.
///
/// The page comes back wrapped in a dialog renderer because that is how the web
/// player draws it; YouTube Music on Android gives it a whole screen, and so
/// does this app. Either way the content is the same handful of role-and-name
/// pairs, and the parser is what has to survive the wrapping changing.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('parseTrackCredits', () {
    test('reads the track the credits are for', () {
      final credits = parseTrackCredits(_fixture('track_credits.json'));

      expect(credits.title, 'Eres Mía');
      expect(credits.artist, 'Romeo Santos');
      expect(credits.subtitle, 'Canción • 2014');
      expect(credits.thumbnailUrl, isNotNull);
    });

    test('reads every role in the order YouTube gave them', () {
      final credits = parseTrackCredits(_fixture('track_credits.json'));

      expect(
        credits.entries.map((entry) => entry.role),
        ['Interpretada por', 'Escrita por', 'Producida por',
            'Metadatos de música proporcionados por'],
      );
      expect(credits.entries.first.name, 'Romeo Santos');
    });

    test('answers an empty page rather than throwing', () {
      final credits = parseTrackCredits({});

      expect(credits.entries, isEmpty);
      expect(credits.title, '');
    });
  });

  group('trackCredits', () {
    test('addresses the page by the video id', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          // Bytes rather than a string: the response carries accents, and
          // http's default encoding for a bare string is latin1.
          return http.Response.bytes(
            File('test/fixtures/track_credits.json').readAsBytesSync(),
            200,
          );
        }),
      );

      final credits = await innertube.trackCredits('DYuhnVSOzwE');

      expect(captured.url.path, endsWith('/browse'));
      expect(
        (jsonDecode(captured.body) as Map<String, dynamic>)['browseId'],
        'MPTCDYuhnVSOzwE',
        reason: 'the credits page is the video id behind an MPTC prefix — '
            'verified against the 159 history rows that carried the entry',
      );
      expect(credits.title, 'Eres Mía');
    });
  });
}
