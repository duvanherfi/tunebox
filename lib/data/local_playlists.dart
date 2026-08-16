import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/song.dart';

/// A playlist that lives on the device.
class LocalPlaylist {
  LocalPlaylist({required this.id, required this.name, List<Song>? songs})
      : songs = songs ?? [];

  final String id;
  String name;
  final List<Song> songs;

  String? get thumbnailUrl => songs.isEmpty ? null : songs.first.thumbnailUrl;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'songs': [for (final song in songs) song.toJson()],
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) => LocalPlaylist(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        songs: (json['songs'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Song.fromJson)
            .toList(),
      );
}

/// Playlists made here rather than on the account.
///
/// The account's playlists are the ones that follow you between devices, and
/// they are still where "add to playlist" writes by default. These are for the
/// rest: a running order for tonight, a list nobody else should see, a way to
/// keep tracks together while signed out — none of which is worth a round trip
/// to YouTube, and one of which YouTube should not be told about at all.
class LocalPlaylists extends ChangeNotifier {
  LocalPlaylists({File? file}) : _file = file;

  static const _fileName = 'playlists.json';

  File? _file;
  List<LocalPlaylist> _playlists = [];

  List<LocalPlaylist> get all => List.unmodifiable(_playlists);

  LocalPlaylist? byId(String id) =>
      _playlists.where((playlist) => playlist.id == id).firstOrNull;

  Future<void> load() async {
    final file = await _resolve();
    if (!file.existsSync()) return;
    try {
      final rows = jsonDecode(file.readAsStringSync());
      if (rows is! List) return;
      _playlists = rows
          .whereType<Map<String, dynamic>>()
          .map(LocalPlaylist.fromJson)
          .toList();
      notifyListeners();
    } catch (_) {
      // Unreadable is the same as empty; the alternative is refusing to start.
    }
  }

  Future<LocalPlaylist> create(String name, {List<Song> songs = const []}) async {
    // Time-based ids: unique enough for a list one person makes by hand, and
    // readable when the file is opened by a human.
    final playlist = LocalPlaylist(
      id: 'pl-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      songs: List.of(songs),
    );
    _playlists = [playlist, ..._playlists];
    await _save();
    return playlist;
  }

  Future<void> rename(String id, String name) async {
    byId(id)?.name = name.trim();
    await _save();
  }

  Future<void> delete(String id) async {
    _playlists = _playlists.where((playlist) => playlist.id != id).toList();
    await _save();
  }

  /// Adds a track unless it is already there — a playlist is a set of choices,
  /// and adding the same one twice is never one of them.
  Future<void> add(String id, Song song) async {
    final playlist = byId(id);
    if (playlist == null) return;
    if (playlist.songs.contains(song)) return;
    playlist.songs.add(song);
    await _save();
  }

  Future<void> removeAt(String id, int index) async {
    final playlist = byId(id);
    if (playlist == null || index < 0 || index >= playlist.songs.length) return;
    playlist.songs.removeAt(index);
    await _save();
  }

  Future<void> move(String id, int from, int to) async {
    final playlist = byId(id);
    if (playlist == null || from < 0 || from >= playlist.songs.length) return;
    final song = playlist.songs.removeAt(from);
    playlist.songs.insert(to.clamp(0, playlist.songs.length), song);
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    final file = await _resolve();
    await file.writeAsString(
      jsonEncode([for (final playlist in _playlists) playlist.toJson()]),
    );
  }

  Future<File> _resolve() async {
    return _file ??= File(
      '${(await getApplicationSupportDirectory()).path}/$_fileName',
    );
  }
}
