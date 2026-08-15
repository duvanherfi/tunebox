import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/song.dart';

/// One listen: what was played and when.
class Play {
  const Play({required this.song, required this.at});

  final Song song;
  final DateTime at;

  Map<String, Object?> toJson() => {
        ...song.toJson(),
        'at': at.millisecondsSinceEpoch,
      };

  factory Play.fromJson(Map<String, dynamic> json) => Play(
        song: Song.fromJson(json),
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
      );
}

/// Everything this app has played, with the times.
///
/// YouTube is told about every listen too, but what it does with that is its
/// business — it writes on its own terms and reads back on its own schedule.
/// This is the record Tunebox controls: it fills the History tab the instant a
/// track starts, works signed out, and is what the listening statistics are
/// counted from.
///
/// Kept as a file rather than a preference because it is a log, not a setting:
/// it grows to thousands of rows, and preferences are read whole into memory at
/// startup. A file with one JSON array is enough at this size — a database
/// would buy indexes that a few thousand entries do not need.
class PlayHistory {
  PlayHistory({this.limit = 5000, File? file}) : _file = file;

  /// Where the old, deduplicated history lived. Read once and then forgotten,
  /// so nobody loses what they listened to across the change.
  static const _legacyKey = 'play_history';

  static const _fileName = 'play_log.json';

  /// Roughly a year of heavy listening. Older plays fall off the end; the
  /// statistics only look back a month anyway.
  final int limit;

  File? _file;
  List<Play> _plays = const [];

  /// Newest first, one entry per play.
  List<Play> get plays => _plays;

  /// Newest first, one entry per track — what a history screen shows.
  List<Song> get songs {
    final seen = <String>{};
    return [
      for (final play in _plays)
        if (seen.add(play.song.videoId)) play.song,
    ];
  }

  Future<void> load() async {
    final file = await _resolve();
    if (file.existsSync()) {
      _plays = _decode(file.readAsStringSync());
      return;
    }
    await _migrateFromPreferences();
  }

  Future<void> record(Song song) async {
    _plays = [Play(song: song, at: DateTime.now()), ..._plays];
    if (_plays.length > limit) _plays = _plays.sublist(0, limit);
    await _save();
  }

  Future<void> clear() async {
    _plays = const [];
    await _save();
  }

  /// The tracks played most since [since], most-played first.
  List<({Song song, int plays})> topSongs(DateTime since, {int take = 20}) {
    final counts = <String, int>{};
    final songs = <String, Song>{};

    for (final play in _plays) {
      if (play.at.isBefore(since)) continue;
      counts.update(play.song.videoId, (n) => n + 1, ifAbsent: () => 1);
      songs.putIfAbsent(play.song.videoId, () => play.song);
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in ranked.take(take))
        (song: songs[entry.key]!, plays: entry.value),
    ];
  }

  /// The artists played most since [since]. Tracks whose row never named an
  /// artist are left out rather than lumped together under a blank.
  List<({String artist, int plays})> topArtists(
    DateTime since, {
    int take = 20,
  }) {
    final counts = <String, int>{};

    for (final play in _plays) {
      if (play.at.isBefore(since)) continue;
      final artist = play.song.artist;
      if (artist == null || artist.isEmpty) continue;
      counts.update(artist, (n) => n + 1, ifAbsent: () => 1);
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in ranked.take(take))
        (artist: entry.key, plays: entry.value),
    ];
  }

  /// How many plays happened since [since].
  int countSince(DateTime since) =>
      _plays.where((play) => !play.at.isBefore(since)).length;

  /// The whole log, for the backup file.
  String export() => jsonEncode(_plays.map((play) => play.toJson()).toList());

  /// Replaces the log with a backup's contents.
  Future<void> import(String contents) async {
    _plays = _decode(contents);
    await _save();
  }

  Future<File> _resolve() async {
    return _file ??= File(
      '${(await getApplicationSupportDirectory()).path}/$_fileName',
    );
  }

  Future<void> _save() async {
    final file = await _resolve();
    await file.parent.create(recursive: true);
    await file.writeAsString(export());
  }

  static List<Play> _decode(String contents) {
    try {
      final rows = jsonDecode(contents);
      if (rows is! List) return const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map((row) {
            try {
              return Play.fromJson(row);
            } catch (_) {
              return null; // One bad row is not worth losing the rest over.
            }
          })
          .whereType<Play>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Carries over the history written before this was a log.
  ///
  /// Those entries had no timestamps — only an order — so they are stamped a
  /// minute apart going backwards from now. That is a fiction, but a harmless
  /// one: it preserves the order, and the statistics only ever look at recent
  /// weeks, which these entries will fall out of on their own.
  Future<void> _migrateFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_legacyKey);
    if (stored == null || stored.isEmpty) return;

    final now = DateTime.now();
    _plays = [
      for (var i = 0; i < stored.length; i++)
        if (_songOrNull(stored[i]) case final Song song)
          Play(song: song, at: now.subtract(Duration(minutes: i + 1))),
    ];
    await _save();
    await prefs.remove(_legacyKey);
  }

  static Song? _songOrNull(String encoded) {
    try {
      return Song.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
