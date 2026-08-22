/// What a row's own menu said can be done to the track in it.
///
/// Every handle here is minted per row, inside the menu YouTube attached to
/// that row, and none of them is derived from the video id: there is no
/// endpoint that takes one. So a track listed from somewhere that carries no
/// menu — a search result, a file on the device — can be played and nothing
/// else, and that is not a gap to work around. Null is also how the interface
/// knows not to offer the action.
///
/// Grouped rather than spread over [Song] because they travel together, are
/// dropped together, and belong to the response they arrived in: a token read
/// back from disk next week would be a stale credential.
class SongActions {
  const SongActions({
    this.removeFromLibrary,
    this.removeFromHistory,
    this.pinToRecap,
    this.unpinFromRecap,
    this.pinnedToRecap = false,
    this.playlistSetVideoId,
    this.hasCredits = false,
  });

  /// A row that brought no menu at all, which is most of them.
  static const none = SongActions();

  /// Takes the track out of the library, leaving the like alone. Only the rows
  /// whose toggle says the track is in the library carry it.
  final String? removeFromLibrary;

  /// Takes the track out of the account's listening history. The same endpoint
  /// as [removeFromLibrary] and a different token, which is why the two are
  /// kept apart: either sent to `feedback` is accepted, and the wrong one
  /// silently makes the other edit.
  final String? removeFromHistory;

  /// The two sides of "Pin to Speed dial", which YouTube Music calls "Fijar en
  /// Vuelve a escucharlo" in Spanish. Both arrive on the same toggle, one per
  /// side, and [pinnedToRecap] says which one to send.
  final String? pinToRecap;
  final String? unpinFromRecap;
  final bool pinnedToRecap;

  /// Which copy of the track this row is, inside the playlist that listed it.
  ///
  /// A playlist can hold the same track twice, so the edit that removes one
  /// names the row and not the video. Present only where the row offered the
  /// removal, which is what says the playlist can be edited at all.
  final String? playlistSetVideoId;

  /// Whether YouTube has credits for this track.
  ///
  /// The page they live on is addressed by the video id, so it could be asked
  /// for on any track — but a track with no credits answers with an empty
  /// page rather than an error, and only the row knows the difference. 159 of
  /// 200 history rows carried the entry on 22 August 2026.
  final bool hasCredits;
}

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
    this.actions = SongActions.none,
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

  /// What the row's own menu offered, when the row brought one.
  ///
  /// Never null so that every caller can ask without checking twice; a row with
  /// no menu carries [SongActions.none], whose every handle is absent.
  ///
  /// Not stored in [toJson]: these belong to the response they arrived in, and
  /// a token read back from disk next week would be a stale credential.
  final SongActions actions;

  /// Larger artwork for the now-playing screen. YouTube encodes the requested
  /// size in the URL, so upgrading is a string substitution rather than
  /// another network round trip.
  String? get highResThumbnailUrl {
    final url = thumbnailUrl;
    if (url == null) return null;
    return url.replaceAll(RegExp(r'w\d+-h\d+'), 'w544-h544');
  }

  /// The same track, carrying the length someone finally measured.
  ///
  /// Plenty of rows arrive without one — videos, mixes, anything YouTube filed
  /// loosely — and the open stream is the only place that length ever appears.
  /// Put back on the track, it reaches everywhere the track goes: the queue the
  /// car draws, and the resume point, which is what the next launch has to draw
  /// a progress bar from.
  Song withDuration(Duration duration) => Song(
        videoId: videoId,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        artistId: artistId,
        albumId: albumId,
        artist: artist,
        actions: actions,
      );

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
    this.duration,
    this.userAgent = '',
    this.trackingUrl,
    this.watchtimeUrl,
    this.cpn = '',
  });

  final String url;
  final int bitrate;
  final String mimeType;

  /// How long this format really is, as the server states it.
  ///
  /// Not decoration: the platform player is not a reliable authority on it.
  /// AVFoundation reads YouTube's fragmented mp4 audio — `stts` and `stsz`
  /// empty, the samples in `moof` boxes — as exactly twice its length, so a
  /// four-minute song is drawn on a nine-minute bar and the music stops halfway
  /// along it. Measured three ways: through the app, through a bare
  /// `AVURLAsset` over the file on disk, and against `ffprobe` and macOS's own
  /// `afinfo`, which both read the same files correctly. Every header inside
  /// the file agrees with them, so the file is not the broken part.
  ///
  /// Null when the server states neither of the two places it usually does.
  final Duration? duration;

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
