import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/data/models/playlist.dart';
import 'package:tunebox/data/saved_collections.dart';

Playlist _collection(String id) => Playlist(
      browseId: id,
      title: 'Collection $id',
      subtitle: 'someone',
      thumbnailUrl: 'https://example.test/$id.jpg',
    );

/// The bookmark is the only part of the library the account cannot supply, so
/// these pin what it must remember on its own.
void main() {
  late Directory directory;

  SavedCollections saved() =>
      SavedCollections(file: File('${directory.path}/saved_collections.json'));

  setUp(() {
    directory = Directory.systemTemp.createTempSync('tunebox_saved');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('marks a collection as saved', () async {
    final store = saved();
    await store.load();

    await store.toggle(_collection('VLPL1'));

    expect(store.isSaved('VLPL1'), isTrue);
    expect(store.all.single.title, 'Collection VLPL1');
  });

  test('unmarks a collection that was already saved', () async {
    final store = saved();
    await store.load();

    await store.toggle(_collection('VLPL1'));
    await store.toggle(_collection('VLPL1'));

    expect(store.isSaved('VLPL1'), isFalse);
    expect(store.all, isEmpty);
  });

  test('puts the newest save first', () async {
    final store = saved();
    await store.load();

    await store.toggle(_collection('VLPL1'));
    await store.toggle(_collection('VLPL2'));

    expect(store.all.map((c) => c.browseId), ['VLPL2', 'VLPL1']);
  });

  test('survives a restart with the cover it was saved with', () async {
    final first = saved();
    await first.load();
    await first.toggle(_collection('VLPL1'));

    final second = saved();
    await second.load();

    expect(second.isSaved('VLPL1'), isTrue);
    expect(second.all.single.thumbnailUrl, 'https://example.test/VLPL1.jpg');
    expect(second.all.single.subtitle, 'someone');
  });

  // The same list arrives with the `VL` prefix from a library shelf and
  // without it from a card on the home feed. A heart that empties depending on
  // which door was used is worse than no heart.
  test('recognises a list whether or not it carries the VL prefix', () async {
    final store = saved();
    await store.load();

    await store.toggle(_collection('VLPL1'));

    expect(store.isSaved('PL1'), isTrue);

    await store.toggle(_collection('PL1'));

    expect(store.isSaved('VLPL1'), isFalse);
    expect(store.all, isEmpty);
  });

  test('reads an absent file as nothing saved', () async {
    final store = saved();
    await store.load();

    expect(store.all, isEmpty);
    expect(store.isSaved('VLPL1'), isFalse);
  });

  group('with an account', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
    });

    Future<Session> signedIn() async {
      final session = Session();
      await session.signIn('SAPISID=secret123');
      return session;
    }

    test('tells YouTube about a save', () async {
      final calls = <String>[];
      final store = SavedCollections(
        file: File('${directory.path}/saved_collections.json'),
        innertube: InnertubeClient(
          httpClient: MockClient((request) async {
            calls.add(request.url.path);
            return http.Response('{}', 200);
          }),
          session: await signedIn(),
        ),
      );
      await store.load();

      await store.toggle(_collection('VLPL1'));

      expect(calls.single, endsWith('/like/like'));
    });

    test('keeps the local mark when YouTube refuses the write', () async {
      final store = SavedCollections(
        file: File('${directory.path}/saved_collections.json'),
        innertube: InnertubeClient(
          httpClient: MockClient((_) async => http.Response('nope', 500)),
          session: await signedIn(),
        ),
      );
      await store.load();

      await expectLater(
        store.toggle(_collection('VLPL1')),
        throwsA(isA<InnertubeException>()),
      );

      expect(
        store.isSaved('VLPL1'),
        isTrue,
        reason: 'the shelf is the listener\'s, whatever the account heard',
      );
    });

    test('does not write at all when signed out', () async {
      var calls = 0;
      final store = SavedCollections(
        file: File('${directory.path}/saved_collections.json'),
        innertube: InnertubeClient(
          httpClient: MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        ),
      );
      await store.load();

      await store.toggle(_collection('VLPL1'));

      expect(calls, 0);
      expect(store.isSaved('VLPL1'), isTrue);
    });
  });
}
