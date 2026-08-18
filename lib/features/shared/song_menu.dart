import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../browse/album_screen.dart';
import '../browse/artist_screen.dart';
import 'sheet_body.dart';

/// Everything you can do to a track that is not "play it now".
///
/// One sheet, reachable from every list in the app, so a song behaves the same
/// whether it was found in search, in a playlist or in the history. Actions
/// that write to the account only appear when there is an account.
Future<void> showSongMenu(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SongMenu(song: song),
  );
}

class _SongMenu extends StatelessWidget {
  const _SongMenu({required this.song});

  final Song song;

  /// Reports the outcome on the surface that is still on screen after the sheet
  /// closes, rather than on the sheet's own context, which is gone by then.
  static void _report(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

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
      _report(messenger, success);
    } catch (error) {
      _report(messenger, l10n.menuFailed('$error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Artwork(url: song.thumbnailUrl, size: 48),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              song.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.radio_rounded),
            title: Text(l10n.menuRadio),
            onTap: () => _run(
              context,
              () => playerService.startRadio(song),
              l10n.menuRadioStarted,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: Text(l10n.menuPlayNext),
            onTap: () => _run(
              context,
              () => playerService.playNext(song),
              l10n.menuQueued,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: Text(l10n.menuAddToQueue),
            onTap: () => _run(
              context,
              () => playerService.addToQueue(song),
              l10n.menuQueued,
            ),
          ),
          // Only offered when the row said where the track came from: half of
          // what YouTube returns — videos, mixes — has no artist page behind it.
          if (song.artistId != null)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(l10n.menuGoArtist),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArtistScreen(browseId: song.artistId!),
                  ),
                );
              },
            ),
          if (song.albumId != null)
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: Text(l10n.menuGoAlbum),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlbumScreen(browseId: song.albumId!),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: Text(l10n.menuAddToPlaylist),
            onTap: () {
              Navigator.of(context).pop();
              showPlaylistPicker(context, [song]);
            },
          ),
          if (session.isSignedIn) ...[
            ListenableBuilder(
              listenable: likes,
              builder: (context, _) {
                final liked = likes.isLiked(song.videoId);
                return ListTile(
                  leading: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  title: Text(liked ? l10n.menuUnlike : l10n.menuLike),
                  onTap: () => _run(
                    context,
                    () => likes.toggle(song),
                    liked ? l10n.menuUnliked : l10n.menuLiked,
                  ),
                );
              },
            ),
          ],
          ListenableBuilder(
            listenable: downloads,
            builder: (context, _) {
              if (downloads.isDownloading(song.videoId)) {
                return ListTile(
                  leading: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text(l10n.menuDownloading),
                );
              }
              if (downloads.has(song.videoId)) {
                return ListTile(
                  leading: const Icon(Icons.download_done_rounded),
                  title: Text(l10n.menuRemoveDownload),
                  onTap: () => _run(
                    context,
                    () => downloads.remove(song.videoId),
                    l10n.menuDownloadRemoved,
                  ),
                );
              }
              return ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.menuDownload),
                onTap: () => _run(
                  context,
                  () => playerService.download(song),
                  l10n.menuDownloaded,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: Text(l10n.menuCopyLink),
            onTap: () => _run(
              context,
              () => Clipboard.setData(
                ClipboardData(
                  text: 'https://music.youtube.com/watch?v=${song.videoId}',
                ),
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

/// Picks which playlist a track joins, or starts a new one.
///
/// The account's playlists are fetched when the sheet opens rather than kept
/// around: they change from other devices, and a stale list here would silently
/// add a song to the wrong place.
/// Asks which playlist to add to.
///
/// Takes a list rather than a track because a whole record is added the same
/// way a single song is, and going one by one would be one request per track.
Future<void> showPlaylistPicker(BuildContext context, List<Song> songs) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.7,
    ),
    builder: (_) => _PlaylistPicker(songs: songs),
  );
}

class _PlaylistPicker extends StatefulWidget {
  const _PlaylistPicker({required this.songs});

  final List<Song> songs;

  @override
  State<_PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends State<_PlaylistPicker> {
  late final Future<List<Playlist>> _playlists = innertube.savedPlaylists();

  Future<void> _add(Playlist playlist) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    try {
      await innertube.addAllToPlaylist(
        playlist.browseId,
        [for (final song in widget.songs) song.videoId],
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.menuAddedTo(playlist.title))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.menuFailed('$error'))),
      );
    }
  }

  /// Adds to a playlist on the device: no network, no account, immediate.
  Future<void> _addLocal(String id, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    for (final song in widget.songs) {
      await localPlaylists.add(id, song);
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.menuAddedTo(name))));
  }

  Future<void> _createLocal() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlistLocalNew),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.playlistNameHint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.create),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await localPlaylists.create(name.trim(), songs: widget.songs);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.menuAddedTo(name.trim()))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            l10n.playlistPickTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.add_rounded),
          title: Text(l10n.playlistLocalNew),
          onTap: _createLocal,
        ),
        const Divider(height: 1),
        ListenableBuilder(
          listenable: localPlaylists,
          builder: (context, _) => Column(
            children: [
              for (final playlist in localPlaylists.all)
                ListTile(
                  leading: Artwork(
                    url: playlist.thumbnailUrl,
                    size: 44,
                    radius: 8,
                  ),
                  title: Text(playlist.name),
                  onTap: () => _addLocal(playlist.id, playlist.name),
                ),
            ],
          ),
        ),
        if (session.isSignedIn) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              l10n.playlistInAccount,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Flexible(
          child: FutureBuilder<List<Playlist>>(
            future: _playlists,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final playlists = snapshot.data ?? const <Playlist>[];
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: playlists.length,
                itemBuilder: (context, index) => ListTile(
                  leading: Artwork(
                    url: playlists[index].thumbnailUrl,
                    size: 44,
                    radius: 8,
                  ),
                  title: Text(
                    playlists[index].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _add(playlists[index]),
                ),
              );
            },
          ),
        ),
        ],
      ],
    );
  }
}
