import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/collection_header.dart';
import '../shared/skeleton.dart';
import '../shared/song_list_view.dart';

/// One record, in its running order.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.browseId, this.title = ''});

  final String browseId;

  /// What the card that opened this said it was called, so the app bar has a
  /// name before the page arrives.
  final String title;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late final Future<MusicPage> _page = innertube.albumPage(widget.browseId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: CollectionHeader(
                  title: page.title.isEmpty ? widget.title : page.title,
                  subtitle: page.subtitle,
                  thumbnailUrl: page.thumbnailUrl,
                  songs: page.songs,
                  collection: Playlist(
                    browseId: widget.browseId,
                    title: page.title.isEmpty ? widget.title : page.title,
                    subtitle: page.subtitle,
                    thumbnailUrl: page.thumbnailUrl,
                  ),
                ),
              ),
              if (page.songs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l10n.libraryPlaylistEmpty)),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: page.songs.length,
                  itemBuilder: (context, index) =>
                      SongRow(songs: page.songs, index: index, numbered: true),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 24 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
