import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/innertube/parsers.dart';

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
  group('parseSearchResults', () {
    test('extracts playable tracks from a search response', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json'));

      expect(songs, isNotEmpty);
      expect(songs.every((song) => song.videoId.isNotEmpty), isTrue);
      expect(songs.every((song) => song.title.isNotEmpty), isTrue);
    });

    test('deduplicates tracks repeated across shelves', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json'));
      final ids = songs.map((song) => song.videoId).toSet();

      expect(ids.length, songs.length);
    });

    test('reads artwork and duration when present', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json'));

      expect(songs.any((song) => song.thumbnailUrl != null), isTrue,
          reason: 'thumbnail path changed');
      expect(songs.any((song) => song.duration != null), isTrue,
          reason: 'duration is no longer in the metadata line');
    });

    test('keeps the duration out of the metadata line', () {
      final songs = parseSearchResults(_fixture('search_daft_punk.json'));
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

    test('returns nothing for a response with no result renderers', () {
      expect(parseSearchResults(const {'contents': {}}), isEmpty);
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
}
