import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/auth/session.dart';

/// Stands in for the keychain, which no test can reach.
class _MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};

  /// Holds [delete] open, the way a keychain that is thinking does.
  Completer<void>? stall;

  /// Refuses every read, the way macOS does when the password dialog is
  /// answered with Deny.
  bool refuses = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (refuses) {
      throw PlatformException(
        code: 'Unexpected security result code',
        message: 'User canceled the operation.',
        details: -128,
      );
    }
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (stall != null) await stall!.future;
    values.remove(key);
  }
}

/// The signature scheme is the one part of authentication with no visible
/// failure mode: a malformed credential just comes back as an empty library,
/// indistinguishable from having liked nothing. These pin the format.
void main() {
  group('a keychain that refuses to be read', () {
    test('opens signed out rather than not opening at all', () async {
      final storage = _MemoryStorage()..values['youtube_cookies'] = 'SAPISID=x';
      final session = Session(storage: storage);
      storage.refuses = true;

      await session.load();

      expect(session.isSignedIn, isFalse);
    });

    test('leaves the stored session where it is', () async {
      // macOS asks again on the next launch, and answering it then has to give
      // the session back. Forgetting it here would make Deny a sign-out.
      final storage = _MemoryStorage()..values['youtube_cookies'] = 'SAPISID=x';
      final session = Session(storage: storage);
      storage.refuses = true;
      await session.load();

      storage.refuses = false;
      await session.load();

      expect(session.cookieHeader, 'SAPISID=x');
    });
  });

  group('sapisidOf', () {
    test('reads SAPISID from a cookie string', () {
      expect(
        Session.sapisidOf('YSC=abc; SAPISID=secret123; LOGIN_INFO=xyz'),
        'secret123',
      );
    });

    test('falls back to the __Secure variants', () {
      expect(
        Session.sapisidOf('YSC=abc; __Secure-3PAPISID=secret456'),
        'secret456',
      );
    });

    test('tolerates missing spaces and stray whitespace', () {
      expect(Session.sapisidOf('YSC=abc;SAPISID=  padded  '), 'padded');
    });

    test('returns null when no usable cookie is present', () {
      expect(Session.sapisidOf('YSC=abc; LOGIN_INFO=xyz'), isNull);
      expect(Session.sapisidOf(''), isNull);
    });

    test('ignores a cookie with an empty value', () {
      expect(
        Session.sapisidOf('SAPISID=; __Secure-3PAPISID=real'),
        'real',
      );
    });
  });

  group('authorization', () {
    test('is SAPISIDHASH followed by timestamp and a SHA-1 digest', () {
      final auth = Session.authorization(
        'secret',
        now: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );

      expect(auth, matches(RegExp(r'^SAPISIDHASH 1700000000_[0-9a-f]{40}$')));
    });

    test('is stable for a given timestamp and changes with it', () {
      final at1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final at2 = DateTime.fromMillisecondsSinceEpoch(1700000001000);

      expect(
        Session.authorization('secret', now: at1),
        Session.authorization('secret', now: at1),
      );
      expect(
        Session.authorization('secret', now: at1),
        isNot(Session.authorization('secret', now: at2)),
      );
    });

    test('changes with the secret', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      expect(
        Session.authorization('one', now: at),
        isNot(Session.authorization('two', now: at)),
      );
    });
  });

  group('signing out', () {
    test('empties the browser as well as the store it keeps', () async {
      final storage = _MemoryStorage();
      var forgotten = 0;
      final session = Session(
        storage: storage,
        forgetBrowser: () async => forgotten++,
      );

      await session.signIn('SAPISID=secret123');
      expect(session.isSignedIn, isTrue);

      await session.signOut();

      expect(session.isSignedIn, isFalse);
      expect(storage.values, isEmpty);
      // Without this the login page walks straight through on the same Google
      // session, and signing out to use another account cannot work.
      expect(forgotten, 1);
    });

    test('says so without waiting for the stores to answer', () async {
      final storage = _MemoryStorage();
      final session = Session(storage: storage);
      await session.signIn('SAPISID=secret123');

      // A store that has not answered yet is the ordinary case on macOS, where
      // the keychain is a round trip out of the process. Told last, a sign-out
      // leaves the account on screen for as long as that takes — and if the
      // store ever refuses, forever.
      storage.stall = Completer<void>();
      var told = false;
      session.addListener(() => told = true);

      final signingOut = session.signOut();
      await pumpEventQueue();

      expect(told, isTrue);
      expect(session.isSignedIn, isFalse);

      storage.stall!.complete();
      await signingOut;
      expect(storage.values, isEmpty);
    });
  });

  group('headers', () {
    test('are empty while signed out, keeping calls anonymous', () {
      expect(Session().headers(), isEmpty);
    });
  });
}
