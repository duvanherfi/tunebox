import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'sheet_body.dart';
import 'song_menu.dart';

/// Keeps a collection, and says so.
///
/// The mark is the listener's and stands even when the account cannot be told;
/// the snackbar reports which of the two happened rather than pretending the
/// write succeeded or undoing the mark.
Future<void> toggleCollectionSaved(
  BuildContext context,
  Playlist collection,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  final saving = !savedCollections.isSaved(collection.browseId);
  try {
    await savedCollections.toggle(collection);
    messenger.showSnackBar(
      SnackBar(
        content: Text(saving ? l10n.collectionSaved : l10n.collectionRemoved),
      ),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.collectionSyncFailed('$error'))),
    );
  }
}

/// Plays what YouTube says goes with this whole list.
///
/// The radio is a network call, so it can arrive late or not at all: the
/// failure is reported where the listener is looking rather than thrown into
/// the void.
Future<void> startCollectionRadio(
  BuildContext context,
  Playlist collection,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  try {
    final songs = await innertube.collectionRadio(collection.browseId);
    if (songs.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.libraryPlaylistEmpty)));
      return;
    }
    await playerService.setShuffleMode(AudioServiceShuffleMode.none);
    await playerService.setQueue(songs);
    messenger.showSnackBar(SnackBar(content: Text(l10n.menuRadioStarted)));
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.menuFailed('$error'))),
    );
  }
}

/// Everything you can do to a playlist or album that is not "play it now".
///
/// The collection-level twin of the song menu, and deliberately the same shape:
/// the same verbs in the same order, applied to every track at once.
Future<void> showCollectionMenu(
  BuildContext context, {
  required Playlist collection,
  required List<Song> songs,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell, or it opens under the player bar.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (_) => _CollectionMenu(collection: collection, songs: songs),
  );
}

class _CollectionMenu extends StatelessWidget {
  const _CollectionMenu({required this.collection, required this.songs});

  final Playlist collection;
  final List<Song> songs;

  /// Runs an action after the sheet is gone, reporting on the surface that is
  /// still on screen rather than on the sheet's own dead context.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.menuFailed('$error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final empty = songs.isEmpty;

    return SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Artwork(url: collection.thumbnailUrl, size: 48),
            title: Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: collection.subtitle.isEmpty
                ? null
                : Text(
                    collection.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            enabled: !empty,
            title: Text(l10n.play),
            onTap: () {
              Navigator.of(context).pop();
              playerService
                  .setShuffleMode(AudioServiceShuffleMode.none)
                  .then((_) => playerService.setQueue(songs));
            },
          ),
          ListTile(
            leading: const Icon(Icons.shuffle_rounded),
            enabled: !empty,
            title: Text(l10n.shuffle),
            onTap: () {
              Navigator.of(context).pop();
              playerService
                  .setShuffleMode(AudioServiceShuffleMode.all)
                  .then((_) => playerService.setQueue(songs));
            },
          ),
          ListTile(
            leading: const Icon(Icons.radio_rounded),
            title: Text(l10n.menuRadio),
            onTap: () {
              Navigator.of(context).pop();
              startCollectionRadio(context, collection);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            enabled: !empty,
            title: Text(l10n.menuPlayNext),
            onTap: () => _run(
              context,
              // Backwards, so the list keeps its running order: each track is
              // inserted immediately after the current one, pushing the last
              // one inserted further down.
              () async {
                for (final song in songs.reversed) {
                  await playerService.playNext(song);
                }
              },
              l10n.menuQueued,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            enabled: !empty,
            title: Text(l10n.menuAddToQueue),
            onTap: () => _run(
              context,
              () async {
                for (final song in songs) {
                  await playerService.addToQueue(song);
                }
              },
              l10n.menuQueued,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            enabled: !empty,
            title: Text(l10n.menuAddToPlaylist),
            onTap: () {
              Navigator.of(context).pop();
              showPlaylistPicker(context, songs);
            },
          ),
          ListenableBuilder(
            listenable: savedCollections,
            builder: (context, _) {
              final saved = savedCollections.isSaved(collection.browseId);
              return ListTile(
                leading: Icon(
                  saved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                title: Text(
                  saved ? l10n.collectionRemove : l10n.collectionSave,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  toggleCollectionSaved(context, collection);
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            enabled: !empty,
            title: Text(l10n.collectionDownloadAll),
            onTap: () => _run(
              context,
              () async {
                for (final song in songs) {
                  if (!downloads.has(song.videoId)) {
                    await playerService.download(song);
                  }
                }
              },
              l10n.collectionDownloading(songs.length),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: Text(l10n.menuCopyLink),
            onTap: () => _run(
              context,
              () => Clipboard.setData(
                ClipboardData(text: collectionLink(collection.browseId)),
              ),
              l10n.menuLinkCopied,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The web address of a collection.
///
/// Albums are browse ids and everything else is a playlist, which are two
/// different paths on music.youtube.com; a link to the wrong one opens nothing.
String collectionLink(String browseId) {
  if (browseId.startsWith('MPRE')) {
    return 'https://music.youtube.com/browse/$browseId';
  }
  final id = browseId.startsWith('VL') ? browseId.substring(2) : browseId;
  return 'https://music.youtube.com/playlist?list=$id';
}
