import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// The player in its collapsed state: a bar showing what is on and the two
/// controls worth reaching for without opening anything.
///
/// Purely presentational — expanding is the sheet's job, so this stays free of
/// navigation and can be faded in and out mid-drag without side effects.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Artwork(url: item.artUri?.toString(), size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Previous as well as next: the bar is where playback is
                // controlled most of the time, and going back one track should
                // not need the whole player opened for it.
                IconButton(
                  tooltip: AppLocalizations.of(context)!.tipPrevious,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: playerService.skipToPrevious,
                ),
                StreamBuilder<PlaybackState>(
                  stream: playerService.playbackState,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final playing = state?.playing ?? false;
                    final busy = state?.processingState ==
                            AudioProcessingState.loading ||
                        state?.processingState ==
                            AudioProcessingState.buffering;

                    if (busy) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return IconButton(
                      tooltip: playing
                          ? AppLocalizations.of(context)!.tipPause
                          : AppLocalizations.of(context)!.tipPlay,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed:
                          playing ? playerService.pause : playerService.play,
                    );
                  },
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.tipNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: playerService.skipToNext,
                ),
              ],
            ),
          ),
        ),
        _MiniProgressBar(fallbackDuration: item.duration),
      ],
    );
  }
}

/// Hairline showing how far into the track playback is.
///
/// Driven by the player's position stream rather than the media session, so it
/// advances smoothly instead of stepping once per state broadcast. Deliberately
/// not interactive: dragging here belongs to the sheet, and a 3px target would
/// only produce accidental seeks.
///
/// Inset and rounded rather than edge-to-edge: the bar it sits in is a floating
/// card now, and a line running into a rounded corner gets sliced by it.
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({this.fallbackDuration});

  final Duration? fallbackDuration;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: playerService.shownPosition,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = playerService.shownDuration ?? fallbackDuration;
        final total = duration?.inMilliseconds ?? 0;
        final value =
            total <= 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total <= 0 ? null : value,
              minHeight: 3,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      },
    );
  }
}
