import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/features/nightstand/charge_watcher.dart';

/// The plugin is not worth mocking; the rule it feeds is. Three conditions,
/// and the one that is easy to get wrong is that unplugging is a battery event
/// too.
void main() {
  test('plugged in, playing, and asked for', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.charging,
        enabled: true,
        playing: true,
      ),
      isTrue,
    );
  });

  test('a full battery still counts as plugged in', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.full,
        enabled: true,
        playing: true,
      ),
      isTrue,
    );
  });

  test('unplugging is an event too, and not one that opens anything', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.discharging,
        enabled: true,
        playing: true,
      ),
      isFalse,
    );
  });

  test('silence on the charger is just a phone on a charger', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.charging,
        enabled: true,
        playing: false,
      ),
      isFalse,
    );
  });

  test('off is off', () {
    expect(
      shouldEnterOnCharge(
        state: BatteryState.charging,
        enabled: false,
        playing: true,
      ),
      isFalse,
    );
  });
}
