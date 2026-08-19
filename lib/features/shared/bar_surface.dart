import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';

/// Blurs whatever is behind a bar, when the chosen background asks for it.
///
/// Only [BarBackground.glass] pays for a `BackdropFilter`: it is the one thing
/// that makes a see-through bar readable over a bright cover, and it is also
/// the most expensive thing on a screen that is never not there. Every other
/// choice gets the plain child, so nobody pays for a filter they did not ask
/// for.
class BarSurface extends StatelessWidget {
  const BarSurface({
    super.key,
    required this.background,
    required this.radius,
    required this.child,
  });

  final BarBackground background;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!background.blurs) return child;

    // Clipped to the bar's own shape: an unclipped filter blurs the whole
    // layer, corners included, and the rounded edge comes out smeared.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: child,
      ),
    );
  }
}
