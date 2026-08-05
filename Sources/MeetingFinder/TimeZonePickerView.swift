import AppKit
import SwiftUI

struct TimeZonePickerView: View {
  @ObservedObject var model: MeetingViewModel
  @State private var query = ""

  private let selectedColumns = Array(
    repeating: GridItem(.flexible(), spacing: 7, alignment: .top),
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
    .background(PopoverWindowStyler())
    .presentationBackground(Color.white.opacity(0.97))
    .presentationCornerRadius(18)
  }

  private var selectedTimeZones: some View {
    LazyVGrid(columns: selectedColumns, alignment: .leading, spacing: 7) {
      ForEach(model.state.cities) { city in
        let relativeOffset = city.relativeOffsetLabel(
          atUTC: model.state.selectedUTCHour,
          on: model.state.referenceDate
        )
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 4) {
            Circle()
              .fill(city.color)
              .frame(width: 6, height: 6)
            Text(city.name)
              .font(.system(size: 9.5, weight: .semibold, design: .rounded))
              .lineLimit(1)
              .minimumScaleFactor(0.84)
          }

          HStack(spacing: 2) {
            Text(relativeOffset)
              .font(.system(size: 8.5, design: .rounded))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .minimumScaleFactor(0.72)
            Spacer(minLength: 0)

            Button {
              model.removeTimeZone(id: city.id)
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .disabled(model.state.cities.count == 1)
            .help(
              model.state.cities.count == 1
                ? "At least one time zone is required" : "Remove \(city.name)")
          }
        }
        .padding(.horizontal, 7)
        .frame(height: 47)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
          RoundedRectangle(cornerRadius: 9)
            .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help(selectedTimeZoneTooltip(for: city, relativeOffset: relativeOffset))
      }
    }
  }

  private func selectedTimeZoneTooltip(for city: City, relativeOffset: String) -> String {
    let fullTimeZoneName =
      TimeZone(identifier: city.id)?.localizedName(for: .generic, locale: .current) ?? city.id
    return "\(city.name)\n\(fullTimeZoneName)\n\(city.id)\n\(relativeOffset)"
  }

  private var searchResults: some View {
    ScrollView {
      LazyVStack(spacing: 2) {
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
      window.hasShadow = true
      window.invalidateShadow()
    }
  }
}
