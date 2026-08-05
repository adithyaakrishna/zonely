import Foundation
import SwiftUI

struct City: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let utcOffsetMinutes: Int
  let colorIndex: Int

  var color: Color {
    Self.palette[colorIndex % Self.palette.count]
  }

  var offsetLabel: String {
    Self.formatOffset(utcOffsetMinutes)
  }

  func localTime(at utcHour: Int) -> LocalTime {
    let unwrappedMinutes = (utcHour * 60) + utcOffsetMinutes
    let dayOffset = Int(floor(Double(unwrappedMinutes) / 1_440.0))
    let minutesInDay = (unwrappedMinutes % 1_440 + 1_440) % 1_440
    return LocalTime(
      hour: minutesInDay / 60,
      minute: minutesInDay % 60,
      dayOffset: dayOffset
    )
  }

  static func timeZone(
    identifier: String,
    name: String? = nil,
    colorIndex: Int,
    at date: Date = Date()
  ) -> City? {
    guard let timeZone = TimeZone(identifier: identifier) else { return nil }
    return City(
      id: identifier,
      name: name ?? TimeZoneCatalog.cityName(for: identifier),
      utcOffsetMinutes: timeZone.secondsFromGMT(for: date) / 60,
      colorIndex: colorIndex
    )
  }

  static func formatOffset(_ minutes: Int) -> String {
    guard minutes != 0 else { return "UTC" }
    let sign = minutes > 0 ? "+" : "−"
    let absoluteMinutes = abs(minutes)
    let hours = absoluteMinutes / 60
    let remainder = absoluteMinutes % 60
    if remainder == 0 {
      return "UTC\(sign)\(hours)"
    }
    return String(format: "UTC%@%d:%02d", sign, hours, remainder)
  }

  private static let palette: [Color] = [
    Color(red: 0.16, green: 0.45, blue: 0.94),
    Color(red: 0.47, green: 0.17, blue: 0.95),
    Color(red: 0.94, green: 0.00, blue: 0.31),
    Color(red: 0.96, green: 0.51, blue: 0.00),
    Color(red: 0.00, green: 0.62, blue: 0.58),
  ]
}

struct LocalTime: Equatable, Sendable {
  let hour: Int
  let minute: Int
  let dayOffset: Int

  init(hour: Int, minute: Int = 0, dayOffset: Int) {
    self.hour = hour
    self.minute = minute
    self.dayOffset = dayOffset
  }

  var label: String {
    String(format: "%02d:%02d", hour, minute)
  }

  var dayLabel: String? {
    switch dayOffset {
    case ..<0: return "−1d"
    case 1...: return "+1d"
    default: return nil
    }
  }

  var isWorkingHour: Bool {
    let minutes = (hour * 60) + minute
    return ((9 * 60)...((17 * 60) + 59)).contains(minutes)
  }
}

struct MeetingState: Equatable, Sendable {
  static let bestUTCHour = 16
  static let maximumCityCount = 5

  static let defaultCities: [City] = [
    City(
      id: "America/Los_Angeles", name: "San Francisco", utcOffsetMinutes: -7 * 60, colorIndex: 0),
    City(id: "America/New_York", name: "New York", utcOffsetMinutes: -4 * 60, colorIndex: 1),
    City(id: "America/Sao_Paulo", name: "São Paulo", utcOffsetMinutes: -3 * 60, colorIndex: 2),
    City(id: "Europe/London", name: "London", utcOffsetMinutes: 60, colorIndex: 3),
  ]

  var selectedUTCHour: Int = 5
  var cities: [City] = Self.defaultCities

  var selectedTimes: [(city: City, time: LocalTime)] {
    cities.map { ($0, $0.localTime(at: selectedUTCHour)) }
  }

  var workingCount: Int {
    selectedTimes.count { $0.time.isWorkingHour }
  }

  var worksForEveryone: Bool {
    !cities.isEmpty && workingCount == cities.count
  }

  var summary: String {
    switch workingCount {
    case 0:
      return "Off hours everywhere"
    case cities.count where !cities.isEmpty:
      return "Works for everyone"
    case cities.count - 1 where cities.count > 1:
      guard let excluded = selectedTimes.first(where: { !$0.time.isWorkingHour }) else {
        return "\(workingCount) of \(cities.count) in working hours"
      }
      let qualifier = excluded.time.hour < 9 ? "early" : "late"
      return "\(workingCount) of \(cities.count), \(qualifier) in \(excluded.city.name)"
    default:
      return "\(workingCount) of \(cities.count) in working hours"
    }
  }

  func availability(for city: City, utcHour: Int) -> Availability {
    let localTime = city.localTime(at: utcHour)
    let localMinutes = (localTime.hour * 60) + localTime.minute
    if ((8 * 60)..<(9 * 60)).contains(localMinutes)
      || ((18 * 60)..<(19 * 60)).contains(localMinutes)
    {
      return .edge
    }
    if ((9 * 60)...((17 * 60) + 59)).contains(localMinutes) {
      return .working
    }
    return .off
  }

  @discardableResult
  mutating func addTimeZone(_ option: TimeZoneOption) -> Bool {
    guard cities.count < Self.maximumCityCount,
      !cities.contains(where: { $0.id == option.id })
    else {
      return false
    }

    let usedColors = Set(cities.map(\.colorIndex))
    let colorIndex =
      (0..<Self.maximumCityCount).first(where: { !usedColors.contains($0) }) ?? cities.count
    cities.append(
      City(
        id: option.id,
        name: option.cityName,
        utcOffsetMinutes: option.utcOffsetMinutes,
        colorIndex: colorIndex
      )
    )
    return true
  }

  @discardableResult
  mutating func removeTimeZone(id: String) -> Bool {
    guard cities.count > 1, let index = cities.firstIndex(where: { $0.id == id }) else {
      return false
    }
    cities.remove(at: index)
    return true
  }

  @discardableResult
  mutating func moveTimeZone(id: String, by offset: Int) -> Bool {
    guard offset != 0,
      let currentIndex = cities.firstIndex(where: { $0.id == id })
    else {
      return false
    }

    let destination = min(max(currentIndex + offset, 0), cities.count - 1)
    guard destination != currentIndex else { return false }
    let city = cities.remove(at: currentIndex)
    cities.insert(city, at: destination)
    return true
  }
}

enum Availability: Sendable {
  case off
  case edge
  case working
}

@MainActor
final class MeetingViewModel: ObservableObject {
  @Published var state: MeetingState

  private let defaults: UserDefaults
  private static let storedTimeZonesKey = "selectedTimeZoneIdentifiers"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    var state = MeetingState()

    if let identifiers = defaults.stringArray(forKey: Self.storedTimeZonesKey),
      !identifiers.isEmpty
    {
      let restoredCities = identifiers.prefix(MeetingState.maximumCityCount).enumerated().compactMap
      { index, identifier in
        City.timeZone(identifier: identifier, colorIndex: index)
      }
      if !restoredCities.isEmpty {
        state.cities = restoredCities
      }
    }

    self.state = state
  }

  func select(hour: Int) {
    state.selectedUTCHour = min(max(hour, 0), 23)
  }

  func findBestTime() {
    select(hour: bestAvailableHour())
  }

  func addTimeZone(_ option: TimeZoneOption) {
    guard state.addTimeZone(option) else { return }
    persistTimeZones()
  }

  func removeTimeZone(id: String) {
    guard state.removeTimeZone(id: id) else { return }
    persistTimeZones()
  }

  func moveTimeZone(id: String, by offset: Int) {
    guard state.moveTimeZone(id: id, by: offset) else { return }
    persistTimeZones()
  }

  private func bestAvailableHour() -> Int {
    (0..<24).max { lhs, rhs in
      let lhsCount = state.cities.count { $0.localTime(at: lhs).isWorkingHour }
      let rhsCount = state.cities.count { $0.localTime(at: rhs).isWorkingHour }
      if lhsCount == rhsCount {
        return abs(lhs - Self.preferredHour) > abs(rhs - Self.preferredHour)
      }
      return lhsCount < rhsCount
    } ?? MeetingState.bestUTCHour
  }

  private func persistTimeZones() {
    defaults.set(state.cities.map(\.id), forKey: Self.storedTimeZonesKey)
  }

  private static let preferredHour = MeetingState.bestUTCHour
}
