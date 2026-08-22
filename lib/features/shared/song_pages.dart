import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/song.dart';
import '../../data/retired_ids.dart';
import '../../main.dart';

/// What has arrived so far of a list that comes a page at a time.
typedef SongPagesView = ({
  /// Every track read up to now, in the order the pages arrived.
  List<Song> songs,

  /// False while more is still coming, so a screen can say so at the foot of
  /// what it already has.
  bool done,

  /// Why the reading stopped short, if it did. What arrived before it is still
  /// in [songs] and is still the account's.
  Object? error,

  /// Starts the whole reading again, from the first page.
  VoidCallback reload,
});

/// Reads a list that arrives a page at a time and rebuilds as each page lands.
///
/// A library surface answers a hundred rows and hides the rest behind a
/// continuation, so a screen shown from one page is a screen that lies about
/// its own length — against a real account a long playlist is fifteen more
/// requests. Waiting for the last of them would leave it blank for all of that,
/// so what has arrived is painted and the rest lands underneath it.
///
/// Only the reading lives here. A library tab paints a flat list, a playlist
/// paints a header above one and an album numbers its rows, so what to make of
/// [SongPagesView] is each caller's own business.
class SongPages extends StatefulWidget {
  const SongPages({
    super.key,
    required this.pages,
    required this.build,
    this.first = const [],
    this.list,
    this.mergeById = false,
  });

  /// Called to start the reading, and again on every reload.
  final Stream<List<Song>> Function() pages;

  /// Tracks that were already in hand before the reading started — an album's
  /// first page arrives with its cover and its name, and asking for it a second
  /// time would be the slowest request of the lot, repeated.
  final List<Song> first;

  /// Which list this is, for the tracks the listener took off it — one of the
  /// names on [RetiredIds].
  ///
  /// Null on the surfaces that offer no way to remove anything, an album or a
  /// search result, which must not inherit another surface's withdrawals.
  final String? list;

  /// Whether a track arriving again replaces the one already listed.
  ///
  /// Off by default, because a playlist can hold the same track twice and each
  /// of those rows is its own row. On where the list is fed from two sources
  /// that describe the same listening: the history is told first by the device,
  /// instantly and with no menu — a track read back from the play log is a name
  /// and a cover — and then by the account, which answers with the row YouTube
  /// attached its actions to. The later telling wins, in the place the first one
  /// already had, so the order stays the order it was heard in.
  final bool mergeById;

  final Widget Function(SongPagesView view) build;

  @override
  State<SongPages> createState() => _SongPagesState();
}

class _SongPagesState extends State<SongPages>
    with AutomaticKeepAliveClientMixin {
  final _songs = <Song>[];
  StreamSubscription<List<Song>>? _reading;
  Object? _error;
  var _done = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(SongPages old) {
    super.didUpdateWidget(old);
    // A screen that swapped what it is reading — a different playlist behind
    // the same route — has to start over rather than pile the new list onto
    // the old one.
    if (old.pages != widget.pages) _read();
  }

  void _read() {
    _reading?.cancel();
    setState(() {
      _songs
        ..clear()
        ..addAll(widget.first);
      _error = null;
      _done = false;
    });
    _reading = widget.pages().listen(
      (page) => setState(() => _add(page)),
      // A page that never came is not a reason to empty the screen: what did
      // arrive is still the account's, and the retry is the same pull down.
      onError: (Object error) => setState(() {
        _error = error;
        _done = true;
      }),
      onDone: () => setState(() => _done = true),
    );
  }

  void _add(List<Song> page) {
    if (!widget.mergeById) {
      _songs.addAll(page);
      return;
    }
    for (final song in page) {
      final at = _songs.indexWhere((listed) => listed.videoId == song.videoId);
      if (at == -1) {
        _songs.add(song);
      } else {
        _songs[at] = song;
      }
    }
  }

  @override
  void dispose() {
    _reading?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = widget.list;
    if (list == null) return _view(_songs);

    // Rebuilt from the notifier rather than filtered once on arrival: the row
    // is removed while this list is already on screen, and the page it came in
    // is not going to be read again.
    return ListenableBuilder(
      listenable: retiredIds,
      builder: (context, _) => _view([
        for (final song in _songs)
          if (!retiredIds.isRetired(list, song.videoId)) song,
      ]),
    );
  }

  Widget _view(List<Song> songs) => widget.build((
        songs: List.unmodifiable(songs),
        done: _done,
        error: _error,
        reload: _read,
      ));
}

/// The foot of a list that has not finished arriving.
///
/// Deliberately wordless: what it says is "there is more under this", and a
/// turning circle says that in every language the app is in.
class MoreComing extends StatelessWidget {
  const MoreComing({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
