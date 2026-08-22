import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/device_songs.dart';

/// What a device holds is the same question on every platform and a different
/// answer on each: Android hands over its whole shared storage behind one
/// permission, a sandboxed Mac hands over the two folders its entitlements name,
/// and the players underneath disagree about which files they can open.
void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('extensions', () {
    test('offers Android the containers ExoPlayer opens', () {
      final android = DeviceSongs.extensionsFor('android');

      expect(android, containsAll({'.mp3', '.flac', '.opus', '.webm', '.mka'}));
      // AVFoundation's format, and ExoPlayer has no extractor for it.
      expect(android, isNot(contains('.aiff')));
    });

    test('offers macOS the containers AVFoundation opens', () {
      final macos = DeviceSongs.extensionsFor('macos');

      expect(macos, containsAll({'.mp3', '.flac', '.aiff', '.m4b'}));
      // Listing these on a Mac would draw rows that answer silence.
      expect(macos, isNot(contains('.opus')));
      expect(macos, isNot(contains('.webm')));
    });

    test('offers a platform with no player of ours nothing', () {
      expect(DeviceSongs.extensionsFor('windows'), isEmpty);
    });
  });

  group('roots', () {
    test('walks the whole of Android shared storage', () {
      expect(DeviceSongs.rootsFor('android'), ['/storage/emulated/0']);
    });

    test('walks the two folders a macOS entitlement can reach', () {
      // Inside the sandbox HOME is the container, where macOS links the real
      // folders once the entitlement is granted.
      expect(
        DeviceSongs.rootsFor('macos', environment: {'HOME': '/container'}),
        ['/container/Music', '/container/Downloads'],
      );
    });

    test('walks nothing where the home is unknown', () {
      expect(DeviceSongs.rootsFor('macos', environment: const {}), isEmpty);
    });
  });

  group('scanning', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('tunebox_device'));
    tearDown(() => root.deleteSync(recursive: true));

    File touch(String relative) {
      final file = File('${root.path}/$relative');
      file.parent.createSync(recursive: true);
      return file..writeAsStringSync('');
    }

    DeviceSongs scanner() =>
        DeviceSongs(roots: [root], extensions: DeviceSongs.extensionsFor('android'));

    Future<List<String>> titles(DeviceSongs device) async {
      await device.scan();
      return device.songs.map((s) => s.title).toList();
    }

    test('reaches music however deep the folders go', () async {
      touch('Music/Albums/Faded.mp3');
      touch('Downloads/one/two/three/Alive.opus');

      expect(await titles(scanner()), ['Alive', 'Faded']);
    });

    test('leaves hidden folders and hidden files alone', () async {
      touch('.Trash/Deleted.mp3');
      touch('Music/.hidden.mp3');
      touch('Music/Kept.mp3');

      expect(await titles(scanner()), ['Kept']);
    });

    test('leaves the Android folder alone, which is app data and not music',
        () async {
      touch('Android/data/com.other/files/Cache.mp3');
      touch('Music/Kept.mp3');

      expect(await titles(scanner()), ['Kept']);
    });

    test('keeps going past a folder it is not allowed to read', () async {
      touch('Music/Kept.mp3');
      final closed = Directory('${root.path}/closed')..createSync();
      File('${closed.path}/Unreachable.mp3').writeAsStringSync('');
      Process.runSync('chmod', ['000', closed.path]);
      addTearDown(() => Process.runSync('chmod', ['755', closed.path]));

      expect(await titles(scanner()), ['Kept']);
    });

    test('skips files no player here can open', () async {
      touch('Music/Notes.txt');
      touch('Music/Cover.jpg');
      touch('Music/Kept.mp3');

      expect(await titles(scanner()), ['Kept']);
    });
  });
}
