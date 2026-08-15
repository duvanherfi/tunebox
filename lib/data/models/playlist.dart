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

/// Who is signed in.
class Account {
  const Account({required this.name, required this.email, this.photoUrl});

  final String name;
  final String email;
  final String? photoUrl;
}

/// A titled row of collections, as the home feed is built from.
class Shelf {
  const Shelf({required this.title, required this.playlists});

  final String title;
  final List<Playlist> playlists;
}
