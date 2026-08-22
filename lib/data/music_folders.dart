import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/platform/folder_bookmarks.dart';

export '../core/platform/folder_bookmarks.dart' show FolderBookmarks;

/// One folder someone pointed the app at, and how to reach it again.
///
/// The path is what a person recognises and what gets shown; the bookmark is
/// what actually reopens the folder after a restart, and only a sandboxed Mac
/// hands one out. `available` is the answer to "is it reachable right now" —
/// false for an unplugged disk or a folder that was deleted.
class MusicFolder {
  const MusicFolder({required this.path, this.bookmark, this.available = true});

  final String path;
  final String? bookmark;
  final bool available;

  String get name => path.split(Platform.pathSeparator).lastWhere(
        (segment) => segment.isNotEmpty,
        orElse: () => path,
      );
}

/// The folders the person added by hand, on top of what the platform gives.
///
/// A sandboxed Mac hands over Music and Downloads and nothing else: Documents,
/// the Desktop and any external disk exist only if someone picks them, and the
/// permission that a pick grants dies with the process unless it is saved as a
/// security-scoped bookmark. Everywhere else there is no sandbox to satisfy and
/// the path on its own is enough.
class MusicFolders extends ChangeNotifier {
  MusicFolders({File? file, FolderBookmarks? bookmarks})
      : _file = file,
        _bookmarks = bookmarks ?? FolderBookmarks.forPlatform();

  static const _fileName = 'music_folders.json';

  File? _file;
  final FolderBookmarks _bookmarks;

  List<MusicFolder> _folders = const [];

  List<MusicFolder> get folders => _folders;

  /// The ones worth walking: a folder that cannot be reached would only cost
  /// the scan a failed listing.
  List<String> get paths =>
      [for (final folder in _folders.where((f) => f.available)) folder.path];

  Future<void> load() async {
    final file = await _resolve();
    if (!file.existsSync()) return;

    final List<dynamic> stored;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, dynamic>) return;
      stored = json['folders'] as List? ?? const [];
    } catch (_) {
      // A list of folders that cannot be read is the same as not having one.
      return;
    }

    final loaded = <MusicFolder>[];
    for (final entry in stored.whereType<Map<String, dynamic>>()) {
      final path = entry['path'] as String?;
      if (path == null) continue;
      final bookmark = entry['bookmark'] as String?;

      // The bookmark is the authority on where the folder is now: resolving it
      // is what reopens the door, and it follows a folder that was moved.
      final reached =
          bookmark == null ? path : await _bookmarks.resolve(bookmark);

      loaded.add(MusicFolder(
        path: reached ?? path,
        bookmark: bookmark,
        available: reached != null && Directory(reached).existsSync(),
      ));
    }

    _folders = loaded;
    notifyListeners();
  }

  Future<void> add(String path) async {
    if (_folders.any((folder) => folder.path == path)) return;

    _folders = [
      ..._folders,
      MusicFolder(
        path: path,
        bookmark: await _bookmarks.create(path),
        available: Directory(path).existsSync(),
      ),
    ];
    notifyListeners();
    await _save();
  }

  Future<void> remove(String path) async {
    _folders = [
      for (final folder in _folders)
        if (folder.path != path) folder,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final file = await _resolve();
    await file.writeAsString(jsonEncode({
      'folders': [
        for (final folder in _folders)
          {'path': folder.path, 'bookmark': folder.bookmark},
      ],
    }));
  }

  Future<File> _resolve() async {
    return _file ??= File(
      '${(await getApplicationSupportDirectory()).path}/$_fileName',
    );
  }
}
