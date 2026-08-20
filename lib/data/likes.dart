import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/innertube/innertube_client.dart';
import 'models/song.dart';

/// Which tracks the account has liked.
///
/// YouTube does not say whether a track is liked in any response this app
/// reads — that state arrives only inside the watch page's menus, so colouring
/// a list would mean a page per row. What is cheap is the liked list itself,
/// and the answer to "is this liked" is whether the id is in it.
///
/// The list is read whole, in the background, and kept on disk. Measured
/// against a real account it comes back in pages of 25 to 44, so a few hundred
/// likes are a dozen requests and some seconds — too slow to answer a heart
/// that is on screen now, which is why the saved copy is what the interface
/// reads while the new one is on its way. Reading is not lazy either: nothing
/// in a list displays like state, so there is no moment of demand to hang the
/// next page on.
///
/// The saved copy ages against likes made on other devices, and the refresh is
/// what settles that: it runs on every launch and on every sign-in, and only a
/// read that reached the end of the list is allowed to take a heart away. A
/// read that broke off halfway adds what it saw and removes nothing, because
/// half a list is not evidence that anything was unliked.
class Likes extends ChangeNotifier {
  Likes(
    this._innertube, {
    File? file,
    Duration pageGap = const Duration(milliseconds: 400),
  })  : _file = file,
        _pageGap = pageGap {
    _innertube.session?.addListener(_onSessionChanged);
  }

  static const _fileName = 'likes.json';

  final InnertubeClient _innertube;
  File? _file;

  /// How long to wait between pages.
  ///
  /// Each page is a large response decoded on this isolate — the same cost as
  /// opening any list in the app. Spacing them apart leaves frames in between
  /// for whatever the listener is actually doing.
  final Duration _pageGap;

  /// What the account's list said, as last read.
  var _liked = <String>{};

  /// What was toggled here, which outranks the list: the write already went
  /// through, so a page read afterwards can still be describing the account
  /// from a moment ago.
  final _toggledHere = <String, bool>{};

  var _refreshing = false;

  bool isLiked(String videoId) =>
      _toggledHere[videoId] ?? _liked.contains(videoId);

  /// Whether liking is possible at all — it writes to an account, and without
  /// one the control should not be offered anywhere, notification included.
  bool get canLike => _innertube.session?.isSignedIn ?? false;

  /// Reads back the list saved by the last run.
  Future<void> load() async {
    final file = await _resolve();
    if (!file.existsSync()) return;

    try {
      final json = jsonDecode(file.readAsStringSync());
      final ids = json is Map<String, dynamic> ? json['ids'] : null;
      if (ids is! List) return;
      _liked = ids.whereType<String>().toSet();
      notifyListeners();
    } catch (_) {
      // A list that cannot be read is the same as not having one: the hearts
      // stay empty until the refresh answers.
    }
  }

  /// Reads the account's list again, from the first page to the last.
  Future<void> refresh() async {
    if (!canLike || _refreshing) return;
    _refreshing = true;

    final fresh = <String>{};
    var complete = false;
    try {
      String? token;
      while (true) {
        final page = await _innertube.likedSongIds(continuation: token);
        fresh.addAll(page.ids);
        token = page.nextToken;
        if (token == null) {
          complete = true;
          break;
        }
        await Future<void>.delayed(_pageGap);
      }
    } catch (_) {
      // Whatever arrived is still true; what did not arrive is not evidence.
    } finally {
      _refreshing = false;
    }

    if (!complete && fresh.isEmpty) return;
    _liked = complete ? fresh : (_liked..addAll(fresh));
    notifyListeners();
    await _save();
  }

  /// Flips the heart at once, then tells YouTube. On failure it flips back —
  /// an icon that lies about what the account holds is worse than a stutter.
  Future<void> toggle(Song song) async {
    final previous = _toggledHere[song.videoId];
    final liked = !isLiked(song.videoId);
    _apply(song.videoId, liked);
    try {
      await _innertube.setLiked(song.videoId, liked);
    } catch (_) {
      _apply(song.videoId, previous);
      rethrow;
    }
    // Saved rather than left to the next refresh, so a restart in between does
    // not undo what the listener just did.
    if (liked) {
      _liked.add(song.videoId);
    } else {
      _liked.remove(song.videoId);
    }
    await _save();
  }

  void _apply(String videoId, bool? liked) {
    if (liked == null) {
      _toggledHere.remove(videoId);
    } else {
      _toggledHere[videoId] = liked;
    }
    notifyListeners();
  }

  /// Another account means another list, and nothing read so far applies.
  Future<void> _onSessionChanged() async {
    _liked = {};
    _toggledHere.clear();
    notifyListeners();

    if (!canLike) {
      final file = await _resolve();
      if (file.existsSync()) await file.delete();
      return;
    }
    await refresh();
  }

  Future<void> _save() async {
    final file = await _resolve();
    await file.writeAsString(jsonEncode({'ids': _liked.toList()}));
  }

  Future<File> _resolve() async => _file ??= File(
        '${(await getApplicationSupportDirectory()).path}/$_fileName',
      );

  @override
  void dispose() {
    _innertube.session?.removeListener(_onSessionChanged);
    super.dispose();
  }
}
