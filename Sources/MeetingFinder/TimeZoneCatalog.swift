import Foundation

struct TimeZoneOption: Identifiable, Equatable, Sendable {
  let id: String
  let cityName: String
  let detail: String
  private let fallbackUTCOffsetMinutes: Int

  init(id: String, cityName: String, detail: String, utcOffsetMinutes: Int) {
    self.id = id
    self.cityName = cityName
    self.detail = detail
    fallbackUTCOffsetMinutes = utcOffsetMinutes
  }

  var utcOffsetMinutes: Int {
    guard let timeZone = TimeZone(identifier: id) else { return fallbackUTCOffsetMinutes }
    return timeZone.secondsFromGMT(for: Date()) / 60
  }

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
        let preferredIdentifier = preferredIdentifier(for: identifier)
        guard let timeZone = TimeZone(identifier: preferredIdentifier) else { return nil }
        let genericName =
          timeZone.localizedName(for: .generic, locale: .current) ?? preferredIdentifier
        return TimeZoneOption(
          id: preferredIdentifier,
          cityName: cityName(for: preferredIdentifier),
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

    let foldedQuery = fold(normalizedQuery)

    return all.filter { option in
      searchableTerms(for: option).contains { term in
        fold(term).contains(foldedQuery)
      }
    }.sorted { lhs, rhs in
      let lhsHasExactShortcut = shortcuts(for: lhs).contains { fold($0) == foldedQuery }
      let rhsHasExactShortcut = shortcuts(for: rhs).contains { fold($0) == foldedQuery }
      if lhsHasExactShortcut != rhsHasExactShortcut {
        return lhsHasExactShortcut
      }
      return lhs.cityName.localizedCaseInsensitiveCompare(rhs.cityName) == .orderedAscending
    }
  }

  static func matchingShortcut(for option: TimeZoneOption, query: String) -> String? {
    let foldedQuery = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
    guard !foldedQuery.isEmpty else { return nil }
    return shortcuts(for: option).first { shortcut in
      fold(shortcut).contains(foldedQuery)
    }
  }

  static func shortcuts(for option: TimeZoneOption) -> [String] {
    var shortcuts = Set(shortcutAliases[option.id] ?? [])
    shortcuts.formUnion(systemShortcuts[option.id] ?? [])

    return shortcuts.sorted { lhs, rhs in
      if lhs.count == rhs.count { return lhs < rhs }
      return lhs.count < rhs.count
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

  private static func searchableTerms(for option: TimeZoneOption) -> [String] {
    [option.cityName, option.detail, option.id, option.offsetLabel] + shortcuts(for: option)
  }

  private static func preferredIdentifier(for identifier: String) -> String {
    preferredIdentifiers[identifier] ?? identifier
  }

  private static func fold(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  }

  private static let abbreviationReferenceDates: [Date] = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return [
      calendar.date(from: DateComponents(year: 2026, month: 1, day: 15)) ?? Date(),
      calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)) ?? Date(),
    ]
  }()

  private static let systemShortcuts: [String: Set<String>] = {
    var shortcutsByIdentifier: [String: Set<String>] = [:]

    for (abbreviation, identifier) in TimeZone.abbreviationDictionary {
      shortcutsByIdentifier[identifier, default: []].insert(abbreviation)
    }

    for identifier in TimeZone.knownTimeZoneIdentifiers {
      guard let timeZone = TimeZone(identifier: identifier) else { continue }
      for date in abbreviationReferenceDates {
        if let abbreviation = timeZone.abbreviation(for: date) {
          shortcutsByIdentifier[identifier, default: []].insert(abbreviation)
        }
      }
    }

    return shortcutsByIdentifier
  }()

  private static let shortcutAliases: [String: [String]] = [
    "America/Los_Angeles": ["PT", "PST", "PDT", "SFO", "LAX", "SEA"],
    "America/New_York": ["ET", "EST", "EDT", "NYC", "JFK", "EWR", "BOS", "IAD"],
    "America/Chicago": ["CT", "CST", "CDT", "CHI", "ORD", "DFW"],
    "America/Denver": ["MT", "MST", "MDT", "DEN"],
    "America/Toronto": ["ET", "EST", "EDT", "YYZ"],
    "America/Vancouver": ["PT", "PST", "PDT", "YVR"],
    "America/Sao_Paulo": ["BRT", "SAO", "GRU"],
    "Europe/London": ["GMT", "BST", "LON", "LHR"],
    "Europe/Paris": ["CET", "CEST", "PAR", "CDG"],
    "Europe/Berlin": ["CET", "CEST", "BER"],
    "Asia/Kolkata": ["IST", "DEL", "BOM", "BLR", "CCU"],
    "Asia/Dubai": ["GST", "DXB"],
    "Asia/Singapore": ["SGT", "SIN"],
    "Asia/Hong_Kong": ["HKT", "HKG"],
    "Asia/Tokyo": ["JST", "TYO", "NRT", "HND"],
    "Australia/Sydney": ["AET", "AEST", "AEDT", "SYD"],
    "Australia/Melbourne": ["AET", "AEST", "AEDT", "MEL"],
  ]

  private static let preferredIdentifiers = [
    "Asia/Calcutta": "Asia/Kolkata"
  ]
}
