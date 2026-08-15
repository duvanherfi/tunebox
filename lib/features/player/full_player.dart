import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/song_menu.dart';
import 'lyrics_view.dart';
import 'queue_sheet.dart';

/// The player in its expanded state.
///
/// Presentational, like its collapsed counterpart: the sheet owns the size and
/// the drag, so this only draws and can be faded in mid-gesture.
///
/// The cover is the background as well as the subject — blurred and darkened
/// behind everything — so the screen takes the colour of whatever is playing
/// without a palette having to be computed for it.
class FullPlayer extends StatefulWidget {
  const FullPlayer({super.key, required this.item, required this.onCollapse});

  final MediaItem item;
  final VoidCallback onCollapse;

  static String format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer> {
  /// Whether the words have taken the cover's place. In place rather than over
  /// it: reading along and reaching for pause are the same moment.
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final art = widget.item.artUri?.toString();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (art != null) _Backdrop(url: art),
        SafeArea(
          child: Column(
            children: [
              _Handle(onCollapse: widget.onCollapse),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _showLyrics
                              ? LyricsView(
                                  key: const ValueKey('lyrics'),
                                  song: playerService.currentSong,
                                )
                              : Center(
                                  child: _SwipeableArtwork(
                                    key: ValueKey(widget.item.id),
                                    url: art,
                                    size: MediaQuery.sizeOf(context).width - 96,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Title(item: widget.item),
                      const SizedBox(height: 16),
                      _QuickActions(
                        showingLyrics: _showLyrics,
                        onToggleLyrics: () =>
                            setState(() => _showLyrics = !_showLyrics),
                      ),
                      const SizedBox(height: 8),
                      _ProgressBar(
                        total: widget.item.duration ?? Duration.zero,
                      ),
                      const _Controls(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              // What is coming, one tap away, named rather than hidden behind
              // an icon nobody presses to find out.
              const _QueueHandle(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The cover, blurred to a wash of its own colours, under a scrim heavy enough
/// that text stays readable over a white sleeve.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: colors.surface),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.surface.withValues(alpha: 0.35),
                colors.surface.withValues(alpha: 0.72),
                colors.surface.withValues(alpha: 0.96),
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// A grab handle rather than a back arrow: this panel is dragged shut, not
/// navigated away from. The track's menu sits beside it.
class _Handle extends StatelessWidget {
  const _Handle({required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
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
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
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
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
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
        const SizedBox(height: 6),
        Text(
          item.artist ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The four things reached for while a track plays, one tap each instead of two
/// through a menu: a radio from here, the words, keeping it, liking it.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.showingLyrics,
    required this.onToggleLyrics,
  });

  final bool showingLyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final song = playerService.currentSong;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundAction(
          icon: Icons.radio_rounded,
          tooltip: l10n.menuRadio,
          onPressed: song == null ? null : () => playerService.startRadio(song),
        ),
        _RoundAction(
          icon: Icons.lyrics_outlined,
          tooltip: l10n.lyricsTitle,
          selected: showingLyrics,
          onPressed: onToggleLyrics,
        ),
        ListenableBuilder(
          listenable: downloads,
          builder: (context, _) {
            final saved = song != null && downloads.has(song.videoId);
            final busy = song != null && downloads.isDownloading(song.videoId);
            return _RoundAction(
              icon:
                  saved ? Icons.download_done_rounded : Icons.download_outlined,
              tooltip: saved ? l10n.menuRemoveDownload : l10n.menuDownload,
              selected: saved,
              busy: busy,
              onPressed: song == null || busy
                  ? null
                  : () => saved
                      ? downloads.remove(song.videoId)
                      : playerService.download(song),
            );
          },
        ),
        ListenableBuilder(
          listenable: likes,
          builder: (context, _) {
            final liked = song != null && likes.isLiked(song.videoId);
            return _RoundAction(
              icon:
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              tooltip: l10n.menuLike,
              selected: liked,
              onPressed: song == null || !session.isSignedIn
                  ? null
                  : () => likes.toggle(song),
            );
          },
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? colors.primaryContainer
            : colors.surfaceContainerHighest.withValues(alpha: 0.55),
        foregroundColor: selected ? colors.onPrimaryContainer : null,
        padding: const EdgeInsets.all(12),
      ),
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
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
          child: DecoratedBox(
            // A cover floating over its own blur needs an edge, or it dissolves
            // into the background it came from.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Artwork(url: widget.url, size: widget.size, radius: 24),
          ),
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
            const ShuffleButton(),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: playerService.skipToPrevious,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 72,
              height: 72,
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : IconButton.filled(
                      iconSize: 38,
                      // A squircle rather than a circle: it is the biggest
                      // target on the screen and the shape should say so.
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed:
                          playing ? playerService.pause : playerService.play,
                    ),
            ),
            const SizedBox(width: 4),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: playerService.skipToNext,
            ),
            const RepeatButton(),
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
            SliderTheme(
              // Thin track, small handle: this is a readout first and a control
              // second, and the default sizes read as a form field.
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                inactiveTrackColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.18),
              ),
              child: Slider(
                value: max <= 0 ? 0 : value,
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0
                    ? null
                    : (next) => playerService.seek(
                          Duration(milliseconds: next.round()),
                        ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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

/// A pull tab for the queue that says what is next, rather than an icon the
/// listener has to press to find out.
class _QueueHandle extends StatelessWidget {
  const _QueueHandle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return StreamBuilder<List<MediaItem>>(
      stream: playerService.queue,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? const <MediaItem>[];
        final at = playerService.currentIndex + 1;
        final next = at < queue.length ? queue[at].title : null;

        return InkWell(
          onTap: () => showQueueSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              children: [
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    next == null ? l10n.queueTitle : '${l10n.queueTitle}: $next',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
