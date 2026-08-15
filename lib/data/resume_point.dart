import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models/song.dart';

/// Where the music was when the app last stopped.
///
/// Closing a music player is not the same as finishing with it: the queue, the
/// track and the second it reached are all still the answer to "what was I
/// listening to". Without this, reopening the app is an empty screen and the
/// question has to be answered again by hand — and a car that connects later
/// has nothing to offer either.
class ResumePoint {
  ResumePoint({File? file}) : _file = file;

  static const _fileName = 'resume.json';

  /// Enough of a queue to be worth restoring. A radio can run to hundreds of
  /// tracks, and the tail of one is nobody's plan.
  static const _maxQueue = 200;

  File? _file;

  List<Song> songs = const [];
  int index = 0;
  Duration position = Duration.zero;
  bool shuffled = false;
  int repeatMode = 0;

  bool get isEmpty => songs.isEmpty || index < 0 || index >= songs.length;
  Song? get song => isEmpty ? null : songs[index];

  Future<void> load() async {
    final file = await _resolve();
    if (!file.existsSync()) return;

    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, dynamic>) return;

      songs = (json['songs'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList();
      index = json['index'] as int? ?? 0;
      position = Duration(milliseconds: json['positionMs'] as int? ?? 0);
      shuffled = json['shuffled'] as bool? ?? false;
      repeatMode = json['repeat'] as int? ?? 0;
    } catch (_) {
      // A resume point that cannot be read is the same as not having one.
      songs = const [];
    }
  }

  Future<void> save({
    required List<Song> songs,
    required int index,
    required Duration position,
    required bool shuffled,
    required int repeatMode,
  }) async {
    this.songs = songs.length > _maxQueue
        ? songs.sublist(0, _maxQueue.clamp(index + 1, songs.length))
        : songs;
    this.index = index;
    this.position = position;
    this.shuffled = shuffled;
    this.repeatMode = repeatMode;

    final file = await _resolve();
    await file.writeAsString(jsonEncode({
      'songs': [for (final song in this.songs) song.toJson()],
      'index': index,
      'positionMs': position.inMilliseconds,
      'shuffled': shuffled,
      'repeat': repeatMode,
    }));
  }

  Future<void> clear() async {
    songs = const [];
    final file = await _resolve();
    if (file.existsSync()) await file.delete();
  }

  Future<File> _resolve() async {
    return _file ??= File(
      '${(await getApplicationSupportDirectory()).path}/$_fileName',
    );
  }
}
