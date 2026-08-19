import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../main.dart';
import 'nightstand_screen.dart';

/// The four places the content sits, one step per cycle. Eight pixels is
/// enough to move a pixel off a lit neighbour and small enough that nobody
/// watching notices the screen crawling.
const _driftSteps = <Offset>[
  Offset(-8, -8),
  Offset(8, -8),
  Offset(8, 8),
  Offset(-8, 8),
];

/// Where the nightstand's content sits at [tick]. Pure so it can be checked
/// without a screen; Dart's modulo is never negative for a positive divisor,
/// so a tick that ever went backwards would still land inside the list.
Offset nightstandDrift(int tick) => _driftSteps[tick % _driftSteps.length];

bool _open = false;

/// Whether the nightstand is already up. Read by the watchers: with three ways
/// in, two of them can fire on the same second.
bool get nightstandIsOpen => _open;

/// The only way in.
///
/// It owns the three side effects — the wakelock, the immersive bars and the
/// brightness — and undoes them in a `finally` rather than in the screen's
/// `dispose`. The push completes however the route ends: our own chevron, the
/// back gesture, a pop from somewhere else. The `finally` also covers the case
/// where it never opened at all.
Future<void> openNightstand(BuildContext context) async {
  if (_open) return;
  _open = true;

  final navigator = Navigator.of(context, rootNavigator: true);

  try {
    // Unconditional, unlike the full player's: keeping the screen on is a
    // preference there and the entire point of the mode here.
    await WakelockPlus.enable();
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    await _setBrightness(settings.nightstandDim / 100);

    await navigator.push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => const NightstandScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  } finally {
    await _restoreBrightness();
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    // Back to whatever the player asked for: this returns to the expanded
    // player, which holds the lock itself when the listener wants it.
    if (!settings.keepAwake) await WakelockPlus.disable();
    _open = false;
  }
}

/// A platform that cannot dim is not a reason to refuse the screen — macOS and
/// the emulator both answer some of these with a failure.
Future<void> _setBrightness(double value) async {
  try {
    await ScreenBrightness.instance.setApplicationScreenBrightness(value);
  } on Exception {
    // Nothing to do about it, and nothing worth telling the listener.
  }
}

Future<void> _restoreBrightness() async {
  try {
    await ScreenBrightness.instance.resetApplicationScreenBrightness();
  } on Exception {
    // Same.
  }
}
