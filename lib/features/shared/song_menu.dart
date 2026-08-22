import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/retired_ids.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../browse/album_screen.dart';
import '../browse/artist_screen.dart';
import 'credits_screen.dart';
import 'sheet_body.dart';

/// Everything you can do to a track that is not "play it now".
///
/// One sheet, reachable from every list in the app, so a song behaves the same
/// whether it was found in search, in a playlist or in the history. Actions
/// that write to the account only appear when there is an account.
///
/// Which of them appear at all is the row's own doing: every edit YouTube makes
/// on a track is asked for with a handle minted inside that row's menu, so a
/// track listed from a surface that carries no menu offers none of them. That
/// is why the same song shows more here when it was opened from the history
/// than from a search.
///
/// [playlistId] is the one thing the row cannot say by itself. It knows it can
/// be dropped from the list that listed it — that is what
/// [SongActions.playlistSetVideoId] means — but not which list that was.
Future<void> showSongMenu(
  BuildContext context,
  Song song, {
  String? playlistId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell, or it opens under the player bar.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SongMenu(song: song, playlistId: playlistId),
  );
}

class _SongMenu extends StatelessWidget {
  const _SongMenu({required this.song, this.playlistId});

  final Song song;

  /// The playlist this row was listed in, when it was listed in one that the
  /// account can edit.
  final String? playlistId;

  /// Reports the outcome on the surface that is still on screen after the sheet
  /// closes, rather than on the sheet's own context, which is gone by then.
  static void _report(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs an action after the sheet is gone, and reports how it went.
  ///
  /// [retireFrom] is the list the track leaves on success. Only then: a write
  /// the account refused has not removed anything, and hiding the row would
  /// tell the listener the opposite of what happened.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success, {
    String? retireFrom,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    try {
      await action();
      if (retireFrom != null) retiredIds.retire(retireFrom, song.videoId);
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
                    retireFrom: liked ? RetiredIds.likes : null,
                  ),
                );
              },
            ),
            // Only where the row brought the handle. The library and the likes
            // are two lists — a saved album fills the first without anyone
            // liking anything — and this takes the track out of the library
            // while the heart above stays as it was. There is no endpoint that
            // takes a video id for it: without the token from the row's own
            // menu the edit cannot be asked for at all, which is why search
            // results and tracks from the device do not offer it.
            if (song.actions.removeFromLibrary != null)
              ListTile(
                leading: const Icon(Icons.bookmark_remove_outlined),
                title: Text(l10n.menuRemoveFromLibrary),
                onTap: () => _run(
                  context,
                  () =>
                      innertube.removeFromLibrary(song.actions.removeFromLibrary!),
                  l10n.menuRemovedFromLibrary,
                  retireFrom: RetiredIds.library,
                ),
              ),
            // Only the history carries this, which is also what makes it safe
            // to send: the token is the whole instruction, and the one that
            // takes a track out of the library looks exactly the same.
            if (song.actions.removeFromHistory != null)
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded),
                title: Text(l10n.menuRemoveFromHistory),
                onTap: () => _run(
                  context,
                  () =>
                      innertube.removeFromHistory(song.actions.removeFromHistory!),
                  l10n.menuRemovedFromHistory,
                  retireFrom: RetiredIds.history,
                ),
              ),
            // Both halves have to be there: the row that can be dropped, and
            // the list it would be dropped from.
            if (song.actions.playlistSetVideoId != null && playlistId != null)
              ListTile(
                leading: const Icon(Icons.playlist_remove_rounded),
                title: Text(l10n.menuRemoveFromPlaylist),
                onTap: () => _run(
                  context,
                  () => innertube.removeFromPlaylist(
                    playlistId!,
                    videoId: song.videoId,
                    setVideoId: song.actions.playlistSetVideoId!,
                  ),
                  l10n.menuRemovedFromPlaylist,
                  retireFrom: RetiredIds.playlist(playlistId!),
                ),
              ),
            if (_pinToken(song) != null)
              ListTile(
                leading: Icon(
                  song.actions.pinnedToRecap
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                ),
                title: Text(song.actions.pinnedToRecap
                    ? l10n.menuUnpinFromRecap
                    : l10n.menuPinToRecap),
                onTap: () => _run(
                  context,
                  () => innertube.setPinnedToRecap(_pinToken(song)!),
                  song.actions.pinnedToRecap ? l10n.menuUnpinned : l10n.menuPinned,
                ),
              ),
          ],
          // Not an account action: the credits of a track are public, and the
          // page answers signed out.
          if (song.actions.hasCredits)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(l10n.menuCredits),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CreditsScreen(song: song)),
                );
              },
            ),
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

/// Whichever side of the pin the row is on: the track is either pinned and can
/// be unpinned, or the other way round, and each side has its own token.
String? _pinToken(Song song) => song.actions.pinnedToRecap
    ? song.actions.unpinFromRecap
    : song.actions.pinToRecap;

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
    // Above the shell, or it opens under the player bar.
    useRootNavigator: true,
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
      // Above the shell, or it opens under the player bar.
      useRootNavigator: true,
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
