import '../../data/models/playlist.dart';
import '../../data/models/song.dart';

/// Reads a nested value, returning null instead of throwing when any hop is
/// missing. InnerTube responses are deeply nested and the shape varies between
/// result types, so absent keys are normal rather than exceptional.
Object? readPath(Object? node, List<Object> path) {
  var current = node;
  for (final key in path) {
    if (current is Map && key is String) {
      current = current[key];
    } else if (current is List && key is int && key < current.length) {
      current = current[key];
    } else {
      return null;
    }
  }
  return current;
}

/// Collects every value stored under [key], at any depth.
///
/// The rigid-path parsing that most InnerTube clients use breaks whenever
/// YouTube reorders a shelf or wraps results in a new container. Searching the
/// whole tree for the renderer we care about survives those reshuffles, which
/// is the difference between an app that keeps working for months and one that
/// needs a patch every few weeks.
List<Object?> findAll(Object? node, String key) {
  final results = <Object?>[];
  void walk(Object? current) {
    if (current is Map) {
      for (final entry in current.entries) {
        if (entry.key == key) {
          results.add(entry.value);
        } else {
          walk(entry.value);
        }
      }
    } else if (current is List) {
      current.forEach(walk);
    }
  }

  walk(node);
  return results;
}

Object? findFirst(Object? node, String key) {
  final all = findAll(node, key);
  return all.isEmpty ? null : all.first;
}

/// Joins the `runs` of a rich-text node into a plain string.
String _readRuns(Object? node) {
  final runs = readPath(node, ['runs']);
  if (runs is! List) return '';
  return runs
      .map((run) => readPath(run, ['text']))
      .whereType<String>()
      .join();
}

final _durationPattern = RegExp(r'(?:(\d+):)?(\d{1,2}):(\d{2})');

/// Finds a `h:mm:ss` or `m:ss` timestamp inside a metadata line.
///
/// YouTube separates the fields of a column with its own bullet character and
/// varies both the separator and the field order by result type, so the
/// timestamp is located by shape rather than by position. The last match wins:
/// when a title itself contains something clock-like, the real duration is
/// still the trailing value.
Duration? _parseDuration(String text) {
  final matches = _durationPattern.allMatches(text);
  if (matches.isEmpty) return null;
  final match = matches.last;
  return Duration(
    hours: int.tryParse(match.group(1) ?? '0') ?? 0,
    minutes: int.parse(match.group(2)!),
    seconds: int.parse(match.group(3)!),
  );
}

/// Turns a search response into playable tracks.
List<Song> parseSearchResults(Map<String, dynamic> json) => parseSongList(json);

/// Turns any InnerTube response into playable tracks.
///
/// Search, liked songs, history and playlist contents all render their rows
/// with the same list-item renderer, so one parser covers every surface.
/// Items with no `videoId` — artist and album cards, "did you mean" rows — are
/// dropped, since these screens only offer things that can start playing.
List<Song> parseSongList(Map<String, dynamic> json) {
  final songs = <Song>[];
  final seen = <String>{};

  for (final item in findAll(json, 'musicResponsiveListItemRenderer')) {
    final videoId = findFirst(item, 'videoId');
    if (videoId is! String || !seen.add(videoId)) continue;

    final columns = readPath(item, ['flexColumns']);
    if (columns is! List || columns.isEmpty) continue;

    final texts = columns
        .map((column) => _readRuns(
            readPath(column, ['musicResponsiveListItemFlexColumnRenderer', 'text'])))
        .where((text) => text.isNotEmpty)
        .toList();
    if (texts.isEmpty) continue;

    final title = texts.first;
    var subtitle = texts.length > 1 ? texts.sublist(1).join(' · ') : '';

    final duration = _parseDuration(subtitle);
    // Shown in its own column, so leaving it in the metadata line too would
    // print every track's length twice.
    if (duration != null) subtitle = _withoutDuration(subtitle);

    final thumbnails = findFirst(item, 'thumbnails');
    String? thumbnailUrl;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
    }

    songs.add(Song(
      videoId: videoId,
      title: title,
      subtitle: subtitle,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      artistId: _linkedPage(item, 'MUSIC_PAGE_TYPE_ARTIST'),
      albumId: _linkedPage(item, 'MUSIC_PAGE_TYPE_ALBUM'),
      artist: _artistName(texts),
    ));
  }

  return songs;
}

/// Picks the performer out of the columns of a row.
///
/// The metadata column opens with the kind of thing the row is — "Song",
/// "Video" — whenever YouTube feels like saying so, and the name follows.
/// Taking the first field that is neither one of those labels nor a number is
/// steadier than counting positions, which differ between search, playlists
/// and albums.
String? _artistName(List<String> texts) {
  if (texts.length < 2) return null;
  for (final field in texts[1].split(RegExp(r'\s*[•·]\s*'))) {
    final value = field.trim();
    if (value.isEmpty) continue;
    if (RegExp(r'^(song|video|episode|canción|episodio)$', caseSensitive: false)
        .hasMatch(value)) {
      continue;
    }
    if (RegExp(r'^\d').hasMatch(value)) continue; // play counts and years
    return value;
  }
  return null;
}

/// Finds the id of the artist or album a row links to.
///
/// The words in a metadata line are links, and each carries the kind of page it
/// opens. Matching on that kind rather than on position is what keeps this
/// working when YouTube reorders the line — which it does per result type.
String? _linkedPage(Object? item, String pageType) {
  for (final endpoint in findAll(item, 'browseEndpoint')) {
    final kind = readPath(endpoint, [
      'browseEndpointContextSupportedConfigs',
      'browseEndpointContextMusicConfig',
      'pageType',
    ]);
    if (kind != pageType) continue;
    final id = readPath(endpoint, ['browseId']);
    if (id is String && id.isNotEmpty) return id;
  }
  return null;
}

/// Strips the timestamp and any separator left dangling around it.
///
/// YouTube joins metadata with several different bullet characters, so the
/// cleanup has to cope with whichever one happened to sit beside the duration.
String _withoutDuration(String text) {
  return text
      .replaceFirst(_durationPattern, '')
      .replaceAll(RegExp(r'\s*[•·]\s*[•·]\s*'), ' • ')
      .replaceAll(RegExp(r'^\s*[•·]\s*|\s*[•·]\s*$'), '')
      .trim();
}

/// Extracts playlist and album cards from a library or browse response.
///
/// Library shelves render collections as two-row grid cards rather than the
/// list rows used for tracks, so this walks for that renderer instead. Cards
/// without a browse id are skipped: they cannot be opened.
List<Playlist> parsePlaylists(Map<String, dynamic> json) {
  final playlists = <Playlist>[];
  final seen = <String>{};

  for (final item in findAll(json, 'musicTwoRowItemRenderer')) {
    final endpoint = readPath(item, ['navigationEndpoint']);

    // A card opens its collection either by browsing it or by starting its
    // radio. Personalised mixes only ever offer the second, so reading nothing
    // but browse endpoints drops precisely the rows a signed-in feed is made
    // of. `VL` is the prefix that turns a playlist id into a browsable one.
    var browseId = readPath(endpoint, ['browseEndpoint', 'browseId']);
    if (browseId is! String) {
      final playlistId =
          readPath(endpoint, ['watchPlaylistEndpoint', 'playlistId']);
      if (playlistId is String) browseId = 'VL$playlistId';
    }
    if (browseId is! String || !seen.add(browseId)) continue;

    final title = _readRuns(readPath(item, ['title']));
    if (title.isEmpty) continue;

    final thumbnails = findFirst(item, 'thumbnails');
    String? thumbnailUrl;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
    }

    playlists.add(Playlist(
      browseId: browseId,
      title: title,
      subtitle: _readRuns(readPath(item, ['subtitle'])),
      thumbnailUrl: thumbnailUrl,
    ));
  }

  return playlists;
}

/// Reads the track list of a watch queue — what `next` answers with.
///
/// A different renderer from every other list in the app: the watch queue is
/// the player's own view of what comes next, and YouTube gives it its own
/// shape, with the artist and the album already joined into one byline.
List<Song> parseWatchQueue(Map<String, dynamic> json) {
  final songs = <Song>[];
  final seen = <String>{};

  for (final item in findAll(json, 'playlistPanelVideoRenderer')) {
    final videoId = readPath(item, ['videoId']);
    if (videoId is! String || !seen.add(videoId)) continue;

    final title = _readRuns(readPath(item, ['title']));
    if (title.isEmpty) continue;

    final thumbnails = findFirst(item, 'thumbnails');
    String? thumbnailUrl;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
    }

    final length = readPath(item, ['lengthText']);

    songs.add(Song(
      videoId: videoId,
      title: title,
      subtitle: _withoutDuration(_readRuns(readPath(item, ['longBylineText']))),
      thumbnailUrl: thumbnailUrl,
      duration: length == null ? null : _parseDuration(_readRuns(length)),
      artistId: _linkedPage(item, 'MUSIC_PAGE_TYPE_ARTIST'),
      albumId: _linkedPage(item, 'MUSIC_PAGE_TYPE_ALBUM'),
      artist: _readRuns(readPath(item, ['longBylineText']))
          .split(RegExp(r'\s*[•·]\s*'))
          .firstOrNull
          ?.trim(),
    ));
  }

  return songs;
}

/// Extracts single tracks rendered as grid cards.
///
/// The home feed shows songs the same way it shows albums — as a cover with a
/// title under it — so a track can arrive in the card renderer rather than the
/// list-row one. What tells them apart is the endpoint: a card that starts a
/// video is a song, whatever it looks like.
List<Song> parseCardSongs(Map<String, dynamic> json) {
  final songs = <Song>[];
  final seen = <String>{};

  for (final item in findAll(json, 'musicTwoRowItemRenderer')) {
    final videoId =
        readPath(item, ['navigationEndpoint', 'watchEndpoint', 'videoId']);
    if (videoId is! String || !seen.add(videoId)) continue;

    final title = _readRuns(readPath(item, ['title']));
    if (title.isEmpty) continue;

    final thumbnails = findFirst(item, 'thumbnails');
    String? thumbnailUrl;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
    }

    songs.add(Song(
      videoId: videoId,
      title: title,
      subtitle: _readRuns(readPath(item, ['subtitle'])),
      thumbnailUrl: thumbnailUrl,
    ));
  }

  return songs;
}

/// The title block at the top of an artist or album page.
///
/// YouTube has three renderers for the same idea and uses whichever the page
/// was built with, so all three are tried in turn rather than picking one and
/// hoping.
({String title, String subtitle, String? thumbnailUrl}) parsePageHeader(
  Map<String, dynamic> json,
) {
  const renderers = [
    'musicImmersiveHeaderRenderer',
    'musicDetailHeaderRenderer',
    'musicResponsiveHeaderRenderer',
  ];

  for (final renderer in renderers) {
    final header = findFirst(json, renderer);
    if (header == null) continue;

    final title = _readRuns(readPath(header, ['title']));
    if (title.isEmpty) continue;

    final thumbnails = findFirst(header, 'thumbnails');
    String? thumbnailUrl;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
    }

    return (
      title: title,
      subtitle: _readRuns(readPath(header, ['subtitle'])),
      thumbnailUrl: thumbnailUrl,
    );
  }

  return (title: '', subtitle: '', thumbnailUrl: null);
}

/// The containers YouTube builds a page's sections out of.
///
/// A carousel scrolls sideways, a grid wraps, a shelf is a plain list — but
/// they are the same idea, a heading over some things, and the app draws them
/// the same way. Which one a page uses is not a decision anyone here made.
const _sectionRenderers = {
  'musicCarouselShelfRenderer',
  'musicShelfRenderer',
  'gridRenderer',
};

/// Splits a browse response into its titled sections.
///
/// Every way a section can carry something playable is read, because which one
/// it uses depends on the page and on who is asking — and a section is dropped
/// only when all of them come back empty, rather than rendered as a title over
/// nothing. Sections are collected in the order the page lists them, since that
/// order is editorial: the front page leads with what it wants seen first.
List<Shelf> parseShelves(Map<String, dynamic> json) {
  final shelves = <Shelf>[];

  void walk(Object? node) {
    if (node is List) {
      node.forEach(walk);
      return;
    }
    if (node is! Map) return;

    for (final entry in node.entries) {
      if (!_sectionRenderers.contains(entry.key)) {
        walk(entry.value);
        continue;
      }

      final section = entry.value is Map<String, dynamic>
          ? entry.value as Map<String, dynamic>
          : <String, dynamic>{'contents': entry.value};

      final shelf = Shelf(
        title: _sectionTitle(section),
        playlists: [...parsePlaylists(section), ...parseArtistRows(section)],
        songs: [...parseSongList(section), ...parseCardSongs(section)],
      );
      if (shelf.title.isNotEmpty && !shelf.isEmpty) shelves.add(shelf);
    }
  }

  walk(json);
  return shelves;
}

/// The heading of a section: the first non-empty run of text inside it.
///
/// Headers come wrapped in a different renderer per section type, so the text
/// is found by shape. It works because the heading is always the first text in
/// the block — the cards' own titles come after.
String _sectionTitle(Map<String, dynamic> section) {
  for (final runs in findAll(section, 'runs').whereType<List>()) {
    if (runs.isEmpty) continue;
    final text = readPath(runs.first, ['text']);
    if (text is String && text.trim().isNotEmpty) return text;
  }
  return '';
}

/// Reads people out of a list of rows.
///
/// The charts rank artists in the same renderer used for tracks, but without a
/// video id — there is nothing to play, only someone to go and see. Those rows
/// were being dropped as unplayable, which is how a chart of forty artists
/// rendered as nothing at all.
List<Playlist> parseArtistRows(Map<String, dynamic> json) {
  final artists = <Playlist>[];
  final seen = <String>{};

  for (final item in findAll(json, 'musicResponsiveListItemRenderer')) {
    if (findFirst(item, 'videoId') != null) continue;

    final browseId = _linkedPage(item, 'MUSIC_PAGE_TYPE_ARTIST');
    if (browseId == null || !seen.add(browseId)) continue;

    final columns = readPath(item, ['flexColumns']);
    if (columns is! List || columns.isEmpty) continue;

    final title = _readRuns(readPath(columns.first, [
      'musicResponsiveListItemFlexColumnRenderer',
      'text',
    ]));
    if (title.isEmpty) continue;

    final thumbnails = findFirst(item, 'thumbnails');
    String? thumbnailUrl;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
    }

    artists.add(Playlist(
      browseId: browseId,
      title: title,
      thumbnailUrl: thumbnailUrl,
    ));
  }

  return artists;
}

/// The mood and genre buttons of the explore page.
///
/// Each is a browse id plus opaque params; neither means anything without the
/// other, so they travel together.
List<Playlist> parseMoodChips(Map<String, dynamic> json) {
  final chips = <Playlist>[];
  final seen = <String>{};

  for (final button in findAll(json, 'musicNavigationButtonRenderer')) {
    final title = _readRuns(readPath(button, ['buttonText']));
    final endpoint = readPath(button, ['clickCommand', 'browseEndpoint']);
    final browseId = readPath(endpoint, ['browseId']);
    final params = readPath(endpoint, ['params']);
    if (title.isEmpty || browseId is! String || !seen.add('$browseId$params')) {
      continue;
    }

    chips.add(Playlist(
      browseId: browseId,
      title: title,
      params: params is String ? params : null,
    ));
  }

  return chips;
}

/// Picks the best audio-only stream from a player response.
///
/// Only formats carrying a ready `url` are considered; anything behind a
/// `signatureCipher` would need a JavaScript interpreter to unscramble, and
/// the iOS client is used precisely so that never happens.
AudioStream? parseBestAudioStream(Map<String, dynamic> json) {
  final formats = readPath(json, ['streamingData', 'adaptiveFormats']);
  if (formats is! List) return null;

  AudioStream? best;
  for (final format in formats) {
    final mimeType = readPath(format, ['mimeType']);
    final url = readPath(format, ['url']);
    if (mimeType is! String || !mimeType.startsWith('audio') || url is! String) {
      continue;
    }
    final bitrate = (readPath(format, ['bitrate']) as num?)?.toInt() ?? 0;
    if (best == null || bitrate > best.bitrate) {
      best = AudioStream(url: url, bitrate: bitrate, mimeType: mimeType);
    }
  }
  return best;
}
