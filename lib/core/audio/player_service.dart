import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/models/song.dart';
import '../../data/play_history.dart';
import '../innertube/innertube_client.dart';
import 'stream_proxy.dart';

/// Bridges the queue of [Song]s to the platform's native player and media
/// notification.
///
/// The queue holds tracks, not URLs, and each stream is resolved at the moment
/// it starts playing. That is deliberate: YouTube's audio URLs are signed and
/// expire within minutes, so a queue of pre-resolved URLs would rot while the
/// user listened to the first track.
class PlayerService extends BaseAudioHandler with SeekHandler {
  PlayerService(this._innertube, this._history) {
    _wirePlayerStreams();
  }

  final InnertubeClient _innertube;
  final PlayHistory _history;
  final _player = AudioPlayer();
  final _proxy = StreamProxy();

  List<Song> _songs = const [];
  int _index = 0;

  /// Pending confirmation that the current track was really listened to.
  /// Cancelled whenever the track changes, so skipping past something never
  /// writes it into the account's history.
  Timer? _watchtime;

  Song? get currentSong =>
      _index >= 0 && _index < _songs.length ? _songs[_index] : null;

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
      if (state == ProcessingState.completed) skipToNext();
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
    );
  }

  MediaItem _toMediaItem(Song song) => MediaItem(
        id: song.videoId,
        title: song.title,
        artist: song.subtitle.isEmpty ? 'YouTube Music' : song.subtitle,
        duration: song.duration,
        artUri: song.highResThumbnailUrl == null
            ? null
            : Uri.parse(song.highResThumbnailUrl!),
      );

  /// Replaces the queue and starts playing at [startIndex].
  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    _songs = List.unmodifiable(songs);
    queue.add(_songs.map(_toMediaItem).toList());
    await _playIndex(startIndex);
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

    final stream = await _innertube.resolveStream(song.videoId);

    // Routed through the proxy so the request carries a Range header, which
    // googlevideo requires and ExoPlayer omits on its first request. The user
    // agent travels along because the URL was issued to one particular client
    // and is fetched wearing that same identity.
    await _proxy.start();
    await _player.setUrl(
      _proxy.wrap(stream.url, userAgent: stream.userAgent).toString(),
    );

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
    unawaited(_innertube.reportPlayback(stream));
    _watchtime = Timer(
      const Duration(seconds: 30),
      () => unawaited(_innertube.reportWatchtime(stream, _player.position)),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_index + 1 < _songs.length) await _playIndex(_index + 1);
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
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }
}
