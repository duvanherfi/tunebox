import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import 'nightstand.dart';

/// Whether a battery event is the one that means "put the phone down for the
/// night". Pure, because the three conditions are the whole feature and the
/// plugin around them is not worth standing in for.
bool shouldEnterOnCharge({
  required BatteryState state,
  required bool enabled,
  required bool playing,
}) {
  if (!enabled || !playing) return false;
  return state == BatteryState.charging || state == BatteryState.full;
}

/// Brings the nightstand up when the phone is plugged in with music playing.
///
/// It holds the navigator key rather than a [BuildContext] because it is not
/// part of any widget: it outlives every screen and has to be able to push
/// from a stream callback.
class ChargeWatcher {
  ChargeWatcher({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  StreamSubscription<BatteryState>? _states;

  void start() {
    // The only two platforms where the question means anything: a laptop on
    // mains is not a phone on a nightstand.
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _states = Battery().onBatteryStateChanged.listen(_onState);
  }

  Future<void> dispose() async {
    await _states?.cancel();
    _states = null;
  }

  void _onState(BatteryState state) {
    if (nightstandIsOpen) return;
    if (!shouldEnterOnCharge(
      state: state,
      enabled: settings.nightstandOnCharge,
      playing: playerService.playbackState.value.playing,
    )) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;
    unawaited(openNightstand(context));
  }
}
