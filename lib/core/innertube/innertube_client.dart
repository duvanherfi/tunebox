import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../auth/session.dart';
import 'parsers.dart';

/// Client identities accepted by InnerTube.
///
/// IMPORTANT: `version` is the single most fragile value in this codebase.
/// YouTube retires old client builds, and when it does the player endpoint
/// starts answering HTTP 400 or `LOGIN_REQUIRED` for every request. That is
/// not a ban and not a cookie problem — it just means the number below went
/// stale. Bump it to a current app release and everything works again.
class _ClientProfile {
  const _ClientProfile({
    required this.name,
    required this.version,
    required this.userAgent,
    this.extra = const {},
  });

  final String name;
  final String version;
  final String userAgent;
  final Map<String, Object> extra;

  Map<String, Object> context(String hl, String gl) => {
        'clientName': name,
        'clientVersion': version,
        'hl': hl,
        'gl': gl,
        ...extra,
      };
}

/// Browsing, search and library metadata. The YouTube Music web client returns
/// the richest catalogue data, but it will not hand out audio URLs.
const _webRemix = _ClientProfile(
  name: 'WEB_REMIX',
  version: '1.20240403.01.00',
  userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
);

/// Clients tried, in order, when resolving audio.
///
/// No single client works reliably. YouTube refuses most of them most of the
/// time — usually with "sign in to confirm you're not a bot" — and which one
/// answers varies by track, by moment and by network. Worse, the refusals are
/// not deterministic: a client that fails once may succeed seconds later, so a
/// single failed probe proves nothing and the list is walked more than once.
///
/// The order below puts the identities that have actually served full streams
/// first. VisionOS leads because it is the one that currently survives most
/// often, which is exactly the kind of fact that will stop being true without
/// warning — hence the list rather than a choice.
const _streamClients = <_ClientProfile>[
  _ClientProfile(
    name: 'VISIONOS',
    version: '0.1',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/18.0 Safari/605.1.15',
    extra: {
      'deviceMake': 'Apple',
      'deviceModel': 'RealityDevice14,1',
      'osName': 'visionOS',
      'osVersion': '1.3.21O771',
    },
  ),
  _ClientProfile(
    name: 'IOS',
    version: '19.29.1',
    userAgent:
        'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)',
    extra: {
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone16,2',
      'osName': 'iOS',
      'osVersion': '17.5.1.21F90',
    },
  ),
  _ClientProfile(
    name: 'IOS',
    version: '19.22.3',
    userAgent:
        'com.google.ios.youtube/19.22.3 (iPad7,6; U; CPU iPadOS 17_7_10 like Mac OS X; en-US)',
    extra: {
      'deviceMake': 'Apple',
      'deviceModel': 'iPad7,6',
      'osName': 'iPadOS',
      'osVersion': '17.7.10.21H450',
    },
  ),
  _ClientProfile(
    name: 'ANDROID_VR',
    version: '1.37',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.37 (Linux; U; Android 12; '
        'en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
    extra: {
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'osName': 'Android',
      'osVersion': '12',
      'androidSdkVersion': 32,
    },
  ),
  _ClientProfile(
    name: 'ANDROID_VR',
    version: '1.61.48',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; '
        'en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)',
    extra: {
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'osName': 'Android',
      'osVersion': '12',
      'androidSdkVersion': 32,
    },
  ),
  _ClientProfile(
    name: 'ANDROID_TESTSUITE',
    version: '1.9',
    userAgent:
        'com.google.android.youtube/1.9 (Linux; U; Android 15; en_US; '
        'Pixel 9 Pro; Build/AP4A.250205.002) gzip',
    extra: {
      'osName': 'Android',
      'osVersion': '15',
      'androidSdkVersion': 35,
    },
  ),
  _ClientProfile(
    name: 'IOS_MUSIC',
    version: '7.27.0',
    userAgent:
        'com.google.ios.youtubemusic/7.27.0 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)',
    extra: {
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone16,2',
      'osName': 'iOS',
      'osVersion': '17.5.1.21F90',
    },
  ),
  _ClientProfile(
    name: 'ANDROID_MUSIC',
    version: '7.27.52',
    userAgent:
        'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 15; '
        'en_US; Pixel 9 Pro; Build/AP4A.250205.002; Cronet/132.0.6834.79) gzip',
    extra: {
      'deviceMake': 'Google',
      'deviceModel': 'Pixel 9 Pro',
      'osName': 'Android',
      'osVersion': '15',
      'androidSdkVersion': 35,
    },
  ),
];

/// Search filters, as the opaque tokens InnerTube expects.
///
/// Only the token lives here; the visible name belongs to the UI, where the
/// translations are.
enum SearchFilter {
  songs('EgWKAQIIAWoKEAkQBRAKEAMQBA=='),
  videos('EgWKAQIQAWoKEAkQBRAKEAMQBA==');

  const SearchFilter(this.params);

  final String params;
}

class InnertubeException implements Exception {
  InnertubeException(this.message);
  final String message;
  @override
  String toString() => 'InnertubeException: $message';
}

/// Talks to YouTube's internal API. Pure Dart on top of `http`, so it runs
/// unchanged on Android, iOS and desktop, and can be unit tested against
/// recorded JSON without a Flutter binding.
class InnertubeClient {
  InnertubeClient({
    http.Client? httpClient,
    this.session,
    this.hl = 'es',
    this.gl = 'CO',
    bool? preferMp4,
  })  : _http = httpClient ?? http.Client(),
        preferMp4 = preferMp4 ?? (Platform.isMacOS || Platform.isIOS);

  /// Language and region asked of InnerTube.
  ///
  /// Not cosmetic: InnerTube localises what it returns, so the category labels
  /// beside every result — the "Song" and "Video" in a metadata line — arrive
  /// in whatever language is requested. A translated interface listing
  /// untranslated results looks broken.
  ///
  /// Taken as plain strings rather than a Locale so this file stays free of
  /// Flutter imports and testable without a binding; the caller converts.

  final http.Client _http;

  /// When signed in, supplies the cookie and signature headers that unlock
  /// library, likes and playlists. Null or signed out leaves every call
  /// anonymous, which is exactly how search and playback already work.
  final Session? session;

  final String hl;
  final String gl;

  static const _base = 'https://youtubei.googleapis.com/youtubei/v1';
  static const _musicBase = 'https://music.youtube.com/youtubei/v1';

  Map<String, String> authHeaders() => session?.headers() ?? const {};

  Future<Map<String, dynamic>> _post(
    String base,
    String endpoint,
    _ClientProfile profile,
    Map<String, Object?> body, {
    String? visitorData,
  }) async {
    final response = await _http.post(
      Uri.parse('$base/$endpoint?prettyPrint=false'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': profile.userAgent,
        'Origin': 'https://music.youtube.com',
        'X-Goog-Visitor-Id': ?visitorData,
        ...authHeaders(),
      },
      body: jsonEncode({
        'context': {
          'client': {
            ...profile.context(hl, gl),
            'visitorData': ?visitorData,
          },
        },
        ...body,
      }),
    );

    // A cookie can die while the app still believes in it — signing out
    // elsewhere, changing the password, or rotating it deliberately. Dropping
    // it here is what keeps the interface honest: otherwise the account panel
    // shows a name and every write fails for no visible reason. Only 401 is
    // read this way; the player endpoint answers 403 to perfectly good
    // sessions all the time.
    if (response.statusCode == 401 && session?.isSignedIn == true) {
      await session?.signOut();
      throw InnertubeException('La sesión caducó. Vuelve a iniciar sesión.');
    }

    if (response.statusCode != 200) {
      throw InnertubeException(
        '$endpoint responded ${response.statusCode}. If this is the player '
        'endpoint, the client version is probably stale.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Full-text search across YouTube Music.
  ///
  /// [filter] narrows results to one kind of thing. Only the filters that
  /// yield playable rows are offered: album and artist results come back as
  /// browse cards with no video id, so they would render as an empty list.
  Future<List<Song>> search(String query, {SearchFilter? filter}) async {
    if (query.trim().isEmpty) return const [];
    final json = await _post(_musicBase, 'search', _webRemix, {
      'query': query,
      if (filter != null) 'params': filter.params,
    });
    return parseSearchResults(json);
  }

  /// The visitor identity YouTube assigns this client, fetched once and reused.
  ///
  /// This is the difference between a track that plays and one that does not.
  /// Asking the player endpoint without it answers UNPLAYABLE every time;
  /// carrying it answers OK every time — measured 0/5 against 5/5. An anonymous
  /// request with no identity at all looks more suspicious to YouTube than one
  /// with a plain visitor id, so the cheapest fix is simply to have one.
  Future<String?> visitorData() async {
    if (_visitorData != null) return _visitorData;
    try {
      final json = await _post(_musicBase, 'browse', _webRemix, {
        'browseId': 'FEmusic_home',
      });
      _visitorData =
          readPath(json, ['responseContext', 'visitorData']) as String?;
    } catch (_) {
      // Playback can still be attempted without it; it just rarely works.
    }
    return _visitorData;
  }

  String? _visitorData;

  /// Raw browse call. Every library surface is the same endpoint with a
  /// different id, so the typed helpers below are thin wrappers.
  Future<Map<String, dynamic>> browse(String browseId, {String? params}) =>
      _post(_musicBase, 'browse', _webRemix, {
        'browseId': browseId,
        'params': ?params,
      });

  /// The next page of a browse response.
  ///
  /// A continuation carries no browse id: the token already names both the
  /// shelf and the place in it. Every library surface here answers the first
  /// hundred rows and hides the rest behind one of these.
  Future<Map<String, dynamic>> browseContinuation(String token) =>
      _post(_musicBase, 'browse', _webRemix, {'continuation': token});

  /// What the app shows on opening: whatever YouTube Music puts on its front
  /// page for this client.
  ///
  /// Signed out this is a couple of rows of playlists rather than songs, which
  /// is not a limitation to work around — recommendations need a listening
  /// history, and without one there is nothing personal to recommend.
  Future<List<Shelf>> homeFeed() async =>
      parseShelves(await browse('FEmusic_home'));

  /// Tells YouTube a track started, so it lands in the account's history.
  ///
  /// Signed out this is pointless and skipped; signed in it is what makes the
  /// History tab fill up, since that tab reads back the very history this
  /// writes to. Failures are swallowed: a play that was not counted is not a
  /// reason to interrupt the music.
  Future<void> reportPlayback(AudioStream stream) =>
      _ping(stream, stream.trackingUrl, const {});

  /// Tells YouTube how much of the track was actually heard.
  ///
  /// The start ping alone does not settle it — a listen that stops immediately
  /// is not one — so the history entry is confirmed by reporting elapsed time
  /// once enough of the track has gone by.
  Future<void> reportWatchtime(AudioStream stream, Duration position) {
    final seconds = position.inMilliseconds / 1000;
    return _ping(stream, stream.watchtimeUrl, {
      'st': '0',
      'et': seconds.toStringAsFixed(3),
      'state': 'playing',
    });
  }

  Future<void> _ping(
    AudioStream stream,
    String? baseUrl,
    Map<String, String> extra,
  ) async {
    if (baseUrl == null || session?.isSignedIn != true) return;
    try {
      // The base URL already carries the track and the session; the nonce and
      // the format version are the player's to add. Merged into the existing
      // query rather than appended, so nothing is sent twice.
      final base = Uri.parse(baseUrl);
      final ping = base.replace(queryParameters: {
        ...base.queryParameters,
        'ver': '2',
        'cpn': stream.cpn,
        // Which surface the listen belongs to. Without this pair YouTube files
        // it as a video watched, not as a track listened to, and the account's
        // music history never moves.
        'c': _webRemix.name,
        'cver': _webRemix.version,
        ...extra,
      });
      await _http.get(
        ping,
        headers: {
          // Matching the client the beacon was minted for and the one the
          // query above claims to be, rather than whoever served the audio.
          'User-Agent': _webRemix.userAgent,
          // Cookies alone, deliberately. The stats endpoint is a beacon, not an
          // API: the signed API headers the rest of this file sends are scoped
          // to another origin and only make the request look wrong.
          if (session?.cookieHeader != null) 'Cookie': session!.cookieHeader!,
        },
      );
    } catch (_) {
      // Nothing to do about it, and nothing worth telling the listener.
    }
  }

  static final _random = Random();

  static String _playbackNonce() {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    return List.generate(
      16,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  /// Who is signed in, for the account panel to show.
  ///
  /// Returns null rather than throwing when signed out or when the shape
  /// changes: a missing name is a cosmetic loss, and it should never be the
  /// reason a settings panel refuses to open.
  Future<Account?> accountInfo() async {
    if (session?.isSignedIn != true) return null;
    try {
      final json = await _post(_musicBase, 'account/account_menu', _webRemix, {});
      final header = findFirst(json, 'activeAccountHeaderRenderer');
      if (header == null) return null;

      final thumbnails = findFirst(readPath(header, ['accountPhoto']), 'thumbnails');
      return Account(
        name: _runsText(readPath(header, ['accountName'])),
        email: _runsText(readPath(header, ['email'])),
        photoUrl: thumbnails is List && thumbnails.isNotEmpty
            ? readPath(thumbnails.last, ['url']) as String?
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static String _runsText(Object? node) {
    final runs = readPath(node, ['runs']);
    if (runs is! List) return '';
    return runs
        .map((run) => readPath(run, ['text']))
        .whereType<String>()
        .join();
  }

  /// Songs the account has liked.
  Future<List<Song>> likedSongs() async =>
      parseSongList(await browse('FEmusic_liked_videos'));

  /// One page of the ids the account has liked, and where to resume.
  ///
  /// Ids rather than [Song]s because the caller is filling a set to colour a
  /// heart with, and a page holds a hundred rows. A null [continuation] starts
  /// the list; a null `nextToken` in the answer means it ended.
  Future<({List<String> ids, String? nextToken})> likedSongIds({
    String? continuation,
  }) async {
    final json = continuation == null
        ? await browse('FEmusic_liked_videos')
        : await browseContinuation(continuation);
    return (ids: parseSongIds(json), nextToken: parseContinuationToken(json));
  }

  /// Recently played tracks.
  Future<List<Song>> history() async =>
      parseSongList(await browse('FEmusic_history'));

  /// What YouTube would finish a half-typed query with.
  ///
  /// Empty on any failure rather than throwing: suggestions are a convenience
  /// offered while someone is typing, and a keyboard is no place for an error.
  Future<List<String>> searchSuggestions(String input) async {
    if (input.trim().isEmpty) return const [];
    try {
      final json = await _post(
        _musicBase,
        'music/get_search_suggestions',
        _webRemix,
        {'input': input},
      );
      return parseSearchSuggestions(json);
    } catch (_) {
      return const [];
    }
  }

  /// Records released this week, as YouTube's explore page lists them.
  Future<List<Shelf>> newReleases() async =>
      parseShelves(await browse('FEmusic_new_releases'));

  /// The charts: what is being played most, where the account says it is.
  Future<List<Shelf>> charts() async =>
      parseShelves(await browse('FEmusic_charts'));

  /// The mood and genre buttons, each of which opens a page of its own.
  Future<List<Playlist>> moods() async =>
      parseMoodChips(await browse('FEmusic_moods_and_genres'));

  /// One mood or genre. The params are what tell an otherwise identical browse
  /// id which category is wanted.
  Future<List<Shelf>> moodPage(Playlist chip) async =>
      parseShelves(await browse(chip.browseId, params: chip.params));

  /// What YouTube would play after this track, on and on.
  ///
  /// This is the endless mix its own player runs on: ask for the radio of a
  /// song and you get that song plus a queue of what goes with it. The app uses
  /// it twice — to start a radio on demand, and to keep the music going when a
  /// queue runs out, which is the difference between a player and a playlist.
  Future<List<Song>> radio(String videoId) async {
    final json = await _post(_musicBase, 'next', _webRemix, {
      'videoId': videoId,
      // `RDAMVM` is the radio of one track. Without it, `next` answers with
      // that single song and nothing after it.
      'playlistId': 'RDAMVM$videoId',
      'isAudioOnly': true,
    });
    final songs = parseWatchQueue(json);

    // The seed is always first in the answer, and it is already playing.
    return songs.where((song) => song.videoId != videoId).toList();
  }

  /// What YouTube would play after this whole collection.
  ///
  /// The same endpoint as a track's radio, seeded by the list instead of by one
  /// song: `RDAMPL` glued onto the playlist id is what YouTube's own "start
  /// radio" on a playlist asks for. Passing a `videoId` as well would pin the
  /// mix to that track, which is the other feature.
  Future<List<Song>> collectionRadio(String playlistId) async {
    final id = _bareId(playlistId);
    final json = await _post(_musicBase, 'next', _webRemix, {
      // Anything that already starts a radio — `RDAMPL` for a list, `RDEM` for
      // an artist — is asked for as it stands: prefixing it again names a mix
      // that does not exist.
      'playlistId': id.startsWith('RD') ? id : 'RDAMPL$id',
      'isAudioOnly': true,
    });
    return parseWatchQueue(json);
  }

  /// Adds or removes a playlist from the account's library.
  ///
  /// The collection-level twin of [setLiked]: YouTube models saving a playlist
  /// as liking it, so it goes through the same endpoint with a playlist target.
  /// An artist is the exception — a channel is not something one likes, it is
  /// something one follows — so it is routed to [setArtistSubscribed] here,
  /// where the difference is YouTube's, rather than in the store that only
  /// knows it was asked to keep something.
  Future<void> setCollectionSaved(String playlistId, bool saved) async {
    if (_isChannel(playlistId)) {
      return setArtistSubscribed(playlistId, saved);
    }
    _requireSession();
    await _post(
      _musicBase,
      saved ? 'like/like' : 'like/removelike',
      _webRemix,
      {
        'target': {'playlistId': _bareId(playlistId)},
      },
    );
  }

  /// Follows or stops following an artist on the account.
  ///
  /// A channel, unlike a playlist, has an endpoint of its own, and it takes a
  /// list: YouTube's own client unsubscribes from several at once from the
  /// library page.
  Future<void> setArtistSubscribed(String channelId, bool subscribed) async {
    _requireSession();
    await _post(
      _musicBase,
      subscribed ? 'subscription/subscribe' : 'subscription/unsubscribe',
      _webRemix,
      {
        'channelIds': [channelId],
      },
    );
  }

  /// A browse id without the `VL` a library shelf prefixes it with. Everything
  /// but `browse` wants the bare playlist id.
  static String _bareId(String playlistId) =>
      playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;

  /// Channel ids are the one browse id that names a person rather than a list.
  static bool _isChannel(String browseId) => browseId.startsWith('UC');

  /// An artist's page: their popular tracks, then their albums and singles.
  Future<MusicPage> artistPage(String browseId) async {
    final json = await browse(browseId);
    final header = parsePageHeader(json);
    final details = parseArtistDetails(json);
    return MusicPage(
      title: header.title,
      subtitle: header.subtitle,
      thumbnailUrl: header.thumbnailUrl,
      songs: parseSongList(json),
      shelves: parseShelves(json),
      radioPlaylistId: details.radioPlaylistId,
      subscribed: details.subscribed,
    );
  }

  /// An album's page. Only its tracks: the rows underneath are recommendations
  /// for other albums, which belong to browsing rather than to this record.
  Future<MusicPage> albumPage(String browseId) async {
    final json = await browse(browseId);
    final header = parsePageHeader(json);
    return MusicPage(
      title: header.title,
      subtitle: header.subtitle,
      thumbnailUrl: header.thumbnailUrl,
      songs: parseSongList(json),
    );
  }

  /// Adds or removes a track from the account's liked songs.
  ///
  /// The first write this app makes rather than reads. It goes through the same
  /// endpoint the web player uses, so a like made here shows up everywhere else
  /// the account is signed in.
  Future<void> setLiked(String videoId, bool liked) async {
    _requireSession();
    await _post(
      _musicBase,
      liked ? 'like/like' : 'like/removelike',
      _webRemix,
      {
        'target': {'videoId': videoId},
      },
    );
  }

  /// Adds a track to one of the account's playlists.
  Future<void> addToPlaylist(String playlistId, String videoId) =>
      addAllToPlaylist(playlistId, [videoId]);

  /// Adds several tracks at once.
  ///
  /// One edit carrying every track rather than one request per track: a record
  /// added song by song would be a hundred round trips, and YouTube accepts the
  /// whole list in a single `actions` array.
  Future<void> addAllToPlaylist(
    String playlistId,
    List<String> videoIds,
  ) async {
    _requireSession();
    if (videoIds.isEmpty) return;
    await _post(_musicBase, 'browse/edit_playlist', _webRemix, {
      // The edit endpoint wants the bare id, not the `VL` browse form.
      'playlistId': _bareId(playlistId),
      'actions': [
        for (final videoId in videoIds)
          {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': videoId},
      ],
    });
  }

  /// Creates a playlist on the account and returns its id.
  ///
  /// Private by default: a playlist made from a phone in a moment is not a
  /// publication, and anything else would be a surprising thing for an app to
  /// decide on someone's behalf.
  Future<String?> createPlaylist(
    String title, {
    List<String> videoIds = const [],
  }) async {
    _requireSession();
    final json = await _post(_musicBase, 'playlist/create', _webRemix, {
      'title': title,
      'privacyStatus': 'PRIVATE',
      if (videoIds.isNotEmpty) 'videoIds': videoIds,
    });
    return (readPath(json, ['playlistId']) ?? readPath(json, ['id'])) as String?;
  }

  void _requireSession() {
    if (session?.isSignedIn != true) {
      throw InnertubeException('Esta acción necesita una sesión iniciada');
    }
  }

  /// Albums the account saved to its library.
  Future<List<Playlist>> savedAlbums() async =>
      parsePlaylists(await browse('FEmusic_liked_albums'));

  /// Artists the account follows, plus the ones behind its saved songs —
  /// YouTube keeps those in separate corpora and a listener does not think of
  /// them as different lists.
  Future<List<Playlist>> savedArtists() async {
    final followed = parseArtistRows(await browse('FEmusic_library_corpus_artists'));
    final seen = followed.map((artist) => artist.browseId).toSet();
    final fromSongs = parseArtistRows(
      await browse('FEmusic_library_corpus_track_artists'),
    );
    return [
      ...followed,
      ...fromSongs.where((artist) => !seen.contains(artist.browseId)),
    ];
  }

  /// Playlists the account created or saved.
  Future<List<Playlist>> savedPlaylists() async =>
      parsePlaylists(await browse('FEmusic_liked_playlists'));

  /// Tracks inside a playlist. InnerTube addresses playlist contents by
  /// prefixing the playlist id with `VL`.
  Future<List<Song>> playlistSongs(String playlistId) async {
    return parseSongList(await browse(_asBrowseId(playlistId)));
  }

  /// Albums are addressed directly; playlists need a `VL` prefix. Prefixing an
  /// album id would ask for a playlist that does not exist.
  static String _asBrowseId(String id) {
    if (id.startsWith('VL') || id.startsWith('MPRE')) return id;
    return 'VL$id';
  }

  /// The order the stream clients are tried in for this listener.
  ///
  /// Signed in, the YouTube Music identities go first. A play is filed under
  /// the client that was served the audio, and only a music client's plays
  /// reach the listening history this app reads back — a stream fetched as a
  /// headset or a phone's main YouTube app scrobbles somewhere else entirely.
  /// Signed out none of that matters and the order is pure availability.
  List<_ClientProfile> get _clientOrder {
    if (session?.isSignedIn != true) return _streamClients;
    return [
      ..._streamClients.where((client) => client.name.endsWith('MUSIC')),
      ..._streamClients.where((client) => !client.name.endsWith('MUSIC')),
    ];
  }

  /// Whether this platform's player needs mp4 rather than the best stream.
  ///
  /// Apple's AVFoundation cannot decode WebM, which is the container YouTube's
  /// highest-bitrate audio comes in. Set on the client rather than read inside
  /// the parser so this file's rules stay measurable from a recorded response.
  final bool preferMp4;

  /// Resolves the best audio stream for a track this platform can open.
  ///
  /// The returned URL is signed and expires within a few minutes, so it is
  /// fetched at playback time and never cached.
  Future<AudioStream> resolveStream(String videoId, {int passes = 2}) async =>
      (await resolveStreams(videoId, passes: passes)).first;

  /// Every stream the answering client offered for a track, best first.
  ///
  /// One pick is one chance: a format the player refuses would lose the track
  /// even when the same response carried another it could have opened. They all
  /// carry the same nonce and the same identity, because they came from one
  /// answer to one request — walking them costs nothing extra on the wire.
  Future<List<AudioStream>> resolveStreams(
    String videoId, {
    int passes = 2,
  }) async {
    String? lastReason;
    final visitor = await visitorData();

    // Started here rather than awaited, so it overlaps the player calls below
    // and costs nothing on the way to the first note.
    final beacon = _musicBeacon(videoId, visitor);

    // Walked more than once on purpose. Refusals are not deterministic: the
    // same client that answers "sign in to confirm you're not a bot" often
    // serves the track a second later, so treating one failure as a verdict
    // throws away streams that were available.
    for (var pass = 0; pass < passes; pass++) {
      for (final client in _clientOrder) {
        final Map<String, dynamic> json;
        try {
          json = await _post(
            _base,
            'player',
            client,
            {
              'videoId': videoId,
              'contentCheckOk': true,
              'racyCheckOk': true,
            },
            visitorData: visitor,
          );
        } catch (_) {
          continue; // A rejected request is just another client to skip.
        }

        final status = readPath(json, ['playabilityStatus', 'status']);
        if (status != 'OK') {
          lastReason =
              readPath(json, ['playabilityStatus', 'reason']) as String? ??
                  lastReason;
          continue;
        }

        final streams = parseAudioStreams(json, preferMp4: preferMp4);
        if (streams.isEmpty) continue;

        // Minted here rather than at report time so the audio request and the
        // reports about it carry the same nonce, which is what lets the server
        // recognise them as one listen. One nonce for the whole answer: the
        // alternates are the same listen by another container.
        final cpn = _playbackNonce();
        // The music client's beacon when there is one, since only that one is
        // counted as a listen; the serving client's otherwise, which is better
        // than nothing and is all there is signed out.
        final trackingUrl = (await beacon).$1 ??
            readPath(json, [
              'playbackTracking',
              'videostatsPlaybackUrl',
              'baseUrl',
            ]) as String?;
        final watchtimeUrl = (await beacon).$2 ??
            readPath(json, [
              'playbackTracking',
              'videostatsWatchtimeUrl',
              'baseUrl',
            ]) as String?;

        final candidates = [
          for (final stream in streams)
            AudioStream(
              url: '${stream.url}&cpn=$cpn',
              bitrate: stream.bitrate,
              mimeType: stream.mimeType,
              duration: stream.duration,
              userAgent: client.userAgent,
              cpn: cpn,
              trackingUrl: trackingUrl,
              watchtimeUrl: watchtimeUrl,
            ),
        ];

        // Probed on the head alone. They come from one client and one URL host,
        // so a client that truncates truncates all of them, and probing each
        // would triple the requests before the first note.
        if (await _servesWholeTrack(candidates.first)) return candidates;
      }
    }

    throw InnertubeException(
      lastReason ?? 'Ningún cliente entregó un stream reproducible',
    );
  }


  /// The playback beacon as YouTube Music's own web client is given it.
  ///
  /// A listen is filed against the surface the beacon names, not against
  /// whoever fetched the bytes — and the clients that will serve this app audio
  /// are plain YouTube ones, so every play landed in the account's *watch*
  /// history and never in `FEmusic_history`. Asking `WEB_REMIX` for the same
  /// track yields a beacon minted for the music surface; pinging that one is
  /// what puts the track at the top of the listening history.
  ///
  /// Both halves are needed: measured against a real account, this URL without
  /// the client parameters [_ping] adds does nothing, and those parameters on
  /// the serving client's URL do nothing either.
  ///
  /// Signed out there is no history to write to, and `WEB_REMIX` answers
  /// `UNPLAYABLE` without a session anyway.
  Future<(String?, String?)> _musicBeacon(String videoId, String? visitor) async {
    if (session?.isSignedIn != true) return (null, null);
    try {
      final json = await _post(
        _musicBase,
        'player',
        _webRemix,
        {'videoId': videoId, 'contentCheckOk': true, 'racyCheckOk': true},
        visitorData: visitor,
      );
      return (
        readPath(json, ['playbackTracking', 'videostatsPlaybackUrl', 'baseUrl'])
            as String?,
        readPath(json, ['playbackTracking', 'videostatsWatchtimeUrl', 'baseUrl'])
            as String?,
      );
    } catch (_) {
      // A play that was not counted is not a reason to interrupt the music.
      return (null, null);
    }
  }

  /// Rejects a stream that would die partway through.
  ///
  /// Some clients hand out a URL that serves an opening megabyte and then
  /// refuses everything after it, which reaches the listener as a track that
  /// stops around the one minute mark. Probing past that point costs three
  /// tiny requests and turns a broken playback into a skipped client.
  Future<bool> _servesWholeTrack(AudioStream stream) async {
    const probes = [
      'bytes=0-0',
      'bytes=262144-262145',
      'bytes=1048576-1048577',
    ];

    for (final range in probes) {
      try {
        final response = await _http.get(
          Uri.parse(stream.url),
          headers: {'Range': range, 'User-Agent': stream.userAgent},
        );
        // 416 means the track is simply shorter than the probe, which is fine.
        if (response.statusCode == 416) continue;
        if (response.statusCode < 200 || response.statusCode > 399) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  void dispose() => _http.close();
}
