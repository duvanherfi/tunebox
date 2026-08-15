import 'package:flutter/material.dart';

import '../../main.dart';

/// Changes track on a horizontal flick, moving with the finger.
///
/// The content follows the drag and fades with distance, so the gesture reads
/// as pushing the current track aside rather than pressing a hidden button.
/// Horizontal only: the player sheet owns vertical drags, and a widget that
/// claimed both would fight it for every diagonal.
class SwipeToChangeTrack extends StatefulWidget {
  const SwipeToChangeTrack({
    super.key,
    required this.child,
    required this.travel,
    this.fade = true,
  });

  final Widget child;

  /// How far a flick can carry the content, and the distance the fade and the
  /// commit threshold are measured against — the width of what is moving.
  final double travel;

  /// Whether the content dims as it goes. Right for a cover, wrong for a bar
  /// that is mostly background.
  final bool fade;

  @override
  State<SwipeToChangeTrack> createState() => _SwipeToChangeTrackState();
}

class _SwipeToChangeTrackState extends State<SwipeToChangeTrack> {
  static const _flickVelocity = 400.0;

  double _offset = 0;
  bool _settling = false;

  void _finish(double velocity) {
    final travelled = _offset.abs() > widget.travel * 0.25;
    final flicked = velocity.abs() > _flickVelocity;

    if (!travelled && !flicked) {
      setState(() => _offset = 0);
      return;
    }

    final forward = flicked ? velocity < 0 : _offset < 0;
    setState(() {
      _settling = true;
      _offset = forward ? -widget.travel : widget.travel;
    });

    if (forward) {
      playerService.skipToNext();
    } else {
      playerService.previousTrack();
    }

    // The incoming track rebuilds this widget with a new key, so the reset is
    // only a safety net for when the queue has nowhere to go.
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() {
          _settling = false;
          _offset = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_settling) return;
        setState(() => _offset += details.delta.dx);
      },
      onHorizontalDragEnd: (details) => _finish(details.primaryVelocity ?? 0),
      onHorizontalDragCancel: () => setState(() => _offset = 0),
      child: AnimatedContainer(
        duration: Duration(milliseconds: _settling ? 200 : 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_offset, 0, 0),
        child: Opacity(
          opacity: widget.fade
              ? (1 - (_offset.abs() / widget.travel)).clamp(0.3, 1.0)
              : 1,
          child: widget.child,
        ),
      ),
    );
  }
}
