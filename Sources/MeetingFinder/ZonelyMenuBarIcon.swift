import AppKit

enum ZonelyMenuBarIcon {
  private static let iconSize = NSSize(width: 18, height: 18)

  static func makeImage(bundle: Bundle = .main) -> NSImage {
    let sourceImage = applicationIcon(in: bundle)
    let image = NSImage(size: iconSize, flipped: false) { rect in
      sourceImage.draw(
        in: rect,
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
}
