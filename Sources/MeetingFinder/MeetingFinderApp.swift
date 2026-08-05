import AppKit

@main
@MainActor
final class MeetingFinderApp: NSObject, NSApplicationDelegate {
  private static var retainedDelegate: MeetingFinderApp?
  private var menuBarController: MenuBarController?

  static func main() {
    let application = NSApplication.shared
    let delegate = MeetingFinderApp()
    retainedDelegate = delegate
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    menuBarController = MenuBarController()

    if CommandLine.arguments.contains("--best-time") {
      menuBarController?.selectBestTime()
    }

    if CommandLine.arguments.contains("--show-panel") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
        self?.menuBarController?.showPanel()
      }
    }
  }
}
