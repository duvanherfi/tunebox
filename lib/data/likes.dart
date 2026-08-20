import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/innertube/innertube_client.dart';
import 'models/song.dart';

/// Which tracks the account has liked, read as the screen asks about them.
///
/// YouTube does not say whether a track is liked in any response this app
/// reads — that state arrives only inside the watch page's menus, so colouring
/// a list would mean a page per row. What is cheap is the liked list itself,
/// and the answer to "is this liked" is whether the id is in it.
///
/// It is read lazily and in order, because the two questions cost differently:
/// knowing a track *is* liked can stop at the page that names it, while knowing
/// it is *not* means having read the list to the end. So nothing is fetched
/// until a heart asks about a track that is not in the set yet, and the crawl
/// advances only while something on screen keeps asking. A listener who opens
/// the app and plays what was already playing costs no requests at all.
///
/// Deliberately not persisted. A saved copy would age badly against likes made
/// on other devices, and it is no longer needed: the list is read again on
/// every launch that looks at one.
class Likes extends ChangeNotifier {
  Likes(this._innertube, {Duration pageGap = const Duration(milliseconds: 400)})
      : _pageGap = pageGap {
    _innertube.session?.addListener(_onSessionChanged);
  }

  final InnertubeClient _innertube;

  /// How long to wait between pages.
  ///
  /// Each page is a large response decoded on this isolate — the same cost as
  /// opening any list in the app. Spacing them apart leaves frames in between
  /// for the list to keep scrolling, and gives the rows that are on screen a
  /// chance to ask again, which is what tells the crawl to carry on.
  final Duration _pageGap;

  /// Ids the account's list has named so far.
  final _fromAccount = <String>{};

  /// What was toggled here, which outranks the list: the write already went
  /// through, so a page read afterwards can still be describing the account
  /// from a moment ago.
  final _toggledHere = <String, bool>{};

  String? _nextToken;
  var _readEverything = false;
  var _reading = false;
  var _asked = false;

  bool isLiked(String videoId) {
    final toggled = _toggledHere[videoId];
    if (toggled != null) return toggled;
    if (_fromAccount.contains(videoId)) return true;

    // Not knowing looks the same as not liked, and asking is what makes the
    // answer arrive: the heart fills in when the page that names it lands.
    _readMore();
    return false;
  }

  /// Whether liking is possible at all — it writes to an account, and without
  /// one the control should not be offered anywhere, notification included.
  bool get canLike => _innertube.session?.isSignedIn ?? false;

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
  }

  void _apply(String videoId, bool? liked) {
    if (liked == null) {
      _toggledHere.remove(videoId);
    } else {
      _toggledHere[videoId] = liked;
    }
    notifyListeners();
  }

  /// Records that something wants an answer, and starts reading if nothing is.
  void _readMore() {
    if (_readEverything || !canLike) return;
    _asked = true;
    if (!_reading) unawaited(_crawl());
  }

  Future<void> _crawl() async {
    _reading = true;
    try {
      while (_asked && !_readEverything) {
        _asked = false;
        final page = await _innertube.likedSongIds(continuation: _nextToken);
        _nextToken = page.nextToken;
        _readEverything = page.nextToken == null;

        if (page.ids.isNotEmpty) {
          _fromAccount.addAll(page.ids);
          notifyListeners();
        }
        if (!_readEverything) await Future<void>.delayed(_pageGap);
      }
    } catch (_) {
      // A list the network refuses is not an error to show anyone: the hearts
      // stay as they are, and the next one to ask starts the read again.
    } finally {
      _reading = false;
    }
  }

  /// Another account means another list, and nothing read so far applies.
  void _onSessionChanged() {
    _fromAccount.clear();
    _toggledHere.clear();
    _nextToken = null;
    _readEverything = false;
    _asked = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _innertube.session?.removeListener(_onSessionChanged);
    super.dispose();
  }
}
