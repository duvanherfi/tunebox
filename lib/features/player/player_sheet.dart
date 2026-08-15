import 'dart:ui' show lerpDouble;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../main.dart';
import 'full_player.dart';
import 'mini_player.dart';

/// The player, as one widget with two sizes rather than two screens.
///
/// It sits at the bottom as a bar and grows to fill the screen as you drag it
/// up, following the finger the whole way. That continuity is the point: an
/// earlier version pushed a separate route, which meant dragging down was
/// really a back gesture — the bar vanished and reappeared instead of the panel
/// shrinking back into it.
///
/// A single value from 0 to 1 drives everything: height, corner radius, and
/// which of the two layouts is visible. The collapsed bar fades out quickly so
/// it is gone well before the full player arrives, and the full player fades in
/// only after the first quarter of the drag, which keeps the two from smearing
/// over each other mid-gesture.
class PlayerSheet extends StatefulWidget {
  const PlayerSheet({super.key, required this.bottomInset});

  /// Height of whatever sits below the collapsed bar, so it rests on top of
  /// the navigation rather than over it.
  final double bottomInset;

  @override
  State<PlayerSheet> createState() => PlayerSheetState();
}

class PlayerSheetState extends State<PlayerSheet>
    with SingleTickerProviderStateMixin {
  static const collapsedHeight = 76.0;
  static const _flingVelocity = 250.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isExpanded => _controller.value > 0.5;

  void expand() => _controller.animateTo(1, curve: Curves.easeOutCubic);
  void collapse() => _controller.animateTo(0, curve: Curves.easeOutCubic);

  double _travel(BuildContext context) =>
      MediaQuery.sizeOf(context).height - collapsedHeight - widget.bottomInset;

  void _onDrag(DragUpdateDetails details) {
    // Upward drag is negative dy, and up means bigger.
    _controller.value -= details.primaryDelta! / _travel(context);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_flingVelocity) {
      expand();
    } else if (velocity > _flingVelocity) {
      collapse();
    } else {
      _settle();
    }
  }

  /// Settles to whichever anchor is nearer.
  ///
  /// Also the answer to a cancelled drag: the system can withdraw a gesture
  /// instead of ending it, and without this the panel simply stops wherever
  /// the finger left it, half open and belonging to neither state.
  void _settle() => _controller.value > 0.5 ? expand() : collapse();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return StreamBuilder<MediaItem?>(
      stream: playerService.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final height =
                lerpDouble(collapsedHeight, screenHeight, t)!;
            final bottom = lerpDouble(widget.bottomInset, 0, t)!;
            final radius = lerpDouble(AppTheme.radiusCard, 0, t)!;
            final margin = lerpDouble(12, 0, t)!;

            // Fades tuned so the two layouts never overlap visibly: the bar is
            // gone by a quarter of the way up, the panel starts there.
            final barOpacity = (1 - t * 4).clamp(0.0, 1.0);
            final panelOpacity = ((t - 0.25) * 4).clamp(0.0, 1.0);

            return Positioned(
              left: margin,
              right: margin,
              bottom: bottom,
              height: height,
              child: PopScope(
                // Back collapses the panel instead of leaving the screen,
                // because at this point the panel *is* where the user is.
                canPop: !_isExpanded,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) collapse();
                },
                child: GestureDetector(
                  onTap: _isExpanded ? null : expand,
                  onVerticalDragUpdate: _onDrag,
                  onVerticalDragEnd: _onDragEnd,
                  onVerticalDragCancel: _settle,
                  child: Material(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (panelOpacity > 0)
                          Opacity(
                            opacity: panelOpacity,
                            child: FullPlayer(item: item, onCollapse: collapse),
                          ),
                        if (barOpacity > 0)
                          Opacity(
                            opacity: barOpacity,
                            child: SizedBox(
                              height: collapsedHeight,
                              child: MiniPlayerBar(item: item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
