import Foundation

struct TimeZoneOption: Identifiable, Equatable, Sendable {
  let id: String
  let cityName: String
  let detail: String
  let utcOffsetMinutes: Int

  var offsetLabel: String {
    City.formatOffset(utcOffsetMinutes)
  }
}

enum TimeZoneCatalog {
  static let popularIdentifiers = [
    "Asia/Kolkata",
    "Asia/Dubai",
    "Asia/Singapore",
    "Asia/Tokyo",
    "Australia/Sydney",
    "Europe/Berlin",
    "Europe/Paris",
    "America/Chicago",
    "America/Denver",
    "America/Toronto",
  ]

  static let all: [TimeZoneOption] = {
    let now = Date()
    return TimeZone.knownTimeZoneIdentifiers
      .filter { !$0.hasPrefix("Etc/") && $0.contains("/") }
      .compactMap { identifier -> TimeZoneOption? in
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }
        let genericName = timeZone.localizedName(for: .generic, locale: .current) ?? identifier
        return TimeZoneOption(
          id: identifier,
          cityName: cityName(for: identifier),
          detail: genericName,
          utcOffsetMinutes: timeZone.secondsFromGMT(for: now) / 60
        )
      }
      .sorted {
        if $0.utcOffsetMinutes == $1.utcOffsetMinutes {
          return $0.cityName.localizedCaseInsensitiveCompare($1.cityName) == .orderedAscending
        }
        return $0.utcOffsetMinutes < $1.utcOffsetMinutes
      }
  }()

  static var popular: [TimeZoneOption] {
    popularIdentifiers.compactMap { identifier in
      all.first(where: { $0.id == identifier })
    }
  }

  static func search(_ query: String) -> [TimeZoneOption] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedQuery.isEmpty else { return popular }

    return all.filter { option in
      option.cityName.localizedCaseInsensitiveContains(normalizedQuery)
        || option.detail.localizedCaseInsensitiveContains(normalizedQuery)
        || option.id.localizedCaseInsensitiveContains(normalizedQuery)
        || option.offsetLabel.localizedCaseInsensitiveContains(normalizedQuery)
    }
  }

  static func cityName(for identifier: String) -> String {
    let preferredNames = [
      "America/Los_Angeles": "San Francisco",
      "America/New_York": "New York",
      "America/Sao_Paulo": "São Paulo",
      "Europe/London": "London",
    ]
    if let preferredName = preferredNames[identifier] {
      return preferredName
    }

    let rawName = identifier.split(separator: "/").last.map(String.init) ?? identifier
    return rawName.replacingOccurrences(of: "_", with: " ")
  }
}
