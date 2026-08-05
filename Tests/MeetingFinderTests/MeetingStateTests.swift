import Testing

@testable import MeetingFinder

struct MeetingStateTests {
  @Test func timeZoneConversionWrapsAcrossDays() {
    let sanFrancisco = MeetingState.defaultCities[0]
    #expect(sanFrancisco.localTime(at: 5) == LocalTime(hour: 22, dayOffset: -1))

    let london = MeetingState.defaultCities[3]
    #expect(london.localTime(at: 23) == LocalTime(hour: 0, dayOffset: 1))
  }

  @Test func initialTimeIsOutsideWorkingHoursEverywhere() {
    let state = MeetingState(selectedUTCHour: 5)
    #expect(state.workingCount == 0)
    #expect(state.summary == "Off hours everywhere")
  }

  @Test func bestTimeWorksForEveryCity() {
    let state = MeetingState(selectedUTCHour: MeetingState.bestUTCHour)
    #expect(state.workingCount == 4)
    #expect(state.worksForEveryone)
    #expect(state.summary == "Works for everyone")
  }

  @Test func summaryNamesTheOnlyExcludedCity() {
    #expect(MeetingState(selectedUTCHour: 15).summary == "3 of 4, early in San Francisco")
    #expect(MeetingState(selectedUTCHour: 20).summary == "3 of 4, late in London")
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
}
