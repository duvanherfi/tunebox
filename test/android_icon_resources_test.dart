import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Android drawable this app names as a string has to survive the release
/// build's resource shrinker.
///
/// The shrinker only sees references from XML and from generated `R` fields.
/// A drawable reached by name from Dart looks unused to it and is deleted, and
/// then `getIdentifier` answers 0. audio_service refuses to build a media
/// control without an icon, so *every* `setPlaybackState` threw: the playback
/// notification was never posted and the media session froze on the last state
/// it had managed to publish — a car sat on a stale, paused track for a whole
/// drive because of it. Only a release build shrinks, so nothing on an emulator
/// or in a debug install ever showed it.
///
/// `res/raw/keep.xml` is what pins them. This keeps that file honest.
void main() {
  final drawables = Directory('android/app/src/main/res/drawable');
  final keepFile = File('android/app/src/main/res/raw/keep.xml');

  /// `drawable/ic_favorite` in any Dart source under lib/.
  Set<String> namedFromDart() {
    final named = <String>{};
    final pattern = RegExp(r"'drawable/([a-z0-9_]+)'");
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entry.readAsStringSync())) {
        named.add(match.group(1)!);
      }
    }
    return named;
  }

  test('every drawable named from Dart exists', () {
    final missing = namedFromDart()
        .where((name) => !File('${drawables.path}/$name.xml').existsSync());
    expect(missing, isEmpty,
        reason: 'named in Dart but no such drawable resource');
  });

  test('every drawable named from Dart is kept from the shrinker', () {
    final keep = keepFile.readAsStringSync();
    // A wildcard entry covers a whole family, which is how the car icons are
    // pinned.
    final wildcards = RegExp(r'@drawable/([a-z0-9_]+)\*')
        .allMatches(keep)
        .map((match) => match.group(1)!)
        .toList();

    bool isPinned(String name) =>
        keep.contains('@drawable/$name,') ||
        keep.contains('@drawable/$name"') ||
        wildcards.any(name.startsWith);

    final unpinned = namedFromDart().where((name) => !isPinned(name));
    expect(unpinned, isEmpty,
        reason: 'add these to android/app/src/main/res/raw/keep.xml — '
            'the release build will otherwise delete them and every '
            'setPlaybackState will throw');
  });
}
