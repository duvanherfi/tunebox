import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'song_list_view.dart';

/// More like this, at the end of a list.
///
/// Reaching the bottom of a playlist is the moment someone is most likely to
/// want another one, and YouTube's radio for its first track is a good enough
/// answer to that without asking anything else. Loaded lazily — when the end is
/// actually scrolled to, not when the screen opens.
class Suggestions extends StatefulWidget {
  const Suggestions({super.key, required this.seed, this.take = 10});

  final Song seed;
  final int take;

  @override
  State<Suggestions> createState() => _SuggestionsState();
}

class _SuggestionsState extends State<Suggestions> {
  late final Future<List<Song>> _songs = innertube
      .radio(widget.seed.videoId)
      .then((songs) => songs.take(widget.take).toList())
      .catchError((_) => <Song>[]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<Song>>(
      future: _songs,
      builder: (context, snapshot) {
        final songs = snapshot.data ?? const <Song>[];
        if (songs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(l10n.playlistSuggestions),
            for (var i = 0; i < songs.length; i++)
              SongRow(songs: songs, index: i),
          ],
        );
      },
    );
  }
}
