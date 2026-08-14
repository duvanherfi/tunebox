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
              child: SizedBox(
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
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed:
                              playing ? playerService.pause : playerService.play,
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
            ),
          ),
        );
      },
    );
  }
}
