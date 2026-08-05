import AppKit

enum ZonelyMenuBarIcon {
  private static let activeCells: [[Bool]] = [
    [false, false, false, false, true, true, true, true, true, true],
    [false, false, true, true, true, true, true, true, false, false],
    [false, false, false, false, true, true, true, false, false, false],
    [false, false, false, true, true, true, true, true, true, false],
    [false, true, true, true, true, true, false, false, false, false],
  ]

  static func makeImage() -> NSImage {
    let iconSize = NSSize(width: 18, height: 18)
    let image = NSImage(size: iconSize, flipped: false) { _ in
      NSGraphicsContext.saveGraphicsState()
      defer { NSGraphicsContext.restoreGraphicsState() }

      drawAvailabilityGrid()
      drawSelector()
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Zonely"
    return image
  }

  private static func drawAvailabilityGrid() {
    let cellSize = NSSize(width: 1.2, height: 1.8)
    let columnGap: CGFloat = 0.38
    let rowGap: CGFloat = 0.65
    let gridWidth = (CGFloat(activeCells[0].count) * cellSize.width) + (9 * columnGap)
    let gridHeight = (CGFloat(activeCells.count) * cellSize.height) + (4 * rowGap)
    let origin = NSPoint(x: (18 - gridWidth) / 2, y: (18 - gridHeight) / 2)

    for (rowIndex, row) in activeCells.enumerated() {
      for (columnIndex, isActive) in row.enumerated() {
        let x = origin.x + (CGFloat(columnIndex) * (cellSize.width + columnGap))
        let y =
          origin.y
          + (CGFloat(activeCells.count - rowIndex - 1) * (cellSize.height + rowGap))
        let cell = NSBezierPath(
          roundedRect: NSRect(origin: NSPoint(x: x, y: y), size: cellSize),
          xRadius: 0.42,
          yRadius: 0.42
        )
        NSColor.black.withAlphaComponent(isActive ? 0.92 : 0.20).setFill()
        cell.fill()
      }
    }
  }

  private static func drawSelector() {
    let selector = NSBezierPath(
      roundedRect: NSRect(x: 7.15, y: 0.9, width: 3.7, height: 16.2),
      xRadius: 1.85,
      yRadius: 1.85
    )

    NSColor.black.withAlphaComponent(0.10).setFill()
    selector.fill()
    NSColor.black.withAlphaComponent(0.96).setStroke()
    selector.lineWidth = 0.85
    selector.stroke()
  }
}
