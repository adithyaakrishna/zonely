import Foundation
import Testing

@testable import MeetingFinder

struct MeetingStateTests {
  @Test func timeZoneConversionWrapsAcrossDays() {
    let sanFrancisco = MeetingState.defaultCities[0]
    #expect(
      sanFrancisco.localTime(at: 5, on: Self.summer)
        == LocalTime(hour: 22, dayOffset: -1))

    let london = MeetingState.defaultCities[3]
    #expect(london.localTime(at: 23, on: Self.summer) == LocalTime(hour: 0, dayOffset: 1))
  }

  @Test func initialTimeIsOutsideWorkingHoursEverywhere() {
    let state = MeetingState(selectedUTCHour: 5, referenceDate: Self.summer)
    #expect(state.workingCount == 0)
    #expect(state.summary == "Off hours everywhere")
  }

  @Test func bestTimeWorksForEveryCity() {
    let state = MeetingState(
      selectedUTCHour: MeetingState.bestUTCHour,
      referenceDate: Self.summer
    )
    #expect(state.workingCount == 4)
    #expect(state.worksForEveryone)
    #expect(state.summary == "Works for everyone")
  }

  @Test func summaryNamesTheOnlyExcludedCity() {
    #expect(
      MeetingState(selectedUTCHour: 15, referenceDate: Self.summer).summary
        == "3 of 4, early in San Francisco")
    #expect(
      MeetingState(selectedUTCHour: 20, referenceDate: Self.summer).summary
        == "3 of 4, late in London")
  }

  @Test func fractionalOffsetsDisplayAndConvertCorrectly() {
    let kolkata = City(
      id: "Asia/Kolkata",
      name: "Kolkata",
      utcOffsetMinutes: 330,
      colorIndex: 4
    )
    #expect(kolkata.offsetLabel == "UTC+5:30")
    #expect(kolkata.localTime(at: 20) == LocalTime(hour: 1, minute: 30, dayOffset: 1))
  }

  @Test func daylightSavingOffsetsUseTheSelectedDate() throws {
    let newYork = City(
      id: "America/New_York",
      name: "New York",
      utcOffsetMinutes: -300,
      colorIndex: 0
    )
    let winter = try #require(ISO8601DateFormatter().date(from: "2026-01-15T00:00:00Z"))
    let summer = try #require(ISO8601DateFormatter().date(from: "2026-07-15T00:00:00Z"))

    #expect(newYork.utcOffsetMinutes(at: winter) == -300)
    #expect(newYork.utcOffsetMinutes(at: summer) == -240)
    #expect(newYork.localTime(at: 12, on: winter) == LocalTime(hour: 7, dayOffset: 0))
    #expect(newYork.localTime(at: 12, on: summer) == LocalTime(hour: 8, dayOffset: 0))
  }

  @Test func searchAcceptsInternationalCityAndAirportCodes() {
    #expect(TimeZoneCatalog.search("SFO").first?.id == "America/Los_Angeles")
    #expect(TimeZoneCatalog.search("NYC").first?.id == "America/New_York")
    #expect(TimeZoneCatalog.search("LHR").contains { $0.id == "Europe/London" })
    #expect(TimeZoneCatalog.search("DEL").contains { $0.id == "Asia/Kolkata" })
    #expect(TimeZoneCatalog.search("IST").contains { $0.id == "Asia/Kolkata" })
  }

  @Test func searchAcceptsStandardAndDaylightTimeZoneAbbreviations() {
    #expect(TimeZoneCatalog.search("PST").contains { $0.id == "America/Los_Angeles" })
    #expect(TimeZoneCatalog.search("PDT").contains { $0.id == "America/Los_Angeles" })
    #expect(TimeZoneCatalog.search("CET").contains { $0.id == "Europe/Berlin" })
    #expect(TimeZoneCatalog.search("CEST").contains { $0.id == "Europe/Paris" })
  }

  @Test func timeZoneListAllowsNoMoreThanFiveUniqueCities() {
    var state = MeetingState()
    let kolkata = TimeZoneOption(
      id: "Asia/Kolkata",
      cityName: "Kolkata",
      detail: "India Standard Time",
      utcOffsetMinutes: 330
    )
    let tokyo = TimeZoneOption(
      id: "Asia/Tokyo",
      cityName: "Tokyo",
      detail: "Japan Standard Time",
      utcOffsetMinutes: 540
    )

    let addedKolkata = state.addTimeZone(kolkata)
    #expect(addedKolkata)
    #expect(state.cities.count == 5)
    let addedDuplicate = state.addTimeZone(kolkata)
    let addedSixth = state.addTimeZone(tokyo)
    #expect(!addedDuplicate)
    #expect(!addedSixth)
    #expect(state.cities.count == MeetingState.maximumCityCount)
  }

  @Test func atLeastOneTimeZoneMustRemain() {
    var state = MeetingState(cities: [MeetingState.defaultCities[0]])
    let removedOnlyCity = state.removeTimeZone(id: state.cities[0].id)
    #expect(!removedOnlyCity)
    #expect(state.cities.count == 1)
  }

  @Test func timeZonesCanBeReorderedAndStayWithinBounds() {
    var state = MeetingState()
    let sanFranciscoID = state.cities[0].id

    let movedDown = state.moveTimeZone(id: sanFranciscoID, by: 2)
    #expect(movedDown)
    #expect(state.cities[2].id == sanFranciscoID)

    let movedToEnd = state.moveTimeZone(id: sanFranciscoID, by: 99)
    #expect(movedToEnd)
    #expect(state.cities.last?.id == sanFranciscoID)

    let movedPastEnd = state.moveTimeZone(id: sanFranciscoID, by: 1)
    #expect(!movedPastEnd)
  }

  @Test func reorderPreviewMovesTheDraggedRowAndMakesRoomInEveryColumn() {
    var session = TimeZoneReorderSession(cityID: "san-francisco", sourceIndex: 0)
    session.update(translation: 67, rowHeight: 34, itemCount: 4)

    #expect(session.destinationIndex(rowHeight: 34, itemCount: 4) == 2)
    #expect(session.offset(for: "san-francisco", at: 0, rowHeight: 34, itemCount: 4) == 67)
    #expect(session.offset(for: "sao-paulo", at: 1, rowHeight: 34, itemCount: 4) == -34)
    #expect(session.offset(for: "new-york", at: 2, rowHeight: 34, itemCount: 4) == -34)
    #expect(session.offset(for: "london", at: 3, rowHeight: 34, itemCount: 4) == 0)
    #expect(
      session.reorderedIDs(
        ["san-francisco", "sao-paulo", "new-york", "london"],
        rowHeight: 34
      ) == ["sao-paulo", "new-york", "san-francisco", "london"]
    )
  }

  private static let summer = ISO8601DateFormatter().date(from: "2026-07-15T00:00:00Z")!
}
