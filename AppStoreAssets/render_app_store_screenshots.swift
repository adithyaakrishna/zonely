import AppKit
import SwiftUI

@main
@MainActor
struct RenderAppStoreScreenshots {
  static let canvasSize = CGSize(width: 1_440, height: 900)

  static func main() throws {
    guard CommandLine.arguments.count == 2 else {
      throw RenderError.usage
    }

    let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )

    let iconPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Assets/ZonelyAppIcon.png")
    guard let appIcon = NSImage(contentsOf: iconPath) else {
      throw RenderError.missingIcon
    }

    try render(
      StoreScreenshot(
        eyebrow: "ZONELY FOR MAC",
        title: "Every time zone.\nOne clear view.",
        subtitle: "Compare local hours across your team without calendar math.",
        accent: Color(red: 0.20, green: 0.43, blue: 0.96),
        secondaryAccent: Color(red: 0.55, green: 0.25, blue: 0.96),
        appIcon: appIcon
      ) {
        MeetingFinderView(model: makeModel(selectedHour: 5))
          .padding(MeetingFinderLayout.panelPadding)
          .scaleEffect(1.32)
      },
      named: "01-every-time-zone.png",
      in: outputDirectory
    )

    try render(
      StoreScreenshot(
        eyebrow: "YOUR WORLD, YOUR WAY",
        title: "Add the places\nthat matter.",
        subtitle: "Search cities and international codes, then keep up to six zones close.",
        accent: Color(red: 0.95, green: 0.38, blue: 0.18),
        secondaryAccent: Color(red: 0.95, green: 0.10, blue: 0.45),
        appIcon: appIcon
      ) {
        StoreTimeZonePickerPreview(model: makeModel(selectedHour: 12))
          .scaleEffect(1.43)
      },
      named: "02-add-six-time-zones.png",
      in: outputDirectory
    )

    try render(
      StoreScreenshot(
        eyebrow: "HUMANE MEETING TIMES",
        title: "Find the overlap\nin one click.",
        subtitle: "Jump straight to a time that stays inside everyone’s working day.",
        accent: Color(red: 0.00, green: 0.65, blue: 0.50),
        secondaryAccent: Color(red: 0.18, green: 0.78, blue: 0.49),
        appIcon: appIcon
      ) {
        MeetingFinderView(model: makeModel(selectedHour: MeetingState.bestUTCHour))
          .padding(MeetingFinderLayout.panelPadding)
          .scaleEffect(1.32)
      },
      named: "03-find-the-overlap.png",
      in: outputDirectory
    )
  }

  private static func makeModel(selectedHour: Int) -> MeetingViewModel {
    let suiteName = "Zonely.AppStoreScreenshots.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    let model = MeetingViewModel(defaults: defaults)
    model.select(hour: selectedHour)
    return model
  }

  private static func render<V: View>(
    _ view: V,
    named name: String,
    in directory: URL
  ) throws {
    let renderer = ImageRenderer(
      content: view
        .frame(width: canvasSize.width, height: canvasSize.height)
        .environment(\.colorScheme, .light)
    )
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(canvasSize)

    guard let image = renderer.cgImage else {
      throw RenderError.rendering
    }
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [:]) else {
      throw RenderError.encoding
    }
    try data.write(to: directory.appendingPathComponent(name))
  }
}

private struct StoreTimeZonePickerPreview: View {
  @ObservedObject var model: MeetingViewModel

  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
    count: 3
  )

  private var suggestions: [TimeZoneOption] {
    Array(
      TimeZoneCatalog.search("")
        .filter { option in
          !model.state.cities.contains(where: { $0.id == option.id })
        }
        .prefix(4)
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Time zones")
          .font(.system(size: 15, weight: .semibold, design: .rounded))
        Spacer()
        Text("\(model.state.cities.count) of \(MeetingState.maximumCityCount)")
          .font(.system(size: 10.5, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(Color.primary.opacity(0.055), in: Capsule())
      }

      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
        Text("Search city, code, or time zone")
          .font(.system(size: 12, design: .rounded))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(
        Color.primary.opacity(0.055),
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )

      Text("SELECTED")
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .tracking(0.8)
        .foregroundStyle(.tertiary)

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(model.state.cities) { city in
          selectedCard(for: city)
        }
      }

      Divider()

      Text("SUGGESTED")
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .tracking(0.8)
        .foregroundStyle(.tertiary)

      VStack(spacing: 5) {
        ForEach(suggestions) { option in
          HStack(spacing: 8) {
            Image(systemName: "globe")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
              Text(option.cityName)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
              Text(option.id)
                .font(.system(size: 9.5, design: .rounded))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(option.offsetLabel)
              .font(.system(size: 9.5, design: .monospaced))
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 7)
          .frame(height: 34)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 20)
    .padding(.top, 24)
    .padding(.bottom, 18)
    .frame(width: 318, height: 410)
    .background(
      Color.white.opacity(0.995),
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
    }
    .shadow(color: Color.black.opacity(0.055), radius: 2, x: 0, y: 1)
    .shadow(color: Color.black.opacity(0.13), radius: 16, x: 0, y: 8)
  }

  private func selectedCard(for city: City) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Circle()
          .fill(city.color)
          .frame(width: 5.5, height: 5.5)
        Text(city.name)
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.84)
      }
      .padding(.trailing, 32)

      Text(
        city.relativeOffsetLabel(
          atUTC: model.state.selectedUTCHour,
          on: model.state.referenceDate,
          comparedTo: .autoupdatingCurrent
        )
      )
      .font(.system(size: 8, design: .rounded))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.68)
    }
    .overlay(alignment: .topTrailing) {
      HStack(spacing: 1) {
        Image(systemName: "info.circle")
          .font(.system(size: 8, weight: .medium))
          .foregroundStyle(.secondary)
          .frame(width: 14, height: 14)
        Image(systemName: "xmark")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 14, height: 14)
      }
    }
    .padding(.horizontal, 6)
    .frame(height: 40)
    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.5)
    }
  }
}

private struct StoreScreenshot<Content: View>: View {
  let eyebrow: String
  let title: String
  let subtitle: String
  let accent: Color
  let secondaryAccent: Color
  let appIcon: NSImage
  @ViewBuilder let content: Content

  var body: some View {
    ZStack {
      Color(red: 0.975, green: 0.978, blue: 0.988)

      Circle()
        .fill(accent.opacity(0.18))
        .frame(width: 720, height: 720)
        .blur(radius: 100)
        .offset(x: 520, y: 330)

      Circle()
        .fill(secondaryAccent.opacity(0.13))
        .frame(width: 540, height: 540)
        .blur(radius: 110)
        .offset(x: -610, y: -370)

      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 14) {
          Image(nsImage: appIcon)
            .resizable()
            .interpolation(.high)
            .frame(width: 54, height: 54)
          Text("Zonely")
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.10))
        }

        Spacer().frame(height: 42)

        Text(eyebrow)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .tracking(2.2)
          .foregroundStyle(accent)

        Spacer().frame(height: 14)

        Text(title)
          .font(.system(size: 54, weight: .bold, design: .rounded))
          .tracking(-1.4)
          .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.09))
          .lineSpacing(-3)

        Spacer().frame(height: 18)

        Text(subtitle)
          .font(.system(size: 21, weight: .regular, design: .rounded))
          .foregroundStyle(Color.black.opacity(0.58))
          .frame(width: 500, alignment: .leading)
          .lineSpacing(5)

        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.leading, 92)
      .padding(.top, 74)
      .padding(.bottom, 78)

      content
        .frame(width: 720, height: 700)
        .offset(x: 325, y: 65)
    }
    .clipped()
  }
}

private enum RenderError: Error {
  case encoding
  case missingIcon
  case rendering
  case usage
}
