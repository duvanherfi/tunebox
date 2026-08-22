import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/core/innertube/parsers.dart';
import 'package:tunebox/data/models/playlist.dart';

/// A playlist the account made and one it merely saved look the same in the
/// library, and are not the same thing: only the first can be renamed, emptied
/// or deleted. Offering those on the second would be an action that always
/// fails, so the page itself has to say which it is — and it does, by carrying
/// an edit header and a delete entry, or by carrying neither.
///
/// Measured on a real account on 22 August 2026 against both kinds.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('parsePlaylistEditable', () {
    test('says yes for a playlist the account made', () {
      expect(parsePlaylistEditable(_fixture('playlist_page.json')), isTrue);
    });

    test('says no for a playlist the account only saved', () {
      expect(
        parsePlaylistEditable(_fixture('playlist_page_saved.json')),
        isFalse,
      );
    });

    test('says no for a response that is not a playlist at all', () {
      expect(parsePlaylistEditable(_fixture('search_daft_punk.json')), isFalse);
    });
  });

  group('playlistPage', () {
    Future<MusicPage> pageFrom(String fixture) async {
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async => http.Response.bytes(
              File('test/fixtures/$fixture').readAsBytesSync(),
              200,
            )),
      );
      return innertube.playlistPage('VLPL2RPwcmS6fPXzBBqcHls-6ewArZqZUB_Z');
    }

    test('brings the header, the first tracks and the editability', () async {
      final page = await pageFrom('playlist_page.json');

      expect(page.title, 'Cool');
      expect(page.songs, isNotEmpty);
      expect(page.editable, isTrue);
    });

    test('a saved playlist arrives without the edits', () async {
      final page = await pageFrom('playlist_page_saved.json');

      expect(page.title, 'Salsa que me gustan');
      expect(page.editable, isFalse);
    });

    test('asks for the playlist under its browse form', () async {
      late http.Request captured;
      final innertube = InnertubeClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            File('test/fixtures/playlist_page.json').readAsBytesSync(),
            200,
          );
        }),
      );

      await innertube.playlistPage('PL2RPwcmS6fPXzBBqcHls-6ewArZqZUB_Z');

      expect(
        (jsonDecode(captured.body) as Map<String, dynamic>)['browseId'],
        'VLPL2RPwcmS6fPXzBBqcHls-6ewArZqZUB_Z',
        reason: 'playlist contents are the id behind a VL prefix; asking for '
            'the bare id answers something else',
      );
    });
  });
}
