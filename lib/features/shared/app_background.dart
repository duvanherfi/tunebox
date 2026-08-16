import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';
import '../../main.dart';

/// The colour wash behind the whole app.
///
/// Painted once, behind every route, so it does not slide with the page during
/// a transition. When no wash is chosen this is nothing at all — the flat
/// surface Material expects, which is what reads best behind dense lists.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        if (themeController.gradient == AppGradient.none) return child;

        final colors = Theme.of(context).colorScheme;

        // Fewer than two colours is not a gradient, so the scheme supplies the
        // ends: the surface it would have been, and a tint of the seed.
        final chosen = themeController.gradientColours;
        final stops = chosen.length >= 2
            ? [for (final value in chosen) Color(value)]
            : [
                colors.surface,
                Color.alphaBlend(
                  colors.primary.withValues(alpha: 0.35),
                  colors.surface,
                ),
              ];

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: switch (themeController.gradient) {
              AppGradient.radial => RadialGradient(
                  colors: stops.reversed.toList(),
                  radius: 1.1,
                  center: Alignment.topCenter,
                ),
              AppGradient.custom => LinearGradient(
                  colors: stops,
                  // The angle arrives in turns; a gradient wants a pair of
                  // points, so it is walked around the unit circle.
                  begin: _alignmentAt(themeController.gradientAngle),
                  end: _alignmentAt(themeController.gradientAngle + 0.5),
                ),
              _ => LinearGradient(
                  colors: stops,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
            },
          ),
          // The app's own surfaces are transparent over this, which is what
          // makes the wash visible at all.
          child: Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor: Colors.transparent,
              canvasColor: Colors.transparent,
            ),
            child: child,
          ),
        );
      },
    );
  }

  static Alignment _alignmentAt(double turns) {
    final radians = turns * 2 * math.pi;
    return Alignment(math.sin(radians), -math.cos(radians));
  }
}
