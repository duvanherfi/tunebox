import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/shelf_row.dart';

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
            itemBuilder: (context, index) => ShelfRow(shelf: shelves[index]),
          ),
        );
      },
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
