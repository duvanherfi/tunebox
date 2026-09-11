import '../../data/models/credits.dart';
import '../../data/models/playlist.dart';
import '../../data/models/search.dart';
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

/// Which page a row points at, by the type YouTube files it under.
///
/// Only the five kinds search answers with. Anything else — a page shape this
/// app has nowhere to open — is left out rather than sent somewhere wrong.
const _collectionKinds = <String, CollectionKind>{
  'MUSIC_PAGE_TYPE_ALBUM': CollectionKind.album,
  'MUSIC_PAGE_TYPE_PLAYLIST': CollectionKind.playlist,
  'MUSIC_PAGE_TYPE_ARTIST': CollectionKind.artist,
  'MUSIC_PAGE_TYPE_USER_CHANNEL': CollectionKind.profile,
  'MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE': CollectionKind.podcast,
};

/// Turns a search response into the mixed list YouTube ranked.
///
/// Search answers with far more than tracks, and reading only the rows that
/// carry a `videoId` threw away more than half of it: measured against the real
/// endpoint on 10 September 2026, "daft punk" came back with 32 rows of which
/// only 14 were playable — the other 18 were 3 albums, 3 artists, 6 playlists,
/// 3 profiles and 3 podcasts, every one of them a page this app already knows
/// how to open.
///
/// The rows stay in the order they arrived, mixed. YouTube sends no section
/// headings with an unfiltered search — one top-result card and 29 loose rows —
/// so grouping by kind would mean inventing a grouping that never came, and the
/// kind is already written into the subtitle of every row, in the listener's
/// own language.
SearchResults parseSearchResults(Map<String, dynamic> json) {
  final results = <SearchResult>[];
  final seen = <String>{};

  // The card YouTube puts above everything else. It is not one of the rows —
  // its own three rows are — so it is read first and separately. First is also
  // what keeps it from showing twice when the list below repeats it, which is
  // ordinary for a top result.
  final card = findFirst(json, 'musicCardShelfRenderer');
  if (card != null) {
    final top = _cardResult(card, seen);
    if (top != null) results.add(top);
  }

  for (final item in findAll(json, 'musicResponsiveListItemRenderer')) {
    if (findFirst(item, 'videoId') != null) {
      final song = _songRow(item, seen);
      if (song != null) results.add(SearchResult.song(song));
      continue;
    }
    final collection = _collectionRow(item, seen);
    if (collection != null) results.add(collection);
  }

  return SearchResults(
    results: results,
    filters: parseSearchFilters(json),
  );
}

/// The ways YouTube offers to narrow this query.
///
/// Nine of them arrive with every response, tokens included, so they are read
/// rather than hard-coded: what the app used to offer was two filters written
/// out by hand, and the reason there were only two was that everything else
/// came back as rows the parser dropped.
///
/// The chip that clears the filter comes with no label and no token, and a
/// filtered response leads with it; it is skipped, since clearing the filter is
/// the app's own "All" chip.
List<SearchFilter> parseSearchFilters(Map<String, dynamic> json) {
  final filters = <SearchFilter>[];
  final seen = <String>{};

  for (final chip in findAll(json, 'chipCloudChipRenderer')) {
    final label = _readRuns(readPath(chip, ['text']));
    final params = readPath(chip, ['navigationEndpoint', 'searchEndpoint', 'params']);
    if (label.isEmpty || params is! String || !seen.add(params)) continue;

    filters.add(SearchFilter(
      label: label,
      // Two of the nine arrive percent-escaped and the rest do not; decoding is
      // a no-op on those, and sending an escaped token asks for nothing.
      params: Uri.decodeComponent(params),
      selected: readPath(chip, ['isSelected']) == true,
    ));
  }

  return filters;
}

/// The top-result card, as one more row.
///
/// Everything the card shows is a title, a subtitle and one endpoint, which is
/// exactly what a row is, so it goes into the same list rather than becoming a
/// second shape on screen. Its own menu is not read: the card wraps the three
/// rows underneath it, and their tokens would come back as if they were its.
SearchResult? _cardResult(Object? card, Set<String> seen) {
  final title = _readRuns(readPath(card, ['title']));
  if (title.isEmpty) return null;

  final subtitle = _readRuns(readPath(card, ['subtitle']));
  final thumbnails = findFirst(readPath(card, ['thumbnail']), 'thumbnails');
  String? thumbnailUrl;
  if (thumbnails is List && thumbnails.isNotEmpty) {
    thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
  }

  final videoId = readPath(card, ['onTap', 'watchEndpoint', 'videoId']);
  if (videoId is String && seen.add(videoId)) {
    return SearchResult.song(Song(
      videoId: videoId,
      title: title,
      subtitle: _withoutDuration(subtitle),
      thumbnailUrl: thumbnailUrl,
      duration: _parseDuration(subtitle),
    ));
  }

  final browse = readPath(card, ['onTap', 'browseEndpoint']);
  final browseId = readPath(browse, ['browseId']);
  final kind = _collectionKinds[readPath(browse, [
    'browseEndpointContextSupportedConfigs',
    'browseEndpointContextMusicConfig',
    'pageType',
  ])];
  if (browseId is! String || kind == null || !seen.add(browseId)) return null;

  return SearchResult.collection(
    Playlist(
      browseId: browseId,
      title: title,
      subtitle: subtitle,
      thumbnailUrl: thumbnailUrl,
    ),
    kind,
  );
}

/// A row that points at a page instead of a track.
///
/// The kind comes from the row's own `navigationEndpoint` rather than from any
/// browse endpoint inside it: an album row also links to its artist and a
/// playlist row to whoever made it, so reading the first page type found in the
/// subtree would open the wrong page about a third of the time.
SearchResult? _collectionRow(Object? item, Set<String> seen) {
  final browse = readPath(item, ['navigationEndpoint', 'browseEndpoint']);
  final browseId = readPath(browse, ['browseId']);
  final kind = _collectionKinds[readPath(browse, [
    'browseEndpointContextSupportedConfigs',
    'browseEndpointContextMusicConfig',
    'pageType',
  ])];
  if (browseId is! String || kind == null || !seen.add(browseId)) return null;

  final columns = readPath(item, ['flexColumns']);
  if (columns is! List || columns.isEmpty) return null;

  final texts = columns
      .map((column) => _readRuns(
          readPath(column, ['musicResponsiveListItemFlexColumnRenderer', 'text'])))
      .where((text) => text.isNotEmpty)
      .toList();
  if (texts.isEmpty) return null;

  final thumbnails = findFirst(item, 'thumbnails');
  String? thumbnailUrl;
  if (thumbnails is List && thumbnails.isNotEmpty) {
    thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
  }

  return SearchResult.collection(
    Playlist(
      browseId: browseId,
      title: texts.first,
      subtitle: texts.length > 1 ? texts.sublist(1).join(' · ') : '',
      thumbnailUrl: thumbnailUrl,
    ),
    kind,
  );
}

/// Lists the track ids of a response, without building the tracks.
///
/// The same rows [parseSongList] reads, reduced to what a membership test
/// needs. Seeding the liked set walks pages of a thousand rows whose titles,
/// artwork and durations nobody will ever read, and a set of strings is what
/// the heart asks about.
List<String> parseSongIds(Map<String, dynamic> json) {
  final ids = <String>[];
  final seen = <String>{};

  for (final item in findAll(json, 'musicResponsiveListItemRenderer')) {
    final videoId = findFirst(item, 'videoId');
    if (videoId is String && seen.add(videoId)) ids.add(videoId);
  }
  return ids;
}

/// The token that asks for the next page, or null at the end of the list.
///
/// Both shapes are read because YouTube serves both: the newer responses wrap
/// it in a `continuationCommand`, while some shelves still carry the older
/// `nextContinuationData`. Which one arrives is not worth finding out at the
/// call site.
String? parseContinuationToken(Map<String, dynamic> json) {
  final command = findFirst(json, 'continuationCommand');
  final token = readPath(command, ['token']);
  if (token is String && token.isNotEmpty) return token;

  final legacy = readPath(findFirst(json, 'nextContinuationData'), ['continuation']);
  return legacy is String && legacy.isNotEmpty ? legacy : null;
}

/// Turns any InnerTube response into playable tracks.
///
/// Search, liked songs, history and playlist contents all render their rows
/// with the same list-item renderer, so one parser covers every surface.
/// Items with no `videoId` — artist and album cards, "did you mean" rows — are
/// dropped, since these screens only offer things that can start playing.
///
/// A podcast is the exception in shape but not in kind: its episodes come in a
/// renderer of their own and they do carry a video id, so they are read here
/// too and a show ends up being a list of tracks like any other.
List<Song> parseSongList(Map<String, dynamic> json) {
  final songs = <Song>[];
  final seen = <String>{};

  for (final item in findAll(json, 'musicResponsiveListItemRenderer')) {
    final song = _songRow(item, seen);
    if (song != null) songs.add(song);
  }

  for (final item in findAll(json, 'musicMultiRowListItemRenderer')) {
    final episode = _episodeRow(item, seen);
    if (episode != null) songs.add(episode);
  }

  return songs;
}

/// One track, out of the row that lists it. Null when the row is not a track or
/// when [seen] has it already.
Song? _songRow(Object? item, Set<String> seen) {
  final videoId = findFirst(item, 'videoId');
  if (videoId is! String || !seen.add(videoId)) return null;

  final columns = readPath(item, ['flexColumns']);
  if (columns is! List || columns.isEmpty) return null;

  final texts = columns
      .map((column) => _readRuns(
          readPath(column, ['musicResponsiveListItemFlexColumnRenderer', 'text'])))
      .where((text) => text.isNotEmpty)
      .toList();
  if (texts.isEmpty) return null;

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

  return Song(
    videoId: videoId,
    title: title,
    subtitle: subtitle,
    thumbnailUrl: thumbnailUrl,
    duration: duration,
    artistId: _linkedPage(item, 'MUSIC_PAGE_TYPE_ARTIST'),
    albumId: _linkedPage(item, 'MUSIC_PAGE_TYPE_ALBUM'),
    artist: _artistName(texts),
    actions: _actionsOf(item),
  );
}

/// One episode of a podcast.
///
/// A different renderer from every other track in the app: instead of columns
/// it carries a title, a line of metadata and a description, and the video id
/// hangs off the row's tap rather than off a menu. Read by path rather than by
/// search because the description holds links of its own, and a video id found
/// anywhere in the subtree could be one of those.
///
/// No duration: the one the row prints is spelled out ("5 min 32 s"), not a
/// timestamp, and it is the open stream that measures a track's length anyway.
Song? _episodeRow(Object? item, Set<String> seen) {
  final videoId = readPath(item, ['onTap', 'watchEndpoint', 'videoId']);
  if (videoId is! String || !seen.add(videoId)) return null;

  final title = _readRuns(readPath(item, ['title']));
  if (title.isEmpty) return null;

  final thumbnails = findFirst(readPath(item, ['thumbnail']), 'thumbnails');
  String? thumbnailUrl;
  if (thumbnails is List && thumbnails.isNotEmpty) {
    thumbnailUrl = readPath(thumbnails.last, ['url']) as String?;
  }

  return Song(
    videoId: videoId,
    title: title,
    subtitle: _readRuns(readPath(item, ['subtitle'])),
    thumbnailUrl: thumbnailUrl,
  );
}


/// Everything a row's menu offers, read off that menu.
///
/// Matched by `iconType` rather than by label: `hl` follows the device locale,
/// so the labels arrive in whatever language the listener reads, while the
/// icons are the same everywhere. Measured against a real account on 22 August
/// 2026, over 200 history rows.
///
/// The care here is all about telling the row's several feedback tokens apart.
/// One row carries four — take out of the library, put into it, pin to the
/// recap, unpin from it — they all go to the same endpoint, and any of them is
/// accepted. Sending the wrong one does not fail; it silently makes a different
/// edit.
SongActions _actionsOf(Object? item) {
  String? removeFromLibrary;
  String? pinToRecap;
  String? unpinFromRecap;
  var pinnedToRecap = false;

  for (final toggle in findAll(item, 'toggleMenuServiceItemRenderer')) {
    // `isToggled` is what says the track is in the library at all. Without it a
    // search result nobody ever saved would come back with a token that removes
    // nothing, and the menu would offer the action on a track that is not there.
    if (readPath(toggle, ['toggledIcon', 'iconType']) == 'BOOKMARK' &&
        readPath(toggle, ['isToggled']) == true) {
      removeFromLibrary = _feedbackToken(toggle, 'toggledServiceEndpoint');
    }
    // The pin arrives with its two sides either way round: YouTube puts the
    // action it is currently offering on the `default` side, so a track that is
    // already pinned comes back offering `KEEP_OFF` there. Measured against the
    // account's own front page — with the sides read rather than assumed, a
    // pinned track offered nothing at all and could never be unpinned.
    //
    // So the icons say which token is which, and which one is on the default
    // side says whether the track is pinned right now.
    final byDefault = readPath(toggle, ['defaultIcon', 'iconType']);
    if (byDefault == 'KEEP' || byDefault == 'KEEP_OFF') {
      final pinIsDefault = byDefault == 'KEEP';
      pinToRecap = _feedbackToken(
        toggle,
        pinIsDefault ? 'defaultServiceEndpoint' : 'toggledServiceEndpoint',
      );
      unpinFromRecap = _feedbackToken(
        toggle,
        pinIsDefault ? 'toggledServiceEndpoint' : 'defaultServiceEndpoint',
      );
      pinnedToRecap = !pinIsDefault;
    }
  }

  String? removeFromHistory;
  String? playlistSetVideoId;

  for (final service in findAll(item, 'menuServiceItemRenderer')) {
    switch (readPath(service, ['icon', 'iconType'])) {
      case 'REMOVE_FROM_HISTORY':
        final token = readPath(
          service,
          ['serviceEndpoint', 'feedbackEndpoint', 'feedbackToken'],
        );
        if (token is String && token.isNotEmpty) removeFromHistory = token;
      case 'REMOVE_FROM_PLAYLIST':
        // Taken from the removal's own endpoint rather than from the row's
        // `playlistItemData`, which carries the same value on every row of
        // every playlist. Here it means what the interface needs it to mean:
        // this playlist can be edited, and this is the row to name.
        final setVideoId = readPath(
          service,
          ['serviceEndpoint', 'playlistEditEndpoint', 'actions', 0, 'setVideoId'],
        );
        if (setVideoId is String && setVideoId.isNotEmpty) {
          playlistSetVideoId = setVideoId;
        }
    }
  }

  var hasCredits = false;
  for (final entry in findAll(item, 'menuNavigationItemRenderer')) {
    if (readPath(entry, ['icon', 'iconType']) == 'PEOPLE_GROUP') {
      hasCredits = true;
    }
  }

  return SongActions(
    removeFromLibrary: removeFromLibrary,
    removeFromHistory: removeFromHistory,
    pinToRecap: pinToRecap,
    unpinFromRecap: unpinFromRecap,
    pinnedToRecap: pinnedToRecap,
    playlistSetVideoId: playlistSetVideoId,
    hasCredits: hasCredits,
  );
}

/// One side of a toggle's feedback token, or null when that side has none.
String? _feedbackToken(Object? toggle, String side) {
  final token = readPath(toggle, [side, 'feedbackEndpoint', 'feedbackToken']);
  return token is String && token.isNotEmpty ? token : null;
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
      // A card's menu is the row's menu: the front page is where a pinned
      // track is offered the way back off the recap, and it draws its tracks
      // as cards.
      actions: _actionsOf(item),
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
    // A channel's page — a profile from search is one — heads itself with this
    // one and none of the others, and without it the page opened under a blank
    // title with no picture.
    'musicVisualHeaderRenderer',
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

/// What an artist's page offers besides their music: the mix YouTube builds
/// around them, and whether the account already follows them.
///
/// The radio comes from the header's own radio button rather than from the play
/// button next to it — that one carries the artist's top tracks, which is a
/// list, not a mix. When the header is shaped some other way, any `RD` id on
/// the page will do: every one of them is a radio of something related, and a
/// mix that is nearly right beats a button that does nothing.
({String? radioPlaylistId, bool? subscribed, String? channelId})
parseArtistDetails(Map<String, dynamic> json) {
  var radio = readPath(
    findFirst(findFirst(json, 'startRadioButton'), 'watchEndpoint'),
    ['playlistId'],
  ) as String?;

  if (radio == null) {
    for (final id in findAll(json, 'playlistId').whereType<String>()) {
      if (id.startsWith('RD')) {
        radio = id;
        break;
      }
    }
  }

  final button = findFirst(json, 'subscribeButtonRenderer');
  return (
    radioPlaylistId: radio,
    subscribed: readPath(button, ['subscribed']) as bool?,
    channelId: readPath(button, ['channelId']) as String?,
  );
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

/// What YouTube would finish the query with.
///
/// Suggestions arrive as rich text so parts of them can be shown in bold — the
/// part you have not typed yet. The app wants the whole line, so the runs are
/// joined and the styling ignored.
List<String> parseSearchSuggestions(Map<String, dynamic> json) {
  final suggestions = <String>[];
  final seen = <String>{};

  for (final item in findAll(json, 'searchSuggestionRenderer')) {
    final text = _readRuns(readPath(item, ['suggestion']));
    if (text.isEmpty || !seen.add(text)) continue;
    suggestions.add(text);
  }

  return suggestions;
}

/// The mood buttons over the front page.
///
/// Ten of them arrive with the home response — Energy, Feel good, Relax,
/// Workout… — and each is the same browse id with a different token, so tapping
/// one asks for the home page again, refiltered. They are read rather than
/// written out here: the labels arrive translated by the device's own `hl`, and
/// the tokens mean nothing outside the response that handed them over.
///
/// A different renderer from the explore page's moods ([parseMoodChips]), and a
/// different thing: those open a page of their own instead of refiltering this
/// one. The chip cloud of a search response is this same renderer, which is why
/// only chips carrying a `browseEndpoint` are read.
List<Playlist> parseHomeChips(Map<String, dynamic> json) {
  final chips = <Playlist>[];
  final seen = <String>{};

  for (final chip in findAll(json, 'chipCloudChipRenderer')) {
    final label = _readRuns(readPath(chip, ['text']));
    final endpoint = readPath(chip, ['navigationEndpoint', 'browseEndpoint']);
    final browseId = readPath(endpoint, ['browseId']);
    final params = readPath(endpoint, ['params']);
    if (label.isEmpty || browseId is! String) continue;
    if (params is! String || !seen.add(params)) continue;

    chips.add(Playlist(browseId: browseId, title: label, params: params));
  }

  return chips;
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

/// Every audio-only stream a player response offers, best first.
///
/// A list rather than a pick because "best" is a guess until something opens
/// it: a format the player refuses would otherwise lose the whole track, even
/// when the same response carried one it could have played. The caller walks
/// these in order and keeps the first that loads.
///
/// Only formats carrying a ready `url` are considered; anything behind a
/// `signatureCipher` would need a JavaScript interpreter to unscramble, and
/// the iOS client is used precisely so that never happens.
///
/// [preferMp4] moves mp4 to the front for players that cannot decode anything
/// else. YouTube's highest-bitrate audio is Opus in WebM, which AVFoundation
/// refuses outright; ExoPlayer plays both, so Android asks for no preference
/// and keeps the better stream at the head.
List<AudioStream> parseAudioStreams(
  Map<String, dynamic> json, {
  bool preferMp4 = false,
}) {
  final formats = readPath(json, ['streamingData', 'adaptiveFormats']);
  if (formats is! List) return const [];

  final streams = <AudioStream>[];
  for (final format in formats) {
    final mimeType = readPath(format, ['mimeType']);
    final url = readPath(format, ['url']);
    if (mimeType is! String || !mimeType.startsWith('audio') || url is! String) {
      continue;
    }
    final bitrate = (readPath(format, ['bitrate']) as num?)?.toInt() ?? 0;
    // A format that claims no bitrate has never turned out to be a real one.
    if (bitrate <= 0) continue;
    streams.add(AudioStream(
      url: url,
      bitrate: bitrate,
      mimeType: mimeType,
      duration: _declaredDuration(format, url),
    ));
  }

  streams.sort((a, b) {
    if (preferMp4) {
      final byContainer = _mp4First(b).compareTo(_mp4First(a));
      if (byContainer != 0) return byContainer;
    }
    final byBitrate = b.bitrate.compareTo(a.bitrate);
    if (byBitrate != 0) return byBitrate;
    return _codecRank(b.mimeType).compareTo(_codecRank(a.mimeType));
  });
  return streams;
}

/// How long a format really runs, as the server states it.
///
/// Read from the response rather than from the player because the player is
/// wrong about it — see [AudioStream.duration]. Two sources, because the
/// server gives two: `approxDurationMs` is the better one, being a field and
/// per format, but a rename would take it away silently and put the doubled
/// length back, and the media URL carries the same value in seconds.
Duration? _declaredDuration(Object? format, String url) {
  final ms = readPath(format, ['approxDurationMs']);
  final parsed = ms is num ? ms.toInt() : int.tryParse(ms is String ? ms : '');
  if (parsed != null && parsed > 0) return Duration(milliseconds: parsed);

  final seconds =
      double.tryParse(Uri.tryParse(url)?.queryParameters['dur'] ?? '');
  if (seconds == null || seconds <= 0) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

int _mp4First(AudioStream stream) => stream.mimeType.startsWith('audio/mp4') ? 1 : 0;

/// Breaks a bitrate tie towards the codec that sounds better at it. Opus beats
/// AAC at equal bitrate, and both beat whatever else turns up.
int _codecRank(String mimeType) {
  final lower = mimeType.toLowerCase();
  if (lower.contains('opus')) return 3;
  if (lower.contains('mp4a')) return 2;
  return 1;
}

/// The single best stream, for callers with nowhere to fall back to.
AudioStream? parseBestAudioStream(
  Map<String, dynamic> json, {
  bool preferMp4 = false,
}) =>
    parseAudioStreams(json, preferMp4: preferMp4).firstOrNull;

/// Turns the credits page into the roles behind a track.
///
/// The response arrives wrapped in a `dismissableDialogRenderer`, which is how
/// the web player draws it; YouTube Music on Android gives the same content a
/// whole screen. The wrapper is walked for rather than followed, like every
/// other renderer here, so a change of container does not empty the screen.
///
/// A track with no credits answers the same page with no sections at all, so an
/// empty result is an ordinary answer and not an error to report.
TrackCredits parseTrackCredits(Map<String, dynamic> json) {
  final dialog = findFirst(json, 'dismissableDialogRenderer');
  if (dialog == null) return const TrackCredits();

  final header = findFirst(dialog, 'musicMultiRowListItemRenderer');
  final thumbnails = findFirst(header, 'thumbnails');

  final entries = <CreditEntry>[];
  for (final section in findAll(dialog, 'dismissableDialogContentSectionRenderer')) {
    final role = _readRuns(readPath(section, ['title']));
    final name = _readRuns(readPath(section, ['subtitle']));
    if (role.isEmpty || name.isEmpty) continue;
    entries.add(CreditEntry(role: role, name: name));
  }

  return TrackCredits(
    title: _readRuns(readPath(header, ['title'])),
    artist: _readRuns(readPath(header, ['subtitle'])),
    subtitle: _readRuns(readPath(header, ['secondTitle'])),
    thumbnailUrl: thumbnails is List && thumbnails.isNotEmpty
        ? readPath(thumbnails.last, ['url']) as String?
        : null,
    entries: entries,
  );
}

/// Whether this playlist page is one the account can edit.
///
/// The two kinds look identical in the library — a list made here and one saved
/// from someone else sit in the same shelf — and only the page tells them
/// apart: YouTube attaches an edit header and a delete entry to the first and
/// neither to the second. Measured against both kinds on a real account.
///
/// Asked of the page rather than guessed from the id, because there is nothing
/// in an id that says who made the list. Offering a rename that always fails
/// would be worse than not offering it.
bool parsePlaylistEditable(Map<String, dynamic> json) =>
    findFirst(json, 'musicPlaylistEditHeaderRenderer') != null;
