import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let panel: FinderPanel
  private let model = MeetingViewModel()
  private var stateObservation: AnyCancellable?
  private var outsideClickMonitor: Any?
  private var shouldShowTimeZonePickerOnNextPresentation = CommandLine.arguments.contains(
    "--show-time-zone-picker")

  override init() {
    let panelSize = MeetingFinderLayout.panelSize(for: model.state.cities.count)
    let rootView = MeetingFinderView(model: model)
      .padding(MeetingFinderLayout.panelPadding)
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = NSRect(origin: .zero, size: panelSize)
    hostingView.autoresizingMask = [.width, .height]

    panel = FinderPanel(
      contentRect: hostingView.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.contentView = hostingView

    super.init()

    configureStatusItem()
    configurePanel()
    observePanelSize()
  }

  func showPanel() {
    NotificationCenter.default.post(name: .hideTimeZonePicker, object: nil)
    model.refreshTimeZoneRules()
    let button = statusItem.button
    let buttonWindow = button?.window
    let menuBarScreen = NSScreen.screens.first { screen in
      screen.visibleFrame.maxY < screen.frame.maxY
    }
    let visibleFrame =
      buttonWindow?.screen?.visibleFrame ?? menuBarScreen?.visibleFrame ?? NSScreen.main?
      .visibleFrame ?? .zero
    var origin: NSPoint

    if let button, let buttonWindow {
      let statusRect = buttonWindow.convertToScreen(button.frame)
      origin = NSPoint(
        x: statusRect.midX - (panel.frame.width / 2),
        y: statusRect.minY - panel.frame.height + 8
      )
    } else if let button {
      let statusRect = button.accessibilityFrame()
      origin = NSPoint(
        x: statusRect.midX - (panel.frame.width / 2),
        y: statusRect.minY - panel.frame.height + 8
      )
    } else {
      // On newer macOS releases status items can be remotely hosted by
      // Control Center, leaving their NSStatusBarButton without a window.
      origin = NSPoint(
        x: visibleFrame.maxX - panel.frame.width - 16,
        y: visibleFrame.maxY - panel.frame.height + 8
      )
    }

    origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - panel.frame.width - 8)
    origin.y = max(origin.y, visibleFrame.minY + 8)

    panel.setFrameOrigin(origin)
    panel.makeKeyAndOrderFront(nil)
    installOutsideClickMonitor()

    if shouldShowTimeZonePickerOnNextPresentation {
      shouldShowTimeZonePickerOnNextPresentation = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
        guard self?.panel.isVisible == true else { return }
        NotificationCenter.default.post(name: .showTimeZonePicker, object: nil)
      }
    }
  }

  func hidePanel() {
    NotificationCenter.default.post(name: .hideTimeZonePicker, object: nil)
    panel.orderOut(nil)
    removeOutsideClickMonitor()
  }

  func selectBestTime() {
    model.findBestTime()
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else { return }
    button.image = ZonelyMenuBarIcon.makeImage()
    button.imageScaling = .scaleProportionallyDown
    button.imagePosition = .imageOnly
    button.title = ""
    button.target = self
    button.action = #selector(statusItemPressed(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.toolTip = "Zonely"
    button.setAccessibilityLabel("Zonely")
    statusItem.isVisible = true
  }

  private func configurePanel() {
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .popUpMenu
    panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
  }

  private func observePanelSize() {
    stateObservation = model.$state
      .map { $0.cities.count }
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] cityCount in
        self?.resizePanel(for: cityCount)
      }
  }

  private func resizePanel(for cityCount: Int) {
    let size = MeetingFinderLayout.panelSize(for: cityCount)
    guard panel.frame.size != size else { return }

    let resize = MeetingFinderLayout.panelResize(from: panel.frame, for: cityCount)
    panel.setFrame(resize.frame, display: true, animate: resize.animates)
  }

  @objc private func statusItemPressed(_ sender: NSStatusBarButton) {
    if NSApp.currentEvent?.type == .rightMouseUp {
      showContextMenu()
      return
    }

    panel.isVisible ? hidePanel() : showPanel()
  }

  private func showContextMenu() {
    let menu = NSMenu()
    let openItem = NSMenuItem(
      title: panel.isVisible ? "Close Zonely" : "Open Zonely", action: #selector(toggleFromMenu),
      keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)
    menu.addItem(.separator())
    let resetItem = NSMenuItem(
      title: "Reset to 05:00 UTC", action: #selector(resetSelection), keyEquivalent: "")
    resetItem.target = self
    menu.addItem(resetItem)
    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit Zonely", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @objc private func toggleFromMenu() {
    panel.isVisible ? hidePanel() : showPanel()
  }

  @objc private func resetSelection() {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
      model.select(hour: 5)
    }
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func installOutsideClickMonitor() {
    removeOutsideClickMonitor()
    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown,
    ]) { [weak self] _ in
      Task { @MainActor in
        self?.hidePanel()
      }
    }
  }

  private func removeOutsideClickMonitor() {
    if let outsideClickMonitor {
      NSEvent.removeMonitor(outsideClickMonitor)
      self.outsideClickMonitor = nil
    }
  }
}

private final class FinderPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
