import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import 'player_screen.dart';

/// Persistent bar above the bottom of the app. Hidden until something is
/// loaded, so an empty session shows no dead chrome.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: playerService.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();

        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlayerScreen()),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        if (item.artUri != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              item.artUri.toString(),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox(width: 44, height: 44),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                item.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<PlaybackState>(
                          stream: playerService.playbackState,
                          builder: (context, stateSnapshot) {
                            final playing = stateSnapshot.data?.playing ?? false;
                            return IconButton(
                              icon:
                                  Icon(playing ? Icons.pause : Icons.play_arrow),
                              onPressed: playing
                                  ? playerService.pause
                                  : playerService.play,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
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
/// not interactive: dragging belongs on the full player, and a 2px target on
/// the edge of the screen would only produce accidental seeks.
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
          minHeight: 2,
          backgroundColor: Colors.white12,
        );
      },
    );
  }
}
