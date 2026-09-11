import 'song.dart';

/// A playlist, album or any other browsable collection of tracks.
class Playlist {
  const Playlist({
    required this.browseId,
    required this.title,
    this.subtitle = '',
    this.thumbnailUrl,
    this.params,
    this.radioPlaylistId,
  });

  /// InnerTube's identifier for the collection. Already carries the `VL`
  /// prefix when it came from a library shelf.
  final String browseId;

  final String title;
  final String subtitle;
  final String? thumbnailUrl;

  /// An opaque selector some collections need alongside their id — the mood and
  /// genre pages are one browse id with a different one of these per category.
  /// Meaningless on its own, and never inspected: it is passed back as given.
  final String? params;

  /// The mix YouTube builds around this collection, when the row that named it
  /// also said where its mix lives. A search row does: every album and playlist
  /// carries an `RDAMPL` id in its menu and every artist an `RDEM` one, and
  /// neither is derivable from the browse id — an artist's names a channel and
  /// an album's a page, and `next` answers nothing for either. Null for the
  /// rows that ship no mix at all, which is how profiles and podcasts arrive.
  final String? radioPlaylistId;

  Map<String, Object?> toJson() => {
        'browseId': browseId,
        'title': title,
        'subtitle': subtitle,
        'thumbnailUrl': thumbnailUrl,
        'params': params,
        'radioPlaylistId': radioPlaylistId,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        browseId: json['browseId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        params: json['params'] as String?,
        radioPlaylistId: json['radioPlaylistId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Playlist && other.browseId == browseId;

  @override
  int get hashCode => browseId.hashCode;
}

/// An artist's or an album's page: a heading, its tracks, and whatever rows of
/// other things YouTube attached below them.
class MusicPage {
  const MusicPage({
    required this.title,
    this.subtitle = '',
    this.thumbnailUrl,
    this.songs = const [],
    this.shelves = const [],
    this.radioPlaylistId,
    this.subscribed,
    this.continuation,
    this.editable = false,
  });

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final List<Song> songs;
  final List<Shelf> shelves;

  /// Where the tracks carry on, when there are more than the first page holds.
  /// Null once the page has handed over everything it has.
  final String? continuation;

  /// The mix YouTube builds around this page. An artist's is a different id
  /// from the page's own, so it has to travel; an album's radio is derived from
  /// its id and this stays null.
  final String? radioPlaylistId;

  /// Whether the account follows this artist, as the page reported it. Null
  /// when nobody is signed in, or when the page is not an artist's.
  final bool? subscribed;

  /// Whether this is a list the account can rename, empty or delete — its own,
  /// rather than one it merely saved. False for everything that is not a
  /// playlist: an album is nobody's to edit.
  final bool editable;
}

/// Who is signed in.
class Account {
  const Account({required this.name, required this.email, this.photoUrl});

  final String name;
  final String email;
  final String? photoUrl;
}

/// One of the countries the charts can be asked for.
///
/// The name arrives already translated by the request's own `hl`, and the code
/// is the only part that goes back to YouTube, so nothing here is written out
/// in the app: the list is whatever the charts response listed.
class ChartCountry {
  const ChartCountry({
    required this.code,
    required this.name,
    this.selected = false,
  });

  /// ISO 3166 two-letter code, as `formData.selectedValues` wants it. `ZZ` is
  /// YouTube's own entry for the worldwide chart.
  final String code;

  final String name;

  /// Whether this is the country the response was already filtered by.
  final bool selected;
}

/// A titled row of the home feed.
///
/// A row holds collections or tracks, not both in practice: YouTube fills the
/// front page with playlist covers for a stranger and with individual songs —
/// "listen again", "quick picks" — once it knows who is asking. Modelling both
/// is what keeps the signed-in feed from arriving empty.
class Shelf {
  const Shelf({
    required this.title,
    this.playlists = const [],
    this.songs = const [],
  });

  final String title;
  final List<Playlist> playlists;
  final List<Song> songs;

  bool get isEmpty => playlists.isEmpty && songs.isEmpty;
}

/// The charts page: its rows, and the countries it could be asked for instead.
///
/// The two travel together because they arrive together — the country menu is
/// part of the same browse response as the rows it filters — and asking twice
/// would be two round trips for one page.
class ChartsPage {
  const ChartsPage({this.shelves = const [], this.countries = const []});

  final List<Shelf> shelves;
  final List<ChartCountry> countries;
}
