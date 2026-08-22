import 'package:flutter/foundation.dart';

/// What the listener has taken off a list during this session.
///
/// What a tab shows is the page the network answered with, and nobody edits
/// that page: a track removed from the library or from the history stayed on
/// screen until the list was read again, which reads as an action that did not
/// work. This is the same idea as [Likes]'s record of what was toggled here —
/// what happened on this device outranks a page that was already on its way.
///
/// Kept per list rather than as one set of ids, because these are different
/// lists that happen to hold the same things: taking a song out of the history
/// says nothing about the library, and dropping it from one playlist leaves it
/// in every other.
///
/// Ids rather than tracks, so the same store answers for the shelf of playlists
/// as well: a list deleted from its own screen has to leave the tab that listed
/// it, and that tab reads its playlists once and keeps them.
///
/// In memory only, and deliberately: the next read of the list comes back
/// without the track, so there is nothing left to remember. Anything still here
/// after a relaunch would be a second, staler copy of the account.
class RetiredIds extends ChangeNotifier {
  /// The account's library — what YouTube Music shows under Library › Songs.
  static const library = 'library';

  /// The account's listening history.
  static const history = 'history';

  /// The account's liked songs.
  static const likes = 'likes';

  /// A playlist is its own list, named by its id.
  static String playlist(String playlistId) => 'playlist:$playlistId';

  /// The shelf of the account's playlists, whose ids are browse ids rather than
  /// video ids. Deleting a list is what takes one off it.
  static const playlists = 'playlists';

  final _byList = <String, Set<String>>{};

  /// Takes [id] off [list], and says so.
  ///
  /// Silent when it was already gone: a rebuild for something that did not
  /// change is a frame spent on nothing.
  void retire(String list, String id) {
    if (_byList.putIfAbsent(list, () => <String>{}).add(id)) {
      notifyListeners();
    }
  }

  bool isRetired(String list, String id) =>
      _byList[list]?.contains(id) ?? false;

  /// Forgets everything. For tests, and for signing out — the next account's
  /// lists are not this one's.
  void clear() {
    if (_byList.isEmpty) return;
    _byList.clear();
    notifyListeners();
  }
}
