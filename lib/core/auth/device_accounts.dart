import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Signs in with a Google account already present on the phone.
///
/// The alternative is pasting a cookie copied from a desktop browser, which
/// works reliably but is tedious enough that it discourages signing in at all.
/// This asks Android for the account instead: the user picks one from the
/// system chooser and the platform side turns that into the same session
/// cookies, without a password ever passing through this app.
///
/// UNVERIFIED against a real account. Google has narrowed this path over the
/// years and it may simply refuse; there was no signed-in device available to
/// test on. It is offered as a shortcut, never as the only way in — failures
/// fall back to pasting, which is known to work.
class DeviceAccounts {
  static const _channel = MethodChannel('tunebox/accounts');

  /// Opens the system account chooser. Null when the user backs out.
  Future<String?> pickAccount() async {
    try {
      return await _channel.invokeMethod<String>('pickAccount');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Nothing on the other end: any platform that is not Android.
      return null;
    }
  }

  /// Turns a chosen account into a cookie header, or throws with the reason.
  Future<String> cookiesFor(String account) async {
    final cookies = await _channel.invokeMethod<String>(
      'cookiesFor',
      {'account': account},
    );
    if (cookies == null || cookies.isEmpty) {
      throw const DeviceAccountsException('empty');
    }
    return cookies;
  }

  /// Only Android implements this, so nowhere else should offer it.
  static bool get isSupported => Platform.isAndroid;
}

class DeviceAccountsException implements Exception {
  const DeviceAccountsException(this.reason);
  final String reason;
  @override
  String toString() => reason;
}
