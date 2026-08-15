import 'package:flutter/material.dart';

import '../../core/innertube/innertube_client.dart';
import '../../data/models/song.dart';
import '../../main.dart';
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

  List<Song> _results = const [];
  SearchFilter? _filter;
  String _lastQuery = '';
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search({String? query}) async {
    final text = (query ?? _controller.text).trim();
    if (text.isEmpty) return;
    _lastQuery = text;

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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SearchBar(
            controller: _controller,
            hintText: 'Buscar canciones o artistas',
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _controller.clear();
                    _results = const [];
                    _lastQuery = '';
                  }),
                ),
            ],
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        // Only shown once there is something to narrow, so an empty screen
        // stays empty instead of offering controls that do nothing.
        if (_lastQuery.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: 'Todo',
                  selected: _filter == null,
                  onSelected: () => _selectFilter(null),
                ),
                for (final filter in SearchFilter.values)
                  _Chip(
                    label: filter.label,
                    selected: _filter == filter,
                    onSelected: () => _selectFilter(filter),
                  ),
              ],
            ),
          ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Empty(
        icon: Icons.cloud_off_rounded,
        title: 'No se pudo buscar',
        detail: _error!,
        action: FilledButton.tonal(
          onPressed: () => _search(query: _lastQuery),
          child: const Text('Reintentar'),
        ),
      );
    }

    if (_results.isEmpty) {
      return _Empty(
        icon: _lastQuery.isEmpty
            ? Icons.search_rounded
            : Icons.sentiment_dissatisfied_rounded,
        title: _lastQuery.isEmpty ? 'Busca algo para empezar' : 'Sin resultados',
        detail: _lastQuery.isEmpty
            ? 'Canciones, artistas o álbumes de YouTube Music.'
            : 'Prueba con otro término o quita el filtro.',
      );
    }

    return SongListView(songs: _results);
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
