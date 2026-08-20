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
  _PagedInnertube({required this.pages, super.session, this.failFirst = false});

  final List<({List<String> ids, String? nextToken})> pages;

  /// Whether the first read fails, as it does in a tunnel.
  final bool failFirst;

  /// The continuation each call asked for; null is the first page.
  final requested = <String?>[];

  final written = <String, bool>{};
  var _index = 0;
  var _failed = false;

  @override
  Future<({List<String> ids, String? nextToken})> likedSongIds({
    String? continuation,
  }) async {
    requested.add(continuation);
    if (failFirst && !_failed) {
      _failed = true;
      throw InnertubeException('offline');
    }
    return pages[_index++];
  }

  @override
  Future<void> setLiked(String videoId, bool liked) async {
    written[videoId] = liked;
  }
}

const _song = Song(videoId: 'song1', title: 'Title', subtitle: 'Artist');

void main() {
  group('seeding from the account', () {
    test('reads the first page when a heart asks about an unknown track',
        () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [(ids: ['a', 'b'], nextToken: null)],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      expect(likes.isLiked('a'), isFalse, reason: 'nothing read yet');
      await pumpEventQueue();

      expect(client.requested, [null]);
      expect(likes.isLiked('a'), isTrue);
      expect(likes.isLiked('b'), isTrue);
    });

    test('stops after one page when nothing else is asking', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [
          (ids: ['a'], nextToken: 'token-1'),
          (ids: ['b'], nextToken: null),
        ],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      likes.isLiked('a');
      await pumpEventQueue();

      expect(client.requested, [null], reason: 'demand ended with the answer');
    });

    test('keeps pulling while something on screen is still unknown', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [
          (ids: ['a'], nextToken: 'token-1'),
          (ids: ['b'], nextToken: 'token-2'),
          (ids: ['c'], nextToken: null),
        ],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      // A row that stays on screen asks again on every rebuild, which is the
      // demand signal the crawl advances on.
      likes.addListener(() => likes.isLiked('never-liked'));
      likes.isLiked('never-liked');
      await pumpEventQueue();

      expect(client.requested, [null, 'token-1', 'token-2']);
      expect(likes.isLiked('c'), isTrue);
    });

    test('asks nothing while signed out', () async {
      final client = _PagedInnertube(
        pages: [(ids: ['a'], nextToken: null)],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      likes.isLiked('a');
      await pumpEventQueue();

      expect(client.requested, isEmpty);
      expect(likes.canLike, isFalse);
    });

    test('a refused read is retried the next time a heart asks', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        failFirst: true,
        pages: [(ids: ['a'], nextToken: null)],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      likes.isLiked('a');
      await pumpEventQueue();
      expect(likes.isLiked('a'), isFalse, reason: 'the page never arrived');

      await pumpEventQueue();
      expect(client.requested.length, 2);
      expect(likes.isLiked('a'), isTrue);
    });
  });

  group('what was toggled here', () {
    test('wins over a later page that still lists an unliked track', () async {
      final client = _PagedInnertube(
        session: _FakeSession(),
        pages: [
          (ids: ['song1'], nextToken: 'token-1'),
          (ids: ['song1', 'x'], nextToken: null),
        ],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      likes.isLiked('song1');
      await pumpEventQueue();
      expect(likes.isLiked('song1'), isTrue, reason: 'the account has it');

      await likes.toggle(_song); // taken back here
      expect(client.written['song1'], isFalse);

      // The rest of the list is read afterwards and still names the track,
      // because YouTube's own list lags a write by a moment.
      likes.isLiked('never-liked');
      await pumpEventQueue();

      expect(likes.isLiked('song1'), isFalse, reason: 'a page resurrected it');
    });

    test('a failed write leaves the heart as the account has it', () async {
      final client = _FailingWrites(
        session: _FakeSession(),
        pages: [(ids: ['song1'], nextToken: null)],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      likes.isLiked('song1');
      await pumpEventQueue();
      expect(likes.isLiked('song1'), isTrue);

      await expectLater(likes.toggle(_song), throwsA(isA<Exception>()));
      expect(likes.isLiked('song1'), isTrue, reason: 'rolled back to the list');
    });
  });

  group('changing account', () {
    test('forgets everything and reads again', () async {
      final session = _FakeSession();
      final client = _PagedInnertube(
        session: session,
        pages: [
          (ids: ['a'], nextToken: null),
          (ids: ['z'], nextToken: null),
        ],
      );
      final likes = Likes(client, pageGap: Duration.zero);

      likes.isLiked('a');
      await pumpEventQueue();
      expect(likes.isLiked('a'), isTrue);

      session.set(false);
      expect(likes.isLiked('a'), isFalse);

      session.set(true);
      likes.isLiked('z');
      await pumpEventQueue();
      expect(likes.isLiked('z'), isTrue);
      expect(client.requested, [null, null]);
    });
  });
}

/// The account refusing every write.
class _FailingWrites extends _PagedInnertube {
  _FailingWrites({required super.pages, super.session});

  @override
  Future<void> setLiked(String videoId, bool liked) async =>
      throw InnertubeException('refused');
}
