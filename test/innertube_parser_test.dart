import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/innertube/parsers.dart';
import 'package:tunebox/data/models/search.dart';

/// These run against real responses recorded from InnerTube.
///
/// Parsing is the only part of the app YouTube can break unilaterally: they
/// reshape the response, every screen empties, and nothing else in the codebase
/// changes. When that happens, re-record the fixtures and these tests point at
/// exactly what moved.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('podcast episodes', () {
    // The same page, anonymous and signed in. Measured on 11 September 2026:
    // the account is what makes the two actions appear at all — anonymous, an
    // episode's menu is five inert items and neither toggle is among them.
    test('a signed-out episode offers neither action', () {
      final episodes = parseSongList(_fixture('podcast_page.json'));

      expect(episodes, isNotEmpty);
      for (final episode in episodes) {
        expect(episode.actions.markPlayed, isNull);
        expect(episode.actions.queueForLater, isFalse);
      }
    });

    test('a signed-in episode carries both sides of "mark as played"', () {
      final episodes = parseSongList(_fixture('podcast_page_signed_in.json'));

      expect(episodes, isNotEmpty);
      for (final episode in episodes) {
        // Both sides travel, and `played` says which one to send. The recorded
        // page has nothing played, so the offer is to mark it.
        expect(episode.actions.markPlayed, isNotNull);
        expect(episode.actions.markUnplayed, isNotNull);
        expect(episode.actions.markPlayed, isNot(episode.actions.markUnplayed));
        expect(episode.actions.played, isFalse);
      }
    });

    // The trap: an episode's menu carries three toggles and every one of them
    // holds feedback tokens. Sending the pin's where the played one goes does
    // not fail — it silently makes a different edit.
    test('does not confuse the played toggle with the pin', () {
      final episode =
          parseSongList(_fixture('podcast_page_signed_in.json')).first;

      expect(episode.actions.pinToRecap, isNotNull);
      expect(episode.actions.pinToRecap, isNot(episode.actions.markPlayed));
      expect(episode.actions.unpinFromRecap, isNot(episode.actions.markPlayed));
      expect(episode.actions.pinToRecap, isNot(episode.actions.markUnplayed));
    });

    // The same episode after marking it played, recorded from the real account
    // on 11 September 2026. This is what says the state is `isToggled` and not
    // which side YouTube is offering: the icons are identical in both files.
    test('reads a played episode as played', () {
      final episode =
          parseSongList(_fixture('podcast_episode_played.json')).single;

      expect(episode.actions.played, isTrue);
      expect(episode.actions.markUnplayed, isNotNull);
    });

    test('the played row offers the same two tokens, on the same sides', () {
      final unplayed =
          parseSongList(_fixture('podcast_page_signed_in.json')).first;
      final played =
          parseSongList(_fixture('podcast_episode_played.json')).single;

      // Same row, same episode, one marked and one not. The tokens are the
      // row's own so they differ; which side each lives on does not.
      expect(unplayed.videoId, played.videoId);
      expect(unplayed.actions.played, isFalse);
      expect(played.actions.played, isTrue);
      expect(played.actions.markPlayed, isNotNull);
    });

    test('reads whether the row offers "Episodes for Later"', () {
      final episodes = parseSongList(_fixture('podcast_page_signed_in.json'));

      for (final episode in episodes) {
        expect(episode.actions.queueForLater, isTrue);
        expect(episode.actions.queuedForLater, isFalse);
      }
    });
  });

  group('parseSearchResults', () {
    test('extracts playable tracks from a search response', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json')).songs;

      expect(songs, isNotEmpty);
      expect(songs.every((song) => song.videoId.isNotEmpty), isTrue);
      expect(songs.every((song) => song.title.isNotEmpty), isTrue);
    });

    test('deduplicates tracks repeated across shelves', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json')).songs;
      final ids = songs.map((song) => song.videoId).toSet();

      expect(ids.length, songs.length);
    });

    test('reads artwork and duration when present', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json')).songs;

      expect(songs.any((song) => song.thumbnailUrl != null), isTrue,
          reason: 'thumbnail path changed');
      expect(songs.any((song) => song.duration != null), isTrue,
          reason: 'duration is no longer in the metadata line');
    });

    test('keeps the duration out of the metadata line', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json')).songs;
      final timed = songs.where((song) => song.duration != null);

      expect(timed, isNotEmpty, reason: 'nothing to check otherwise');
      for (final song in timed) {
        expect(
          song.subtitle,
          isNot(matches(RegExp(r'\d+:\d{2}'))),
          reason: 'the duration has its own column and would print twice',
        );
      }
    });

    // The whole point of the parser: the response holds far more than tracks,
    // and every row of it is a page the app can open. Measured on 10 September
    // 2026 against the same query these fixtures were recorded from.
    test('keeps the rows that are pages, not tracks', () {
      final results = parseSearchResults(_fixture('search_daft_punk.json'));
      final kinds = <CollectionKind, int>{};
      for (final row in results.results) {
        if (row.kind != null) kinds.update(row.kind!, (n) => n + 1, ifAbsent: () => 1);
      }

      // 14 playable rows plus the top-result card, which is not one of them.
      expect(results.songs.length, 15);
      expect(kinds, {
        CollectionKind.album: 3,
        CollectionKind.artist: 3,
        CollectionKind.playlist: 6,
        CollectionKind.profile: 3,
        CollectionKind.podcast: 3,
      });
    });

    test('tells a profile from an artist, which share a prefix', () {
      final results = parseSearchResults(_fixture('search_daft_punk.json'));
      final profiles = results.results
          .where((row) => row.kind == CollectionKind.profile)
          .map((row) => row.collection!);

      expect(profiles, isNotEmpty);
      expect(
        profiles.every((profile) => profile.browseId.startsWith('UC')),
        isTrue,
        reason: 'the id alone would call these artists',
      );
    });

    test('leads with the top-result card', () {
      final results = parseSearchResults(_fixture('search_daft_punk.json'));

      expect(results.results.first.song?.videoId, '5NV6Rdv1a3I');
      expect(
        results.songs.map((song) => song.videoId).toSet().length,
        results.songs.length,
        reason: 'the card is often listed again below, and would show twice',
      );
    });

    test('reads the filters YouTube offers, tokens included', () {
      final filters = parseSearchResults(_fixture('search_daft_punk.json')).filters;

      expect(filters.length, 9);
      expect(filters.every((filter) => filter.label.isNotEmpty), isTrue);
      expect(filters.every((filter) => filter.params.isNotEmpty), isTrue);
      expect(
        filters.any((filter) => filter.params.contains('%')),
        isFalse,
        reason: 'an escaped token asks for nothing',
      );
    });

    // The trap this guards: an artist row's menu carries two watch playlist
    // endpoints and both begin with `RD`. The first is their shuffle (`RDAO`)
    // and only the second is their mix, so taking whichever came first put a
    // shuffle where the radio should be.
    test('reads each collection row\'s own mix, not its shuffle', () {
      final results = parseSearchResults(_fixture('search_daft_punk.json'));

      final artists = results.results
          .where((row) => row.kind == CollectionKind.artist)
          .map((row) => row.collection!);
      expect(artists, isNotEmpty);
      for (final artist in artists) {
        expect(artist.radioPlaylistId, startsWith('RDEM'));
      }

      for (final kind in [CollectionKind.album, CollectionKind.playlist]) {
        final rows = results.results
            .where((row) => row.kind == kind)
            .map((row) => row.collection!);
        expect(rows, isNotEmpty);
        for (final row in rows) {
          expect(row.radioPlaylistId, startsWith('RDAMPL'));
        }
      }
    });

    // A profile and a podcast ship no watch playlist endpoint at all, which is
    // why the menu asks whether to offer a radio rather than assuming one.
    test('leaves the rows with no mix without one', () {
      final results = parseSearchResults(_fixture('search_daft_punk.json'));
      final without = results.results.where((row) =>
          row.kind == CollectionKind.profile ||
          row.kind == CollectionKind.podcast);

      expect(without, isNotEmpty);
      expect(
        without.every((row) => row.collection!.radioPlaylistId == null),
        isTrue,
      );
    });

    test('reads the top-result card\'s own buttons', () {
      final results = parseSearchResults(_fixture('search_daft_punk.json'));
      final card = results.results.first;

      expect(card.top, isTrue);
      // Two buttons came; only one of them plays anything. The other is
      // "Guardar", a `modalEndpoint` asking an anonymous listener to sign in,
      // and a button that cannot do what it says is worse than no button.
      expect(card.buttons.length, 1);
      expect(card.buttons.single.icon, 'PLAY_ARROW');
      expect(card.buttons.single.videoId, '5NV6Rdv1a3I');
      expect(card.buttons.single.label, isNotEmpty);
    });

    test('marks only the card as the top result', () {
      final results = parseSearchResults(_fixture('search_daft_punk.json'));

      expect(results.results.where((row) => row.top).length, 1);
      expect(results.results.skip(1).every((row) => row.buttons.isEmpty), isTrue);
    });

    test('returns nothing for a response with no result renderers', () {
      expect(parseSearchResults(const {'contents': {}}).isEmpty, isTrue);
    });
  });

  group('podcasts and channels', () {
    // A show's episodes arrive in a renderer nothing else in the app uses, and
    // they were the reason a podcast opened as an empty list.
    test('reads a show as the list of tracks it is', () {
      final songs = parseSongList(_fixture('podcast_page.json'));

      expect(songs, isNotEmpty);
      expect(songs.every((song) => song.videoId.isNotEmpty), isTrue);
      expect(songs.every((song) => song.title.isNotEmpty), isTrue);
      expect(songs.every((song) => song.thumbnailUrl != null), isTrue);
    });

    test('names the show', () {
      expect(parsePageHeader(_fixture('podcast_page.json')).title, 'Music Story');
    });

    // A profile from search opens on the artist page, and a channel heads
    // itself with a renderer no other page uses: without it the page came up
    // blank at the top.
    test('names a channel, which heads itself differently', () {
      final header = parsePageHeader(_fixture('channel_page.json'));

      expect(header.title, isNotEmpty);
      expect(header.thumbnailUrl, isNotNull);
    });

    test('reads what a channel published', () {
      final shelves = parseShelves(_fixture('channel_page.json'));

      expect(shelves, isNotEmpty);
      expect(shelves.every((shelf) => shelf.title.isNotEmpty), isTrue);
      expect(shelves.any((shelf) => shelf.playlists.isNotEmpty), isTrue);
    });
  });

  group('parseBestAudioStream', () {
    test('picks the highest-bitrate audio-only format', () {
      final stream = parseBestAudioStream(_fixture('player_ios.json'));

      expect(stream, isNotNull);
      expect(stream!.mimeType, startsWith('audio'));
      expect(stream.bitrate, greaterThan(0));
      expect(stream.url, startsWith('https://'));
    });

    test('returns null when no streaming data is present', () {
      expect(parseBestAudioStream(const {'playabilityStatus': {}}), isNull);
    });
  });

  group('parseShelves', () {
    Map<String, dynamic> carousel(String title, List<Object> items) => {
          'musicCarouselShelfRenderer': {
            'header': {
              'musicCarouselShelfBasicHeaderRenderer': {
                'title': {
                  'runs': [
                    {'text': title},
                  ],
                },
              },
            },
            'contents': items,
          },
        };

    Map<String, dynamic> card(String title, Map<String, Object> endpoint) => {
          'musicTwoRowItemRenderer': {
            'title': {
              'runs': [
                {'text': title},
              ],
            },
            'navigationEndpoint': endpoint,
          },
        };

    test('reads mixes, which only ever offer a watch playlist endpoint', () {
      final shelves = parseShelves({
        'contents': [
          carousel('Mixed for you', [
            card('My Supermix', {
              'watchPlaylistEndpoint': {'playlistId': 'RDTMAK5uy'},
            }),
          ]),
        ],
      });

      expect(shelves, hasLength(1));
      expect(shelves.single.playlists.single.browseId, 'VLRDTMAK5uy');
    });

    test('reads tracks that arrive as cards rather than list rows', () {
      final shelves = parseShelves({
        'contents': [
          carousel('Listen again', [
            card('Glory Box', {
              'watchEndpoint': {'videoId': 'abc123'},
            }),
          ]),
        ],
      });

      expect(shelves.single.playlists, isEmpty);
      expect(shelves.single.songs.single.videoId, 'abc123');
    });

    test('drops a row with a heading but nothing playable under it', () {
      final shelves = parseShelves({
        'contents': [
          carousel('Empty', [
            card('An artist', {
              'browseEndpoint': <String, Object>{},
            }),
          ]),
        ],
      });

      expect(shelves, isEmpty);
    });
  });

  group('parseHomeChips', () {
    test('reads the moods over the front page', () {
      final chips = parseHomeChips(_fixture('home_page.json'));

      expect(chips, hasLength(10));
      expect(chips.map((chip) => chip.title), contains('Relax'));
      expect(
        chips.every((chip) => chip.browseId == 'FEmusic_home'),
        isTrue,
        reason: 'a mood is the same page asked for again, refiltered',
      );
      expect(
        chips.map((chip) => chip.params).toSet(),
        hasLength(10),
        reason: 'the token is the only thing telling one mood from another',
      );
    });

    test('leaves the chips of a search alone', () {
      expect(
        parseHomeChips(_fixture('search_daft_punk.json')),
        isEmpty,
        reason: 'a search filter is the same renderer over a search endpoint, '
            'and it narrows a query rather than a page',
      );
    });

    test('finds where the front page carries on', () {
      expect(parseContinuationToken(_fixture('home_page.json')), isNotEmpty);
    });
  });

  group('parseWatchQueue', () {
    test('reads the rows a radio comes back as', () {
      final songs = parseWatchQueue({
        'contents': [
          {
            'playlistPanelVideoRenderer': {
              'videoId': 'abc123',
              'title': {
                'runs': [
                  {'text': 'Daydream In Blue'},
                ],
              },
              'longBylineText': {
                'runs': [
                  {'text': 'I Monster • Neveroddoreven • 3:52'},
                ],
              },
              'lengthText': {
                'runs': [
                  {'text': '3:52'},
                ],
              },
            },
          },
        ],
      });

      expect(songs.single.videoId, 'abc123');
      expect(songs.single.duration, const Duration(minutes: 3, seconds: 52));
      expect(
        songs.single.subtitle,
        isNot(contains('3:52')),
        reason: 'the length has its own column',
      );
    });
  });

  group('readPath', () {
    test('returns null instead of throwing on a missing hop', () {
      expect(readPath(const {'a': 1}, ['b', 'c']), isNull);
    });

    test('walks maps and list indices', () {
      expect(readPath(const {'a': [{'b': 'ok'}]}, ['a', 0, 'b']), 'ok');
    });
  });

  // AVFoundation cannot decode WebM at all, and YouTube's highest-bitrate audio
  // is Opus in WebM — so on Apple platforms "best" has to mean "best of what
  // this one can open", or every track dies with AVErrorFileFormatNotRecognized
  // (-11828). ExoPlayer plays both, which is why Android never saw it.
  group('parseBestAudioStream', () {
    final response = {
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
    };

    test('takes the highest bitrate when any container will do', () {
      expect(
        parseBestAudioStream(response)!.url,
        'https://example.invalid/opus',
      );
    });

    test('prefers mp4 over a higher-bitrate webm when asked', () {
      expect(
        parseBestAudioStream(response, preferMp4: true)!.url,
        'https://example.invalid/m4a',
      );
    });

    test('still answers with webm when mp4 is the one missing', () {
      final webmOnly = {
        'streamingData': {
          'adaptiveFormats': [
            {
              'mimeType': 'audio/webm; codecs="opus"',
              'url': 'https://example.invalid/opus',
              'bitrate': 160000,
            },
          ],
        },
      };

      expect(
        parseBestAudioStream(webmOnly, preferMp4: true)!.url,
        'https://example.invalid/opus',
      );
    });
  });

  // One pick is one chance: a format the player cannot open loses the whole
  // track even when the same response carried another it could have played.
  // The candidates come out ranked so the caller can walk them.
  group('parseAudioStreams', () {
    Map<String, dynamic> withFormats(List<Map<String, Object?>> formats) => {
          'streamingData': {'adaptiveFormats': formats},
        };

    test('ranks by bitrate, then by codec', () {
      final streams = parseAudioStreams(withFormats([
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
      ]));

      expect(
        streams.map((s) => s.url),
        ['https://example.invalid/opus', 'https://example.invalid/m4a'],
      );
    });

    test('puts mp4 first when asked, keeping the rest as fallbacks', () {
      final streams = parseAudioStreams(
        withFormats([
          {
            'mimeType': 'audio/webm; codecs="opus"',
            'url': 'https://example.invalid/opus',
            'bitrate': 160000,
          },
          {
            'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
            'url': 'https://example.invalid/m4a',
            'bitrate': 128000,
          },
        ]),
        preferMp4: true,
      );

      expect(
        streams.map((s) => s.url),
        ['https://example.invalid/m4a', 'https://example.invalid/opus'],
      );
    });

    test('drops what could never play: no url, no bitrate, not audio', () {
      final streams = parseAudioStreams(withFormats([
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'signatureCipher': 'locked',
          'bitrate': 128000,
        },
        {
          'mimeType': 'audio/webm; codecs="opus"',
          'url': 'https://example.invalid/zero',
          'bitrate': 0,
        },
        {
          'mimeType': 'video/mp4; codecs="avc1"',
          'url': 'https://example.invalid/video',
          'bitrate': 900000,
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'url': 'https://example.invalid/good',
          'bitrate': 128000,
        },
      ]));

      expect(streams.map((s) => s.url), ['https://example.invalid/good']);
    });
  });

  // AVFoundation reads YouTube's fragmented mp4 audio as exactly twice its
  // length, so the platform player cannot be the authority on how long a track
  // is. The server states it twice — as a field and on the media URL — and
  // both were measured against the real audio.
  group('parseAudioStreams duration', () {
    Map<String, dynamic> withFormats(List<Map<String, Object?>> formats) => {
          'streamingData': {'adaptiveFormats': formats},
        };

    test('reads how long the track really is', () {
      final streams = parseAudioStreams(withFormats([
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'url': 'https://example.invalid/m4a?dur=293.082',
          'bitrate': 128000,
          'approxDurationMs': '293082',
        },
      ]));

      expect(streams.single.duration, const Duration(milliseconds: 293082));
    });

    // The field is the better source — it is per format and needs no parsing —
    // but it is one rename away from vanishing, and losing it silently would
    // put the doubled length back. The URL carries the same seconds.
    test('falls back to the seconds on the media URL', () {
      final streams = parseAudioStreams(withFormats([
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'url': 'https://example.invalid/m4a?itag=140&dur=293.082&x=1',
          'bitrate': 128000,
        },
      ]));

      expect(streams.single.duration, const Duration(milliseconds: 293082));
    });

    test('says nothing when the server states neither', () {
      final streams = parseAudioStreams(withFormats([
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'url': 'https://example.invalid/m4a',
          'bitrate': 128000,
        },
      ]));

      expect(streams.single.duration, isNull);
    });

    test('reads it from a recorded response', () {
      final streams = parseAudioStreams(_fixture('player_ios.json'));

      expect(streams, isNotEmpty);
      for (final stream in streams) {
        expect(stream.duration, isNotNull);
        // The recorded track is 249 seconds; the formats differ by a frame or
        // two, which is why each carries its own.
        expect(stream.duration!.inSeconds, closeTo(249, 1));
      }
    });
  });

  group('parseSongIds', () {
    test('names the same tracks parseSongList builds', () {
      final json = _fixture('search_daft_punk.json');

      expect(
        parseSongIds(json),
        parseSongList(json).map((song) => song.videoId).toList(),
      );
    });

    test('is empty rather than throwing on a response with no rows', () {
      expect(parseSongIds(const {'contents': {}}), isEmpty);
    });
  });

  group('parseContinuationToken', () {
    test('reads the command the current responses carry', () {
      expect(
        parseContinuationToken(const {
          'contents': {
            'continuationItemRenderer': {
              'continuationEndpoint': {
                'continuationCommand': {'token': 'next-page'},
              },
            },
          },
        }),
        'next-page',
      );
    });

    test('falls back to the older continuation data', () {
      expect(
        parseContinuationToken(const {
          'contents': {
            'musicShelfRenderer': {
              'continuations': [
                {
                  'nextContinuationData': {'continuation': 'older-page'},
                },
              ],
            },
          },
        }),
        'older-page',
      );
    });

    test('answers null at the end of the list', () {
      expect(parseContinuationToken(_fixture('search_daft_punk.json')), isNull);
    });
  });
}
