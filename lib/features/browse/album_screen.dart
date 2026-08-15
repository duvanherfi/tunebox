import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

/// Cover, name and the two ways in: straight through, or shuffled.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.songs,
    this.round = false,
  });

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final List<Song> songs;

  /// Artists are people, and a circle reads as one; a record is a square.
  final bool round;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        // The cover again, blurred and fading out behind its own header, so a
        // record's page takes the colour of the record.
        if (thumbnailUrl != null)
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0, 0.7, 0.92],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Image.network(
                  thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            children: [
              Artwork(
                url: thumbnailUrl,
                size: 200,
                radius: round ? 100 : AppTheme.radiusCard,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: songs.isEmpty
                        ? null
                        : () async {
                            await playerService.setShuffleMode(
                              AudioServiceShuffleMode.none,
                            );
                            await playerService.setQueue(songs);
                          },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.play),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: songs.isEmpty
                        ? null
                        : () async {
                            // Shuffle first, so the queue arrives already scrambled
                            // rather than starting on track one and jumping.
                            await playerService.setShuffleMode(
                              AudioServiceShuffleMode.all,
                            );
                            await playerService.setQueue(songs);
                          },
                    icon: const Icon(Icons.shuffle_rounded),
                    label: Text(l10n.shuffle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}
