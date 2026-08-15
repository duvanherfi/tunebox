import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/song.dart';

/// What this app has played, kept on the device.
///
/// YouTube is told about every play too, but what it does with that is its
/// business: the account's own history is written on its terms and read back on
/// its schedule, and a listener who just pressed play should not have to wait
/// for either. This is the record Tunebox controls — it fills the History tab
/// immediately, works signed out, and merges with the account's history rather
/// than replacing it.
class PlayHistory {
  PlayHistory({this.limit = 200});

  static const _key = 'play_history';

  /// Enough to be a history and small enough to stay a preference rather than
  /// a database. Older entries fall off the end.
  final int limit;

  List<Song> _songs = const [];

  List<Song> get songs => _songs;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? const [];
    _songs = stored
        .map((entry) {
          try {
            return Song.fromJson(jsonDecode(entry) as Map<String, dynamic>);
          } catch (_) {
            return null; // A malformed entry is not worth losing the rest over.
          }
        })
        .whereType<Song>()
        .toList();
  }

  /// Puts a track at the top, where a listener expects to find what they just
  /// heard. Playing something again moves it rather than repeating it.
  Future<void> record(Song song) async {
    _songs = [song, ..._songs.where((other) => other.videoId != song.videoId)];
    if (_songs.length > limit) _songs = _songs.sublist(0, limit);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _songs.map((song) => jsonEncode(song.toJson())).toList(),
    );
  }

  Future<void> clear() async {
    _songs = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
