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
  const SearchResult.song(
    Song this.song, {
    this.top = false,
    this.buttons = const [],
  })  : collection = null,
        kind = null;

  const SearchResult.collection(
    Playlist this.collection,
    CollectionKind this.kind, {
    this.top = false,
    this.buttons = const [],
  }) : song = null;

  final Song? song;
  final Playlist? collection;
  final CollectionKind? kind;

  /// Whether this is the card YouTube put above everything else. It is the same
  /// title, subtitle and destination as any other row — what makes it a card is
  /// that YouTube also sent [buttons] with it.
  final bool top;

  /// The ways into the top result that the card itself offers, as it offered
  /// them: an artist gets Shuffle and Mix, an album Play and Shuffle, a track
  /// Play. Empty on every other row, and empty on a card whose buttons ask for
  /// something this app cannot do.
  final List<SearchCardButton> buttons;
}

/// One button on the top-result card.
///
/// The label arrives translated, like every other label in a response, so it is
/// shown as it came rather than matched against anything: what the button
/// *does* is read from its command, not from what it says.
class SearchCardButton {
  const SearchCardButton({
    required this.label,
    required this.icon,
    this.videoId,
    this.playlistId,
    this.params,
  });

  final String label;

  /// YouTube's own `iconType`, passed on for the screen to map. A name rather
  /// than an icon because this file knows nothing about Flutter.
  final String icon;

  /// A single track to play, for the card that tops a track.
  final String? videoId;

  /// A queue to play, for the card that tops an album, a playlist or an artist.
  /// [params] rides with it: the same id answers the album in order or shuffled
  /// depending on which one it carries.
  final String? playlistId;
  final String? params;
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
