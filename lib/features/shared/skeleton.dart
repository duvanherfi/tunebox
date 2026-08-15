import 'package:flutter/material.dart';

/// Placeholder shapes in the layout the real content will take.
///
/// A spinner says "wait" and nothing else; this says what is coming and where,
/// so the screen does not jump when it arrives. It also makes the wait feel
/// shorter, which is the only honest kind of speed improvement available when
/// the delay belongs to somebody else's server.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          // A slow breath rather than a sweeping shimmer: at this size a
          // travelling highlight is noise, and this reads as "not yet".
          color: Color.lerp(
            colors.surfaceContainerHighest,
            colors.surfaceContainerHigh,
            _controller.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// The shape of a list of tracks, while the tracks are on their way.
class SongListSkeleton extends StatelessWidget {
  const SongListSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Skeleton(width: 48, height: 48, radius: 12),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 200, height: 14),
                  SizedBox(height: 8),
                  Skeleton(width: 120, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shape of the rows of covers a browsing screen is built from.
class ShelfSkeleton extends StatelessWidget {
  const ShelfSkeleton({super.key, this.rows = 2});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Skeleton(width: 160, height: 18),
            ),
            SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    const Skeleton(width: 156, height: 156, radius: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
