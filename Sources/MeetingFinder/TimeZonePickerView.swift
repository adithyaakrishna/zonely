import AppKit
import SwiftUI

struct TimeZonePickerView: View {
  @ObservedObject var model: MeetingViewModel
  @State private var query = ""
  @State private var citySearchResults: [TimeZoneOption] = []
  @State private var citySearchPhase: CitySearchPhase = .idle
  @State private var selectedInfoTimeZoneID: String?
  @State private var infoButtonFrames: [String: CGRect] = [:]

  private let pickerCoordinateSpace = "timeZonePicker"

  private let selectedColumns = Array(
    repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
    count: 3
  )

  private var availableResults: [TimeZoneOption] {
    TimeZoneCatalog.merging(
      catalogResults: TimeZoneCatalog.search(query),
      cityResults: citySearchResults
    )
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
        TextField("Search any city or time zone", text: $query)
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
      Theme.popoverBackground,
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .background(
      PopoverWindowStyler { location in
        dismissSelectedInfoIfNeeded(at: location)
      }
    )
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Theme.popoverBorder, lineWidth: 0.5)
    }
    .shadow(color: Color.black.opacity(0.055), radius: 2, x: 0, y: 1)
    .shadow(color: Color.black.opacity(0.13), radius: 16, x: 0, y: 8)
    .presentationBackground(Theme.popoverBackground)
    .presentationCornerRadius(18)
    .coordinateSpace(name: pickerCoordinateSpace)
    .onPreferenceChange(InfoButtonFramePreferenceKey.self) { frames in
      infoButtonFrames = frames
    }
    .task(id: query) {
      await searchWorldwideCities(for: query)
    }
  }

  private var selectedTimeZones: some View {
    LazyVGrid(columns: selectedColumns, alignment: .leading, spacing: 10) {
      ForEach(model.state.cities) { city in
        SelectedTimeZoneCard(
          city: city,
          relativeOffset: relativeOffset(for: city),
          cityCount: model.state.cities.count,
          pickerCoordinateSpace: pickerCoordinateSpace,
          onToggleInfo: {
            selectedInfoTimeZoneID =
              selectedInfoTimeZoneID == city.id ? nil : city.id
          },
          onRemove: {
            selectedInfoTimeZoneID = nil
            model.removeTimeZone(id: city.id)
          }
        )
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
            selectedInfoTimeZoneID = nil
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
                Text(searchDetail(for: option))
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

        if citySearchPhase == .searching {
          HStack(spacing: 7) {
            ProgressView()
              .controlSize(.mini)
            Text("Searching cities worldwide…")
              .font(.system(size: 10, design: .rounded))
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 34)
          .accessibilityElement(children: .combine)
        }

        if availableResults.isEmpty && citySearchPhase != .searching {
          VStack(spacing: 3) {
            Text(emptyResultsTitle)
              .font(.system(size: 11, design: .rounded))
            if citySearchPhase == .unavailable {
              Text("Check your internet connection and try again")
                .font(.system(size: 9.5, design: .rounded))
            }
          }
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 54)
        }
      }
    }
    .frame(maxHeight: .infinity)
  }

  private var emptyResultsTitle: String {
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "No more suggestions"
    }
    return citySearchPhase == .unavailable
      ? "City search is unavailable" : "No matching cities or time zones"
  }

  private func searchDetail(for option: TimeZoneOption) -> String {
    guard option.detail.localizedCaseInsensitiveCompare(option.id) != .orderedSame else {
      return option.id
    }
    return "\(option.detail) · \(option.id)"
  }

  @MainActor
  private func searchWorldwideCities(for rawQuery: String) async {
    let normalizedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    citySearchResults = []

    guard normalizedQuery.count >= CityTimeZoneSearch.minimumQueryLength else {
      citySearchPhase = .idle
      return
    }

    citySearchPhase = .searching

    do {
      try await Task.sleep(for: .milliseconds(350))
      let results = try await CityTimeZoneSearch.search(normalizedQuery)
      try Task.checkCancellation()
      guard query.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedQuery else { return }
      citySearchResults = results
      citySearchPhase = .finished
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      citySearchPhase = .unavailable
    }
  }
}

private enum CitySearchPhase {
  case idle
  case searching
  case finished
  case unavailable
}

private struct SelectedTimeZoneCard: View {
  let city: City
  let relativeOffset: String
  let cityCount: Int
  let pickerCoordinateSpace: String
  let onToggleInfo: () -> Void
  let onRemove: () -> Void

  @State private var horizontalDragOffset: CGFloat = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
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

      Text(relativeOffset)
        .font(.system(size: 8, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }
    .overlay(alignment: .topTrailing) {
      HStack(spacing: 1) {
        Button(action: onToggleInfo) {
          Image(systemName: "info.circle")
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 14, height: 14)
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
          guard cityCount > 1 else { return }
          onRemove()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(PointingHandCursorModifier())
        .opacity(cityCount == 1 ? 0.42 : 1)
        .help(
          cityCount == 1
            ? "At least one time zone is required" : "Remove \(city.name)"
        )
        .accessibilityLabel("Remove \(city.name)")
        .accessibilityHint(cityCount == 1 ? "At least one time zone is required" : "")
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
    .offset(x: horizontalDragOffset)
    .opacity(1 - min(abs(horizontalDragOffset) / 180, 0.22))
    .simultaneousGesture(horizontalRemovalGesture)
    .accessibilityAction(.delete) {
      guard cityCount > 1 else { return }
      onRemove()
    }
  }

  private var horizontalRemovalGesture: some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        guard abs(value.translation.width) > abs(value.translation.height) else { return }
        horizontalDragOffset = value.translation.width
      }
      .onEnded { value in
        if TimeZonePickerInteraction.shouldRemoveTimeZone(
          translation: value.translation,
          cityCount: cityCount
        ) {
          onRemove()
          horizontalDragOffset = 0
          return
        }

        if reduceMotion {
          horizontalDragOffset = 0
        } else {
          withAnimation(.spring(response: 0.24, dampingFraction: 1)) {
            horizontalDragOffset = 0
          }
        }
      }
  }
}

enum TimeZonePickerInteraction {
  static func shouldRemoveTimeZone(translation: CGSize, cityCount: Int) -> Bool {
    guard cityCount > 1 else { return false }
    let horizontalDistance = abs(translation.width)
    return horizontalDistance >= 36 && horizontalDistance > abs(translation.height) * 1.25
  }

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
  let onMouseDown: (CGPoint) -> Void

  func makeNSView(context: Context) -> PopoverStylingView {
    let view = PopoverStylingView()
    view.onMouseDown = onMouseDown
    return view
  }

  func updateNSView(_ nsView: PopoverStylingView, context: Context) {
    nsView.onMouseDown = onMouseDown
  }
}

private final class PopoverStylingView: NSView {
  var onMouseDown: ((CGPoint) -> Void)?
  private var mouseDownMonitor: Any?

  override var isFlipped: Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    removeMouseDownMonitor()

    DispatchQueue.main.async { [weak self] in
      guard let window = self?.window else { return }
      window.hasShadow = false
      window.invalidateShadow()
    }

    guard let window else { return }
    mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
      [weak self, weak window] event in
      guard let self, let window, event.window === window else { return event }
      onMouseDown?(convert(event.locationInWindow, from: nil))
      return event
    }
  }

  private func removeMouseDownMonitor() {
    guard let mouseDownMonitor else { return }
    NSEvent.removeMonitor(mouseDownMonitor)
    self.mouseDownMonitor = nil
  }
}
