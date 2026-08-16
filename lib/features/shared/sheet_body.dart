import 'package:flutter/material.dart';

/// The frame every bottom sheet in the app sits in.
///
/// Two things that only matter off a portrait phone, and matter a lot there: a
/// sheet is capped and centred rather than stretched — a menu three thousand
/// pixels wide puts its labels and its controls at opposite ends of the screen
/// — and it scrolls, because a landscape phone is shorter than the sheet is
/// tall and a menu that overflows is a menu with items nobody can reach.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.child, this.scrollable = true});

  final Widget child;

  /// Off for sheets that already manage their own scrolling inside a list.
  final bool scrollable;

  /// Wide enough for a row of controls, narrow enough to stay one thing.
  static const maxWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: SafeArea(
          top: false,
          child: scrollable ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );
  }
}
