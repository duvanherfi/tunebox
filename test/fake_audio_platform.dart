import 'dart:async';

import 'package:flutter/services.dart';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// A [JustAudioPlatform] that decodes nothing.
///
/// It exists so the queue logic in `PlayerService` — which track follows which,
/// and what the media session is told about it — can be tested without a
/// device. Nothing here plays audio; the fake simply answers the calls
/// just_audio would make and lets a test say "and now the track ended".
class FakeJustAudio extends JustAudioPlatform {
  final players = <String, FakeAudioPlayer>{};

  /// How many loads every player of this platform refuses before accepting
  /// one, as a real player refuses a container it cannot decode. Set before
  /// anything plays: the app builds its player lazily on the first track, and
  /// the audio it is handed is a proxy URL that says nothing about the format.
  int rejectLoads = 0;

  /// The player the app is using, once it has created one.
  FakeAudioPlayer get player => players.values.single;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      players[request.id] = FakeAudioPlayer(request.id)
        ..rejectLoads = rejectLoads;

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    players.remove(request.id);
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

class FakeAudioPlayer extends AudioPlayerPlatform {
  FakeAudioPlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();

  /// Every URI the player was asked to load, in order. The test's window onto
  /// which track the queue actually reached for.
  final loaded = <String>[];

  /// Loads still to be refused before one is accepted.
  int rejectLoads = 0;

  Duration duration = const Duration(minutes: 3);
  Duration position = Duration.zero;
  bool playing = false;
  ProcessingStateMessage state = ProcessingStateMessage.idle;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  void _emit() {
    if (_events.isClosed) return;
    _events.add(PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: position,
      duration: duration,
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ));
  }

  /// Pretends the loaded track ran all the way to its end, which is the moment
  /// the queue has to decide what plays next.
  void reachTheEnd() {
    position = duration;
    state = ProcessingStateMessage.completed;
    _emit();
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final source = request.audioSourceMessage;
    final uri = source is UriAudioSourceMessage ? source.uri : source.id;
    loaded.add(uri);
    if (rejectLoads > 0) {
      rejectLoads--;
      throw PlatformException(code: 'abort', message: 'Cannot Open');
    }
    position = request.initialPosition ?? Duration.zero;
    state = ProcessingStateMessage.ready;
    _emit();
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playing = true;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    playing = false;
    position += const Duration(seconds: 1);
    _emit();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    position = request.position ?? Duration.zero;
    _emit();
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async =>
      SetShuffleOrderResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async =>
      SetAndroidAudioAttributesResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async =>
          SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async =>
      SetAllowsExternalPlaybackResponse();

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async =>
      SetPreferredPeakBitRateResponse();

  @override
  Future<AudioEffectSetEnabledResponse> audioEffectSetEnabled(
    AudioEffectSetEnabledRequest request,
  ) async =>
      AudioEffectSetEnabledResponse();

  @override
  Future<AndroidLoudnessEnhancerSetTargetGainResponse>
      androidLoudnessEnhancerSetTargetGain(
    AndroidLoudnessEnhancerSetTargetGainRequest request,
  ) async =>
          AndroidLoudnessEnhancerSetTargetGainResponse();

  @override
  Future<AndroidEqualizerGetParametersResponse> androidEqualizerGetParameters(
    AndroidEqualizerGetParametersRequest request,
  ) async =>
      AndroidEqualizerGetParametersResponse(
        parameters: AndroidEqualizerParametersMessage(
          minDecibels: -15,
          maxDecibels: 15,
          bands: const [],
        ),
      );

  @override
  Future<AndroidEqualizerBandSetGainResponse> androidEqualizerBandSetGain(
    AndroidEqualizerBandSetGainRequest request,
  ) async =>
      AndroidEqualizerBandSetGainResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    unawaited(_events.close());
    return DisposeResponse();
  }
}
