import AppKit
import SwiftUI

enum Theme {
  static let panelBackground = color(light: rgb(0.935, 0.935, 0.94), dark: rgb(0.13, 0.13, 0.14))
  static let panelBorder = color(light: black(0.032), dark: white(0.06))
  static let cardBackground = color(light: white(0.96), dark: rgb(0.185, 0.185, 0.20))

  static let textTitle = color(light: rgb(0.07, 0.07, 0.08), dark: rgb(0.94, 0.94, 0.95))
  static let textBody = color(light: rgb(0.12, 0.12, 0.13), dark: rgb(0.90, 0.90, 0.92))
  static let textSecondary = color(light: black(0.57), dark: white(0.62))
  static let textTime = color(light: black(0.46), dark: white(0.50))
  static let textHourAxis = color(light: black(0.42), dark: white(0.45))
  static let textOffset = color(light: black(0.40), dark: white(0.44))
  static let textDayBadge = color(light: black(0.36), dark: white(0.40))

  static let controlIcon = color(light: black(0.62), dark: white(0.70))
  static let controlBackground = color(light: white(0.72), dark: white(0.12))
  static let chipText = color(light: rgb(0.27, 0.27, 0.31), dark: rgb(0.78, 0.78, 0.82))
  static let chipFill = color(light: black(0.045), dark: white(0.08))
  static let buttonFill = color(light: rgb(0.06, 0.06, 0.07), dark: rgb(0.92, 0.92, 0.94))
  static let buttonText = color(light: white(1), dark: rgb(0.08, 0.08, 0.09))
  static let grip = color(light: black(1), dark: white(1))

  static let cellOff = color(light: black(0.055), dark: white(0.12))
  static let indicatorOff = color(light: rgb(0.10, 0.10, 0.11), dark: rgb(0.85, 0.85, 0.88))
  static let handleFallback = color(light: rgb(0.08, 0.08, 0.09), dark: rgb(0.88, 0.88, 0.90))
  static let dotOff = color(light: black(0.14), dark: white(0.22))

  static let successText = color(light: rgb(0.02, 0.52, 0.30), dark: rgb(0.35, 0.85, 0.58))
  static let successFill = color(light: rgb(0.91, 1.0, 0.95), dark: rgb(0.10, 0.28, 0.18))

  static let popoverBackground = color(
    light: rgb(1, 1, 1, 0.995), dark: rgb(0.16, 0.16, 0.17, 0.995))
  static let popoverBorder = color(light: black(0.06), dark: white(0.09))

  static func dynamicNSColor(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }
  }

  static func selectorOuterBorderWidth(for colorScheme: ColorScheme) -> CGFloat {
    colorScheme == .dark ? 0.8 : 1.25
  }

  static func selectorInnerBorderWidth(for colorScheme: ColorScheme) -> CGFloat {
    colorScheme == .dark ? 0.25 : 0.45
  }

  private static func color(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: dynamicNSColor(light: light, dark: dark))
  }

  private static func rgb(
    _ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1
  ) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
  }

  private static func black(_ alpha: CGFloat) -> NSColor {
    rgb(0, 0, 0, alpha)
  }

  private static func white(_ alpha: CGFloat) -> NSColor {
    rgb(1, 1, 1, alpha)
  }
}
