import AppKit
import SwiftUI

struct TimeZonePickerView: View {
  @ObservedObject var model: MeetingViewModel
  @State private var query = ""
  @State private var selectedInfoTimeZoneID: String?
  @State private var infoButtonFrames: [String: CGRect] = [:]

  private let pickerCoordinateSpace = "timeZonePicker"

  private let selectedColumns = Array(
    repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
    count: 3
  )

  private var availableResults: [TimeZoneOption] {
    TimeZoneCatalog.search(query)
      .filter { option in
        !model.state.cities.contains(where: { $0.id == option.id })
      }
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
        TextField("Search city, code, or time zone", text: $query)
          .textFieldStyle(.plain)
          .font(.system(size: 12, design: .rounded))
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(
        Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

      Text("SELECTED")
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .tracking(0.8)
        .foregroundStyle(.tertiary)

      selectedTimeZones

      Divider()

      HStack {
        Text(query.isEmpty ? "SUGGESTED" : "RESULTS")
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .tracking(0.8)
          .foregroundStyle(.tertiary)
        Spacer()
        if model.state.cities.count == MeetingState.maximumCityCount {
          Text("Remove one to add another")
            .font(.system(size: 9.5, design: .rounded))
            .foregroundStyle(.secondary)
        }
      }

      searchResults
    }
    .padding(16)
    .frame(width: 310, height: 390)
    .background(
      Color.white.opacity(0.995),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .background(PopoverWindowStyler())
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
    }
    .shadow(color: Color.black.opacity(0.055), radius: 2, x: 0, y: 1)
    .shadow(color: Color.black.opacity(0.13), radius: 16, x: 0, y: 8)
    .presentationBackground(Color.white.opacity(0.995))
    .presentationCornerRadius(18)
    .coordinateSpace(name: pickerCoordinateSpace)
    .onPreferenceChange(InfoButtonFramePreferenceKey.self) { frames in
      infoButtonFrames = frames
    }
    .simultaneousGesture(
      SpatialTapGesture(coordinateSpace: .named(pickerCoordinateSpace))
        .onEnded { value in
          dismissSelectedInfoIfNeeded(at: value.location)
        },
      including: .all
    )
  }

  private var selectedTimeZones: some View {
    LazyVGrid(columns: selectedColumns, alignment: .leading, spacing: 10) {
      ForEach(model.state.cities) { city in
        let relativeOffset = relativeOffset(for: city)
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
          .padding(.trailing, 28)

          Text(relativeOffset)
            .font(.system(size: 8, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
        }
        .overlay(alignment: .topTrailing) {
          HStack(spacing: 1) {
            Button {
              selectedInfoTimeZoneID =
                selectedInfoTimeZoneID == city.id ? nil : city.id
            } label: {
              Image(systemName: "info.circle")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(PointingHandCursorModifier())
            .background {
              GeometryReader { proxy in
                Color.clear.preference(
                  key: InfoButtonFramePreferenceKey.self,
                  value: [city.id: proxy.frame(in: .named(pickerCoordinateSpace))]
                )
              }
            }
            .accessibilityLabel("Show details for \(city.name)")

            Button {
              guard model.state.cities.count > 1 else { return }
              if selectedInfoTimeZoneID == city.id {
                selectedInfoTimeZoneID = nil
              }
              model.removeTimeZone(id: city.id)
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .modifier(PointingHandCursorModifier())
            .opacity(model.state.cities.count == 1 ? 0.42 : 1)
            .help(
              model.state.cities.count == 1
                ? "At least one time zone is required" : "Remove \(city.name)"
            )
            .accessibilityLabel("Remove \(city.name)")
            .accessibilityHint(
              model.state.cities.count == 1 ? "At least one time zone is required" : ""
            )
          }
        }
        .padding(.horizontal, 6)
        .frame(height: 40)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .zIndex(selectedInfoTimeZoneID == city.id ? 20 : 0)
      }
    }
    .overlay(alignment: .top) {
      if let city = selectedInfoTimeZone {
        selectedTimeZoneTooltip(for: city, relativeOffset: relativeOffset(for: city))
          .offset(y: selectedTimeZoneGridHeight + 6)
          .transition(.opacity)
          .zIndex(30)
      }
    }
    .zIndex(20)
  }

  private var selectedInfoTimeZone: City? {
    guard let selectedInfoTimeZoneID else { return nil }
    return model.state.cities.first { $0.id == selectedInfoTimeZoneID }
  }

  private func dismissSelectedInfoIfNeeded(at location: CGPoint) {
    guard selectedInfoTimeZoneID != nil else { return }
    if TimeZonePickerInteraction.shouldDismissInfo(
      at: location,
      infoButtonFrames: infoButtonFrames
    ) {
      selectedInfoTimeZoneID = nil
    }
  }

  private var selectedTimeZoneGridHeight: CGFloat {
    model.state.cities.count > 3 ? 90 : 40
  }

  private func relativeOffset(for city: City) -> String {
    city.relativeOffsetLabel(
      atUTC: model.state.selectedUTCHour,
      on: model.state.referenceDate,
      comparedTo: .autoupdatingCurrent
    )
  }

  private func selectedTimeZoneTooltip(for city: City, relativeOffset: String) -> some View {
    let fullTimeZoneName =
      TimeZone(identifier: city.id)?.localizedName(for: .generic, locale: .current) ?? city.id
    let currentTimeZone = TimeZone.autoupdatingCurrent
    let currentTimeZoneName =
      currentTimeZone.localizedName(for: .generic, locale: .current) ?? currentTimeZone.identifier

    return VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 8) {
        Text(city.name)
          .font(.system(size: 10.5, weight: .semibold, design: .rounded))
        Spacer(minLength: 8)
        Text(relativeOffset)
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.72))
      }

      Text(fullTimeZoneName)
        .font(.system(size: 9.5, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.82))

      Text(city.id)
        .font(.system(size: 8.5, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.58))

      if model.state.cities.count == 1 {
        Text("Why is it not removable?")
          .font(.system(size: 8.5, weight: .semibold, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.76))
        Text("Zonely requires at least one time zone.")
          .font(.system(size: 8.5, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.64))
      } else {
        Text("Your timezone: \(currentTimeZoneName)")
          .font(.system(size: 8.5, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.64))
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(width: 268, alignment: .leading)
    .background(
      Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.96),
      in: RoundedRectangle(cornerRadius: 9, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
    }
    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
    .accessibilityElement(children: .combine)
  }

  private var searchResults: some View {
    ScrollView {
      LazyVStack(spacing: 5) {
        ForEach(availableResults.prefix(40)) { option in
          Button {
            model.addTimeZone(option)
            query = ""
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "globe")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
              VStack(alignment: .leading, spacing: 1) {
                Text(option.cityName)
                  .font(.system(size: 11.5, weight: .medium, design: .rounded))
                  .foregroundStyle(.primary)
                  .lineLimit(1)
                Text(option.id)
                  .font(.system(size: 9.5, design: .rounded))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer()
              if let shortcut = TimeZoneCatalog.matchingShortcut(for: option, query: query) {
                Text(shortcut.uppercased())
                  .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 5)
                  .frame(height: 17)
                  .background(Color.primary.opacity(0.05), in: Capsule())
              }
              Text(option.offsetLabel)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .frame(height: 34)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(model.state.cities.count == MeetingState.maximumCityCount)
        }

        if availableResults.isEmpty {
          Text(query.isEmpty ? "No more suggestions" : "No matching time zones")
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 54)
        }
      }
    }
    .frame(maxHeight: .infinity)
  }
}

enum TimeZonePickerInteraction {
  static func shouldDismissInfo(
    at location: CGPoint,
    infoButtonFrames: [String: CGRect]
  ) -> Bool {
    !infoButtonFrames.values.contains { frame in
      frame.insetBy(dx: -2, dy: -2).contains(location)
    }
  }
}

private struct InfoButtonFramePreferenceKey: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]

  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
  }
}

private struct PointingHandCursorModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .onContinuousHover { phase in
        switch phase {
        case .active:
          NSCursor.pointingHand.set()
        case .ended:
          NSCursor.arrow.set()
        }
      }
      .onDisappear {
        NSCursor.arrow.set()
      }
  }
}

private struct PopoverWindowStyler: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    PopoverStylingView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PopoverStylingView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    DispatchQueue.main.async { [weak self] in
      guard let window = self?.window else { return }
      window.hasShadow = false
      window.invalidateShadow()
    }
  }
}
