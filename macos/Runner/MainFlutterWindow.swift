import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Set the window size
    let newFrame = NSRect(x: windowFrame.origin.x, y: windowFrame.origin.y, width: 1200, height: 800)
    self.setFrame(newFrame, display: true, animate: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
