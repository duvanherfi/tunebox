import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/song.dart';

/// Music already on the phone.
///
/// Files rather than a media database: the folders people keep music in are
/// public, and walking them needs one permission and no plugin that has to be
/// kept alive across Android versions. The cost is metadata — a file knows its
/// name and where it sits, not who played it — so the name is the title and the
/// folder is the artist, which is exactly what a well-kept music folder encodes
/// anyway.
class DeviceSongs extends ChangeNotifier {
  DeviceSongs({List<Directory>? roots}) : _roots = roots;

  /// Where music lives on Android. Scanned in order, deepest folders included.
  static const _defaultRoots = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Documents',
  ];

  static const _extensions = {'.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg'};

  /// The mark that tells the player this track is a path rather than a video.
  static const prefix = 'local:';

  final List<Directory>? _roots;

  List<Song> _songs = const [];
  bool _scanning = false;

  List<Song> get songs => _songs;
  bool get scanning => _scanning;

  /// Asks for access to the device's audio, then reads it.
  ///
  /// Returns false when the permission was refused, which is a decision to be
  /// reported rather than retried.
  Future<bool> scan() async {
    if (!await _permitted()) return false;

    _scanning = true;
    notifyListeners();
    try {
      final found = <Song>[];
      for (final directory in _roots ?? _defaultRoots.map(Directory.new)) {
        if (!directory.existsSync()) continue;
        await for (final entry in directory.list(recursive: true, followLinks: false)) {
          if (entry is! File) continue;
          final path = entry.path;
          final dot = path.lastIndexOf('.');
          if (dot < 0 || !_extensions.contains(path.substring(dot).toLowerCase())) {
            continue;
          }
          found.add(_songFrom(entry));
        }
      }
      found.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      _songs = found;
      return true;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  static Song _songFrom(File file) {
    final segments = file.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final name = segments.last;
    final folder = segments.length > 1 ? segments[segments.length - 2] : '';
    final dot = name.lastIndexOf('.');

    return Song(
      videoId: '$prefix${file.path}',
      title: dot > 0 ? name.substring(0, dot) : name,
      subtitle: folder,
      artist: folder.isEmpty ? null : folder,
    );
  }

  /// Android 13 split storage permissions by media type; older versions have
  /// only the blanket one. Asking for both and accepting either keeps this
  /// working in both worlds.
  Future<bool> _permitted() async {
    if (await Permission.audio.request().isGranted) return true;
    return Permission.storage.request().isGranted;
  }

  /// Where a local track's audio is, given the id it was published under.
  static String pathOf(String videoId) => videoId.startsWith(prefix)
      ? videoId.substring(prefix.length)
      : videoId;

  static bool isLocal(String videoId) => videoId.startsWith(prefix);
}
