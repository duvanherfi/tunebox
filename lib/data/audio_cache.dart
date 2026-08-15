import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Audio kept around after it was played, in case it is played again.
///
/// Different from a download in intent, not in mechanism: a download is a
/// promise the listener made, and the app never deletes it. This is the app's
/// own guess, made silently, and thrown away oldest-first the moment it grows
/// past what the listener allowed.
class AudioCache {
  AudioCache({Directory? directory}) : _directory = directory;

  Directory? _directory;

  /// Ready before the first track, because playback asks for the path
  /// synchronously and cannot wait on a directory lookup.
  Future<void> load() => _resolve();

  File fileFor(String videoId) => File('${_directory!.path}/$videoId.audio');

  Future<int> sizeInBytes() async {
    final directory = await _resolve();
    var total = 0;
    await for (final entry in directory.list()) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }

  /// Deletes the least recently used files until the cache fits [limitBytes].
  ///
  /// Modification time is the clock: every play rewrites or reopens the file,
  /// so the oldest file is the one least recently listened to.
  Future<void> prune(int limitBytes) async {
    final directory = await _resolve();
    final files = <File>[];
    await for (final entry in directory.list()) {
      if (entry is File) files.add(entry);
    }

    var total = 0;
    for (final file in files) {
      total += await file.length();
    }
    if (total <= limitBytes) return;

    files.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    for (final file in files) {
      if (total <= limitBytes) break;
      total -= await file.length();
      await file.delete();
    }
  }

  Future<void> clear() async {
    final directory = await _resolve();
    await for (final entry in directory.list()) {
      if (entry is File) await entry.delete();
    }
  }

  Future<Directory> _resolve() async {
    return _directory ??= await () async {
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/audio_cache',
      );
      await directory.create(recursive: true);
      return directory;
    }();
  }
}
