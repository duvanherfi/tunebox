import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/data/backup.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/play_history.dart';

void main() {
  late Directory directory;
  late PlayHistory history;
  late Backup backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'playback_speed': 1.5});
    directory = Directory.systemTemp.createTempSync('tunebox_backup');
    history = PlayHistory(file: File('${directory.path}/play_log.json'));
    await history.load();
    backup = Backup(
      history: history,
      directory: Directory('${directory.path}/backups')
        ..createSync(recursive: true),
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('carries the listening log and the settings', () async {
    await history.record(
      const Song(videoId: 'a', title: 'Glory Box', subtitle: 'Portishead'),
    );

    final file = await backup.write();
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    expect((json['history'] as List), hasLength(1));
    expect(json['settings']['playback_speed'], 1.5);
  });

  test('puts a copy back over what is there now', () async {
    await history.record(
      const Song(videoId: 'a', title: 'Glory Box', subtitle: 'Portishead'),
    );
    final file = await backup.write();

    await history.clear();
    expect(history.plays, isEmpty);

    await backup.restore(file);
    expect(history.songs.single.title, 'Glory Box');
  });

  test('refuses a file that is not a backup', () async {
    final stray = File('${directory.path}/stray.json')
      ..writeAsStringSync('[1, 2, 3]');

    expect(() => backup.restore(stray), throwsFormatException);
  });

  test('keeps the five most recent copies', () async {
    final backups = Directory('${directory.path}/backups');
    for (var day = 1; day <= 8; day++) {
      File('${backups.path}/tunebox-2026-01-0$day.json')
          .writeAsStringSync('{}');
    }

    await backup.write();

    expect(await backup.list(), hasLength(5));
  });
}
