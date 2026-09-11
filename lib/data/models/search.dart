import 'playlist.dart';
import 'song.dart';

/// What a search row points at when it is not a track.
///
/// Read off the row's own endpoint rather than guessed from the id, because two
/// of these share a prefix: a profile's browse id starts with `UC` exactly like
/// an artist's, and only the page type tells them apart.
enum CollectionKind { album, playlist, artist, profile, podcast }

/// One row of a search response: something to play, or somewhere to go.
///
/// YouTube ranks tracks, albums, artists, playlists, profiles and podcasts into
/// a single column and sends no section headings with them, so the results stay
/// in one list in the order they arrived. Which of the two a row is, the row
/// says; what kind of thing it is, the subtitle already spells out in the
/// listener's language.
class SearchResult {
  const SearchResult.song(Song this.song)
      : collection = null,
        kind = null;

  const SearchResult.collection(Playlist this.collection, CollectionKind this.kind)
      : song = null;

  final Song? song;
  final Playlist? collection;
  final CollectionKind? kind;
}

/// One of the ways YouTube offers to narrow a search, as it offered it.
///
/// The label arrives translated and the token opaque, and both come out of the
/// response — so the filters are whatever YouTube is handing out today rather
/// than a list this app has to keep in step by hand.
class SearchFilter {
  const SearchFilter({
    required this.label,
    required this.params,
    this.selected = false,
  });

  final String label;

  /// The opaque selector to send back with the query. Never inspected.
  final String params;

  /// Whether this is the filter the response was narrowed by.
  final bool selected;
}

/// Everything a search answered with: the ranked rows and the ways to narrow
/// them.
class SearchResults {
  const SearchResults({this.results = const [], this.filters = const []});

  final List<SearchResult> results;
  final List<SearchFilter> filters;

  bool get isEmpty => results.isEmpty;

  /// Only the tracks, in the order they appear — the rows a screen can play,
  /// with the pages left out.
  List<Song> get songs => [for (final result in results) ?result.song];
}
