import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/shelf_row.dart';

/// Where you go when you do not know what you want to hear.
///
/// Three ways of not knowing: what came out this week, what everyone else is
/// playing, and what fits a mood. Each is a browse id away, and they all come
/// back as the same rows of covers the home feed is built from.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  late final Future<List<Shelf>> _newReleases = innertube.newReleases();
  late final Future<List<Shelf>> _charts = innertube.charts();
  late final Future<List<Playlist>> _moods = innertube.moods();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.exploreNew),
              Tab(text: l10n.exploreCharts),
              Tab(text: l10n.exploreMoods),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Shelves(future: _newReleases),
                _Shelves(future: _charts),
                _Moods(future: _moods),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows of covers, or an honest report of why there are none.
class _Shelves extends StatelessWidget {
  const _Shelves({required this.future});

  final Future<List<Shelf>> future;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<Shelf>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Empty(text: '${snapshot.error}');
        }

        final shelves = snapshot.data ?? const <Shelf>[];
        if (shelves.isEmpty) return _Empty(text: l10n.homeEmptyBody);

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: shelves.length,
          itemBuilder: (context, index) => ShelfRow(shelf: shelves[index]),
        );
      },
    );
  }
}

/// Moods and genres, as a wall of chips rather than rows: they are labels, not
/// records, and nothing about them is worth a cover-sized tile.
class _Moods extends StatelessWidget {
  const _Moods({required this.future});

  final Future<List<Playlist>> future;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<Playlist>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final moods = snapshot.data ?? const <Playlist>[];
        if (moods.isEmpty) return _Empty(text: l10n.homeEmptyBody);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in moods)
                ActionChip(
                  label: Text(mood.title),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MoodScreen(mood: mood),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One mood or genre: the playlists YouTube files under it.
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key, required this.mood});

  final Playlist mood;

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  late final Future<List<Shelf>> _page = innertube.moodPage(widget.mood);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mood.title)),
      body: _Shelves(future: _page),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
