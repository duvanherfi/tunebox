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

  /// Watches playback and pushes every change to the launcher.
  void listen(AudioHandler handler) {
    handler.mediaItem.listen((item) => _publish(item, handler.playbackState.value));
    handler.playbackState.listen((state) => _publish(handler.mediaItem.value, state));
  }

  Future<void> _publish(MediaItem? item, PlaybackState state) async {
    try {
      await HomeWidget.saveWidgetData('title', item?.title);
      await HomeWidget.saveWidgetData('artist', item?.artist ?? '');
      await HomeWidget.saveWidgetData('playing', state.playing);
      await HomeWidget.saveWidgetData('art', await _art(item));
      await HomeWidget.updateWidget(name: _provider, androidName: _provider);
    } catch (_) {
      // A widget nobody has placed still gets these calls; failing to draw one
      // is never a reason to disturb playback.
    }
  }

  /// Downloads the cover to a file the widget can read directly.
  ///
  /// A widget lives in the launcher's process and cannot reach the app's
  /// private storage or the network, so the bitmap has to be waiting on disk
  /// before the launcher asks for it.
  Future<String?> _art(MediaItem? item) async {
    final url = item?.artUri?.toString();
    if (url == null) return null;
    if (_artFor == item!.id && _artPath != null) return _artPath;

    try {
      final response = await _http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/widget-art.png');
      await file.writeAsBytes(response.bodyBytes);

      _artFor = item.id;
      _artPath = file.path;
      return _artPath;
    } catch (_) {
      return null;
    }
  }
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
