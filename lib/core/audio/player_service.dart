import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/play_history.dart';
import '../../data/audio_cache.dart';
import '../../data/device_songs.dart';
import '../../data/downloads.dart';
import '../../data/likes.dart';
import '../../data/resume_point.dart';
import '../../data/settings.dart';
import '../innertube/innertube_client.dart';
import '../scrobble/scrobbler.dart';
import 'stream_proxy.dart';

/// Bridges the queue of [Song]s to the platform's native player and media
/// notification.
///
/// The queue holds tracks, not URLs, and each stream is resolved at the moment
/// it starts playing. That is deliberate: YouTube's audio URLs are signed and
/// expire within minutes, so a queue of pre-resolved URLs would rot while the
/// user listened to the first track.
class PlayerService extends BaseAudioHandler with SeekHandler {
  PlayerService(
    this._innertube,
    this._history,
    this._settings,
    this._downloads,
    this._cache,
    this._scrobbler,
    this._likes,
    this._resume,
    this._browseLabels,
  ) {
    _wirePlayerStreams();
    _settings.addListener(_applySettings);
    // The heart in the shade is drawn from playback state, so a like made
    // anywhere else has to republish it.
    _likes.addListener(_publishState);
    _applySettings();
    unawaited(_restoreEqualizer());
  }

  final InnertubeClient _innertube;
  final PlayHistory _history;
  final Settings _settings;
  final Downloads _downloads;
  final AudioCache _cache;
  final Scrobbler _scrobbler;
  final Likes _likes;
  final ResumePoint _resume;

  static const _likeAction = 'like';
  static const _shuffleAction = 'shuffle';
  static const _repeatAction = 'repeat';
  static const _radioAction = 'radio';

  /// How many refused tracks in a row the queue steps over before giving up.
  static const _refusalsBeforeGivingUp = 5;

  /// Names for what a car shows. Passed in rather than looked up, because this
  /// class runs without a widget tree and the translations live in one.
  final ({
    String likes,
    String playlists,
    String albums,
    String artists,
    String downloads,
    String history,
    String shuffle,
    String repeat,
    String radio,
  }) _browseLabels;

  /// Whether this platform has the effects at all.
  ///
  /// They are Android's own, and just_audio activates every effect in the
  /// pipeline regardless of platform — it filters which ones it *sends* on
  /// load, but not which ones it activates. Carried onto macOS they make
  /// `MissingPluginException` out of every `setAudioSource`, which `_playIndex`
  /// reads as a track YouTube refused: the queue steps over the whole list in
  /// silence, one skip per track. Measured on macOS, invisible on Android.
  static final bool supportsEqualizer = Platform.isAndroid;

  /// Whether caching a stream while it plays works here.
  ///
  /// `LockCachingAudioSource` hands the audio to the platform through
  /// just_audio's own stream source, and AVFoundation cannot open what comes
  /// out: every track dies with `AVErrorFileFormatNotRecognized` (-11828) even
  /// when the format is the mp4 it asked for. Measured on macOS by turning this
  /// one thing off — with it off the same track plays. Elsewhere the audio
  /// still goes through [StreamProxy]; it just is not written to disk on the
  /// way past.
  static final bool supportsStreamCaching = Platform.isAndroid;

  /// Effects sit in the pipeline whether or not they are switched on: Android
  /// attaches them when the audio session opens, so one added later would not
  /// take hold until the next track.
  final AndroidEqualizer? _equalizer =
      supportsEqualizer ? AndroidEqualizer() : null;
  final AndroidLoudnessEnhancer? _loudness =
      supportsEqualizer ? AndroidLoudnessEnhancer() : null;

  late final _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [?_loudness, ?_equalizer],
    ),
  );
  final _proxy = StreamProxy();

  /// Null where the platform has no equalizer; the settings screen offers the
  /// bands only where there is something behind them.
  AndroidEqualizer? get equalizer => _equalizer;

  /// The queue in the order it will play, which is what the queue screen shows
  /// and what shuffling rearranges.
  List<Song> _songs = const [];

  /// The same tracks in the order they arrived, kept only so that turning
  /// shuffle off puts the album back the way its maker intended.
  List<Song> _unshuffled = const [];

  int _index = 0;

  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;
  bool _shuffled = false;

  /// Whether a finished queue reaches for YouTube's radio instead of stopping.
  /// On by default: someone who pressed play on one song usually meant "play
  /// music", and the queue running dry is not a decision they made.
  bool get autoplay => _settings.autoplay;

  /// When the music will stop by itself, if it will. Exposed as a notifier so
  /// the interface can count down without polling the player.
  final sleepAt = ValueNotifier<DateTime?>(null);
  Timer? _sleep;

  /// Stops the music after [after], or cancels a pending stop when null.
  void sleepAfter(Duration? after) {
    _sleep?.cancel();
    if (after == null) {
      _sleep = null;
      sleepAt.value = null;
      return;
    }
    sleepAt.value = DateTime.now().add(after);
    _sleep = Timer(after, () {
      sleepAt.value = null;
      // Paused rather than stopped: someone who fell asleep to an album should
      // find it where they left it, not back at the start of nothing.
      pause();
    });
  }

  /// Puts the saved band gains back.
  ///
  /// Deliberately without a timeout: the equalizer's parameters only exist once
  /// Android has opened an audio session, so this waits — possibly for minutes,
  /// until the first track plays — and then applies them.
  Future<void> _restoreEqualizer() async {
    final equalizer = _equalizer;
    if (equalizer == null) return;
    final gains = _settings.bandGains;
    if (gains.isEmpty) return;
    final parameters = await equalizer.parameters;
    for (var i = 0; i < parameters.bands.length && i < gains.length; i++) {
      await parameters.bands[i].setGain(gains[i]);
    }
  }

  void _applySettings() {
    _player.setSpeed(_settings.speed);
    _player.setSkipSilenceEnabled(_settings.skipSilence);
    _loudness?.setEnabled(_settings.normalizeVolume);
    // A few decibels: enough to lift a quiet master to meet a loud one, not so
    // much that anything clips.
    _loudness?.setTargetGain(_settings.normalizeVolume ? 0.5 : 0);
    _equalizer?.setEnabled(_settings.equalizerEnabled);
  }

  int _savedAt = -1;

  /// Volume the fade is working towards, so a fade-out in progress is not
  /// undone by the stream's next tick.
  double _fadeTarget = 1;

  /// Raises the volume from silence over the configured seconds.
  Future<void> _fadeIn() async {
    final seconds = _settings.fadeSeconds;
    if (seconds <= 0) {
      await _player.setVolume(1);
      return;
    }
    _fadeTarget = 1;
    await _player.setVolume(0);
    const step = Duration(milliseconds: 100);
    final steps = seconds * 1000 ~/ step.inMilliseconds;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(step);
      if (_fadeTarget != 1) return; // A new track took over mid-fade.
      await _player.setVolume(i / steps);
    }
  }

  void _fadeOutNearTheEnd(Duration position) {
    final seconds = _settings.fadeSeconds;
    final total = _player.duration;
    if (seconds <= 0 || total == null || !_player.playing) return;

    final left = total - position;
    if (left > Duration(seconds: seconds)) {
      // Comfortably inside the track: nothing to do, and the volume belongs to
      // whatever the fade-in left it at.
      return;
    }
    final ratio = (left.inMilliseconds / (seconds * 1000)).clamp(0.0, 1.0);
    _fadeTarget = ratio;
    _player.setVolume(ratio);
  }

  /// Where a restored track should start, until the first play consumes it.
  ///
  /// Nothing is fetched to restore a queue: reopening the app costs no network
  /// and no battery, and the stream is only resolved when someone actually
  /// presses play — at which point it opens at the second it was left on.
  Duration? _pending;

  /// Whether the player currently holds audio for [_index]. False after a
  /// restore, which is how play() knows it has to load before it can start.
  bool _loaded = false;

  /// Pending confirmation that the current track was really listened to.
  /// Cancelled whenever the track changes, so skipping past something never
  /// counts as having been heard.
  Timer? _watchtime;

  Song? get currentSong =>
      _index >= 0 && _index < _songs.length ? _songs[_index] : null;

  List<Song> get songs => _songs;
  int get currentIndex => _index;

  AudioPlayer get player => _player;

  /// The position to put on screen: the player's own once audio is loaded, and
  /// the remembered one before that. A restored track shows where it will
  /// resume from, rather than sitting at zero until someone presses play.
  Stream<Duration> get shownPosition => _player.positionStream
      .map((position) => _loaded ? position : (_pending ?? Duration.zero));

  /// Likewise for the length: known from the listing before the stream opens.
  Duration? get shownDuration => _player.duration ?? currentSong?.duration;

  void _wirePlayerStreams() {
    _player.playbackEventStream.listen(
      (event) => playbackState.add(_transformState(event)),
      onError: (Object error, StackTrace stack) =>
          playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      )),
    );

    // Where the music is, written down every few seconds and whenever it
    // starts or stops. Every few rather than every tick: this is a file, and
    // losing at most five seconds of position is not worth the writes.
    _player.positionStream.listen((position) {
      final second = position.inSeconds;
      if (second == _savedAt || second % 5 != 0) return;
      _savedAt = second;
      unawaited(_saveResumePoint());
    });
    _player.playingStream.listen((_) => unawaited(_saveResumePoint()));

    // Fading out is driven by position rather than by a timer: seeking, pausing
    // and speed changes all move the end of a track around, and a timer set
    // when it started would be wrong by then.
    _player.positionStream.listen(_fadeOutNearTheEnd);

    // just_audio reports completion of the single loaded track; advancing the
    // queue is this class's job because the queue lives here, not in the player.
    _player.processingStateStream.listen((state) {
      if (state != ProcessingState.completed) return;
      if (_repeat == AudioServiceRepeatMode.one) {
        unawaited(_playIndex(_index));
      } else {
        unawaited(_advance());
      }
    });
  }

  PlaybackState _transformState(PlaybackEvent event) {
    final song = currentSong;
    final liked = song != null && _likes.isLiked(song.videoId);

    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        // Liking from the shade, where half of it happens. No stop button: the
        // system already offers a way out of a media notification, and the one
        // audio_service draws is a bare white square.
        //
        // These are custom actions rather than notification buttons, so they
        // reach Android Auto's control row without crowding the phone's shade.
        // Every icon named here must survive the release shrinker — see
        // res/raw/keep.xml, and the test that keeps the two in step.
        if (_likes.canLike)
          MediaControl.custom(
            androidIcon: liked
                ? 'drawable/ic_favorite_filled'
                : 'drawable/ic_favorite',
            label: 'Like',
            name: _likeAction,
          ),
        MediaControl.custom(
          androidIcon: 'drawable/ic_auto_shuffle',
          label: _browseLabels.shuffle,
          name: _shuffleAction,
        ),
        MediaControl.custom(
          androidIcon: _repeat == AudioServiceRepeatMode.one
              ? 'drawable/ic_auto_repeat_one'
              : 'drawable/ic_auto_repeat',
          label: _browseLabels.repeat,
          name: _repeatAction,
        ),
        MediaControl.custom(
          androidIcon: 'drawable/ic_auto_radio',
          label: _browseLabels.radio,
          name: _radioAction,
        ),
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _index,
      repeatMode: _repeat,
      shuffleMode: _shuffled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  MediaItem _toMediaItem(Song song) => MediaItem(
        id: song.videoId,
        title: song.title,
        // The performer when the row named one; the whole metadata line only
        // as a fallback, since a notification reading "Song • 5.3M plays" says
        // nothing about who is playing.
        artist: song.artist ??
            (song.subtitle.isEmpty ? 'YouTube Music' : song.subtitle),
        duration: song.duration,
        artUri: song.highResThumbnailUrl == null
            ? null
            : Uri.parse(song.highResThumbnailUrl!),
      );

  /// Puts back what was playing when the app last closed, paused and at the
  /// second it stopped on. The queue and the modes come back with it.
  Future<void> restore() async {
    if (_resume.isEmpty) return;

    _songs = List.of(_resume.songs);
    _unshuffled = List.of(_resume.songs);
    _index = _resume.index;
    _shuffled = _resume.shuffled;
    _repeat = AudioServiceRepeatMode.values[
        _resume.repeatMode.clamp(0, AudioServiceRepeatMode.values.length - 1)];
    _pending = _resume.position;
    _loaded = false;

    _publishQueue();
    mediaItem.add(_toMediaItem(_songs[_index]));
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.ready,
      playing: false,
      updatePosition: _resume.position,
      queueIndex: _index,
      repeatMode: _repeat,
      shuffleMode: _shuffled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    ));
  }

  /// Writes down where the music is, so the next launch — or the next car —
  /// can pick it up. Cheap enough to call on every change worth remembering.
  Future<void> _saveResumePoint() async {
    if (_songs.isEmpty) return;
    await _resume.save(
      songs: _songs,
      index: _index,
      position: _loaded ? _player.position : (_pending ?? Duration.zero),
      shuffled: _shuffled,
      repeatMode: _repeat.index,
    );
  }

  /// Replaces the queue and starts playing at [startIndex].
  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    _songs = List.of(songs);
    _unshuffled = List.of(songs);
    if (_shuffled) _shuffleAround(startIndex);
    _publishQueue();
    if (!await _playIndex(_shuffled ? 0 : startIndex)) await _advance();
  }

  /// Puts a track right after the one playing, for "play next".
  Future<void> playNext(Song song) async {
    if (_songs.isEmpty) return setQueue([song]);
    _insert(song, _index + 1);
  }

  /// Puts a track at the end of the queue.
  Future<void> addToQueue(Song song) async {
    if (_songs.isEmpty) return setQueue([song]);
    _insert(song, _songs.length);
  }

  void _insert(Song song, int at) {
    // A track already queued moves rather than doubling: two identical rows in
    // a queue are never what someone meant.
    final existing = _songs.indexOf(song);
    if (existing >= 0) {
      if (existing == _index) return;
      _songs.removeAt(existing);
      if (existing < _index) _index--;
      if (existing < at) at--;
    }
    _songs.insert(at.clamp(0, _songs.length), song);
    if (!_unshuffled.contains(song)) _unshuffled.add(song);
    _publishQueue();
  }

  /// Moves a track within the queue, as dragging a row does. [to] is the
  /// destination once the track has been lifted out.
  Future<void> moveQueueItem(int from, int to) async {
    if (from < 0 || from >= _songs.length) return;
    final playing = currentSong;
    final song = _songs.removeAt(from);
    _songs.insert(to.clamp(0, _songs.length), song);

    // The track that is playing keeps playing wherever it ends up, so the
    // index follows the song rather than the position.
    if (playing != null) _index = _songs.indexOf(playing);
    _publishQueue();
  }

  /// Drops a track from the queue. Removing what is playing moves on to the
  /// next one, which is the only reading of the gesture that makes sense.
  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _songs.length) return;
    final song = _songs.removeAt(index);
    _unshuffled.remove(song);

    if (_songs.isEmpty) {
      _publishQueue();
      await stop();
      return;
    }
    if (index < _index) {
      _index--;
      _publishQueue();
    } else if (index == _index) {
      _index = index.clamp(0, _songs.length - 1);
      _publishQueue();
      await _playIndex(_index);
    } else {
      _publishQueue();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffled = shuffleMode != AudioServiceShuffleMode.none;
    if (_shuffled) {
      _shuffleAround(_index);
    } else {
      // Back to the arrival order, with the current track still current.
      final playing = currentSong;
      _songs = _unshuffled.where(_songs.contains).toList();
      _index = playing == null ? 0 : _songs.indexOf(playing).clamp(0, _songs.length - 1);
    }
    _publishQueue();
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  /// Shuffles the queue while leaving the track at [around] playing, first in
  /// the new order: stopping the music to shuffle it would be absurd.
  void _shuffleAround(int around) {
    if (_songs.isEmpty) return;
    final current = _songs[around.clamp(0, _songs.length - 1)];
    final rest = List.of(_songs)..remove(current);
    rest.shuffle();
    _songs = [current, ...rest];
    _index = 0;
  }

  /// Republishes the state from the player as it is right now.
  ///
  /// For the moments the player itself has no event to offer — a like taken
  /// elsewhere, a track that never loaded — where the media session would
  /// otherwise keep describing the situation before it.
  void _publishState() =>
      playbackState.add(_transformState(_player.playbackEvent));

  void _publishQueue() {
    queue.add(_songs.map(_toMediaItem).toList());
    playbackState.add(playbackState.value.copyWith(queueIndex: _index));
  }

  /// Loads [index] and starts it, answering whether the track could be played
  /// at all.
  ///
  /// A refusal is an ordinary outcome rather than an error to throw past the
  /// caller: YouTube does not serve every track to every client, and the
  /// caller here is usually the end of the previous song — it has to be told
  /// "not this one" so it can decide what plays instead. Thrown, the refusal
  /// became an unhandled async error and the music simply stopped at the tail
  /// of the track that had just finished.
  Future<bool> _playIndex(int index, {Duration? from}) async {
    _watchtime?.cancel();
    if (index < 0 || index >= _songs.length) {
      await stop();
      return false;
    }
    _index = index;
    final song = _songs[index];
    mediaItem.add(_toMediaItem(song));

    final AudioStream? stream;
    try {
      stream = await _resolve(song);
    } catch (_) {
      // The queue will move past this one. Republish so nothing downstream —
      // the car especially — is left believing a track is playing when no
      // audio ever arrived for it.
      _loaded = false;
      _publishState();
      return false;
    }

    _loaded = true;
    _pending = null;
    if (from != null && from > Duration.zero) await _player.seek(from);

    // The player knows the real duration once the stream is open; the search
    // listing's value is only an estimate.
    final actual = _player.duration;
    if (actual != null) {
      mediaItem.add(_toMediaItem(song).copyWith(duration: actual));
    }

    unawaited(_fadeIn());

    // Deliberately not awaited: just_audio's play() completes when playback
    // *stops*, not when it starts, so waiting on it would hold everything below
    // — and the caller — until the track ended.
    unawaited(_player.play());

    // Recorded once the stream is open rather than on tap, so a track that
    // never resolved does not appear in a history of things that played. The
    // account is told too — and confirmed a while later, once enough of the
    // track has been heard to call it a listen.
    unawaited(_history.record(song));
    unawaited(_saveResumePoint());
    unawaited(_scrobbler.nowPlaying(song));

    // Half the track, or two minutes, whichever comes first — the rule the
    // scrobbling services ask for, and a fair definition of "listened to".
    final startedAt = DateTime.now();
    final duration = _player.duration ?? song.duration;
    final counts = duration == null
        ? const Duration(seconds: 30)
        : Duration(
            milliseconds: (duration.inMilliseconds ~/ 2).clamp(
              30 * 1000,
              120 * 1000,
            ),
          );

    _watchtime = Timer(counts, () {
      unawaited(_scrobbler.scrobble(song, startedAt));
      if (stream case final playing?) {
        unawaited(_innertube.reportWatchtime(playing, _player.position));
      }
    });

    if (stream case final playing?) {
      unawaited(_innertube.reportPlayback(playing));
    }
    return true;
  }

  /// Points the player at [song]'s audio, returning the stream it opened — or
  /// null when the track came off this phone and no stream was involved.
  ///
  /// Throws when YouTube will not serve the track, which is the one failure
  /// [_playIndex] has to survive.
  Future<AudioStream?> _resolve(Song song) async {
    // A downloaded track never touches the network — not to resolve it, not to
    // report it. That is the whole promise of a download.
    if (DeviceSongs.isLocal(song.videoId)) {
      // Already a file on this phone: nothing to resolve, nothing to report.
      await _player.setFilePath(DeviceSongs.pathOf(song.videoId));
    } else if (_downloads.has(song.videoId)) {
      await _player.setFilePath(_downloads.fileFor(song.videoId).path);
    } else {
      // Every format the answering client offered, best first. Walked rather
      // than trusted: which containers a player can open is a property of the
      // platform, not of the answer, and losing a track because the best
      // stream happens to be one this device cannot decode is a bug the queue
      // used to hide as a skip.
      final candidates = await _innertube.resolveStreams(song.videoId);
      await _proxy.start();

      Object? refusal;
      for (final candidate in candidates) {
        // Routed through the proxy so the request carries a Range header, which
        // googlevideo requires and ExoPlayer omits on its first request. The
        // user agent travels along because the URL was issued to one particular
        // client and is fetched wearing that same identity.
        final source = _proxy.wrap(candidate.url, userAgent: candidate.userAgent);
        try {
          if (_settings.cacheEnabled && supportsStreamCaching) {
            // The same bytes are written to disk as they play, so hearing a
            // track twice costs one download. Keyed by video id rather than by
            // URL: the URL is signed and different every time, the track is
            // not. just_audio marks this experimental; it has been in every
            // release for years and there is no other way to cache while
            // streaming.
            // ignore: experimental_member_use
            await _player.setAudioSource(LockCachingAudioSource(
              source,
              cacheFile: _cache.fileFor(song.videoId),
            ));
            unawaited(_cache.prune(_settings.cacheLimitMb * 1024 * 1024));
          } else if (candidate.duration case final length?) {
            // Clipped to the length the server declared, because the platform
            // player is not a reliable authority on it: AVFoundation reads
            // YouTube's fragmented mp4 audio as exactly twice its length — see
            // [AudioStream.duration]. Left alone, the music stops halfway along
            // the bar and the counter runs on through silence for as long again
            // before the queue moves.
            //
            // One clip settles both halves of that, which is why it is done
            // here rather than by correcting the number downstream: the
            // platform reports the clip as the duration, so every surface —
            // the player, the notification, the car — reads it without knowing
            // any of this; and it ends the item at that point, so the queue
            // advances on the player's own completion instead of on a watchdog
            // racing it.
            //
            // Not available on the cached path above: clipping takes a
            // `UriAudioSource` and `LockCachingAudioSource` is a
            // `StreamAudioSource`. That costs nothing today — caching only runs
            // where the player reads these files correctly — but the two cannot
            // both be had for one track.
            await _player.setAudioSource(ClippingAudioSource(
              child: AudioSource.uri(source),
              end: length,
            ));
          } else {
            await _player.setUrl(source.toString());
          }
          return candidate;
        } catch (error) {
          refusal = error;
          // Whatever the refused format managed to write is not this track in
          // any container the next attempt will use, and the cache is keyed by
          // track: left behind it would be served as the real thing forever.
          final partial = _cache.fileFor(song.videoId);
          if (partial.existsSync()) await partial.delete();
        }
      }
      throw refusal ?? InnertubeException('Ningún formato se pudo abrir');
    }
    // A file on this device: nothing to resolve, nothing to report.
    return null;
  }

  /// The browsing tree a car stereo asks for.
  ///
  /// Android Auto talks to the same media session the phone does, but it draws
  /// nothing of the app's own interface: everything a driver can reach has to
  /// be answered here. So this is the whole library — the account's likes,
  /// playlists, albums and artists as well as what is already on the phone —
  /// rather than the two device-only shelves it used to be. A car with no
  /// signal falls back to downloads and history, which need no network.
  ///
  /// Ids carry the shelf they came from (`likes/dQw4w9WgXcQ`), because tapping
  /// a track in a car means "play this list starting here" and the media id is
  /// the only thing that comes back.
  static const _likesId = 'likes';
  static const _playlistsId = 'playlists';
  static const _albumsId = 'albums';
  static const _artistsId = 'artists';
  static const _downloadsId = 'downloads';
  static const _historyId = 'history';

  /// What each shelf last answered with, so tapping a row plays the list the
  /// driver is looking at without fetching it a second time.
  final _browsed = <String, List<Song>>{};

  /// How a shelf lays its contents out. Declared per item rather than once at
  /// the root: covers belong in a grid, tracks belong in a list, and a car
  /// shows both under the same tree.
  static Map<String, dynamic> _style({required int browsable, required int playable}) => {
        AndroidContentStyle.supportedKey: true,
        AndroidContentStyle.browsableHintKey: browsable,
        AndroidContentStyle.playableHintKey: playable,
      };

  /// A shelf: a row with an icon that opens onto something else.
  MediaItem _shelf(String id, String title, String icon, {bool grid = false}) =>
      MediaItem(
        id: id,
        title: title,
        playable: false,
        // Resolved by the car as a resource of this app, which is why these
        // drawables are pinned in res/raw/keep.xml against the shrinker.
        artUri: Uri.parse('android.resource://com.tunebox.tunebox/drawable/$icon'),
        extras: _style(
          browsable: grid
              ? AndroidContentStyle.gridItemHintValue
              : AndroidContentStyle.listItemHintValue,
          playable: AndroidContentStyle.listItemHintValue,
        ),
      );

  /// A collection — a playlist, an album, an artist — as a cover the driver can
  /// open.
  MediaItem _collection(Playlist collection, String prefix) => MediaItem(
        id: '$prefix/${collection.browseId}',
        title: collection.title,
        artist: collection.subtitle.isEmpty ? null : collection.subtitle,
        playable: false,
        artUri: collection.thumbnailUrl == null
            ? null
            : Uri.parse(collection.thumbnailUrl!),
        extras: _style(
          browsable: AndroidContentStyle.gridItemHintValue,
          playable: AndroidContentStyle.listItemHintValue,
        ),
      );

  /// A track as a car row. Remembers which shelf it was listed under so that
  /// playing it can queue up its neighbours.
  MediaItem _track(Song song, String shelf) =>
      _toMediaItem(song).copyWith(id: '$shelf/${song.videoId}');

  /// Answers a shelf of tracks, remembering it for [playFromMediaId].
  List<MediaItem> _tracks(String shelf, List<Song> songs) {
    _browsed[shelf] = songs;
    return songs.map((song) => _track(song, shelf)).toList();
  }

  /// Whatever the account holds, or an empty shelf when it cannot be reached.
  /// A car is exactly where the signal drops, and an error there is a dialog
  /// the driver has to dismiss; an empty list is not.
  Future<List<T>> _fromAccount<T>(Future<List<T>> Function() fetch) async {
    try {
      return await fetch();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return [
          // Only offered when there is an account behind them; a car showing
          // four shelves that all open onto nothing is worse than showing two
          // that work.
          if (_likes.canLike) ...[
            _shelf(_likesId, _browseLabels.likes, 'ic_favorite'),
            _shelf(_playlistsId, _browseLabels.playlists, 'ic_auto_playlist',
                grid: true),
            _shelf(_albumsId, _browseLabels.albums, 'ic_auto_album', grid: true),
            _shelf(_artistsId, _browseLabels.artists, 'ic_auto_artist',
                grid: true),
          ],
          _shelf(_downloadsId, _browseLabels.downloads, 'ic_auto_download'),
          _shelf(_historyId, _browseLabels.history, 'ic_auto_history'),
        ];

      case AudioService.recentRootId:
        // What a car asks for the moment it connects, to offer "resume": the
        // last thing played, and nothing else — this is a resume hint, not a
        // shelf to browse.
        final last = currentSong ?? _history.songs.firstOrNull;
        return [if (last != null) _toMediaItem(last)];

      case _likesId:
        return _tracks(_likesId, await _fromAccount(_innertube.likedSongs));
      case _downloadsId:
        return _tracks(_downloadsId, _downloads.songs);
      case _historyId:
        return _tracks(_historyId, _history.songs.take(100).toList());

      case _playlistsId:
        final saved = await _fromAccount(_innertube.savedPlaylists);
        return saved.map((p) => _collection(p, _playlistsId)).toList();
      case _albumsId:
        final saved = await _fromAccount(_innertube.savedAlbums);
        return saved.map((p) => _collection(p, _albumsId)).toList();
      case _artistsId:
        final saved = await _fromAccount(_innertube.savedArtists);
        return saved.map((p) => _collection(p, _artistsId)).toList();

      default:
        final slash = parentMediaId.indexOf('/');
        if (slash < 0) return const [];
        final shelf = parentMediaId.substring(0, slash);
        final id = parentMediaId.substring(slash + 1);
        final songs = switch (shelf) {
          _playlistsId =>
            await _fromAccount(() => _innertube.playlistSongs(id)),
          _albumsId => (await _innertube.albumPage(id)).songs,
          _artistsId => (await _innertube.artistPage(id)).songs,
          _ => const <Song>[],
        };
        return _tracks(parentMediaId, songs);
    }
  }

  /// Playing something the car chose means making it the queue, since a car has
  /// no way to say "this and then those".
  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    // The last segment is the track; everything before it names the shelf,
    // which for a playlist is itself two segments (`playlists/PL123`).
    final slash = mediaId.lastIndexOf('/');
    final shelf = slash < 0 ? null : mediaId.substring(0, slash);
    final videoId = slash < 0 ? mediaId : mediaId.substring(slash + 1);

    // The car's "resume" offer is the track that was already loaded: play it
    // where it was left rather than starting its queue over.
    if (currentSong?.videoId == videoId) {
      await play();
      return;
    }

    // The shelf the driver was looking at becomes the queue, so a car behaves
    // like the app does: tapping the fourth song plays it and then the fifth.
    //
    // The car keeps the tree it was shown even after Android has killed this
    // app, so a tap routinely arrives for a shelf this run never listed. Asking
    // for it again is the difference between playing the playlist the driver is
    // looking at and playing whatever the fallback happened to hold — or, when
    // the track is in neither, doing nothing at all to a tap.
    var source = _browsed[shelf];
    if (source == null && shelf != null) {
      await getChildren(shelf);
      source = _browsed[shelf];
    }
    source ??= [..._downloads.songs, ..._history.songs];
    final index = source.indexWhere((song) => song.videoId == videoId);
    if (index < 0) return;
    await setQueue(source, startIndex: index);
  }

  @override
  Future<void> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    final song = currentSong;
    switch (name) {
      case _likeAction:
        if (song == null) return;
        await _likes.toggle(song);
        // The icon is drawn from the state, so the shade only changes once the
        // account has actually taken the like.
        _publishState();
      case _shuffleAction:
        await setShuffleMode(
          _shuffled
              ? AudioServiceShuffleMode.none
              : AudioServiceShuffleMode.all,
        );
      case _repeatAction:
        // Round the same three the player screen cycles, so a driver who has
        // used the app already knows what the button does.
        await setRepeatMode(switch (_repeat) {
          AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
          AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
          _ => AudioServiceRepeatMode.none,
        });
        // The icon says which of the three it is now.
        _publishState();
      case _radioAction:
        if (song == null) return;
        await startRadio(song);
    }
  }

  @override
  Future<void> play() async {
    // After a restore there is a track and a position but no audio yet; the
    // first press is what goes and gets it.
    if (!_loaded && currentSong != null) {
      if (!await _playIndex(_index, from: _pending)) await _advance();
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _advance();

  /// Moves to the track after the current one, stepping over any the servers
  /// refuse.
  ///
  /// A liked-songs playlist of any size holds a few videos that no client is
  /// served — taken down, region-locked, or simply not offered. Stopping on
  /// the first of them is what left the music dead at the end of the previous
  /// track; walking the whole queue hammering a network that is plainly not
  /// answering would be just as wrong, so the stepping is bounded.
  Future<void> _advance() async {
    for (var refused = 0; refused < _refusalsBeforeGivingUp; refused++) {
      final int next;
      if (_index + 1 < _songs.length) {
        next = _index + 1;
      } else if (_repeat == AudioServiceRepeatMode.all && _songs.isNotEmpty) {
        next = 0;
      } else if (await _extendWithRadio()) {
        // Nothing queued and nothing to repeat: rather than fall silent, ask
        // YouTube what goes with this and keep going. Silence at the end of a
        // queue is a playlist's behaviour, not a radio's.
        next = _index + 1;
      } else {
        return;
      }
      if (await _playIndex(next)) return;
    }
    await stop();
  }

  /// Appends the current track's radio to the queue. False when there was
  /// nothing to add, which is also what happens with no network — and then the
  /// music simply stops, as it did before.
  Future<bool> _extendWithRadio() async {
    final seed = currentSong;
    if (seed == null || !autoplay) return false;
    try {
      final related = await _innertube.radio(seed.videoId);
      final fresh = related.where((song) => !_songs.contains(song)).toList();
      if (fresh.isEmpty) return false;
      _songs.addAll(fresh);
      _unshuffled.addAll(fresh);
      _publishQueue();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resolves a track and hands the local proxy's URL to [Downloads], which is
  /// the only way to fetch a whole file from googlevideo — it refuses anything
  /// but bounded ranges, and the proxy is what turns one request into many.
  Future<void> download(Song song) async {
    _downloads.enqueue(song, (queued) async {
      final stream = await _innertube.resolveStream(queued.videoId);
      await _proxy.start();
      await _downloads.add(
        queued,
        _proxy.wrap(stream.url, userAgent: stream.userAgent),
        userAgent: stream.userAgent,
      );
    });
  }

  /// Starts a radio from one track: it plays, and what YouTube says goes with
  /// it queues up behind.
  Future<void> startRadio(Song seed) async {
    await setQueue([seed]);
    await _extendWithRadio();
  }

  @override
  Future<void> skipToPrevious() async {
    // Matches the convention every music player uses: rewind first, and only
    // change track when already near the start.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    await previousTrack();
  }

  /// Always the track before, with no rewind-first rule.
  ///
  /// That rule is right for a button pressed twice in a row and wrong for a
  /// swipe: dragging a cover aside says "the other one", never "start this one
  /// again".
  Future<void> previousTrack() async {
    if (_index > 0) await _playIndex(_index - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _playIndex(index);
  }

  @override
  Future<void> stop() async {
    _watchtime?.cancel();
    sleepAfter(null);
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }
}
