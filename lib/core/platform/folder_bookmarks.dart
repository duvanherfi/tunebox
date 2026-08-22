import 'dart:io';

import 'package:flutter/services.dart';

/// Turning a folder into something that still opens after a restart.
///
/// Only macOS needs this. Its sandbox grants access to a picked folder for the
/// life of the process and no longer; a security-scoped bookmark is the receipt
/// that buys the same access back on the next launch. Nowhere else does a
/// folder need a receipt, so [None] answers that there is nothing to keep and
/// the stored path stands on its own.
abstract class FolderBookmarks {
  /// What to keep so [resolve] can reopen [path] later, or null where the
  /// platform keeps nothing.
  Future<String?> create(String path);

  /// Where the bookmarked folder is now, having reopened it, or null when it
  /// can no longer be reached — a deleted folder, an unplugged disk.
  Future<String?> resolve(String bookmark);

  factory FolderBookmarks.forPlatform() =>
      Platform.isMacOS ? const MacBookmarks() : const None();

  /// For the platforms where a path is its own permission.
  const factory FolderBookmarks.none() = None;
}

class None implements FolderBookmarks {
  const None();

  @override
  Future<String?> create(String path) async => null;

  @override
  Future<String?> resolve(String bookmark) async => bookmark;
}

/// The Swift side, in `MainFlutterWindow.swift`.
///
/// A refusal is an ordinary answer here rather than an error: a folder can be
/// gone, on a disk that is not plugged in, or bookmarked by a build that no
/// longer matches. Any of those means "not reachable", which the list shows,
/// and none of them is worth an exception out of app startup.
class MacBookmarks implements FolderBookmarks {
  const MacBookmarks();

  static const _channel = MethodChannel('com.tunebox.tunebox/bookmarks');

  @override
  Future<String?> create(String path) async {
    try {
      return await _channel.invokeMethod<String>('create', {'path': path});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<String?> resolve(String bookmark) async {
    try {
      return await _channel
          .invokeMethod<String>('resolve', {'bookmark': bookmark});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
