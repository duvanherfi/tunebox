import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Ours rather than a package: the one on pub for this, macos_secure_bookmarks,
    // stopped at Dart 2.
    FolderBookmarks.register(
      with: flutterViewController.registrar(forPlugin: "FolderBookmarks"))

    super.awakeFromNib()
  }
}
