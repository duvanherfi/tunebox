import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../main.dart';
import 'player_screen.dart';

/// Persistent bar above the bottom of the app. Hidden until something is
/// loaded, so an empty session shows no dead chrome.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<MediaItem?>(
      stream: playerService.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Material(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayerScreen()),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Artwork(url: item.artUri?.toString(), size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                item.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<PlaybackState>(
                          stream: playerService.playbackState,
                          builder: (context, stateSnapshot) {
                            final state = stateSnapshot.data;
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return IconButton(
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              onPressed: playing
                                  ? playerService.pause
                                  : playerService.play,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: playerService.skipToNext,
                        ),
                      ],
                    ),
                  ),
                  _MiniProgressBar(fallbackDuration: item.duration),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hairline showing how far into the track playback is.
///
/// Driven by the player's position stream rather than the media session, so it
/// advances smoothly instead of stepping once per state broadcast. Deliberately
/// not interactive: dragging belongs on the full player, and a 3px target at
/// the edge of a card would only produce accidental seeks.
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({this.fallbackDuration});

  /// Duration from the listing, used until the player reports the real one.
  final Duration? fallbackDuration;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: playerService.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = playerService.player.duration ?? fallbackDuration;
        final total = duration?.inMilliseconds ?? 0;
        final value =
            total <= 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);

        return LinearProgressIndicator(
          value: total <= 0 ? null : value,
          minHeight: 3,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        );
      },
    );
  }
}
