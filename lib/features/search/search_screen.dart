import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../core/innertube/innertube_client.dart';
import '../../data/models/song.dart';
import '../../main.dart';
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

  List<Song> _results = const [];
  SearchFilter? _filter;
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
      final results = await innertube.search(text, filter: _filter);
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

  void _selectFilter(SearchFilter? filter) {
    setState(() => _filter = filter);
    if (_lastQuery.isNotEmpty) _search(query: _lastQuery);
  }

  String _filterLabel(AppLocalizations l10n, SearchFilter filter) {
    return switch (filter) {
      SearchFilter.songs => l10n.filterSongs,
      SearchFilter.videos => l10n.filterVideos,
    };
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
                    _results = const [];
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
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: l10n.filterAll,
                  selected: _filter == null,
                  onSelected: () => _selectFilter(null),
                ),
                for (final filter in SearchFilter.values)
                  _Chip(
                    label: _filterLabel(l10n, filter),
                    selected: _filter == filter,
                    onSelected: () => _selectFilter(filter),
                  ),
              ],
            ),
          ),
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

    return SongListView(songs: _results);
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: true,
        onSelected: (_) => onSelected(),
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
