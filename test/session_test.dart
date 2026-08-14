import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/auth/session.dart';

/// The signature scheme is the one part of authentication with no visible
/// failure mode: a malformed credential just comes back as an empty library,
/// indistinguishable from having liked nothing. These pin the format.
void main() {
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

  group('headers', () {
    test('are empty while signed out, keeping calls anonymous', () {
      expect(Session().headers(), isEmpty);
    });
  });
}
