import 'package:flutter/material.dart';

import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'song_list_view.dart';

/// How a list of tracks can be ordered.
enum SongOrder {
  /// However it arrived: the account's own order, or newest first for a
  /// history. Always the default, because it is the order someone built.
  natural,
  title,
  artist,
  plays,
}

/// A list of tracks with a header that reorders it.
///
/// The order a list arrives in is meaningful — a playlist's sequence, a
/// history's recency — so it stays the default and everything else is a
/// deliberate choice. Sorting happens here rather than in the loaders: the same
/// tracks are shown in several places, and each should be free to order them
/// its own way.
class SortedSongs extends StatefulWidget {
  const SortedSongs({super.key, required this.songs});

  final List<Song> songs;

  @override
  State<SortedSongs> createState() => _SortedSongsState();
}

class _SortedSongsState extends State<SortedSongs> {
  SongOrder _order = SongOrder.natural;
  bool _descending = false;

  List<Song> get _sorted {
    if (_order == SongOrder.natural && !_descending) return widget.songs;

    final songs = List.of(widget.songs);
    switch (_order) {
      case SongOrder.natural:
        break;
      case SongOrder.title:
        songs.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case SongOrder.artist:
        songs.sort((a, b) {
          final left = (a.artist ?? a.subtitle).toLowerCase();
          final right = (b.artist ?? b.subtitle).toLowerCase();
          return left.compareTo(right);
        });
      case SongOrder.plays:
        // Counted from this device's log: YouTube's play counts are about the
        // world, and this list is about one listener.
        final counts = <String, int>{};
        for (final play in playHistory.plays) {
          counts.update(play.song.videoId, (n) => n + 1, ifAbsent: () => 1);
        }
        songs.sort(
          (a, b) =>
              (counts[b.videoId] ?? 0).compareTo(counts[a.videoId] ?? 0),
        );
    }
    return _descending ? songs.reversed.toList() : songs;
  }

  String _label(AppLocalizations l10n, SongOrder order) => switch (order) {
        SongOrder.natural => l10n.sortNatural,
        SongOrder.title => l10n.sortTitle,
        SongOrder.artist => l10n.sortArtist,
        SongOrder.plays => l10n.sortPlays,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
          child: Row(
            children: [
              PopupMenuButton<SongOrder>(
                initialValue: _order,
                onSelected: (order) => setState(() => _order = order),
                itemBuilder: (context) => [
                  for (final order in SongOrder.values)
                    PopupMenuItem(value: order, child: Text(_label(l10n, order))),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _label(l10n, _order),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _descending ? l10n.sortDescending : l10n.sortAscending,
                icon: Icon(
                  _descending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _descending = !_descending),
              ),
              Text(
                l10n.sortCount(widget.songs.length),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Expanded(child: SongListView(songs: _sorted)),
      ],
    );
  }
}
