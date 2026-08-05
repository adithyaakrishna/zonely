import AppKit

enum ZonelyMenuBarIcon {
  static func makeImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 16, height: 18), flipped: false) { _ in
      NSGraphicsContext.saveGraphicsState()
      defer { NSGraphicsContext.restoreGraphicsState() }

      NSColor.black.setStroke()
      NSColor.black.setFill()

      let globeConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
      if let globe = NSImage(
        systemSymbolName: "globe",
        accessibilityDescription: "Zonely"
      )?.withSymbolConfiguration(globeConfiguration) {
        globe.draw(
          in: NSRect(x: 0.8, y: 4, width: 10, height: 10),
          from: .zero,
          operation: .sourceOver,
          fraction: 1
        )
      }

      let selectorRail = NSBezierPath(
        roundedRect: NSRect(x: 9.4, y: 2, width: 3.8, height: 14),
        xRadius: 1.9,
        yRadius: 1.9
      )
      selectorRail.lineWidth = 1.1
      selectorRail.stroke()

      let sliderThumb = NSBezierPath(
        roundedRect: NSRect(x: 7, y: 7.3, width: 8.8, height: 3.4),
        xRadius: 1.7,
        yRadius: 1.7
      )
      sliderThumb.fill()

      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Zonely"
    return image
  }
}
