import AppKit

enum ZonelyMenuBarIcon {
  private static let center = NSPoint(x: 9, y: 9)

  static func makeImage() -> NSImage {
    let iconSize = NSSize(width: 18, height: 18)
    let image = NSImage(size: iconSize, flipped: false) { _ in
      NSGraphicsContext.saveGraphicsState()
      defer { NSGraphicsContext.restoreGraphicsState() }

      drawClock()
      drawSharedWindow()
      drawHands()
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Zonely"
    return image
  }

  private static func drawClock() {
    let clock = NSBezierPath(ovalIn: NSRect(x: 1.9, y: 1.9, width: 14.2, height: 14.2))
    clock.lineWidth = 1.25
    NSColor.black.setStroke()
    clock.stroke()
  }

  private static func drawSharedWindow() {
    let window = NSBezierPath(
      roundedRect: NSRect(x: 7.05, y: 2.65, width: 3.9, height: 12.7),
      xRadius: 1.95,
      yRadius: 1.95
    )
    NSColor.black.withAlphaComponent(0.14).setFill()
    window.fill()
    NSColor.black.setStroke()
    window.lineWidth = 0.75
    window.stroke()
  }

  private static func drawHands() {
    let hands = NSBezierPath()
    hands.move(to: center)
    hands.line(to: NSPoint(x: center.x, y: 12.9))
    hands.move(to: center)
    hands.line(to: NSPoint(x: 12.1, y: center.y))
    hands.lineWidth = 1.35
    hands.lineCapStyle = .round
    hands.lineJoinStyle = .round
    NSColor.black.setStroke()
    hands.stroke()

    let centerPoint = NSBezierPath(
      ovalIn: NSRect(x: center.x - 0.8, y: center.y - 0.8, width: 1.6, height: 1.6)
    )
    NSColor.black.setFill()
    centerPoint.fill()
  }
}
