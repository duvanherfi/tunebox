import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/sheet_body.dart';
import '../shared/shelf_row.dart';
import '../shared/skeleton.dart';
import '../shared/song_list_view.dart';

/// Where you go when you do not know what you want to hear.
///
/// Four ways of not knowing: what came out this week, what everyone else is
/// playing, what is moving right now, and what fits a mood. Each is a browse id
/// away, and they all come back as the same rows of covers the home feed is
/// built from.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  late final Future<List<Shelf>> _newReleases = innertube.newReleases();
  late final Future<List<Shelf>> _trending = innertube.trending();
  late final Future<List<Playlist>> _moods = innertube.moods();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            // Four labels do not fit a phone at every text size, and a tab
            // whose word is cut in half is worse than one that scrolls.
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: l10n.exploreNew),
              Tab(text: l10n.exploreCharts),
              Tab(text: l10n.exploreTrending),
              Tab(text: l10n.exploreMoods),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Shelves(future: _newReleases),
                const _Charts(),
                _Trending(future: _trending),
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
    return FutureBuilder<List<Shelf>>(
      future: future,
      builder: (context, snapshot) => _ShelvesView(
        state: snapshot.connectionState,
        error: snapshot.error,
        shelves: snapshot.data ?? const [],
      ),
    );
  }
}

/// The rows themselves, once somebody else has done the waiting.
///
/// Separate from [_Shelves] because the charts tab waits on a different future
/// — the page and its country menu arrive together — and wrapping that in a
/// second [FutureBuilder] made a new future on every repaint, which flashed the
/// skeleton over a list that was already there.
class _ShelvesView extends StatelessWidget {
  const _ShelvesView({
    required this.state,
    required this.shelves,
    this.error,
    this.header,
  });

  final ConnectionState state;
  final List<Shelf> shelves;
  final Object? error;

  /// Drawn above the rows, and only when there is something to filter: a
  /// control over a page that did not load is a control that does nothing.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (state != ConnectionState.done) return const ShelfSkeleton();
    if (error != null) return _Empty(text: '$error');
    if (shelves.isEmpty) return _Empty(text: l10n.homeEmptyBody);

    final rows = header == null ? shelves.length : shelves.length + 1;
    return ListView.builder(
      padding:
          EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
      itemCount: rows,
      itemBuilder: (context, index) {
        if (header != null) {
          if (index == 0) return header;
          index -= 1;
        }
        return ShelfRow(shelf: shelves[index]);
      },
    );
  }
}

/// The charts, for one country at a time.
///
/// The country is a setting rather than a tap that forgets: someone who listens
/// to another country's chart is not passing through, and `gl` — which is the
/// device's own locale — would put them back where they started on every
/// launch.
class _Charts extends StatefulWidget {
  const _Charts();

  @override
  State<_Charts> createState() => _ChartsState();
}

class _ChartsState extends State<_Charts> {
  late Future<ChartsPage> _page = innertube.chartsPage(
    country: settings.chartCountry,
  );

  /// Kept from the last answer so the button can name the country while the
  /// next one is still loading — the menu arrives with the page it filters.
  List<ChartCountry> _countries = const [];

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context)!;
    final chosen = await showModalBottomSheet<ChartCountry>(
      context: context,
      // Above the shell, or it opens under the player bar.
      useRootNavigator: true,
      showDragHandle: true,
      // Seventy countries are taller than a sheet's default third of the
      // screen, and a list that has to be dragged open to be read is a list
      // nobody scrolls.
      isScrollControlled: true,
      // Not the whole screen either: a sheet that reaches the status bar reads
      // as a page that arrived by the wrong door, and there is nothing left to
      // tap to dismiss it.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      builder: (context) => SheetBody(
        scrollable: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.chartsCountry,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _countries.length,
                itemBuilder: (context, index) {
                  final country = _countries[index];
                  return ListTile(
                    title: Text(country.name),
                    trailing: country.selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen == null || chosen.selected) return;
    await settings.setChartCountry(chosen.code);
    if (!mounted) return;
    setState(() {
      _page = innertube.chartsPage(country: chosen.code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChartsPage>(
      future: _page,
      builder: (context, snapshot) {
        final page = snapshot.data;
        if (page != null && page.countries.isNotEmpty) {
          _countries = page.countries;
        }
        final selected =
            _countries.where((country) => country.selected).firstOrNull;

        return _ShelvesView(
          state: snapshot.connectionState,
          error: snapshot.error,
          shelves: page?.shelves ?? const [],
          header: selected == null
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: ActionChip(
                      avatar: const Icon(Icons.public, size: 18),
                      label: Text(selected.name),
                      onPressed: _pick,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// What is moving right now, as a ranked list rather than a carousel: twenty
/// tracks in order are a chart, and a chart reads down, not sideways.
class _Trending extends StatelessWidget {
  const _Trending({required this.future});

  final Future<List<Shelf>> future;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<Shelf>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ShelfSkeleton();
        }
        if (snapshot.hasError) return _Empty(text: '${snapshot.error}');

        final songs = [
          for (final shelf in snapshot.data ?? const <Shelf>[]) ...shelf.songs,
        ];
        if (songs.isEmpty) return _Empty(text: l10n.homeEmptyBody);

        return SongListView(songs: songs);
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
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
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
