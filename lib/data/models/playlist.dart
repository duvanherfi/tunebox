import 'song.dart';

/// A playlist, album or any other browsable collection of tracks.
class Playlist {
  const Playlist({
    required this.browseId,
    required this.title,
    this.subtitle = '',
    this.thumbnailUrl,
    this.params,
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

  Map<String, Object?> toJson() => {
        'browseId': browseId,
        'title': title,
        'subtitle': subtitle,
        'thumbnailUrl': thumbnailUrl,
        'params': params,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        browseId: json['browseId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        params: json['params'] as String?,
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
  });

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final List<Song> songs;
  final List<Shelf> shelves;

  /// The mix YouTube builds around this page. An artist's is a different id
  /// from the page's own, so it has to travel; an album's radio is derived from
  /// its id and this stays null.
  final String? radioPlaylistId;

  /// Whether the account follows this artist, as the page reported it. Null
  /// when nobody is signed in, or when the page is not an artist's.
  final bool? subscribed;
}

/// Who is signed in.
class Account {
  const Account({required this.name, required this.email, this.photoUrl});

  final String name;
  final String email;
  final String? photoUrl;
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
