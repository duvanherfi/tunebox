import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/models/song.dart';

/// The picture half of playback: one libmpv player that shows a video track
/// with its audio track hung off the side.
///
/// Separate from [PlayerService]'s `just_audio` player rather than a
/// replacement for it. The two engines are good at different things — the
/// audio one carries the equalizer, the stream cache and the fades, none of
/// which exist here — so only one of them sounds at a time and the service
/// decides which.
///
/// Built lazily and torn down when the picture is put away. libmpv is a real
/// decoder with real memory behind it, and most listening never asks for a
/// video at all; paying for it at launch would tax every session for a feature
/// used in few of them.
class VideoPlayback {
  Player? _player;
  VideoController? _controller;

  /// The surface the `Video` widget draws, or null while nothing is open.
  VideoController? get controller => _controller;

  /// Whether a video is loaded right now. This is what tells the service which
  /// engine it should be publishing state from.
  bool get isOpen => _player != null;

  final _stateChanges = StreamController<void>.broadcast();
  final _completions = StreamController<void>.broadcast();

  /// Fires whenever anything the media session publishes has moved: position,
  /// play/pause, buffering. One stream rather than several because every
  /// listener does the same thing with it — republish the whole state.
  Stream<void> get stateChanges => _stateChanges.stream;

  /// Fires when the track being shown runs out. The queue lives in the
  /// service, not here, so what happens next is its decision — exactly as it
  /// is for the audio engine.
  Stream<void> get completions => _completions.stream;

  Duration get position => _player?.state.position ?? Duration.zero;
  Duration? get duration {
    final value = _player?.state.duration;
    // mpv answers zero until it has read the header, and a zero length drawn
    // on a progress bar is worse than no length at all.
    return value == null || value == Duration.zero ? null : value;
  }

  Duration get buffered => _player?.state.buffer ?? Duration.zero;
  bool get playing => _player?.state.playing ?? false;
  bool get buffering => _player?.state.buffering ?? false;
  bool get completed => _player?.state.completed ?? false;

  final _subscriptions = <StreamSubscription<void>>[];

  /// Opens [video] with [audio] alongside it, starting at [from].
  ///
  /// The two arrive as separate streams because YouTube serves no muxed format
  /// for music any more — see `docs/streaming-findings.md`. mpv takes the
  /// picture as the medium and the sound as an external track, and keeps them
  /// in step itself, seeks included.
  ///
  /// The user agent travels with both: the URLs were issued to one client and
  /// googlevideo can hold them to it.
  Future<void> open({
    required VideoStream video,
    required AudioStream audio,
    Duration from = Duration.zero,
    bool play = true,
  }) async {
    final player = _player ??= Player();
    // Left at its defaults on purpose. media_kit already detects an emulator
    // and drops to software rendering by itself — it says so in the log — so
    // forcing CPU rendering here buys nothing there and costs real devices the
    // GPU path they do have.
    _controller ??= VideoController(player);

    if (_subscriptions.isEmpty) {
      for (final stream in <Stream<Object?>>[
        player.stream.position,
        player.stream.playing,
        player.stream.buffering,
        player.stream.duration,
      ]) {
        _subscriptions.add(stream.listen((_) {
          if (!_stateChanges.isClosed) _stateChanges.add(null);
        }));
      }
      _subscriptions.add(player.stream.completed.listen((done) {
        if (done && !_completions.isClosed) _completions.add(null);
      }));
    }

    await player.open(
      Media(
        video.url,
        httpHeaders: {
          if (video.userAgent.isNotEmpty) 'User-Agent': video.userAgent,
        },
        start: from > Duration.zero ? from : null,
      ),
      play: play,
    );
    // After the medium, never before: mpv attaches an external track to what is
    // already loaded, and one added to nothing is dropped when the next file
    // opens.
    await player.setAudioTrack(AudioTrack.uri(audio.url));
  }

  Future<void> play() async => _player?.play();
  Future<void> pause() async => _player?.pause();
  Future<void> seek(Duration position) async => _player?.seek(position);

  /// Puts the picture away and gives libmpv's memory back.
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    _controller = null;
    await player?.dispose();
    if (!_stateChanges.isClosed) _stateChanges.add(null);
  }

  Future<void> dispose() async {
    await close();
    unawaited(_stateChanges.close());
    unawaited(_completions.close());
  }
}
