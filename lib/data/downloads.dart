import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/song.dart';

/// Tracks kept on the device, and the ones on their way there.
///
/// A download is a file plus the metadata needed to draw a row without asking
/// YouTube anything — that is the whole point: on a plane, in a lift, on a
/// prepaid plan, the library still works.
///
/// The index is a JSON file next to the audio. It could be a database, but
/// there is exactly one query — "is this track here, and what is it called" —
/// and a map in memory answers it.
class Downloads extends ChangeNotifier {
  Downloads({Directory? directory}) : _directory = directory;

  static const _indexName = 'downloads.json';

  Directory? _directory;

  final Map<String, Song> _songs = {};

  /// Progress of what is downloading now, from 0 to 1, by video id. A track
  /// here is not yet playable offline.
  final Map<String, double> _progress = {};

  List<Song> get songs => _songs.values.toList().reversed.toList();
  Map<String, double> get inProgress => Map.unmodifiable(_progress);

  bool has(String videoId) => _songs.containsKey(videoId);
  bool isDownloading(String videoId) => _progress.containsKey(videoId);

  Future<void> load() async {
    final index = File('${(await _resolve()).path}/$_indexName');
    if (!index.existsSync()) return;

    try {
      final rows = jsonDecode(index.readAsStringSync());
      if (rows is! List) return;
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final song = Song.fromJson(row);
        // A row whose file went missing — cleared storage, a restore onto
        // another phone — is not a download, whatever the index says.
        if (fileFor(song.videoId).existsSync()) _songs[song.videoId] = song;
      }
    } catch (_) {
      // An unreadable index means no downloads, not a broken app.
    }
  }

  /// Where a track's audio lives. Synchronous because playback asks on every
  /// track and the directory is resolved once at startup.
  File fileFor(String videoId) => File('${_directory!.path}/$videoId.audio');

  /// Fetches [url] into the downloads directory, reporting progress.
  ///
  /// The bytes come through the same local proxy playback uses, because
  /// googlevideo refuses an unbounded request and only the proxy knows how to
  /// ask for a track in pieces.
  Future<void> add(Song song, Uri url, {required String userAgent}) async {
    if (has(song.videoId) || isDownloading(song.videoId)) return;

    _progress[song.videoId] = 0;
    notifyListeners();

    final client = HttpClient();
    final partial = File('${fileFor(song.videoId).path}.part');
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      final response = await request.close();
      if (response.statusCode >= 400) {
        throw HttpException('${response.statusCode}', uri: url);
      }

      final total = response.contentLength;
      var written = 0;
      final sink = partial.openWrite();
      await response.forEach((chunk) {
        sink.add(chunk);
        written += chunk.length;
        if (total > 0) {
          _progress[song.videoId] = written / total;
          notifyListeners();
        }
      });
      await sink.close();

      // Renamed only once complete, so a half-written file is never mistaken
      // for a download when the app is killed mid-transfer.
      await partial.rename(fileFor(song.videoId).path);
      _songs[song.videoId] = song;
    } catch (_) {
      if (partial.existsSync()) await partial.delete();
      rethrow;
    } finally {
      client.close();
      _progress.remove(song.videoId);
      notifyListeners();
      await _saveIndex();
    }
  }

  Future<void> remove(String videoId) async {
    _songs.remove(videoId);
    final file = fileFor(videoId);
    if (file.existsSync()) await file.delete();
    notifyListeners();
    await _saveIndex();
  }

  Future<int> sizeInBytes() async {
    var total = 0;
    for (final song in _songs.values) {
      final file = fileFor(song.videoId);
      if (file.existsSync()) total += await file.length();
    }
    return total;
  }

  Future<Directory> _resolve() async {
    return _directory ??= await () async {
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/downloads',
      );
      await directory.create(recursive: true);
      return directory;
    }();
  }

  Future<void> _saveIndex() async {
    final index = File('${(await _resolve()).path}/$_indexName');
    await index.writeAsString(
      jsonEncode([for (final song in _songs.values) song.toJson()]),
    );
  }
}
