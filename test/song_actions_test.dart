import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/innertube/parsers.dart';

/// What a row's own menu says can be done to the track in it.
///
/// Every one of these handles exists only inside the menu YouTube attached to
/// that row: none is derived from the video id, and none can be asked for
/// without the response it arrived in. So the parser is the whole feature —
/// what it fails to keep, the interface cannot offer.
///
/// The fixtures are real responses with their tokens scrubbed. A feedback token
/// is a credential: anyone holding one can edit that account.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  /// The row's own menu is the only place YouTube says a track is in the
  /// library, and the only place it hands over the handle to take it out.
  group('taking a track out of the library', () {
    test('reads the token that removes a track from the library', () {
      final songs = parseSongList(_fixture('library_songs.json'));

      expect(songs.first.actions.removeFromLibrary, 'REMOVE_jmy3fkMENF0');
    });

    test('leaves the token null when the row does not offer the action', () {
      final songs = parseSongList(_fixture('library_songs.json'));

      expect(songs.last.actions.removeFromLibrary, isNull);
    });

    test('ignores the other feedback tokens the same row carries', () {
      final songs = parseSongList(_fixture('library_songs.json'));
      final tokens = songs.map((song) => song.actions.removeFromLibrary).nonNulls;

      expect(tokens, everyElement(startsWith('REMOVE_')),
          reason: 'a row also carries the pin-to-recap and add-to-library '
              'tokens, and either would silently do the wrong thing');
    });

    test('leaves it null on a surface whose rows carry no menu', () {
      final songs = parseSongList(_fixture('search_daft_punk.json'));

      expect(
          songs.every((song) => song.actions.removeFromLibrary == null), isTrue);
    });
  });

  group('taking a track out of the history', () {
    test('reads the token from the row that offers it', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(songs.first.actions.removeFromHistory, isNotNull);
    });

    test('is offered on every row of the history', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(
        songs.every((song) => song.actions.removeFromHistory != null),
        isTrue,
        reason: 'measured against the account on 22 August 2026: 200 of 200 '
            'history rows carry it',
      );
    });

    test('is absent where the row is not a history row', () {
      final songs = parseSongList(_fixture('library_songs.json'));

      expect(songs.every((song) => song.actions.removeFromHistory == null),
          isTrue);
    });

    test('is not the token that takes the track out of the library', () {
      final songs = parseSongList(_fixture('history_page.json'));
      final song = songs.first;

      expect(song.actions.removeFromLibrary, isNotNull);
      expect(
        song.actions.removeFromHistory,
        isNot(song.actions.removeFromLibrary),
        reason: 'one row carries several feedback tokens, and sending the '
            'wrong one to the same endpoint silently does something else',
      );
    });
  });

  group('pinning a track to the recap', () {
    test('reads both sides of the toggle', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(songs.first.actions.pinToRecap, isNotNull);
      expect(songs.first.actions.unpinFromRecap, isNotNull);
    });

    test('keeps the two sides apart', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(
        songs.first.actions.pinToRecap,
        isNot(songs.first.actions.unpinFromRecap),
      );
    });

    test('says the track is not pinned when the toggle is not toggled', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(songs.first.actions.pinnedToRecap, isFalse);
    });
  });

  /// A pinned track's row comes back with the two sides of the toggle the
  /// other way round: YouTube always puts the action it is offering on the
  /// `default` side, so the icons rather than the sides are what say which is
  /// which. Recorded from the account's own front page on 22 August 2026, with
  /// a track pinned for the purpose and unpinned again afterwards.
  group('a track that is already pinned', () {
    test('is read as pinned', () {
      final songs = parseCardSongs(_fixture('pinned_card.json'));

      expect(songs.single.actions.pinnedToRecap, isTrue);
    });

    test('offers the way back off the recap', () {
      final songs = parseCardSongs(_fixture('pinned_card.json'));

      expect(
        songs.single.actions.unpinFromRecap,
        isNotNull,
        reason: 'without this a pinned track could never be unpinned from the '
            'app: the only row that offers it is the one that is pinned',
      );
    });

    test('still knows the token that would pin it again', () {
      final songs = parseCardSongs(_fixture('pinned_card.json'));

      expect(songs.single.actions.pinToRecap, isNotNull);
      expect(
        songs.single.actions.pinToRecap,
        isNot(songs.single.actions.unpinFromRecap),
      );
    });

    test('a card carries the rest of the menu too', () {
      final songs = parseCardSongs(_fixture('pinned_card.json'));

      expect(
        songs.single.actions.removeFromLibrary,
        isNotNull,
        reason: 'the home feed draws tracks as cards, and a card has the same '
            'menu the list row has',
      );
    });
  });

  group('taking a track out of a playlist', () {
    test('keeps the handle the edit needs', () {
      final songs = parseSongList(_fixture('playlist_page.json'));

      expect(songs.first.actions.playlistSetVideoId, '56B44F6D10557CC6');
    });

    test('gives each row its own handle', () {
      final songs = parseSongList(_fixture('playlist_page.json'));

      expect(
        songs.map((song) => song.actions.playlistSetVideoId).toSet().length,
        songs.length,
      );
    });

    test('is absent on a surface that is not a playlist', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(songs.every((song) => song.actions.playlistSetVideoId == null),
          isTrue);
    });
  });

  group('the credits of a track', () {
    test('is offered where the row carries the entry', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(songs.first.actions.hasCredits, isTrue);
    });

    test('is not offered where the row does not', () {
      final songs = parseSongList(_fixture('history_page.json'));

      expect(
        songs.last.actions.hasCredits,
        isFalse,
        reason: 'a track with no credits still answers the browse id, but with '
            'nothing in it — 41 of 200 history rows are like that',
      );
    });
  });
}
