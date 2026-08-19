import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Why the system installer could not be reached.
enum InstallFailure {
  /// Android has not been told this app may install packages. The only
  /// failure with a way out the user can take, which is why it has a name of
  /// its own rather than a message.
  notPermitted,

  /// The downloaded APK is not signed by the key this app was signed with.
  /// Somebody served a different binary; there is no version of this that is
  /// a false alarm worth waving through.
  signature,

  /// Anything else: no file, an unreadable archive, no installer to open it.
  refused,
}

/// The system installer, on the other side of a `MethodChannel`.
///
/// This side is deliberately thin — the check that matters (does the APK carry
/// our signature) happens in `Installer.kt`, where the certificates are, and
/// this class cannot skip it.
class Installer {
  const Installer();

  static const _channel = MethodChannel('tunebox/installer');

  /// Only Android has an installer to talk to, and only Android's settings
  /// hold the switch this app asks for.
  static bool get isSupported => Platform.isAndroid;

  /// Whether Android would let this app start an install right now.
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the system page where the permission is granted. There is no
  /// callback: Android grants it out there and [canInstall] answers again
  /// when the app comes back.
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // The page is missing on this build of Android; nothing to recover.
    } on MissingPluginException {
      // Not Android.
    }
  }

  /// Hands [path] to the system installer. Answers null on success — from
  /// here on the system owns the flow — or the reason it never started.
  Future<InstallFailure?> install(String path) async {
    try {
      final started = await _channel.invokeMethod<bool>(
        'install',
        {'path': path},
      );
      return started == true ? null : InstallFailure.refused;
    } on PlatformException catch (error) {
      return switch (error.code) {
        'signature' || 'wrong_package' => InstallFailure.signature,
        _ => InstallFailure.refused,
      };
    } on MissingPluginException {
      return InstallFailure.refused;
    }
  }
}
