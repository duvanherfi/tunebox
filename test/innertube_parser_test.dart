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

  group('readPath', () {
    test('returns null instead of throwing on a missing hop', () {
      expect(readPath(const {'a': 1}, ['b', 'c']), isNull);
    });

    test('walks maps and list indices', () {
      expect(readPath(const {'a': [{'b': 'ok'}]}, ['a', 0, 'b']), 'ok');
    });
  });
}
