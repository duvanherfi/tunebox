import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/data/settings.dart';
import 'package:tunebox/data/updates.dart';
import 'package:tunebox/features/settings/update_sheet.dart';
import 'package:tunebox/l10n/app_localizations.dart';
import 'package:tunebox/main.dart' as app;

/// The sheet is the only thing the listener ever sees of the updater, and it
/// has to say three different things without being asked twice: there is a
/// version, there is not, and Android will not let this app install one.
void main() {
  const installed = AppVersion(name: '0.1.3', build: 4);

  late Directory directory;

  // What GitHub answers next. The globals in main.dart are `late final`, so
  // the store is built once and each test changes what the network says
  // rather than swapping the store.
  late String body;
  late int status;

  /// What the platform side answers. Mocked rather than left unanswered: an
  /// unhandled channel never replies at all, and the sheet would sit waiting
  /// on it instead of doing the thing under test.
  late bool permitted;
  String? handed;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('update_sheet_test');

    app.settings = Settings();
    await app.settings.load();
    app.updates = Updates(
      installed: installed,
      directory: directory,
      httpClient: MockClient((_) async => http.Response(body, status)),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('tunebox/installer'),
      (call) async => switch (call.method) {
        'canInstall' => permitted,
        'install' => (handed = call.arguments['path'] as String?) != null,
        _ => null,
      },
    );
  });

  tearDownAll(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  String release() =>
      File('test/fixtures/release_latest.json').readAsStringSync();

  setUp(() {
    body = release();
    status = 200;
    permitted = true;
    handed = null;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUpdateSheet(context, checkOnOpen: true),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('names the version it found and what changed', (tester) async {
    await open(tester);

    expect(find.text('There is a new version'), findsOneWidget);
    expect(find.textContaining('Version 0.1.4'), findsOneWidget);
    // 43118592 bytes, said the way a person reads a download.
    expect(find.textContaining('41.1 MB'), findsOneWidget);
    expect(find.textContaining('mesita de noche'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
  });

  testWidgets('says so when there is nothing to install', (tester) async {
    final same = jsonDecode(release()) as Map<String, dynamic>;
    (same['assets'] as List).first['name'] = 'tunebox-0.1.3+4.apk';
    same['tag_name'] = 'v0.1.3';
    body = jsonEncode(same);

    await open(tester);

    expect(find.text('You are on the latest version.'), findsOneWidget);
    expect(find.text('Install'), findsNothing);
  });

  testWidgets('offers the way out when Android refuses to install', (
    tester,
  ) async {
    permitted = false;

    await open(tester);
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();

    expect(find.textContaining('may install apps'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('downloads and hands the apk to the installer', (tester) async {
    await open(tester);

    // runAsync because the download writes a real file, and the fake clock a
    // widget test runs on never lets that finish.
    await tester.runAsync(() async {
      await tester.tap(find.text('Install'));
      for (var tries = 0; tries < 200 && handed == null; tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();

    expect(handed, endsWith('tunebox-0.1.4+5.apk'));
    expect(find.textContaining('could not be reached'), findsNothing);
    // The file is gone from the sheet's hands, not from the disk: the
    // installer reads it after this returns.
    expect(File(handed!).existsSync(), isTrue);
  });

  testWidgets('reports a check it could not make', (tester) async {
    body = '{"message":"no"}';
    status = 403;

    await open(tester);

    expect(find.text('GitHub could not be reached. Try again later.'),
        findsOneWidget);
  });
}
