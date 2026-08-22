import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/auth/secure_storage.dart';

/// Credentials on macOS have to go to the file-based keychain.
///
/// `flutter_secure_storage` asks for the data protection keychain by default,
/// and that one is only opened to an app signed with a `keychain-access-groups`
/// entitlement — which Xcode will not sign ad-hoc. This app is signed ad-hoc,
/// so with the default every write answered `-34018 A required entitlement
/// isn't present`, `Session.signIn` threw before notifying anyone, and a
/// sign-in on macOS left the account panel on its fallback icon and was gone
/// by the next launch.
///
/// Nothing in a build fails when this is wrong: it is a runtime answer from
/// the keychain on one platform, in a store no test touches. Hence a test that
/// reads the source.
void main() {
  test('the shared secure store avoids the data protection keychain', () {
    final options = secureStorage.mOptions;
    expect(options, isA<MacOsOptions>());
    expect((options as MacOsOptions).usesDataProtectionKeychain, isFalse);
  });

  test('nothing else builds a secure store of its own', () {
    final offenders = <String>[];
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      if (entry.path.endsWith('core/auth/secure_storage.dart')) continue;
      if (entry.readAsStringSync().contains('FlutterSecureStorage(')) {
        offenders.add(entry.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'these build their own store instead of using secureStorage, '
          'and so get the data protection keychain back',
    );
  });
}
