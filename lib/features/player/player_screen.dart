import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../main.dart';

/// The full player: artwork, position and transport controls.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static String format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reproduciendo',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      body: StreamBuilder<MediaItem?>(
        stream: playerService.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const Center(child: Text('Nada sonando'));
          }

          return SafeArea(
            child: GestureDetector(
              // Flicking down closes the player, the way a sheet would. Bound
              // to velocity rather than distance so a decisive flick works
              // without dragging the whole screen height.
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 300) {
                  Navigator.of(context).maybePop();
                }
              },
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Artwork carries the screen, so it gets the space and a
                  // radius large enough to read as a card rather than a photo.
                  Center(
                    child: _SwipeableArtwork(
                      key: ValueKey(item.id),
                      url: item.artUri?.toString(),
                      size: MediaQuery.sizeOf(context).width - 56,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.artist ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ProgressBar(total: item.duration ?? Duration.zero),
                  const SizedBox(height: 12),
                  const _Controls(),
                  const Spacer(flex: 2),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Artwork that changes track on a horizontal flick.
///
/// The card follows the finger and animates out in the direction of travel, so
/// the gesture reads as pushing the current track aside rather than pressing a
/// hidden button. Anything short of a real flick springs back, which keeps an
/// accidental brush from skipping a song.
class _SwipeableArtwork extends StatefulWidget {
  const _SwipeableArtwork({super.key, required this.url, required this.size});

  final String? url;
  final double size;

  @override
  State<_SwipeableArtwork> createState() => _SwipeableArtworkState();
}

class _SwipeableArtworkState extends State<_SwipeableArtwork>
    with SingleTickerProviderStateMixin {
  static const _flickVelocity = 400.0;

  double _offset = 0;
  bool _settling = false;

  void _finish(double velocity) {
    final width = widget.size;
    final travelled = _offset.abs() > width * 0.25;
    final flicked = velocity.abs() > _flickVelocity;

    if (!travelled && !flicked) {
      setState(() => _offset = 0);
      return;
    }

    final forward = (flicked ? velocity < 0 : _offset < 0);
    setState(() {
      _settling = true;
      _offset = forward ? -width : width;
    });

    if (forward) {
      playerService.skipToNext();
    } else {
      playerService.skipToPrevious();
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
      child: AnimatedContainer(
        duration: Duration(milliseconds: _settling ? 200 : 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_offset, 0, 0),
        child: Opacity(
          // Fading with distance signals that letting go will commit, without
          // needing any on-screen hint.
          opacity: (1 - (_offset.abs() / widget.size)).clamp(0.3, 1.0),
          child: Artwork(url: widget.url, size: widget.size, radius: 24),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: playerService.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final busy =
            state?.processingState == AudioProcessingState.loading ||
                state?.processingState == AudioProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 40,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: playerService.skipToPrevious,
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 76,
              height: 76,
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : IconButton.filled(
                      iconSize: 40,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed:
                          playing ? playerService.pause : playerService.play,
                    ),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 40,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: playerService.skipToNext,
            ),
          ],
        );
      },
    );
  }
}

/// Seek bar driven by the player's own position stream rather than the media
/// session, so the handle moves smoothly instead of once per state broadcast.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.total});

  final Duration total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<Duration>(
      stream: playerService.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = playerService.player.duration ?? total;
        final max = duration.inMilliseconds.toDouble();
        final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

        final labels = theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );

        return Column(
          children: [
            Slider(
              value: max <= 0 ? 0 : value,
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0
                  ? null
                  : (next) =>
                      playerService.seek(Duration(milliseconds: next.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(PlayerScreen.format(position), style: labels),
                  Text(PlayerScreen.format(duration), style: labels),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
