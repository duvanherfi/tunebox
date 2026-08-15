/// A playable track. Pure Dart, no Flutter or platform imports, so the whole
/// data layer stays portable to iOS and desktop later.
class Song {
  const Song({
    required this.videoId,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
    this.duration,
  });

  final String videoId;
  final String title;

  /// Artist / album / duration line as YouTube Music renders it. It arrives
  /// pre-joined rather than split, because the field order is not stable
  /// across result types (song vs. video vs. album).
  final String subtitle;

  final String? thumbnailUrl;
  final Duration? duration;

  /// Larger artwork for the now-playing screen. YouTube encodes the requested
  /// size in the URL, so upgrading is a string substitution rather than
  /// another network round trip.
  String? get highResThumbnailUrl {
    final url = thumbnailUrl;
    if (url == null) return null;
    return url.replaceAll(RegExp(r'w\d+-h\d+'), 'w544-h544');
  }

  @override
  bool operator ==(Object other) => other is Song && other.videoId == videoId;

  @override
  int get hashCode => videoId.hashCode;
}

/// One decoded audio stream from the player endpoint.
class AudioStream {
  const AudioStream({
    required this.url,
    required this.bitrate,
    required this.mimeType,
    this.userAgent = '',
  });

  final String url;
  final int bitrate;
  final String mimeType;

  /// Identity of the client this URL was issued to. Googlevideo can hold a URL
  /// to the client that asked for it, so the bytes are fetched wearing the same
  /// face that resolved them.
  final String userAgent;
}
