import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/auth/session.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/data/account_store.dart';
import 'package:tunebox/data/models/playlist.dart';

/// Answers whatever the test lined up, and counts how often it was asked.
class _FakeInnertube extends InnertubeClient {
  _FakeInnertube({super.session});

  /// Read in order; the last one stands for every call after it.
  final answers = <Account?>[];
  var asked = 0;

  @override
  Future<Account?> accountInfo() async {
    final answer = answers.isEmpty
        ? null
        : answers[asked.clamp(0, answers.length - 1)];
    asked++;
    return answer;
  }
}

/// `accountInfo()` swallows every kind of failure and answers null, so a call
/// that goes out before the cookies from a fresh sign-in are worth anything
/// looks exactly like an account with no name. What the corner does about that
/// is this store's business, and it is what left a real sign-in showing the
/// fallback icon until the app was started again.
void main() {
  const someone = Account(
    name: 'Duvan',
    email: 'duvan@example.com',
    photoUrl: 'https://example.com/photo.jpg',
  );

  late Session session;
  late _FakeInnertube fake;
  late AccountStore store;

  // Short enough that the test does not sit waiting, long enough that the
  // reading is a real Timer rather than a straight line.
  const waits = [Duration(milliseconds: 10), Duration(milliseconds: 10)];

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    session = Session();
    // Signed in before the store exists, the way main.dart has it: the session
    // is loaded first and the store is built on top of it and asked once. That
    // keeps each test's reading to the one it makes itself.
    await session.signIn('SAPISID=secret123');
    fake = _FakeInnertube(session: session);
    store = AccountStore(fake, session, waits: waits);
  });

  tearDown(() => store.dispose());

  test('asks again when the first answer was a failure', () async {
    fake.answers.addAll([null, someone]);

    await store.refresh();
    expect(store.account, isNull, reason: 'the first call failed');

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(store.account?.name, 'Duvan');
    expect(fake.asked, greaterThan(1));
  });

  test('gives up rather than asking for ever', () async {
    fake.answers.add(null);

    await store.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(fake.asked, waits.length + 1);
  });

  test('a failed read keeps the account already in hand', () async {
    fake.answers.addAll([someone, null]);

    await store.refresh();
    expect(store.account?.name, 'Duvan');

    await store.refresh();

    // Emptying the corner because one request went wrong trades something true
    // for something that is not.
    expect(store.account?.name, 'Duvan');
  });

  test('a notice arriving mid-read is answered, not dropped', () async {
    fake.answers.addAll([null, someone]);

    // Two at once: the first is still in flight when the second arrives, and
    // the second is the one asking with what the session holds now.
    final first = store.refresh();
    final second = store.refresh();
    await Future.wait([first, second]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(fake.asked, 2, reason: 'the second notice was acted on');
    expect(store.account?.name, 'Duvan');
  });

  test('signing out forgets who it was', () async {
    fake.answers.add(someone);
    await store.refresh();
    expect(store.account, isNotNull);

    await session.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(store.account, isNull);
  });
}
