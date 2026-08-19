import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/features/nightstand/idle_watcher.dart';

/// The watcher takes its two conditions as plain values rather than reading
/// settings and the player itself. That is what makes the rule — N seconds
/// untouched, and a touch starts the count again — checkable without a device.
void main() {
  Future<int Function()> pump(
    WidgetTester tester, {
    required int seconds,
    required bool enabled,
  }) async {
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: IdleWatcher(
          seconds: seconds,
          enabled: enabled,
          onIdle: () => fired++,
          child: const ColoredBox(
            color: Colors.black,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    return () => fired;
  }

  testWidgets('comes up once the time passes untouched', (tester) async {
    final fired = await pump(tester, seconds: 2, enabled: true);

    await tester.pump(const Duration(seconds: 1));
    expect(fired(), 0);

    await tester.pump(const Duration(seconds: 2));
    expect(fired(), 1);
  });

  testWidgets('a touch starts the count again', (tester) async {
    final fired = await pump(tester, seconds: 2, enabled: true);

    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(200, 300));

    // Would have fired here if the touch had not put it off.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(fired(), 0);

    await tester.pump(const Duration(seconds: 1));
    expect(fired(), 1);
  });

  testWidgets('never with nothing playing', (tester) async {
    final fired = await pump(tester, seconds: 1, enabled: false);

    await tester.pump(const Duration(seconds: 5));
    expect(fired(), 0);
  });

  testWidgets('never when the delay is off', (tester) async {
    final fired = await pump(tester, seconds: 0, enabled: true);

    await tester.pump(const Duration(seconds: 5));
    expect(fired(), 0);
  });
}
