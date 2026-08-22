import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../data/retired_ids.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/collection_header.dart';
import '../shared/skeleton.dart';
import '../shared/song_list_view.dart';
import '../shared/song_pages.dart';
import '../shared/suggestions.dart';

/// The tracks inside a saved playlist or album.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  /// The whole page rather than only its tracks, because the same request that
  /// answers with the first hundred also says whether this is a list the
  /// account made — which is the difference between offering to rename it and
  /// offering an action that always fails.
  late final Future<MusicPage> _page =
      innertube.playlistPage(widget.playlist.browseId);

  /// The name as it stands here, which is not always the name the card that
  /// opened this carried: renaming happens on this screen.
  ///
  /// Kept locally rather than read back, and that is not an optimisation.
  /// Measured on 22 August 2026: the edit answers `STATUS_SUCCEEDED` and the
  /// very next read of the playlist still comes back with the old name. Asking
  /// again would draw the rename as if it had not happened.
  String? _renamed;

  String get _title => _renamed ?? widget.playlist.title;

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _title);

    final name = await showDialog<String>(
      context: context,
      // Above the shell, or it opens under the player bar.
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlistRename),
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
            child: Text(l10n.playlistRename),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await innertube.renamePlaylist(widget.playlist.browseId, name.trim());
      if (mounted) setState(() => _renamed = name.trim());
      messenger.showSnackBar(SnackBar(content: Text(l10n.playlistRenamed)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.menuFailed('$error'))),
      );
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;

    // Confirmed because there is no undo — YouTube's own client asks too, and
    // this is the one action here that cannot be put back.
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlistDelete),
        content: Text(l10n.playlistDeleteConfirm(_title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.playlistDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await innertube.deletePlaylist(widget.playlist.browseId);
      // The library read its playlists once and kept them, so the shelf is told
      // rather than asked again.
      retiredIds.retire(RetiredIds.playlists, widget.playlist.browseId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.playlistDeleted)));
      // Back to the library: staying on the page of a list that no longer
      // exists would leave a screen nothing can refresh.
      navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.menuFailed('$error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<MusicPage>(
        future: _page,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SongListSkeleton();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final page = snapshot.data!;
          // Only a list the account made can be edited from here. A saved one
          // is someone else's, and YouTube says so by attaching no editor to
          // its page.
          final playlistId = page.editable ? widget.playlist.browseId : null;

          return SongPages(
            // The first hundred came with the page; a longer list carries on
            // from the token beside them rather than asking again.
            first: page.songs,
            pages: () => innertube.songPagesAfter(page.continuation),
            list: RetiredIds.playlist(widget.playlist.browseId),
            build: (view) {
              final songs = view.songs;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: CollectionHeader(
                      title: _title,
                      subtitle: widget.playlist.subtitle,
                      thumbnailUrl: widget.playlist.thumbnailUrl,
                      songs: songs,
                      collection: widget.playlist,
                      onRename: page.editable ? _rename : null,
                      onDelete: page.editable ? _delete : null,
                    ),
                  ),
                  if (songs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(l10n.libraryPlaylistEmpty)),
                      ),
                    )
                  else ...[
                    SliverList.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, index) => SongRow(
                        songs: songs,
                        index: index,
                        playlistId: playlistId,
                      ),
                    ),
                    // Only once the list really is the whole list. Suggestions
                    // under a hundred rows of a list that is still growing
                    // would read as its end, and it is not.
                    if (view.done)
                      SliverToBoxAdapter(child: Suggestions(seed: songs.first)),
                  ],
                  if (!view.done) const SliverToBoxAdapter(child: MoreComing()),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 24 + MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
