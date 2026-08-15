import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/song_list_view.dart';

/// What you actually listened to, counted from this device's own log.
///
/// Not YouTube's numbers: those are about the whole world. These are about one
/// listener, which is the only reason to look.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Weeks, months and years are the windows people think in.
  static const _windows = [
    Duration(days: 7),
    Duration(days: 30),
    Duration(days: 365),
  ];

  int _window = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final since = DateTime.now().subtract(_windows[_window]);
    final songs = playHistory.topSongs(since, take: 25);
    final artists = playHistory.topArtists(since, take: 10);
    final total = playHistory.countSince(since);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.statsWeek)),
                ButtonSegment(value: 1, label: Text(l10n.statsMonth)),
                ButtonSegment(value: 2, label: Text(l10n.statsYear)),
              ],
              selected: {_window},
              onSelectionChanged: (picked) =>
                  setState(() => _window = picked.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              l10n.statsPlays(total),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                l10n.statsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (artists.isNotEmpty) ...[
            SectionHeader(l10n.statsArtists),
            for (final entry in artists)
              _Bar(
                label: entry.artist,
                plays: entry.plays,
                of: artists.first.plays,
              ),
          ],
          if (songs.isNotEmpty) ...[
            SectionHeader(l10n.statsSongs),
            for (var i = 0; i < songs.length; i++)
              SongRow(
                songs: [for (final entry in songs) entry.song],
                index: i,
              ),
          ],
        ],
      ),
    );
  }
}

/// An artist's share of the listening, drawn rather than tabulated: the point
/// of a ranking is the gap between first and fifth, and a bar shows that faster
/// than a column of numbers.
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.plays, required this.of});

  final String label;
  final int plays;
  final int of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$plays',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: of == 0 ? 0 : plays / of,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
