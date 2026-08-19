import 'dart:ui' show lerpDouble;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../main.dart';
import '../shared/bar_surface.dart';
import 'full_player.dart';
import 'mini_player.dart';
import 'swipe_to_change.dart';

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

  /// Air between the collapsed bar and the navigation under it. They are two
  /// separate things — what is playing and where you are — and a hairline
  /// between two stacked slabs reads as one badly drawn one.
  static const gap = 10.0;

  /// The same inset the navigation pill uses, so the two line up as a pair
  /// rather than as two rectangles of different widths.
  static const _sideMargin = 16.0;

  /// And the same ceiling, for the same reason.
  static const _maxCollapsedWidth = 520.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller.dispose();
    super.dispose();
  }

  bool get _isExpanded => _controller.value > 0.5;

  void expand() {
    _controller.animateTo(1, curve: Curves.easeOutCubic);
    // Held only while the player fills the screen: a phone propped up as a
    // now-playing display should not sleep, and one in a pocket should.
    if (settings.keepAwake) WakelockPlus.enable();
  }

  void collapse() {
    _controller.animateTo(0, curve: Curves.easeOutCubic);
    WakelockPlus.disable();
  }

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

        // Both: the animation moves it, and the appearance setting changes how
        // much of the app shows through it.
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, themeController]),
          builder: (context, _) {
            final t = _controller.value;
            final height = lerpDouble(collapsedHeight, screenHeight, t)!;
            final bottom = lerpDouble(widget.bottomInset + gap, 0, t)!;
            final radius = lerpDouble(AppTheme.radiusCard, 0, t)!;
            // See-through while it is a bar, solid by the time it is a screen.
            final opacity = themeController.barBackground.opacityAt(t);
            final margin = lerpDouble(_sideMargin, 0, t)!;

            // Fades tuned so the two layouts never overlap visibly: the bar is
            // gone by a quarter of the way up, the panel starts there.
            final barOpacity = (1 - t * 4).clamp(0.0, 1.0);
            final panelOpacity = ((t - 0.25) * 4).clamp(0.0, 1.0);

            // Capped like the navigation under it, so the pair stays a pair on
            // a wide screen instead of becoming a stripe across it.
            final width = MediaQuery.sizeOf(context).width;
            final capped = t < 0.5 && width - margin * 2 > _maxCollapsedWidth
                ? (width - _maxCollapsedWidth) / 2
                : margin;

            return Positioned(
              left: capped,
              right: capped,
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
                  child: BarSurface(
                    // Blurred only while it is still a bar: by the time it is a
                    // screen it is opaque, and a filter under an opaque fill is
                    // a cost with nothing to show for it.
                    background: opacity < 1
                        ? themeController.barBackground
                        : BarBackground.solid,
                    radius: radius,
                    child: Material(
                      color: colors.surfaceContainerHigh.withValues(
                        alpha: opacity,
                      ),
                      // Rounded on all four corners while it is a floating bar,
                      // squaring off as it grows into the screen.
                      borderRadius: BorderRadius.circular(radius),
                      elevation: opacity == 1 ? lerpDouble(3, 0, t)! : 0,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
                      surfaceTintColor: Colors.transparent,
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          if (panelOpacity > 0)
                            Opacity(
                              opacity: panelOpacity,
                              child: FullPlayer(
                                item: item,
                                onCollapse: collapse,
                              ),
                            ),
                          if (barOpacity > 0)
                            Opacity(
                              opacity: barOpacity,
                              child: SizedBox(
                                height: collapsedHeight,
                                // Swiping the bar changes track, the same way
                                // swiping the cover does. This is the surface
                                // that is on screen all day, so it is the one
                                // the gesture is really for.
                                child: SwipeToChangeTrack(
                                  key: ValueKey(item.id),
                                  travel: MediaQuery.sizeOf(context).width,
                                  fade: false,
                                  child: MiniPlayerBar(item: item),
                                ),
                              ),
                            ),
                        ],
                      ),
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
