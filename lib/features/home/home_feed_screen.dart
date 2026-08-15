import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../library/playlist_screen.dart';

/// What the app opens on: rows of collections from YouTube Music's front page.
///
/// Signed out these are playlists rather than songs. That is what the service
/// returns without a listening history to draw on, and it is what the official
/// clients show in the same situation — so the screen leans into it and makes
/// the covers the content, rather than padding a thin feed to look fuller.
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Shelf>> _future = innertube.homeFeed();

  @override
  bool get wantKeepAlive => true;

  void _reload() => setState(() => _future = innertube.homeFeed());

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<Shelf>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _Message(
            icon: Icons.cloud_off_rounded,
            title: l10n.homeErrorTitle,
            detail: '${snapshot.error}',
            action: FilledButton.tonal(
              onPressed: _reload,
              child: Text(l10n.retry),
            ),
          );
        }

        final shelves = snapshot.data ?? const <Shelf>[];
        if (shelves.isEmpty) {
          return _Message(
            icon: Icons.library_music_outlined,
            title: l10n.homeEmptyTitle,
            detail: l10n.homeEmptyBody,
            action: FilledButton.tonal(
              onPressed: _reload,
              child: Text(l10n.retry),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: shelves.length,
            itemBuilder: (context, index) => _ShelfRow(shelf: shelves[index]),
          ),
        );
      },
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.shelf});

  final Shelf shelf;

  static const _cardWidth = 156.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(shelf.title),
        SizedBox(
          // Room for the cover plus two lines of title beneath it.
          height: _cardWidth + 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shelf.playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _PlaylistCard(
              playlist: shelf.playlists[index],
              width: _cardWidth,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.width});

  final Playlist playlist;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistScreen(playlist: playlist),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(url: playlist.thumbnailUrl, size: width),
            const SizedBox(height: 8),
            Text(
              playlist.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
