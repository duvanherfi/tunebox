import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local_playlists.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/song_menu.dart';

/// One playlist made on this device: its tracks, in the order they were put in.
///
/// Editable in place — drag to reorder, swipe to remove — because a list you
/// made yourself is one you keep changing, and sending that through a dialog
/// each time would make it a chore.
class LocalPlaylistScreen extends StatelessWidget {
  const LocalPlaylistScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: localPlaylists,
      builder: (context, _) {
        final playlist = localPlaylists.byId(id);
        if (playlist == null) return const Scaffold();

        return Scaffold(
          appBar: AppBar(
            title: Text(playlist.name),
            actions: [
              IconButton(
                tooltip: l10n.playlistRename,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _rename(context, playlist),
              ),
              IconButton(
                tooltip: l10n.playlistDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  await localPlaylists.delete(id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: playlist.songs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.playlistEmptyLocal,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () async {
                              await playerService.setShuffleMode(
                                AudioServiceShuffleMode.none,
                              );
                              await playerService.setQueue(playlist.songs);
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(l10n.play),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              await playerService.setShuffleMode(
                                AudioServiceShuffleMode.all,
                              );
                              await playerService.setQueue(playlist.songs);
                            },
                            icon: const Icon(Icons.shuffle_rounded),
                            label: Text(l10n.shuffle),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
                        itemCount: playlist.songs.length,
                        onReorder: (from, to) => localPlaylists.move(
                          id,
                          from,
                          to > from ? to - 1 : to,
                        ),
                        itemBuilder: (context, index) {
                          final song = playlist.songs[index];
                          return Dismissible(
                            key: ValueKey('${playlist.id}-${song.videoId}'),
                            onDismissed: (_) =>
                                localPlaylists.removeAt(id, index),
                            background: ColoredBox(
                              color: theme.colorScheme.errorContainer,
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Icon(Icons.delete_outline_rounded),
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: Artwork(
                                url: song.thumbnailUrl,
                                size: 44,
                                radius: 8,
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist ?? song.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => playerService.setQueue(
                                playlist.songs,
                                startIndex: index,
                              ),
                              onLongPress: () => showSongMenu(context, song),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: Tooltip(
                                  message: l10n.tipReorder,
                                  child: const Icon(Icons.drag_handle_rounded),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, LocalPlaylist playlist) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: playlist.name);

    final name = await showDialog<String>(
      context: context,
      // Above the shell, or it opens under the player bar.
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlistRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.playlistRename),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await localPlaylists.rename(playlist.id, name);
    }
  }
}
