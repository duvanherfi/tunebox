import Cocoa
import FlutterMacOS

/// Keeps a picked folder reachable across launches.
///
/// The sandbox grants access to whatever the open panel returned, and that
/// grant dies with the process. A security-scoped bookmark is the receipt that
/// buys the same access back next time, and it needs two entitlements to exist:
/// `files.user-selected.read-only` for the pick and `files.bookmarks.app-scope`
/// for the receipt.
///
/// The scope opened by `resolve` is never closed. Stopping it would take the
/// folder away mid-session — the library tab would empty itself while someone
/// was looking at it — and the process ending releases it anyway.
enum FolderBookmarks {
  static let channelName = "com.tunebox.tunebox/bookmarks"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger)

    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]

      switch call.method {
      case "create":
        guard let path = arguments?["path"] as? String else {
          result(nil)
          return
        }
        result(create(path: path))
      case "resolve":
        guard let bookmark = arguments?["bookmark"] as? String else {
          result(nil)
          return
        }
        result(resolve(bookmark: bookmark))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// A refusal is an ordinary answer, not an error: a folder can be gone or on
  /// a disk that is not plugged in, and the list shows that as unreachable.
  private static func create(path: String) -> String? {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    return try? url.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    ).base64EncodedString()
  }

  private static func resolve(bookmark: String) -> String? {
    guard let data = Data(base64Encoded: bookmark) else { return nil }

    var stale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )
    else { return nil }

    // A stale bookmark still resolves and still opens; what it no longer does
    // is survive another launch, so Dart is told the path and will hand back a
    // fresh bookmark the next time the folder is added.
    guard url.startAccessingSecurityScopedResource() else { return nil }
    return url.path
  }
}
