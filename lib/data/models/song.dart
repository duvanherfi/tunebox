/// A playable track. Pure Dart, no Flutter or platform imports, so the whole
/// data layer stays portable to iOS and desktop later.
class Song {
  const Song({
    required this.videoId,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
    this.duration,
    this.artistId,
    this.albumId,
    this.artist,
  });

  final String videoId;
  final String title;

  /// Artist / album / duration line as YouTube Music renders it. It arrives
  /// pre-joined rather than split, because the field order is not stable
  /// across result types (song vs. video vs. album).
  final String subtitle;

  final String? thumbnailUrl;
  final Duration? duration;

  /// Where this track came from, when the row said so.
  ///
  /// The metadata line is already showing the artist and the album as text;
  /// these are the same names as somewhere to go. Absent on plenty of rows —
  /// videos, mixes, anything YouTube filed loosely — so every use is optional.
  final String? artistId;
  final String? albumId;

  /// Just the performer, pulled out of the metadata line.
  ///
  /// The subtitle is for reading; this is for asking other services about the
  /// track — a lyrics database wants "Portishead", not "Song • Portishead ·
  /// 140M plays".
  final String? artist;

  /// Larger artwork for the now-playing screen. YouTube encodes the requested
  /// size in the URL, so upgrading is a string substitution rather than
  /// another network round trip.
  String? get highResThumbnailUrl {
    final url = thumbnailUrl;
    if (url == null) return null;
    return url.replaceAll(RegExp(r'w\d+-h\d+'), 'w544-h544');
  }

  /// Stored form, for the on-device play history. Only what a row needs to be
  /// drawn and played again; everything else is fetched fresh anyway.
  Map<String, Object?> toJson() => {
        'videoId': videoId,
        'title': title,
        'subtitle': subtitle,
        'thumbnailUrl': thumbnailUrl,
        'durationMs': duration?.inMilliseconds,
        'artist': artist,
      };

  factory Song.fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'];
    return Song(
      videoId: json['videoId'] as String,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      artist: json['artist'] as String?,
    );
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
    this.trackingUrl,
    this.watchtimeUrl,
    this.cpn = '',
  });

  final String url;
  final int bitrate;
  final String mimeType;

  /// Where to report that this track started, and where to report how much of
  /// it was heard.
  ///
  /// YouTube counts a play only when the client says so, which is how its own
  /// apps fill a listening history. Pinging these signed in is what puts a
  /// track into the account's history — and therefore into the History tab,
  /// which reads that same history back.
  final String? trackingUrl;
  final String? watchtimeUrl;

  /// Client playback nonce: the identifier tying the audio request and the
  /// reports about it into one listen.
  ///
  /// It has to be the same string in both, and it has to travel on the media
  /// URL as well, or the reports describe a playback the server never saw and
  /// are discarded — which is exactly how a play goes uncounted.
  final String cpn;

  /// Identity of the client this URL was issued to. Googlevideo can hold a URL
  /// to the client that asked for it, so the bytes are fetched wearing the same
  /// face that resolved them.
  final String userAgent;
}
