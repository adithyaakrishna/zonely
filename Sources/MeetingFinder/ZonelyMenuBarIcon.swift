import AppKit

enum ZonelyMenuBarIcon {
  private static let iconSize = NSSize(width: 20, height: 18)

  static func makeImage(bundle: Bundle = .main) -> NSImage {
    let sourceImage = menuBarArtwork(in: bundle) ?? applicationIcon(in: bundle)
    let image = NSImage(size: iconSize, flipped: false) { rect in
      let drawingRect = aspectFitRect(for: sourceImage.size, inside: rect)
      sourceImage.draw(
        in: drawingRect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
      )
      return true
    }
    image.isTemplate = false
    image.accessibilityDescription = "Zonely"
    return image
  }

  private static func menuBarArtwork(in bundle: Bundle) -> NSImage? {
    guard let artworkURL = bundle.url(forResource: "ZonelyMenuBar", withExtension: "svg") else {
      return nil
    }
    return NSImage(contentsOf: artworkURL)
  }

  private static func applicationIcon(in bundle: Bundle) -> NSImage {
    let declaredIconName =
      bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "Zonely.icns"
    let iconPath = declaredIconName as NSString
    let resourceName = iconPath.deletingPathExtension
    let resourceExtension = iconPath.pathExtension.isEmpty ? "icns" : iconPath.pathExtension

    if let iconURL = bundle.url(forResource: resourceName, withExtension: resourceExtension),
      let icon = NSImage(contentsOf: iconURL)
    {
      return icon
    }

    return NSWorkspace.shared.icon(forFile: bundle.bundlePath)
  }

  private static func aspectFitRect(for sourceSize: NSSize, inside bounds: NSRect) -> NSRect {
    guard sourceSize.width > 0, sourceSize.height > 0 else { return bounds }
    let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
    let fittedSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    return NSRect(
      x: bounds.midX - (fittedSize.width / 2),
      y: bounds.midY - (fittedSize.height / 2),
      width: fittedSize.width,
      height: fittedSize.height
    )
  }
}
