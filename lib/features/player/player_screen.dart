import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../main.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<MediaItem?>(
        stream: playerService.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const Center(child: Text('Nada sonando'));
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                if (item.artUri != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        item.artUri.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.white10,
                          child: Icon(Icons.music_note, size: 64),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  item.artist ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                ),
                const SizedBox(height: 24),
                _ProgressBar(total: item.duration ?? Duration.zero),
                const SizedBox(height: 8),
                StreamBuilder<PlaybackState>(
                  stream: playerService.playbackState,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final playing = state?.playing ?? false;
                    final busy = state?.processingState ==
                            AudioProcessingState.loading ||
                        state?.processingState ==
                            AudioProcessingState.buffering;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 44,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: playerService.skipToPrevious,
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: busy
                              ? const Center(child: CircularProgressIndicator())
                              : IconButton.filled(
                                  iconSize: 40,
                                  icon: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                  ),
                                  onPressed: playing
                                      ? playerService.pause
                                      : playerService.play,
                                ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          iconSize: 44,
                          icon: const Icon(Icons.skip_next),
                          onPressed: playerService.skipToNext,
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
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
    return StreamBuilder<Duration>(
      stream: playerService.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = playerService.player.duration ?? total;
        final max = duration.inMilliseconds.toDouble();
        final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

        return Column(
          children: [
            Slider(
              value: max <= 0 ? 0 : value,
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0
                  ? null
                  : (next) => playerService
                      .seek(Duration(milliseconds: next.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(PlayerScreen._format(position),
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(PlayerScreen._format(duration),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
