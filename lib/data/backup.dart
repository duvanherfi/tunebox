import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'play_history.dart';

/// Copies of what this app knows that YouTube does not.
///
/// The listening log and the settings: everything the account already holds is
/// deliberately left out — likes and playlists are restored by signing in, and
/// a backup that duplicates them would go stale the moment it was written.
/// Downloaded audio is left out too, for the obvious reason.
///
/// Backups are written where a phone's file manager can reach them, so they can
/// be copied off the device by whatever means the owner prefers.
class Backup {
  Backup({required PlayHistory history, Directory? directory})
      : _history = history,
        _directory = directory;

  static const _lastBackupKey = 'last_backup_at';
  static const _automaticKey = 'automatic_backup';

  /// How many copies to keep. Enough to go back past a mistake noticed a few
  /// days late, few enough that they never become the storage problem.
  static const _keep = 5;

  final PlayHistory _history;
  Directory? _directory;

  bool get automatic => _automatic;
  bool _automatic = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _automatic = prefs.getBool(_automaticKey) ?? false;
  }

  Future<void> setAutomatic(bool value) async {
    _automatic = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_automaticKey, value);
  }

  /// Writes a copy if one is enabled and the last is a day old.
  ///
  /// Called at startup rather than on a schedule: a music player is not running
  /// in the background waiting to write files, and "once a day, whenever you
  /// happen to open it" is what a daily backup means on a phone.
  Future<void> maybeWriteAutomatic() async {
    if (!_automatic) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastBackupKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    if (age < const Duration(days: 1).inMilliseconds) return;

    await write();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Writes a copy and returns the file. Named by the day it was taken, so a
  /// second copy on the same day replaces the first rather than piling up.
  Future<File> write() async {
    final directory = await _resolve();
    final day = DateTime.now().toIso8601String().split('T').first;
    final file = File('${directory.path}/tunebox-$day.json');

    final prefs = await SharedPreferences.getInstance();
    await file.writeAsString(jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'history': jsonDecode(_history.export()),
      'settings': {
        for (final key in prefs.getKeys())
          if (!_private.contains(key)) key: prefs.get(key),
      },
    }));

    await _prune();
    return file;
  }

  /// The copies on the device, newest first.
  Future<List<File>> list() async {
    final directory = await _resolve();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Puts a copy back. The listening log is replaced wholesale rather than
  /// merged: a backup is a photograph of a moment, and merging two would
  /// invent a history that never happened.
  Future<void> restore(File file) async {
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Ese archivo no es una copia de Tunebox');
    }

    final history = json['history'];
    if (history != null) await _history.import(jsonEncode(history));

    final settings = json['settings'];
    if (settings is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in settings.entries) {
        if (_private.contains(entry.key)) continue;
        final value = entry.value;
        if (value is bool) await prefs.setBool(entry.key, value);
        if (value is int) await prefs.setInt(entry.key, value);
        if (value is double) await prefs.setDouble(entry.key, value);
        if (value is String) await prefs.setString(entry.key, value);
        if (value is List) {
          await prefs.setStringList(entry.key, value.cast<String>());
        }
      }
    }
  }

  /// Preference keys a backup must never carry. Credentials live in secure
  /// storage, but the flags around them are still nobody's business in a file
  /// that gets copied to a computer.
  static const _private = {'last_backup_at'};

  Future<void> _prune() async {
    final files = await list();
    for (final file in files.skip(_keep)) {
      await file.delete();
    }
  }

  Future<Directory> _resolve() async {
    return _directory ??= await () async {
      // The app's own folder on shared storage: reachable from a file manager
      // without asking for permission to read the whole device.
      final external = await getExternalStorageDirectory();
      final directory = Directory(
        '${(external ?? await getApplicationSupportDirectory()).path}/backups',
      );
      await directory.create(recursive: true);
      return directory;
    }();
  }
}
