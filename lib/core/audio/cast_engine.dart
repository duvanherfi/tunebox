import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

/// What the receiver is doing, read straight off the protocol.
enum CastPlayerState { idle, loading, buffering, playing, paused }

/// The Cast receiver as a playback engine: the third one beside `just_audio`
/// and libmpv, driven the same way by [PlayerService].
///
/// Built on `flutter_chrome_cast` for discovery, sessions and commands, with
/// two of its parts deliberately bypassed — both measured on a real Nest Mini:
///
/// * **Status.** The plugin turns every receiver status into typed objects and
///   drops the update when any field fails to parse; the probe's view sat on
///   `loading` while the native callbacks were reporting `PLAYING`. The status
///   channel is taken over here and only the four fields playback needs are
///   read, each of them tolerantly.
/// * **Metadata.** The plugin's music metadata sends `title`/`artist` under
///   keys Android does not recognise, and a null `releaseDate` crashes the
///   native side converting it to `Long`. [_TrackMetadata] sends the SDK's own
///   keys and nothing nullable.
class CastEngine {
  CastEngine._();

  static final instance = CastEngine._();

  /// The registered Custom Web Receiver (`cast_receiver/`). Overridable at
  /// build time; `CC1AD845` is Google's Default Media Receiver, which needs no
  /// registration and plays the same audio.
  static const appId = String.fromEnvironment(
    'CAST_RECEIVER_APP_ID',
    defaultValue: 'D2CA181C',
  );

  /// Android only for now: the iOS half of the plugin is untested here and the
  /// iOS build is not distributed yet.
  static bool get supported => Platform.isAndroid;

  static const _statusChannel =
      MethodChannel('com.felnanuke.google_cast.remote_media_client');

  bool _ready = false;

  /// The device a session is open with, or null. Drives the button.
  final device = ValueNotifier<GoogleCastDevice?>(null);

  /// True between asking to connect and the session answering.
  final connecting = ValueNotifier<bool>(false);

  bool get connected => device.value != null;

  CastPlayerState state = CastPlayerState.idle;
  Duration position = Duration.zero;
  Duration? duration;

  /// When [position] was last reported, so it can be advanced between the
  /// receiver's half-second progress updates.
  DateTime _positionAt = DateTime.now();

  final _changes = StreamController<void>.broadcast();
  final _finished = StreamController<void>.broadcast();
  final _failed = StreamController<void>.broadcast();
  final _sessions = StreamController<bool>.broadcast();

  /// Any movement of the remote player: state, position, length.
  Stream<void> get changes => _changes.stream;

  /// The loaded track ran to its end.
  Stream<void> get finished => _finished.stream;

  /// The receiver could not play what it was given.
  Stream<void> get failed => _failed.stream;

  /// True when a session opens, false when it closes for whatever reason —
  /// including the receiver being stopped from another phone or the speaker.
  Stream<bool> get sessions => _sessions.stream;

  bool get playing =>
      state == CastPlayerState.playing || state == CastPlayerState.buffering;

  /// Extrapolated between updates, so the bar moves smoothly instead of in
  /// half-second steps.
  Duration get livePosition {
    if (state != CastPlayerState.playing) return position;
    final moved = position + DateTime.now().difference(_positionAt);
    final end = duration;
    return end != null && moved > end ? end : moved;
  }

  Future<void> init() async {
    if (_ready || !supported) return;
    _ready = true;
    await GoogleCastContext.instance.setSharedInstanceWithOptions(
      GoogleCastOptionsAndroid(appId: appId),
    );
    // Created first so its constructor's handler is the one replaced, and not
    // the one that replaces ours.
    GoogleCastRemoteMediaClient.instance;
    _statusChannel.setMethodCallHandler(_onStatus);

    GoogleCastSessionManager.instance.currentSessionStream.listen((session) {
      final state = session?.connectionState;
      connecting.value = state == GoogleCastConnectState.connecting;
      final now = state == GoogleCastConnectState.connected
          ? session?.device
          : null;
      final was = device.value;
      if (now?.deviceID == was?.deviceID) return;
      device.value = now;
      if ((now != null) != (was != null)) {
        if (now == null) {
          _reset();
          unawaited(stopDiscovery());
        }
        _sessions.add(now != null);
      }
    });
  }

  /// Where the receiver was when the session last closed, for handing the
  /// track back to the phone.
  Duration lastPosition = Duration.zero;

  void _reset() {
    lastPosition = livePosition;
    state = CastPlayerState.idle;
    position = Duration.zero;
    duration = null;
  }

  Stream<List<GoogleCastDevice>> get devices =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  Future<void> startDiscovery() =>
      GoogleCastDiscoveryManager.instance.startDiscovery();

  Future<void> stopDiscovery() =>
      GoogleCastDiscoveryManager.instance.stopDiscovery();

  Future<void> connect(GoogleCastDevice target) async {
    connecting.value = true;
    final ok =
        await GoogleCastSessionManager.instance.startSessionWithDevice(target);
    if (!ok) connecting.value = false;
  }

  /// Ends the session and stops the receiver, so the speaker falls silent
  /// rather than finishing the track on its own.
  Future<void> disconnect() =>
      GoogleCastSessionManager.instance.endSessionAndStopCasting();

  Future<void> load({
    required Uri url,
    required String contentType,
    required String title,
    String? artist,
    String? album,
    Uri? artwork,
    Duration from = Duration.zero,
    bool autoplay = true,
  }) async {
    state = CastPlayerState.loading;
    position = from;
    _positionAt = DateTime.now();
    duration = null;
    _changes.add(null);
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      GoogleCastMediaInformation(
        contentId: url.toString(),
        contentUrl: url,
        contentType: contentType,
        streamType: CastMediaStreamType.buffered,
        metadata: _TrackMetadata(
          title: title,
          artist: artist,
          album: album,
          artwork: artwork,
        ),
      ),
      autoPlay: autoplay,
      playPosition: from,
    );
  }

  Future<void> play() => GoogleCastRemoteMediaClient.instance.play();

  Future<void> pause() => GoogleCastRemoteMediaClient.instance.pause();

  Future<void> seek(Duration to) {
    position = to;
    _positionAt = DateTime.now();
    _changes.add(null);
    return GoogleCastRemoteMediaClient.instance.seek(
      GoogleCastMediaSeekOption(
        position: to,
        resumeState: GoogleCastMediaResumeState.unchanged,
      ),
    );
  }

  Future<void> stop() => GoogleCastRemoteMediaClient.instance.stop();

  Future<dynamic> _onStatus(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onPlayerPositionChanged':
          final map = Map<String, dynamic>.from(call.arguments as Map);
          final progress = (map['progress'] as num?)?.toInt() ?? 0;
          final length = (map['duration'] as num?)?.toInt() ?? 0;
          // The SDK reports 0/0 while nothing is loaded; that is not a seek
          // back to the start.
          if (progress == 0 && length == 0) return;
          position = Duration(milliseconds: progress);
          _positionAt = DateTime.now();
          if (length > 0) duration = Duration(milliseconds: length);
          _changes.add(null);
        case 'onMediaStatusChanged':
          if (call.arguments == null) return;
          _applyStatus(
            Map<String, dynamic>.from(jsonDecode(call.arguments as String)),
          );
      }
    } catch (error) {
      debugPrint('Cast status ignored: $error');
    }
  }

  void _applyStatus(Map<String, dynamic> status) {
    final raw = '${status['playerState'] ?? ''}'.toUpperCase();
    final next = switch (raw) {
      'PLAYING' || '2' => CastPlayerState.playing,
      'PAUSED' || '3' => CastPlayerState.paused,
      'BUFFERING' || '4' => CastPlayerState.buffering,
      'LOADING' || '5' => CastPlayerState.loading,
      _ => CastPlayerState.idle,
    };
    final idleReason = '${status['idleReason'] ?? ''}'.toUpperCase();

    final current = status['currentTime'];
    if (current is num && next != CastPlayerState.idle) {
      position = Duration(milliseconds: (current * 1000).round());
      _positionAt = DateTime.now();
    }
    final media = status['media'];
    if (media is Map && media['duration'] is num) {
      final seconds = media['duration'] as num;
      if (seconds > 0) {
        duration = Duration(milliseconds: (seconds * 1000).round());
      }
    }

    final was = state;
    state = next;
    _changes.add(null);

    if (next == CastPlayerState.idle && was != CastPlayerState.idle) {
      if (idleReason == 'FINISHED' || idleReason == '1') {
        _finished.add(null);
      } else if (idleReason == 'ERROR' || idleReason == '4') {
        _failed.add(null);
      }
    }
  }
}

/// Music metadata under the keys the Android SDK actually reads.
class _TrackMetadata extends GoogleCastMediaMetadata {
  _TrackMetadata({
    required this.title,
    this.artist,
    this.album,
    Uri? artwork,
  }) : super(
          metadataType: GoogleCastMediaMetadataType.musicTrackMediaMetadata,
          images: artwork == null ? null : [GoogleCastImage(url: artwork)],
        );

  final String title;
  final String? artist;
  final String? album;

  static const _key = 'com.google.android.gms.cast.metadata';

  @override
  Map<String, dynamic> toMap() => {
        'metadataType': metadataType.value,
        '$_key.TITLE': title,
        if (artist != null) '$_key.ARTIST': artist,
        if (album != null) '$_key.ALBUM_TITLE': album,
        if (images != null) 'images': images!.map((x) => x.toMap()).toList(),
      };
}

/// Keeps the phone awake enough to serve while it casts.
///
/// During a session the phone plays nothing, so nothing else holds the CPU or
/// the Wi-Fi radio up: with the screen off Android lets both sleep, and the
/// receiver's next window request goes unanswered a few minutes into a track.
class CastLocks {
  static const _channel = MethodChannel('com.tunebox.tunebox/cast_locks');

  static Future<void> hold(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod(on ? 'acquire' : 'release');
    } on MissingPluginException {
      // The background engine audio_service may run without the activity.
    }
  }
}
