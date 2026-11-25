import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/audio/cast_engine.dart';

void main() {
  final engine = CastEngine.instance;

  Future<int> heard(void Function() action) async {
    var count = 0;
    final sub = engine.changes.listen((_) => count++);
    action();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return count;
  }

  setUp(() {
    engine.state = CastPlayerState.paused;
    engine.takeProgress(const Duration(seconds: 30), const Duration(minutes: 3));
  });

  // The SDK ticks twice a second whatever the state; each tick used to
  // republish the media session, all through a paused session.
  test('a paused tick at the same second tells no one', () async {
    expect(
      await heard(() => engine.takeProgress(
          const Duration(seconds: 30), const Duration(minutes: 3))),
      0,
    );
  });

  test('a playing tick where extrapolation already was tells no one',
      () async {
    engine.state = CastPlayerState.playing;
    expect(
      await heard(() => engine.takeProgress(
          const Duration(seconds: 30, milliseconds: 400),
          const Duration(minutes: 3))),
      0,
    );
  });

  test('a jump is heard: someone sought on the receiver', () async {
    expect(
      await heard(() => engine.takeProgress(
          const Duration(seconds: 90), const Duration(minutes: 3))),
      1,
    );
    expect(engine.position, const Duration(seconds: 90));
  });

  test('a new length is heard', () async {
    expect(
      await heard(() => engine.takeProgress(
          const Duration(seconds: 30), const Duration(minutes: 4))),
      1,
    );
    expect(engine.duration, const Duration(minutes: 4));
  });
}
