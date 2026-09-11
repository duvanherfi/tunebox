import 'package:flutter/material.dart';

import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/chip_row.dart';
import '../shared/shelf_row.dart';
import '../shared/skeleton.dart';
import '../shared/song_pages.dart';

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
  /// Every shelf read so far, in the order the pages arrived. That order is
  /// editorial: the front page leads with what it wants seen first.
  final _shelves = <Shelf>[];

  /// The moods YouTube offers over its own home. Kept across a refiltering,
  /// since only the first page of each carries them and they are the same ten.
  var _chips = const <Playlist>[];

  /// The selected mood's token, or null for the front page as it comes.
  String? _mood;

  /// Where the shelves carry on, or null once the feed has ended.
  String? _nextToken;

  /// Which reading a late answer belongs to. Tapping a second mood while the
  /// first is still in the air must not pile one feed onto the other.
  var _reads = 0;

  /// Whether a page is already on its way, since the foot of the list asks for
  /// the next one every time it is built.
  var _busy = false;

  Object? _error;
  var _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final reading = ++_reads;
    setState(() {
      _shelves.clear();
      _nextToken = null;
      _error = null;
      _loading = true;
    });

    try {
      final page = await innertube.homeFeed(params: _mood);
      if (!mounted || reading != _reads) return;
      setState(() {
        _shelves.addAll(page.shelves);
        if (page.chips.isNotEmpty) _chips = page.chips;
        _nextToken = page.nextToken;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || reading != _reads) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// The shelves under the ones already read.
  ///
  /// Asked for as the list reaches its foot rather than all at once on opening:
  /// the front page is what the app launches into, and four requests deep is a
  /// lot to wait through for rows nobody has scrolled to yet.
  Future<void> _readMore() async {
    final token = _nextToken;
    if (token == null || _busy) return;
    _busy = true;
    final reading = _reads;

    try {
      final page = await innertube.homeFeed(params: _mood, continuation: token);
      if (!mounted || reading != _reads) return;
      setState(() {
        _shelves.addAll(page.shelves);
        // A token that came back as the one just spent would ask for the same
        // page for as long as anyone kept scrolling.
        _nextToken = page.nextToken == token ? null : page.nextToken;
      });
    } catch (_) {
      // What arrived is still the front page. A page that never came stops the
      // reading there instead of throwing away the shelves already on screen.
      if (mounted && reading == _reads) setState(() => _nextToken = null);
    } finally {
      _busy = false;
    }
  }

  void _pick(String? mood) {
    if (mood == _mood) return;
    _mood = mood;
    _read();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        if (_chips.isNotEmpty)
          ChipRow(options: [
            (
              label: l10n.filterAll,
              selected: _mood == null,
              onSelected: () => _pick(null),
            ),
            for (final chip in _chips)
              (
                label: chip.title,
                selected: _mood == chip.params,
                onSelected: () => _pick(chip.params),
              ),
          ]),
        Expanded(child: _body(l10n)),
      ],
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) return const ShelfSkeleton(rows: 3);

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: l10n.homeErrorTitle,
        detail: '$_error',
        action: FilledButton.tonal(
          onPressed: _read,
          child: Text(l10n.retry),
        ),
      );
    }

    if (_shelves.isEmpty) {
      return _Message(
        icon: Icons.library_music_outlined,
        title: l10n.homeEmptyTitle,
        detail: l10n.homeEmptyBody,
        action: FilledButton.tonal(
          onPressed: _read,
          child: Text(l10n.retry),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _read,
      child: ListView.builder(
        padding:
            EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
        itemCount: _shelves.length + (_nextToken == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index < _shelves.length) return ShelfRow(shelf: _shelves[index]);

          // Building the foot of the list is what asking for the next page
          // means here: it is only built when the list has been scrolled that
          // far. The request lands after this frame, so the rebuild it causes
          // is not one inside a build.
          _readMore();
          return const MoreComing();
        },
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
