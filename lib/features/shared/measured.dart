import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reports how tall its child turned out to be.
///
/// The navigation bar's height is not a number this app gets to decide: it is
/// Material's, plus whatever the device reserves for its gesture bar, and both
/// change with the phone. Reserving space for it by adding up constants was
/// close enough to look right and wrong enough to leave a band of dead space
/// above it — so the space is measured instead of guessed.
class Measured extends SingleChildRenderObjectWidget {
  const Measured({super.key, required this.onSize, required Widget super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasured).onSize = onSize;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size) return;
    _reported = size;
    // After the frame, not during it: the callback moves other widgets, and
    // laying out during layout is how a build loop starts.
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(size));
  }
}
