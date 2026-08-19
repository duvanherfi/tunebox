import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/core/theme/theme_controller.dart';
import 'package:tunebox/data/audio_cache.dart';
import 'package:tunebox/data/backup.dart';
import 'package:tunebox/data/downloads.dart';
import 'package:tunebox/data/play_history.dart';
import 'package:tunebox/data/settings.dart';
import 'package:tunebox/features/settings/appearance_screen.dart';
import 'package:tunebox/features/settings/backup_settings_screen.dart';
import 'package:tunebox/features/settings/nightstand_settings_screen.dart';
import 'package:tunebox/features/settings/playback_settings_screen.dart';
import 'package:tunebox/features/settings/settings_screen.dart';
import 'package:tunebox/features/settings/storage_settings_screen.dart';
import 'package:tunebox/l10n/app_localizations.dart';
import 'package:tunebox/main.dart' as app;

/// Settings used to be one screen called "Playback and sound" that also held
/// storage, backups and the home screen widget. The index is the promise that
/// each domain is its own door: what the rows say is what is behind them.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    app.settings = Settings();
    await app.settings.load();
    app.themeController = ThemeController();
    await app.themeController.load();

    // Storage and backups read from disk the moment they are drawn, so they
    // get a temp directory of their own rather than the app's.
    final temp = await Directory.systemTemp.createTemp('tunebox_settings');
    app.downloads = Downloads(directory: temp);
    app.audioCache = AudioCache(directory: temp);
    app.playHistory = PlayHistory(file: File('${temp.path}/history.json'));
    app.backup = Backup(history: app.playHistory, directory: temp);
    await app.backup.load();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists one row per domain', (tester) async {
    await open(tester);

    expect(find.text('Playback and sound'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Backups'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Nightstand'), findsOneWidget);
  });

  // Opened from a fresh tree each time rather than walked back to: pageBack
  // reaches for a Cupertino back button on a macOS host, and none of this is
  // about how the arrow is drawn.
  for (final (row, screen) in [
    ('Playback and sound', PlaybackSettingsScreen),
    ('Storage', StorageSettingsScreen),
    ('Backups', BackupSettingsScreen),
    ('Appearance', AppearanceScreen),
    ('Nightstand', NightstandSettingsScreen),
  ]) {
    testWidgets('$row opens its own screen', (tester) async {
      await open(tester);

      await tester.tap(find.text(row));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w.runtimeType == screen),
          findsOneWidget);
    });
  }

  testWidgets('the sleep timer is not a setting: it stays in the player',
      (tester) async {
    await open(tester);

    expect(find.text('Sleep timer'), findsNothing);

    await tester.tap(find.text('Playback and sound'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep timer'), findsNothing);
  });
}
