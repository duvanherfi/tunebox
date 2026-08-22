import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Keeps the home screen widget showing what is playing.
///
/// The widget's buttons do not come back through here — they broadcast media
/// keys straight to the playback service, so they work with the app closed.
/// This is the other direction only: title, artist, cover and whether the music
/// is running.
class HomeWidgetBridge {
  HomeWidgetBridge({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _provider = 'TuneboxWidget';

  final http.Client _http;

  /// The cover already on disk, and which track it belongs to. A launcher
  /// redraws its widgets often; downloading the same image each time would be
  /// a request per redraw.
  String? _artFor;
  String? _artPath;

  /// What the launcher is already showing, and what it has been asked to show
  /// next. Only the newest request is kept: the widget draws a situation, not a
  /// history, so a request overtaken by another has nothing left to say.
  _Wanted? _shown;
  _Wanted? _wanted;
  bool _publishing = false;

  /// Watches playback and pushes every change to the launcher.
  ///
  /// Both subjects speak far more often than they say anything new — a track
  /// change, a run of skips or a drag along the seek bar each republish the
  /// state many times over — and every publish is five platform round trips
  /// ending in an `APPWIDGET_UPDATE` broadcast that comes back into this app's
  /// own main thread. Sent one per event they arrive as hundreds at once and
  /// the main thread stops answering input, which is an ANR. So the events are
  /// filtered down to the four things the widget actually draws, and publishes
  /// are run one at a time: while one is in flight the rest collapse into a
  /// single pending request, which also bounds the rate without a timer.
  void listen(AudioHandler handler) {
    handler.mediaItem.listen((item) => _want(item, handler.playbackState.value));
    handler.playbackState.listen((state) => _want(handler.mediaItem.value, state));
  }

  void _want(MediaItem? item, PlaybackState state) {
    final wanted = _Wanted(
      id: item?.id,
      title: item?.title,
      artist: item?.artist ?? '',
      artUrl: item?.artUri?.toString(),
      playing: state.playing,
    );
    if (wanted == _shown && _wanted == null) return;
    _wanted = wanted;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_publishing) return;
    _publishing = true;
    try {
      while (_wanted != null) {
        final wanted = _wanted!;
        _wanted = null;
        if (wanted == _shown) continue;
        if (await _publish(wanted)) _shown = wanted;
      }
    } finally {
      _publishing = false;
    }
  }

  /// False when the launcher could not be written to, so the next event tries
  /// again rather than being suppressed as already shown.
  Future<bool> _publish(_Wanted wanted) async {
    try {
      await HomeWidget.saveWidgetData('title', wanted.title);
      await HomeWidget.saveWidgetData('artist', wanted.artist);
      await HomeWidget.saveWidgetData('playing', wanted.playing);
      await HomeWidget.saveWidgetData('art', await _art(wanted));
      await HomeWidget.updateWidget(name: _provider, androidName: _provider);
      return true;
    } catch (_) {
      // A widget nobody has placed still gets these calls; failing to draw one
      // is never a reason to disturb playback.
      return false;
    }
  }

  /// Downloads the cover to a file the widget can read directly.
  ///
  /// A widget lives in the launcher's process and cannot reach the app's
  /// private storage or the network, so the bitmap has to be waiting on disk
  /// before the launcher asks for it.
  Future<String?> _art(_Wanted wanted) async {
    final url = wanted.artUrl;
    if (url == null) return null;
    if (_artFor == wanted.id && _artPath != null) return _artPath;

    try {
      final response = await _http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/widget-art.png');
      await file.writeAsBytes(response.bodyBytes);

      _artFor = wanted.id;
      _artPath = file.path;
      return _artPath;
    } catch (_) {
      return null;
    }
  }
}

/// The four things the widget draws, plus the track they belong to.
///
/// The comparison is what turns a stream of playback events into the handful
/// that change anything on a launcher: everything else the player publishes —
/// position, buffered position, processing state, queue index — is invisible
/// here, and republishing for it costs a round trip and a broadcast for a
/// widget that would come out identical.
class _Wanted {
  const _Wanted({
    required this.id,
    required this.title,
    required this.artist,
    required this.artUrl,
    required this.playing,
  });

  final String? id;
  final String? title;
  final String artist;
  final String? artUrl;
  final bool playing;

  @override
  bool operator ==(Object other) =>
      other is _Wanted &&
      other.id == id &&
      other.title == title &&
      other.artist == artist &&
      other.artUrl == artUrl &&
      other.playing == playing;

  @override
  int get hashCode => Object.hash(id, title, artist, artUrl, playing);
}

/// Asks the launcher to place the widget on the home screen.
///
/// The alternative is telling someone to long-press their wallpaper and hunt
/// through a picker; every launcher since Android 8 can be asked directly, and
/// the ones that cannot simply answer no.
Future<bool> requestWidgetOnHomeScreen() async {
  const channel = MethodChannel('com.tunebox.tunebox/widget');
  try {
    return await channel.invokeMethod<bool>('pin') ?? false;
  } catch (_) {
    return false;
  }
}
