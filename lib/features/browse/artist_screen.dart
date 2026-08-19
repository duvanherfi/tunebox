import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/collection_header.dart';
import '../shared/shelf_row.dart';
import '../shared/skeleton.dart';
import '../shared/song_list_view.dart';

/// An artist: their popular tracks first, then everything they released.
///
/// The tracks come as a plain list and the releases as the same sideways rows
/// the home feed is built from, which is exactly how YouTube sends them — one
/// page, two shapes.
class ArtistScreen extends StatefulWidget {
  const ArtistScreen({super.key, required this.browseId, this.name = ''});

  final String browseId;
  final String name;

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  late final Future<MusicPage> _page = _load();

  /// The page, plus whatever it says about the account's relationship with this
  /// artist. A subscription made on the web is older than this shelf, so it is
  /// adopted rather than offered again.
  Future<MusicPage> _load() async {
    final page = await innertube.artistPage(widget.browseId);
    if (page.subscribed == true) {
      await savedCollections.remember(_asCollection(page));
    }
    return page;
  }

  Playlist _asCollection(MusicPage page) => Playlist(
    browseId: widget.browseId,
    title: page.title.isEmpty ? widget.name : page.title,
    thumbnailUrl: page.thumbnailUrl,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
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
                  title: page.title.isEmpty ? widget.name : page.title,
                  // An artist's subtitle is a subscriber count, which says
                  // nothing about the music; the header stays quiet.
                  subtitle: '',
                  thumbnailUrl: page.thumbnailUrl,
                  songs: page.songs,
                  round: true,
                  artist: true,
                  collection: _asCollection(page),
                  radioPlaylistId: page.radioPlaylistId,
                ),
              ),
              if (page.songs.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionHeader(l10n.artistSongs)),
                SliverList.builder(
                  itemCount: page.songs.length,
                  itemBuilder: (context, index) =>
                      SongRow(songs: page.songs, index: index),
                ),
              ],
              SliverList.builder(
                itemCount: page.shelves.length,
                itemBuilder: (context, index) =>
                    ShelfRow(shelf: page.shelves[index]),
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
