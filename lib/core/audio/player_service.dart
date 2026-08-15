import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/models/song.dart';
import '../../data/play_history.dart';
import '../../data/audio_cache.dart';
import '../../data/downloads.dart';
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
    this._browseLabels,
  ) {
    _wirePlayerStreams();
    _settings.addListener(_applySettings);
    _applySettings();
    unawaited(_restoreEqualizer());
  }

  final InnertubeClient _innertube;
  final PlayHistory _history;
  final Settings _settings;
  final Downloads _downloads;
  final AudioCache _cache;
  final Scrobbler _scrobbler;

  /// Names for the two shelves a car shows. Passed in rather than looked up,
  /// because this class runs without a widget tree and the translations live
  /// in one.
  final ({String downloads, String history}) _browseLabels;

  /// Effects sit in the pipeline whether or not they are switched on: Android
  /// attaches them when the audio session opens, so one added later would not
  /// take hold until the next track.
  final _equalizer = AndroidEqualizer();
  final _loudness = AndroidLoudnessEnhancer();

  late final _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_loudness, _equalizer],
    ),
  );
  final _proxy = StreamProxy();

  AndroidEqualizer get equalizer => _equalizer;

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
    final gains = _settings.bandGains;
    if (gains.isEmpty) return;
    final parameters = await _equalizer.parameters;
    for (var i = 0; i < parameters.bands.length && i < gains.length; i++) {
      await parameters.bands[i].setGain(gains[i]);
    }
  }

  void _applySettings() {
    _player.setSpeed(_settings.speed);
    _player.setSkipSilenceEnabled(_settings.skipSilence);
    _loudness.setEnabled(_settings.normalizeVolume);
    // A few decibels: enough to lift a quiet master to meet a loud one, not so
    // much that anything clips.
    _loudness.setTargetGain(_settings.normalizeVolume ? 0.5 : 0);
    _equalizer.setEnabled(_settings.equalizerEnabled);
  }

  /// Pending confirmation that the current track was really listened to.
  /// Cancelled whenever the track changes, so skipping past something never
  /// counts as having been heard.
  Timer? _watchtime;

  Song? get currentSong =>
      _index >= 0 && _index < _songs.length ? _songs[_index] : null;

  List<Song> get songs => _songs;
  int get currentIndex => _index;

  AudioPlayer get player => _player;

  void _wirePlayerStreams() {
    _player.playbackEventStream.listen(
      (event) => playbackState.add(_transformState(event)),
      onError: (Object error, StackTrace stack) =>
          playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      )),
    );

    // just_audio reports completion of the single loaded track; advancing the
    // queue is this class's job because the queue lives here, not in the player.
    _player.processingStateStream.listen((state) {
      if (state != ProcessingState.completed) return;
      if (_repeat == AudioServiceRepeatMode.one) {
        _playIndex(_index);
      } else {
        skipToNext();
      }
    });
  }

  PlaybackState _transformState(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
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

  /// Replaces the queue and starts playing at [startIndex].
  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    _songs = List.of(songs);
    _unshuffled = List.of(songs);
    if (_shuffled) _shuffleAround(startIndex);
    _publishQueue();
    await _playIndex(_shuffled ? 0 : startIndex);
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

  void _publishQueue() {
    queue.add(_songs.map(_toMediaItem).toList());
    playbackState.add(playbackState.value.copyWith(queueIndex: _index));
  }

  Future<void> _playIndex(int index) async {
    _watchtime?.cancel();
    if (index < 0 || index >= _songs.length) {
      await stop();
      return;
    }
    _index = index;
    final song = _songs[index];
    mediaItem.add(_toMediaItem(song));

    // A downloaded track never touches the network — not to resolve it, not to
    // report it. That is the whole promise of a download.
    AudioStream? stream;
    if (_downloads.has(song.videoId)) {
      await _player.setFilePath(_downloads.fileFor(song.videoId).path);
    } else {
      stream = await _innertube.resolveStream(song.videoId);

      // Routed through the proxy so the request carries a Range header, which
      // googlevideo requires and ExoPlayer omits on its first request. The user
      // agent travels along because the URL was issued to one particular client
      // and is fetched wearing that same identity.
      await _proxy.start();
      final source = _proxy.wrap(stream.url, userAgent: stream.userAgent);

      if (_settings.cacheEnabled) {
        // The same bytes are written to disk as they play, so hearing a track
        // twice costs one download. Keyed by video id rather than by URL: the
        // URL is signed and different every time, the track is not.
        // just_audio marks this experimental; it has been in every release for
        // years and there is no other way to cache while streaming.
        // ignore: experimental_member_use
        await _player.setAudioSource(LockCachingAudioSource(
          source,
          cacheFile: _cache.fileFor(song.videoId),
        ));
        unawaited(_cache.prune(_settings.cacheLimitMb * 1024 * 1024));
      } else {
        await _player.setUrl(source.toString());
      }
    }

    // The player knows the real duration once the stream is open; the search
    // listing's value is only an estimate.
    final actual = _player.duration;
    if (actual != null) {
      mediaItem.add(_toMediaItem(song).copyWith(duration: actual));
    }

    // Deliberately not awaited: just_audio's play() completes when playback
    // *stops*, not when it starts, so waiting on it would hold everything below
    // — and the caller — until the track ended.
    unawaited(_player.play());

    // Recorded once the stream is open rather than on tap, so a track that
    // never resolved does not appear in a history of things that played. The
    // account is told too — and confirmed a while later, once enough of the
    // track has been heard to call it a listen.
    unawaited(_history.record(song));
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
  }

  /// The browsing tree a car stereo asks for.
  ///
  /// Android Auto talks to the same media session the phone uses, but it can
  /// only show what this answers with — and it will not fetch anything: a car
  /// gets what is already on the device, which is downloads and what has been
  /// played, plus the liked songs the account already handed over.
  static const _rootId = 'root';
  static const _downloadsId = 'downloads';
  static const _historyId = 'history';

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    switch (parentMediaId) {
      case _rootId:
        return [
          MediaItem(
            id: _downloadsId,
            title: _browseLabels.downloads,
            playable: false,
          ),
          MediaItem(
            id: _historyId,
            title: _browseLabels.history,
            playable: false,
          ),
        ];
      case _downloadsId:
        return _downloads.songs.map(_toMediaItem).toList();
      case _historyId:
        return _history.songs.take(50).map(_toMediaItem).toList();
      default:
        return const [];
    }
  }

  /// Playing something the car chose means making it the queue, since a car has
  /// no way to say "this and then those".
  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final source = [..._downloads.songs, ..._history.songs];
    final index = source.indexWhere((song) => song.videoId == mediaId);
    if (index < 0) return;
    await setQueue(source, startIndex: index);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_index + 1 < _songs.length) {
      await _playIndex(_index + 1);
      return;
    }
    if (_repeat == AudioServiceRepeatMode.all && _songs.isNotEmpty) {
      await _playIndex(0);
      return;
    }
    // Nothing queued and nothing to repeat: rather than fall silent, ask
    // YouTube what goes with this and keep going. Silence at the end of a
    // queue is a playlist's behaviour, not a radio's.
    if (await _extendWithRadio()) await _playIndex(_index + 1);
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
    final stream = await _innertube.resolveStream(song.videoId);
    await _proxy.start();
    await _downloads.add(
      song,
      _proxy.wrap(stream.url, userAgent: stream.userAgent),
      userAgent: stream.userAgent,
    );
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
    if (_index > 0) await _playIndex(_index - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) => _playIndex(index);

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
