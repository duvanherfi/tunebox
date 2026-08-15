import 'song.dart';

/// A playlist, album or any other browsable collection of tracks.
class Playlist {
  const Playlist({
    required this.browseId,
    required this.title,
    this.subtitle = '',
    this.thumbnailUrl,
  });

  /// InnerTube's identifier for the collection. Already carries the `VL`
  /// prefix when it came from a library shelf.
  final String browseId;

  final String title;
  final String subtitle;
  final String? thumbnailUrl;

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
  });

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final List<Song> songs;
  final List<Shelf> shelves;
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
