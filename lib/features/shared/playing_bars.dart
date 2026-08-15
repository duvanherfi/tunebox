import 'dart:math';

import 'package:flutter/material.dart';

/// Three bars that rise and fall, drawn beside whichever row is playing.
///
/// A list needs to say which of its rows is the one you are hearing, and a
/// static icon says "this is a song" — every row is a song. Movement is the
/// only mark that reads instantly at a glance, and it stops when the music
/// does, so the list also shows that playback is paused.
class PlayingBars extends StatefulWidget {
  const PlayingBars({super.key, required this.playing, this.size = 16});

  final bool playing;
  final double size;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(PlayingBars old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Offset phases so the three never move as one block, which would
            // read as a single flashing shape rather than as levels.
            for (final phase in const [0.0, 0.33, 0.66])
              _Bar(
                color: color,
                width: widget.size / 5,
                height: widget.playing
                    ? widget.size *
                        (0.35 + 0.65 * _level(_controller.value + phase))
                    : widget.size * 0.4,
              ),
          ],
        ),
      ),
    );
  }

  static double _level(double t) => (sin(t % 1 * 2 * pi) + 1) / 2;
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.color,
    required this.width,
    required this.height,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width),
      ),
    );
  }
}
