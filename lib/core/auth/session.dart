import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

/// Holds the signed-in YouTube session and derives the headers InnerTube
/// expects from it.
///
/// There is no OAuth path to the internal API, so authentication works the way
/// the YouTube Music web app itself works: the browser cookies obtained from a
/// real Google login, plus an `Authorization` header derived from one of them.
/// Cookies live in secure storage and never leave the device.
class Session extends ChangeNotifier {
  Session({FlutterSecureStorage? storage, Future<void> Function()? forgetBrowser})
      : _storage = storage ?? secureStorage,
        _forgetBrowser = forgetBrowser;

  static const _cookieKey = 'youtube_cookies';
  static const origin = 'https://music.youtube.com';

  final FlutterSecureStorage _storage;

  /// Empties the login browser's own cookie jar. Wired in `main.dart`, because
  /// the browser belongs to the login screen and not to this layer.
  final Future<void> Function()? _forgetBrowser;

  String? _cookieHeader;

  String? get cookieHeader => _cookieHeader;
  bool get isSignedIn => _cookieHeader != null && sapisidOf(_cookieHeader!) != null;

  Future<void> load() async {
    _cookieHeader = await _storage.read(key: _cookieKey);
    notifyListeners();
  }

  Future<void> signIn(String cookieHeader) async {
    _cookieHeader = cookieHeader;
    await _storage.write(key: _cookieKey, value: cookieHeader);
    notifyListeners();
  }

  /// Forgets the session everywhere it was left, not just here.
  ///
  /// The cookies this holds are a copy: the browser the sign-in ran in keeps
  /// its own, and it is a persistent store that outlives the app. Deleting only
  /// this copy signs the app out and leaves Google signed in, so the very next
  /// sign-in walks through the login page without stopping — same account, no
  /// chooser, no password — and reads as a sign-out that did nothing. Which is
  /// what someone signing out to use another account is trying to do.
  ///
  /// Announced before either store is emptied: the session is already gone as
  /// far as anything asking is concerned, and a screen should not keep showing
  /// an account while a keychain write it cannot see is still in flight.
  Future<void> signOut() async {
    _cookieHeader = null;
    notifyListeners();
    await _storage.delete(key: _cookieKey);
    await _forgetBrowser?.call();
  }

  /// Headers that turn an anonymous InnerTube call into a signed-in one.
  /// Empty when signed out, which is what keeps phase 1 working untouched.
  Map<String, String> headers({DateTime? now}) {
    final cookies = _cookieHeader;
    if (cookies == null) return const {};
    final sapisid = sapisidOf(cookies);
    if (sapisid == null) return const {};

    return {
      'Cookie': cookies,
      'Authorization': authorization(sapisid, now: now),
      'X-Goog-AuthUser': '0',
      'Origin': origin,
    };
  }

  /// Builds the `SAPISIDHASH` credential.
  ///
  /// The scheme is Google's own: SHA-1 over the current unix timestamp, the
  /// SAPISID cookie and the origin, joined by single spaces, sent alongside
  /// that same timestamp. YouTube's web frontend computes it in JavaScript on
  /// every request, which is also why the cookie it needs is readable from
  /// `document.cookie` rather than being HttpOnly.
  static String authorization(String sapisid, {DateTime? now}) {
    final seconds =
        (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final digest = sha1.convert(utf8.encode('$seconds $sapisid $origin'));
    return 'SAPISIDHASH ${seconds}_$digest';
  }

  /// Pulls the SAPISID value out of a `name=value; name=value` cookie string.
  ///
  /// Google issues the same secret under several names depending on how the
  /// login happened; any of them works, so they are tried in order of how
  /// commonly they appear on a fresh music.youtube.com session.
  static String? sapisidOf(String cookieHeader) {
    const names = ['SAPISID', '__Secure-3PAPISID', '__Secure-1PAPISID'];
    final jar = <String, String>{};
    for (final pair in cookieHeader.split(';')) {
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      jar[pair.substring(0, index).trim()] = pair.substring(index + 1).trim();
    }
    for (final name in names) {
      final value = jar[name];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
