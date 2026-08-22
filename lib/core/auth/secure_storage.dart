import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one secure store the app keeps credentials in.
///
/// It exists to hold a single setting. `flutter_secure_storage` asks for the
/// macOS *data protection* keychain by default, and that keychain is only
/// opened to an app whose signature carries a `keychain-access-groups`
/// entitlement — which Xcode refuses to sign ad-hoc: "Runner has entitlements
/// that require signing with a development certificate". Ad-hoc is how this app
/// is signed, since notarising needs the paid Developer Program, so every write
/// answered `-34018 A required entitlement isn't present` and the sign-in on
/// macOS never persisted: cookies lived until the app closed, and the account
/// panel was left with the fallback icon.
///
/// The file-based keychain is the one that has always worked for an app signed
/// like this. It is macOS-only: iOS ignores the flag, and the Android and Linux
/// implementations never see it.
const secureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
