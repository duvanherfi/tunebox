import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/data/likes.dart';
import 'package:tunebox/data/models/song.dart';

/// A session that can be signed in and out without touching secure storage.
class _FakeSession extends Session {
  bool _signedIn = true;

  @override
  bool get isSignedIn => _signedIn;

  void set(bool value) {
    _signedIn = value;
    notifyListeners();
  }
}

/// The account's liked songs, served one page at a time.
class _PagedInnertube extends InnertubeClient {
  _PagedInnertube({required this.pages, super.session, this.failAfter});

  final List<({List<String> ids, String? nextToken})> pages;

  /// How many pages answer before the network refuses, as it does in a tunnel.
  final int? failAfter;

  /// The continuation each call asked for; null is the first page.
  final requested = <String?>[];

  final written = <String, bool>{};
  var _index = 0;

  @override
  Future<({List<String> ids, String? nextToken})> likedSongIds({
    String? continuation,
  }) async {
    requested.add(continuation);
    if (failAfter != null && requested.length > failAfter!) {
      throw InnertubeException('offline');
    }
    return pages[_index++];
  }

  @override
  Future<void> setLiked(String videoId, bool liked) async {
    written[videoId] = liked;
  }
}

/// The account refusing every write.
class _FailingWrites extends _PagedInnertube {
  _FailingWrites({required super.pages, super.session});

  @override
  Future<void> setLiked(String videoId, bool liked) async =>
      throw InnertubeException('refused');
}

const _song = Song(videoId: 'song1', title: 'Title', subtitle: 'Artist');

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('likes_test');
    file = File('${dir.path}/likes.json');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  group('what was read last time', () {
    test('colours the hearts before anything is asked of the network',
        () async {
      file.writeAsStringSync(jsonEncode({'ids': ['a', 'b']}));
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [(ids: ['a'], nextToken: null)],
      );

      final likes = Likes(client, file: file, pageGap: Duration.zero);
      await likes.load();

      expect(likes.isLiked('a'), isTrue);
      expect(likes.isLiked('b'), isTrue);
      expect(client.requested, isEmpty, reason: 'reading asks nothing');
    });

    test('an unreadable file is the same as knowing nothing', () async {
      file.writeAsStringSync('not json');
      final likes = Likes(
        _PagedInnertube(session: _FakeSession(), pages: const []),
        file: file,
        pageGap: Duration.zero,
      );

      await likes.load();

      expect(likes.isLiked('a'), isFalse);
    });
  });

  group('refreshing against the account', () {
    test('reads every page and keeps what it found', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [
          (ids: ['a'], nextToken: 'token-1'),
          (ids: ['b'], nextToken: 'token-2'),
          (ids: ['c'], nextToken: null),
        ],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);

      await likes.refresh();

      expect(client.requested, [null, 'token-1', 'token-2']);
      expect(likes.isLiked('c'), isTrue);
      expect(jsonDecode(file.readAsStringSync())['ids'], ['a', 'b', 'c']);
    });

    test('drops what the account no longer lists', () async {
      file.writeAsStringSync(jsonEncode({'ids': ['gone', 'kept']}));
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [(ids: ['kept'], nextToken: null)],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);
      await likes.load();

      await likes.refresh();

      expect(likes.isLiked('kept'), isTrue);
      expect(likes.isLiked('gone'), isFalse, reason: 'unliked elsewhere');
    });

    test('a read that breaks off adds what arrived and removes nothing',
        () async {
      file.writeAsStringSync(jsonEncode({'ids': ['old']}));
      final client = _PagedInnertube(
        session: _FakeSession(),
        failAfter: 1,
        pages: [(ids: ['new'], nextToken: 'token-1')],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);
      await likes.load();

      await likes.refresh();

      expect(likes.isLiked('new'), isTrue);
      expect(likes.isLiked('old'), isTrue,
          reason: 'half a list is no reason to empty a heart');
    });

    test('asks nothing while signed out', () async {
      final client = _PagedInnertube(pages: [(ids: ['a'], nextToken: null)]);
      final likes = Likes(client, file: file, pageGap: Duration.zero);

      await likes.refresh();

      expect(client.requested, isEmpty);
      expect(likes.canLike, isFalse);
    });

    test('one read at a time', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [
          (ids: ['a'], nextToken: 'token-1'),
          (ids: ['b'], nextToken: null),
        ],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);

      await Future.wait([likes.refresh(), likes.refresh()]);

      expect(client.requested, [null, 'token-1']);
    });
  });

  group('what was toggled here', () {
    test('is saved at once, so a restart still knows it', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: const [],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);
      await likes.load();

      await likes.toggle(_song);

      expect(client.written['song1'], isTrue);
      final next = Likes(client, file: file, pageGap: Duration.zero);
      await next.load();
      expect(next.isLiked('song1'), isTrue);
    });

    test('wins over a page read while the write was in flight', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [
          (ids: ['song1'], nextToken: 'token-1'),
          (ids: ['song1'], nextToken: null),
        ],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);
      final refreshing = likes.refresh();

      await likes.toggle(_song); // liked, then taken back below
      await likes.toggle(_song);
      await refreshing;

      expect(likes.isLiked('song1'), isFalse, reason: 'a page resurrected it');
      expect(client.written['song1'], isFalse);
    });

    test('a failed write leaves the heart as the account has it', () async {
      final client = _FailingWrites(
        session: _FakeSession(),
        pages: [(ids: ['song1'], nextToken: null)],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);
      await likes.refresh();

      await expectLater(likes.toggle(_song), throwsA(isA<Exception>()));
      expect(likes.isLiked('song1'), isTrue, reason: 'rolled back to the list');
    });
  });

  group('changing account', () {
    test('signing out forgets the list and what was saved of it', () async {
      final session = _FakeSession();
      final client = _PagedInnertube(
        session: session,
        pages: [(ids: ['a'], nextToken: null)],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);
      await likes.refresh();
      expect(likes.isLiked('a'), isTrue);

      session.set(false);
      await pumpEventQueue();

      expect(likes.isLiked('a'), isFalse);
      expect(file.existsSync(), isFalse);
    });

    test('signing in reads the new account', () async {
      final session = _FakeSession().. set(false);
      final client = _PagedInnertube(
        session: session,
        pages: [(ids: ['z'], nextToken: null)],
      );
      final likes = Likes(client, file: file, pageGap: Duration.zero);

      session.set(true);
      await pumpEventQueue();

      expect(likes.isLiked('z'), isTrue);
    });
  });
}
