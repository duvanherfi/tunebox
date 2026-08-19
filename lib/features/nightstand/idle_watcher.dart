import 'dart:async';

import 'package:flutter/material.dart';

/// Calls [onIdle] when [seconds] pass without a touch anywhere inside it.
///
/// It takes its conditions as plain values instead of reading the settings and
/// the player itself. That keeps the rule — this long untouched, and a touch
/// starts the count again — separable from where the two answers come from,
/// and testable without a device.
class IdleWatcher extends StatefulWidget {
  const IdleWatcher({
    super.key,
    required this.seconds,
    required this.enabled,
    required this.onIdle,
    required this.child,
  });

  /// How long untouched before [onIdle]. Zero means never.
  final int seconds;

  /// Whether the count runs at all.
  final bool enabled;

  final VoidCallback onIdle;
  final Widget child;

  @override
  State<IdleWatcher> createState() => _IdleWatcherState();
}

class _IdleWatcherState extends State<IdleWatcher> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  /// Rearmed when the terms change: a track that starts or a delay that is
  /// turned on has to take effect without the listener touching anything.
  @override
  void didUpdateWidget(IdleWatcher old) {
    super.didUpdateWidget(old);
    if (old.seconds != widget.seconds || old.enabled != widget.enabled) _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    if (!widget.enabled || widget.seconds <= 0) return;
    _timer = Timer(Duration(seconds: widget.seconds), widget.onIdle);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Translucent, not opaque: everything under this still has to be
      // pressable. The watcher only wants to know that a finger arrived.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _arm(),
      child: widget.child,
    );
  }
}
