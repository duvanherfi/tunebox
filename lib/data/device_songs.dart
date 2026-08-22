import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/song.dart';

/// Music already on the device.
///
/// Files rather than a media database: the folders people keep music in are
/// public, and walking them needs one permission and no plugin that has to be
/// kept alive across Android versions. The cost is metadata — a file knows its
/// name and where it sits, not who played it — so the name is the title and the
/// folder is the artist, which is exactly what a well-kept music folder encodes
/// anyway.
class DeviceSongs extends ChangeNotifier {
  DeviceSongs({List<Directory>? roots, Set<String>? extensions})
      : _roots = roots,
        _extensions = extensions ?? extensionsFor(Platform.operatingSystem);

  /// Containers both players open. The rest is decided per platform, because a
  /// row that cannot be opened is worse than a row that is missing: it looks
  /// like music and answers silence.
  static const _common = {'.mp3', '.m4a', '.aac', '.flac', '.wav'};

  /// What the platform's own player can decode.
  ///
  /// ExoPlayer reads Ogg, Opus, WebM and Matroska and has no AIFF extractor;
  /// AVFoundation is the other way round.
  static Set<String> extensionsFor(String platform) => switch (platform) {
        'android' => const {
            ..._common,
            '.ogg',
            '.oga',
            '.opus',
            '.webm',
            '.mka',
            '.m4b',
          },
        'macos' => const {..._common, '.aiff', '.aif', '.m4b'},
        _ => const {},
      };

  /// Where to start walking.
  ///
  /// Android grants its whole shared storage behind one permission, so there is
  /// one root and everything under it. A sandboxed Mac grants folder by folder,
  /// and only Music and Downloads have an entitlement — inside the container
  /// macOS links them under `HOME` once that entitlement is granted, so the
  /// container's own home is the right place to look and no bookmark is needed.
  static List<String> rootsFor(String platform,
      {Map<String, String>? environment}) {
    switch (platform) {
      case 'android':
        return const ['/storage/emulated/0'];
      case 'macos':
        final base = (environment ?? Platform.environment)['HOME'];
        return base == null ? const [] : ['$base/Music', '$base/Downloads'];
      default:
        return const [];
    }
  }

  /// App data rather than anyone's music, and on Android 11 and later its
  /// `data` and `obb` throw at whoever lists them.
  static const _skippedAtRoot = {'Android'};

  /// The mark that tells the player this track is a path rather than a video.
  static const prefix = 'local:';

  final List<Directory>? _roots;
  final Set<String> _extensions;

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
      final roots = _roots ??
          rootsFor(Platform.operatingSystem).map(Directory.new).toList();
      for (final directory in roots) {
        await _walk(directory, found, atRoot: true);
      }
      found.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      _songs = found;
      return true;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Walks one folder, by hand rather than with `list(recursive: true)`.
  ///
  /// A recursive listing is a single stream, so the first folder that refuses
  /// to be read — `Android/data` on any modern phone — ends it, and everything
  /// still unvisited is lost with it. Recursing a level at a time makes a
  /// refusal cost that one folder.
  Future<void> _walk(Directory directory, List<Song> found,
      {bool atRoot = false}) async {
    final List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } on FileSystemException {
      return;
    }

    for (final entry in entries) {
      final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty,
          orElse: () => '');
      // Hidden by the only convention the platforms share.
      if (name.startsWith('.')) continue;

      if (entry is Directory) {
        if (atRoot && _skippedAtRoot.contains(name)) continue;
        await _walk(entry, found);
      } else if (entry is File) {
        final dot = name.lastIndexOf('.');
        if (dot < 0 || !_extensions.contains(name.substring(dot).toLowerCase())) {
          continue;
        }
        found.add(_songFrom(entry));
      }
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
  ///
  /// macOS has nothing to ask at runtime: its answer was decided when the app
  /// was signed, by whether the entitlement is there. Everywhere else there are
  /// no roots to walk, so there is nothing to ask for either — and
  /// permission_handler ships no desktop implementation, so asking threw
  /// `MissingPluginException` out of the library tab rather than answering no.
  Future<bool> _permitted() async {
    if (Platform.isMacOS) return true;
    if (!Platform.isAndroid) return false;
    if (await Permission.audio.request().isGranted) return true;
    return Permission.storage.request().isGranted;
  }

  /// Where a local track's audio is, given the id it was published under.
  static String pathOf(String videoId) => videoId.startsWith(prefix)
      ? videoId.substring(prefix.length)
      : videoId;

  static bool isLocal(String videoId) => videoId.startsWith(prefix);
}
