import CoreLocation
import Foundation

struct GeocodedCityCandidate: Sendable {
  let cityName: String?
  let administrativeArea: String?
  let country: String?
  let timeZoneIdentifier: String?
}

enum CityTimeZoneSearch {
  static let minimumQueryLength = 2

  @MainActor
  static func search(_ query: String) async throws -> [TimeZoneOption] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalizedQuery.count >= minimumQueryLength else { return [] }

    let geocoder = CLGeocoder()
    let placemarks: [CLPlacemark]
    do {
      placemarks = try await geocoder.geocodeAddressString(normalizedQuery)
      try Task.checkCancellation()
    } catch {
      let locationError = error as NSError
      if locationError.domain == kCLErrorDomain,
        locationError.code == CLError.geocodeFoundNoResult.rawValue
      {
        return []
      }
      throw error
    }

    let candidates = placemarks.map { placemark in
      GeocodedCityCandidate(
        cityName: placemark.locality ?? placemark.name,
        administrativeArea: placemark.administrativeArea,
        country: placemark.country,
        timeZoneIdentifier: placemark.timeZone?.identifier
      )
    }
    return options(from: candidates, query: normalizedQuery)
  }

  static func options(
    from candidates: [GeocodedCityCandidate],
    query: String,
    at date: Date = Date()
  ) -> [TimeZoneOption] {
    let fallbackCityName = query.trimmingCharacters(in: .whitespacesAndNewlines)
    var seenResults = Set<String>()

    return candidates.compactMap { candidate -> TimeZoneOption? in
      guard let identifier = candidate.timeZoneIdentifier,
        let timeZone = TimeZone(identifier: identifier)
      else {
        return nil
      }

      let cityName = candidate.cityName.nilIfBlank ?? fallbackCityName
      guard !cityName.isEmpty else { return nil }

      let deduplicationKey = "\(cityName.foldingForSearch)|\(identifier)"
      guard seenResults.insert(deduplicationKey).inserted else { return nil }

      let locationParts = [candidate.administrativeArea, candidate.country]
        .compactMap(\.nilIfBlank)
        .reduce(into: [String]()) { parts, part in
          guard !parts.contains(where: { $0.localizedCaseInsensitiveCompare(part) == .orderedSame })
          else { return }
          parts.append(part)
        }
      let detail =
        locationParts.isEmpty
        ? timeZone.localizedName(for: .generic, locale: .current) ?? identifier
        : locationParts.joined(separator: ", ")

      return TimeZoneOption(
        id: identifier,
        cityName: cityName,
        detail: detail,
        utcOffsetMinutes: timeZone.secondsFromGMT(for: date) / 60
      )
    }
  }
}

extension Optional where Wrapped == String {
  fileprivate var nilIfBlank: String? {
    guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}

extension String {
  fileprivate var foldingForSearch: String {
    folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  }
}
