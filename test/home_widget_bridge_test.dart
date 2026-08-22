import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/home_widget_bridge.dart';

/// The smallest handler that owns the two subjects the bridge listens to.
class _Handler extends BaseAudioHandler {}

/// Counts what actually goes over the wire to the launcher.
///
/// The widget is drawn by another process, reached through a method channel, so
/// "how often does the bridge publish" is not a private detail: it is one
/// platform round trip per call, on the thread that also draws the app.
class _Launcher {
  _Launcher({this.delay = Duration.zero});

  final Duration delay;
  final List<String> calls = [];
  final List<Map<String, Object?>> saved = [];

  /// How many publishes were running at once. Anything above one means two
  /// publishes are interleaving their writes into the same four keys.
  int inFlight = 0;
  int mostInFlight = 0;

  int get updates => calls.where((call) => call == 'updateWidget').length;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'),
            (call) async {
      calls.add(call.method);
      if (call.method == 'saveWidgetData') {
        final arguments = (call.arguments as Map).cast<String, Object?>();
        saved.add(arguments);
      }
      if (call.method == 'updateWidget') return true;

      inFlight++;
      mostInFlight = inFlight > mostInFlight ? inFlight : mostInFlight;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      inFlight--;
      return true;
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  }

  Object? lastSaved(String key) {
    for (final entry in saved.reversed) {
      if (entry['id'] == key) return entry['data'];
    }
    return null;
  }
}

PlaybackState _state({bool playing = false}) =>
    PlaybackState(playing: playing, updatePosition: Duration.zero);

MediaItem _item({String title = 'One', String artist = 'Someone'}) =>
    MediaItem(id: title, title: title, artist: artist);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Launcher launcher;
  late _Handler handler;

  setUp(() {
    handler = _Handler();
    launcher = _Launcher();
  });

  tearDown(() => launcher.remove());

  test('a burst of states that say the same thing publishes once', () async {
    launcher.install();
    HomeWidgetBridge().listen(handler);
    handler.mediaItem.add(_item());
    await pumpEventQueue();
    final settled = launcher.updates;

    // What a track change, a run of skips or a seek looks like from here: the
    // player republishes its state many times over, and every one of them
    // describes the same four things the widget draws.
    for (var i = 0; i < 40; i++) {
      handler.playbackState.add(_state(playing: true));
    }
    await pumpEventQueue();

    expect(launcher.updates - settled, lessThanOrEqualTo(1),
        reason: 'each publish is five platform round trips and a broadcast '
            'back into the main thread; forty of them is the ANR');
  });

  test('publishes never overlap', () async {
    launcher = _Launcher(delay: const Duration(milliseconds: 5));
    launcher.install();
    HomeWidgetBridge().listen(handler);

    for (var i = 0; i < 20; i++) {
      handler.mediaItem.add(_item(title: 'Track $i'));
      handler.playbackState.add(_state(playing: i.isEven));
    }
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(launcher.mostInFlight, 1,
        reason: 'two publishes in flight write the same four keys in an '
            'order nobody controls, and each fetches the cover again');
  });

  test('the launcher ends up showing the last thing that happened', () async {
    launcher = _Launcher(delay: const Duration(milliseconds: 5));
    launcher.install();
    HomeWidgetBridge().listen(handler);

    for (var i = 0; i < 20; i++) {
      handler.mediaItem.add(_item(title: 'Track $i'));
    }
    handler.playbackState.add(_state(playing: true));
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(launcher.lastSaved('title'), 'Track 19');
    expect(launcher.lastSaved('playing'), true);
  });

  test('a real change still reaches the launcher', () async {
    launcher.install();
    HomeWidgetBridge().listen(handler);

    handler.mediaItem.add(_item(title: 'One'));
    await pumpEventQueue();
    handler.playbackState.add(_state(playing: true));
    await pumpEventQueue();
    handler.mediaItem.add(_item(title: 'Two'));
    await pumpEventQueue();

    expect(launcher.lastSaved('title'), 'Two');
    expect(launcher.updates, greaterThanOrEqualTo(2),
        reason: 'coalescing must not turn into never publishing');
  });
}
