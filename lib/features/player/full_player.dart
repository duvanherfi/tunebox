import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/song_menu.dart';
import 'queue_sheet.dart';

/// The player in its expanded state.
///
/// Presentational, like its collapsed counterpart: the sheet owns the size and
/// the drag, so this only draws and can be faded in mid-gesture.
class FullPlayer extends StatelessWidget {
  const FullPlayer({super.key, required this.item, required this.onCollapse});

  final MediaItem item;
  final VoidCallback onCollapse;

  static String format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          // A grab handle rather than a back arrow: this panel is dragged
          // shut, not navigated away from. The track's menu sits beside it,
          // where a title bar's overflow button would be.
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: GestureDetector(
                    onTap: onCollapse,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () {
                      final song = playerService.currentSong;
                      if (song != null) showSongMenu(context, song);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  Center(
                    child: _SwipeableArtwork(
                      key: ValueKey(item.id),
                      url: item.artUri?.toString(),
                      size: MediaQuery.sizeOf(context).width - 112,
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
                  const SizedBox(height: 20),
                  _ProgressBar(total: item.duration ?? Duration.zero),
                  const SizedBox(height: 8),
                  const _Controls(),
                  const _SecondaryControls(),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Artwork that changes track on a horizontal flick.
///
/// The card follows the finger and fades with distance, so the gesture reads as
/// pushing the current track aside rather than pressing a hidden button.
/// Horizontal only, which leaves vertical drags to the sheet that contains it.
class _SwipeableArtwork extends StatefulWidget {
  const _SwipeableArtwork({super.key, required this.url, required this.size});

  final String? url;
  final double size;

  @override
  State<_SwipeableArtwork> createState() => _SwipeableArtworkState();
}

class _SwipeableArtworkState extends State<_SwipeableArtwork> {
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

    final forward = flicked ? velocity < 0 : _offset < 0;
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
              iconSize: 38,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: playerService.skipToPrevious,
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 72,
              height: 72,
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : IconButton.filled(
                      iconSize: 38,
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
              iconSize: 38,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: playerService.skipToNext,
            ),
          ],
        );
      },
    );
  }
}

/// Shuffle, the queue, and repeat: the three things a listener reaches for once
/// the music is already playing, kept off the main row so the transport
/// controls stay unmistakable.
class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const ShuffleButton(),
        IconButton(
          tooltip: l10n.queueTooltip,
          icon: const Icon(Icons.queue_music_rounded),
          onPressed: () => showQueueSheet(context),
        ),
        const RepeatButton(),
      ],
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
                  Text(FullPlayer.format(position), style: labels),
                  Text(FullPlayer.format(duration), style: labels),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
