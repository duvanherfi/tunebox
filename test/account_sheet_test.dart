import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/core/theme/theme_controller.dart';
import 'package:tunebox/data/account_store.dart';
import 'package:tunebox/data/models/playlist.dart';
import 'package:tunebox/features/account/account_sheet.dart';
import 'package:tunebox/l10n/app_localizations.dart';
import 'package:tunebox/main.dart' as app;

/// An account that answers with whatever the test last decided, so the moment
/// the answer arrives is under the test's control rather than the network's.
class _FakeInnertube extends InnertubeClient {
  _FakeInnertube({super.session});

  Account? answer;

  @override
  Future<Account?> accountInfo() async => answer;
}

/// Signing in and seeing who you signed in as are two different moments: the
/// session flips at once and the name and photo arrive from the network a beat
/// later. The panel has to survive that gap on its own.
void main() {
  late _FakeInnertube fake;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    app.session = Session();
    await app.session.signIn('SAPISID=secret123');
    fake = _FakeInnertube(session: app.session);
    app.innertube = fake;
    app.accountStore = AccountStore(fake, app.session);
    app.themeController = ThemeController();
    await app.themeController.load();
  });

  testWidgets('fills the panel in when the account arrives, with the sheet '
      'still open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAccountSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Duvan'), findsNothing);

    // What signing in does: the session is already live, and the account
    // itself lands afterwards.
    fake.answer = const Account(name: 'Duvan', email: 'duvan@example.test');
    await app.accountStore.refresh();
    await tester.pump();

    expect(find.text('Duvan'), findsOneWidget);
    expect(find.text('duvan@example.test'), findsOneWidget);
  });
}
