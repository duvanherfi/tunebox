import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/music_folders.dart';

/// A folder someone chose has to still open the next time the app starts, and
/// on a sandboxed Mac the path alone does not grant that — the bookmark does.
/// Everything here is about that round trip and about what happens when it
/// fails: an unplugged disk is not a decision to forget the folder.
void main() {
  late Directory support;
  late File file;

  setUp(() {
    support = Directory.systemTemp.createTempSync('tunebox_folders');
    file = File('${support.path}/music_folders.json');
  });
  tearDown(() => support.deleteSync(recursive: true));

  Directory folder(String name) =>
      Directory('${support.path}/$name')..createSync(recursive: true);

  group('without bookmarks, as on Windows and Linux', () {
    test('remembers a folder across a restart', () async {
      final music = folder('Music');
      final first = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await first.load();
      await first.add(music.path);

      final second = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await second.load();

      expect(second.folders.map((f) => f.path), [music.path]);
      expect(second.paths, [music.path]);
    });

    test('adding the same folder twice keeps one', () async {
      final music = folder('Music');
      final folders = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await folders.load();
      await folders.add(music.path);
      await folders.add(music.path);

      expect(folders.folders, hasLength(1));
    });

    test('keeps a folder that is not there, and does not walk it', () async {
      final gone = Directory('${support.path}/External');
      final folders = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await folders.load();
      await folders.add(gone.path);

      expect(folders.folders.single.available, isFalse);
      expect(folders.paths, isEmpty);
    });

    test('forgets a folder that was removed', () async {
      final music = folder('Music');
      final folders = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await folders.load();
      await folders.add(music.path);
      await folders.remove(music.path);

      final reopened = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await reopened.load();
      expect(reopened.folders, isEmpty);
    });
  });

  group('with bookmarks, as on macOS', () {
    test('stores what the platform hands back for the folder', () async {
      final music = folder('Music');
      final bookmarks = _FakeBookmarks();
      final folders = MusicFolders(file: file, bookmarks: bookmarks);
      await folders.load();
      await folders.add(music.path);

      expect(
        jsonDecode(file.readAsStringSync())['folders'],
        [
          {'path': music.path, 'bookmark': bookmarks.tokenFor(music.path)}
        ],
      );
    });

    test('follows a folder that moved, because the bookmark does', () async {
      final music = folder('Music');
      final bookmarks = _FakeBookmarks();
      final first = MusicFolders(file: file, bookmarks: bookmarks);
      await first.load();
      await first.add(music.path);

      final moved = folder('Elsewhere/Music');
      bookmarks.moved[bookmarks.tokenFor(music.path)!] = moved.path;

      final second = MusicFolders(file: file, bookmarks: bookmarks);
      await second.load();

      expect(second.paths, [moved.path]);
    });

    test('keeps a folder whose bookmark no longer resolves', () async {
      final music = folder('Music');
      final bookmarks = _FakeBookmarks();
      final first = MusicFolders(file: file, bookmarks: bookmarks);
      await first.load();
      await first.add(music.path);

      bookmarks.stale.add(bookmarks.tokenFor(music.path)!);

      final second = MusicFolders(file: file, bookmarks: bookmarks);
      await second.load();

      expect(second.folders.single.available, isFalse);
      expect(second.paths, isEmpty);
    });
  });

  group('a file that cannot be read', () {
    test('is the same as having no folders', () async {
      file.writeAsStringSync('not json at all');
      final folders = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await folders.load();

      expect(folders.folders, isEmpty);
    });

    test('is not there at all on a first run', () async {
      final folders = MusicFolders(file: file, bookmarks: const FolderBookmarks.none());
      await folders.load();

      expect(folders.folders, isEmpty);
    });
  });
}

/// Stands in for the platform's bookmark store: a token per path, which can be
/// pointed somewhere else or invalidated the way a real one is by moving or
/// unplugging the folder.
class _FakeBookmarks implements FolderBookmarks {
  final Map<String, String> _tokens = {};
  final Map<String, String> moved = {};
  final Set<String> stale = {};

  String? tokenFor(String path) => _tokens[path];

  @override
  Future<String?> create(String path) => Future.value(_tokens[path] ??= 'b${_tokens.length}:$path');

  @override
  Future<String?> resolve(String bookmark) => Future.value(
        stale.contains(bookmark) ? null : moved[bookmark] ?? _tokens.entries.firstWhere((e) => e.value == bookmark).key,
      );
}
