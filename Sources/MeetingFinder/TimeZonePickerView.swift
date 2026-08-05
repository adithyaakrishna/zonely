import SwiftUI

struct TimeZonePickerView: View {
  @ObservedObject var model: MeetingViewModel
  @State private var query = ""

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
        TextField("Search city or time zone", text: $query)
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
    .presentationBackground(.thinMaterial)
    .presentationCornerRadius(18)
  }

  private var selectedTimeZones: some View {
    VStack(spacing: 2) {
      ForEach(model.state.cities) { city in
        HStack(spacing: 8) {
          Circle()
            .fill(city.color)
            .frame(width: 7, height: 7)
          VStack(alignment: .leading, spacing: 1) {
            Text(city.name)
              .font(.system(size: 11.5, weight: .medium, design: .rounded))
              .lineLimit(1)
            Text(city.offsetLabel)
              .font(.system(size: 9.5, design: .monospaced))
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button {
            model.removeTimeZone(id: city.id)
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(.secondary)
              .frame(width: 22, height: 22)
              .background(Color.primary.opacity(0.05), in: Circle())
          }
          .buttonStyle(.plain)
          .disabled(model.state.cities.count == 1)
          .help(
            model.state.cities.count == 1
              ? "At least one time zone is required" : "Remove \(city.name)")
        }
        .frame(height: 34)
      }
    }
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
