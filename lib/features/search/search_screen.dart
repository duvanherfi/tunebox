import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/playlist.dart';
import '../../data/models/search.dart';
import '../../main.dart';
import '../../data/models/song.dart';
import '../shared/chip_row.dart';
import '../shared/collection_menu.dart';
import '../shared/shelf_row.dart';
import '../shared/skeleton.dart';
import '../shared/song_list_view.dart';

/// Search over the whole YouTube Music catalogue. Works signed out; the session
/// only changes whether results are personalised.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();

  final _focus = FocusNode();

  SearchResults _results = const SearchResults();

  /// The token of the filter in force, as YouTube handed it out. Null is
  /// everything.
  String? _filter;
  String _lastQuery = '';
  bool _loading = false;
  String? _error;

  /// What YouTube would finish the typing with, and the timer that keeps this
  /// from asking on every keystroke.
  List<String> _suggestions = const [];
  Timer? _debounce;

  /// Suggestions replace the results while the field has focus and something
  /// half-typed in it — the moment when help is wanted and results are stale.
  bool get _suggesting =>
      _focus.hasFocus && _controller.text.trim().isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Asks for suggestions a beat after typing stops. A request per keystroke
  /// would be four or five in flight at once, arriving out of order.
  void _onTyped(String text) {
    setState(() {});
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final found = await innertube.searchSuggestions(text);
      if (mounted && _controller.text == text) {
        setState(() => _suggestions = found);
      }
    });
  }

  Future<void> _search({String? query}) async {
    final text = (query ?? _controller.text).trim();
    if (text.isEmpty) return;
    _lastQuery = text;
    _controller.text = text;
    _focus.unfocus();
    unawaited(recentSearches.record(text));

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await innertube.search(text, params: _filter);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _selectFilter(String? params) {
    setState(() => _filter = params);
    if (_lastQuery.isNotEmpty) _search(query: _lastQuery);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SearchBar(
            controller: _controller,
            hintText: l10n.searchHint,
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  tooltip: l10n.tipClear,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _controller.clear();
                    _results = const SearchResults();
                    _lastQuery = '';
                  }),
                ),
            ],
            focusNode: _focus,
            onSubmitted: (_) => _search(),
            onChanged: _onTyped,
          ),
        ),
        // Only shown once there is something to narrow, so an empty screen
        // stays empty instead of offering controls that do nothing.
        if (_lastQuery.isNotEmpty && !_suggesting)
          ChipRow(options: [
            (
              label: l10n.filterAll,
              selected: _filter == null,
              onSelected: () => _selectFilter(null),
            ),
            for (final filter in _results.filters)
              (
                label: filter.label,
                selected: _filter == filter.params,
                onSelected: () => _selectFilter(filter.params),
              ),
          ]),
        Expanded(child: _buildBody(l10n)),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_suggesting) {
      return _Suggestions(
        suggestions: _suggestions,
        onPick: (query) => _search(query: query),
      );
    }

    if (_lastQuery.isEmpty && recentSearches.queries.isNotEmpty) {
      return _Recents(
        onPick: (query) => _search(query: query),
      );
    }

    if (_loading) {
      return const SongListSkeleton();
    }

    if (_error != null) {
      return _Empty(
        icon: Icons.cloud_off_rounded,
        title: l10n.searchErrorTitle,
        detail: _error!,
        action: FilledButton.tonal(
          onPressed: () => _search(query: _lastQuery),
          child: Text(l10n.retry),
        ),
      );
    }

    if (_results.isEmpty) {
      return _Empty(
        icon: _lastQuery.isEmpty
            ? Icons.search_rounded
            : Icons.sentiment_dissatisfied_rounded,
        title: _lastQuery.isEmpty ? l10n.searchStartTitle : l10n.searchEmptyTitle,
        detail: _lastQuery.isEmpty ? l10n.searchStartBody : l10n.searchEmptyBody,
      );
    }

    return _Results(results: _results);
  }
}

/// Everything the search answered with, in the order it ranked it.
///
/// One column with both shapes in it, which is what YouTube Music does: an
/// album, an artist and a track sit next to each other and the metadata line
/// says which is which — YouTube writes it there itself, translated. Grouping
/// them would mean inventing sections the response never sent.
class _Results extends StatelessWidget {
  const _Results({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final rows = results.results;

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: 8 + MediaQuery.paddingOf(context).bottom),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.top && row.buttons.isNotEmpty) return _TopResultCard(result: row);
        if (row.song != null) {
          // A tap starts that track and its radio, not the other results: they
          // are ranked answers to a query, not a list anyone chose to hear in
          // order. It is the link YouTube Music puts on the same row — a video
          // id with no list behind it.
          return SongRow(
            songs: [row.song!],
            index: 0,
            startsRadio: true,
          );
        }
        return _CollectionRow(collection: row.collection!, kind: row.kind!);
      },
    );
  }
}

/// The result YouTube ranked above the rest, drawn the way it sent it.
///
/// The card is the same title, subtitle and destination as any other row — what
/// makes it a card is the two buttons YouTube attaches, and those are the
/// reason it cannot stay a row: they are the whole point of the shape. What
/// they are depends on what is on top. Measured against the real endpoint on
/// 11 September 2026: an artist gets Shuffle and Mix, an album Play and
/// Shuffle, a track Play. The labels arrive translated and are shown as they
/// came; what each button does is read from its command, never from its text.
class _TopResultCard extends StatelessWidget {
  const _TopResultCard({required this.result});

  final SearchResult result;

  void _open(BuildContext context) {
    final collection = result.collection;
    if (collection != null) {
      openCollection(context, collection, kind: result.kind);
      return;
    }
    playerService.startRadio(result.song!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final person = result.kind == CollectionKind.artist ||
        result.kind == CollectionKind.profile;
    // Read off one side or the other, never mixed: a collection with no cover
    // would otherwise fall through to a track that is not there.
    final collection = result.collection;
    final song = result.song;
    final title = collection?.title ?? song!.title;
    final subtitle = collection?.subtitle ?? song!.subtitle;
    final art = collection != null ? collection.thumbnailUrl : song!.thumbnailUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Artwork(url: art, size: 72, radius: person ? 36 : AppTheme.radiusArtwork),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Wrap rather than Row: two translated labels are not two
                // predictable widths, and a narrow phone is where they meet.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final button in result.buttons)
                      _CardButton(button: button, song: result.song),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the card's buttons, doing what its command says.
class _CardButton extends StatelessWidget {
  const _CardButton({required this.button, this.song});

  final SearchCardButton button;

  /// The track the card is about, when it is about a track. The button names
  /// the same video id, and this is the row that already carries its title and
  /// its cover — building a second one from the id alone would put a nameless
  /// track in the player.
  final Song? song;

  /// YouTube's icon names, mapped to the ones already on screen elsewhere in
  /// the app. Anything unrecognised falls back to a plain play arrow rather
  /// than to nothing: the button still works, it just looks ordinary.
  static const _icons = <String, IconData>{
    'PLAY_ARROW': Icons.play_arrow_rounded,
    'MUSIC_SHUFFLE': Icons.shuffle_rounded,
    'SHUFFLE': Icons.shuffle_rounded,
    'MIX': Icons.radio_rounded,
    'RADIO': Icons.radio_rounded,
  };

  Future<void> _run(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (button.videoId != null && song != null) {
      // The card over a track carries the track itself, so there is nothing to
      // fetch: it plays exactly as its row would.
      await playerService.startRadio(song!);
      return;
    }
    if (button.playlistId == null) return;

    try {
      final songs = await innertube.cardQueue(
        button.playlistId!,
        params: button.params,
      );
      if (songs.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryPlaylistEmpty)),
        );
        return;
      }
      // The order is the server's answer — these params are what tell one id
      // apart in order from the same id shuffled — so the player is put back in
      // sequence rather than shuffling what has already been shuffled.
      await playerService.setShuffleMode(AudioServiceShuffleMode.none);
      await playerService.setQueue(songs);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.menuFailed('$error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => _run(context),
      icon: Icon(_icons[button.icon] ?? Icons.play_arrow_rounded, size: 20),
      label: Text(button.label),
    );
  }
}

/// A result that opens a page instead of playing something.
///
/// The same shape as a track's row — cover, title, metadata line — because the
/// two are mixed into one column and a different shape would read as a
/// different list. Only the cover changes: a person is round, and the arrow
/// says this row goes somewhere rather than starting.
class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.collection, required this.kind});

  final Playlist collection;
  final CollectionKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final person =
        kind == CollectionKind.artist || kind == CollectionKind.profile;

    return InkWell(
      onTap: () => openCollection(context, collection, kind: kind),
      // The same two ways in a track's row offers, doing the collection-level
      // version of the same thing. The track list it acts on is not in a search
      // row, so it is fetched while the sheet is already open.
      onLongPress: () => showCollectionMenu(
        context,
        collection: collection,
        pending: collectionSongs(collection, kind),
        artist: kind == CollectionKind.artist,
        radio: kind != CollectionKind.profile && kind != CollectionKind.podcast,
        radioId: collection.radioPlaylistId,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Artwork(
              url: collection.thumbnailUrl,
              radius: person ? 26 : AppTheme.radiusArtwork,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    collection.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    collection.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // The width a track's menu button takes, so both kinds of row end
            // on the same line.
            SizedBox(
              width: 48,
              child: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What YouTube thinks is being typed, offered as rows to tap.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemCount: suggestions.length,
      itemBuilder: (context, index) => ListTile(
        leading: const Icon(Icons.search_rounded),
        title: Text(suggestions[index]),
        onTap: () => onPick(suggestions[index]),
      ),
    );
  }
}

/// What was looked for before, on the screen that would otherwise be empty.
class _Recents extends StatelessWidget {
  const _Recents({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: recentSearches,
      builder: (context, _) => ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.searchRecent,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: recentSearches.clear,
                  child: Text(l10n.searchRecentClear),
                ),
              ],
            ),
          ),
          for (final query in recentSearches.queries)
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(query),
              trailing: IconButton(
                tooltip: l10n.tipRemove,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => recentSearches.remove(query),
              ),
              onTap: () => onPick(query),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
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
