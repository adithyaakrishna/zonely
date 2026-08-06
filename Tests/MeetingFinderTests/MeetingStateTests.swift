import Foundation
import Testing

@testable import MeetingFinder

struct MeetingStateTests {
  @MainActor
  @Test func menuBarIconUsesTheRingZTemplateArtwork() {
    let icon = ZonelyMenuBarIcon.makeImage()

    #expect(icon.size == CGSize(width: 18, height: 18))
    #expect(icon.isTemplate)
    #expect(icon.accessibilityDescription == "Zonely")
  }

  @Test func timeZoneInfoDismissesOnlyOutsideInfoButtons() {
    let frames = ["London": CGRect(x: 40, y: 20, width: 12, height: 12)]

    #expect(
      !TimeZonePickerInteraction.shouldDismissInfo(
        at: CGPoint(x: 46, y: 26),
        infoButtonFrames: frames
      ))
    #expect(
      !TimeZonePickerInteraction.shouldDismissInfo(
        at: CGPoint(x: 39, y: 19),
        infoButtonFrames: frames
      ))
    #expect(
      TimeZonePickerInteraction.shouldDismissInfo(
        at: CGPoint(x: 12, y: 12),
        infoButtonFrames: frames
      ))
  }

  @Test func horizontalSwipeRemovesOnlyAfterThreshold() {
    #expect(
      TimeZonePickerInteraction.shouldRemoveTimeZone(
        translation: CGSize(width: -40, height: 4),
        cityCount: 3
      ))
    #expect(
      TimeZonePickerInteraction.shouldRemoveTimeZone(
        translation: CGSize(width: 40, height: -3),
        cityCount: 3
      ))
    #expect(
      !TimeZonePickerInteraction.shouldRemoveTimeZone(
        translation: CGSize(width: 35, height: 0),
        cityCount: 3
      ))
    #expect(
      !TimeZonePickerInteraction.shouldRemoveTimeZone(
        translation: CGSize(width: 40, height: 34),
        cityCount: 3
      ))
    #expect(
      !TimeZonePickerInteraction.shouldRemoveTimeZone(
        translation: CGSize(width: 60, height: 0),
        cityCount: 1
      ))
  }

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
    #expect(
      kolkata.relativeOffsetLabel(atUTC: 20, comparedTo: Self.utc)
        == "5h 30m ahead of you")
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
    let kolkataTimeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
    let newYorkTimeZone = try #require(TimeZone(identifier: "America/New_York"))

    #expect(newYork.utcOffsetMinutes(at: winter) == -300)
    #expect(newYork.utcOffsetMinutes(at: summer) == -240)
    #expect(
      newYork.relativeOffsetLabel(atUTC: 12, on: winter, comparedTo: Self.utc)
        == "5h behind you")
    #expect(
      newYork.relativeOffsetLabel(atUTC: 12, on: summer, comparedTo: Self.utc)
        == "4h behind you")
    #expect(
      newYork.relativeOffsetLabel(atUTC: 12, on: summer, comparedTo: kolkataTimeZone)
        == "9h 30m behind you")
    #expect(
      newYork.relativeOffsetLabel(atUTC: 12, on: summer, comparedTo: newYorkTimeZone)
        == "Same time as you")
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

  @Test func timeZoneListAllowsNoMoreThanSixUniqueCities() {
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
    let dubai = TimeZoneOption(
      id: "Asia/Dubai",
      cityName: "Dubai",
      detail: "Gulf Standard Time",
      utcOffsetMinutes: 240
    )

    let addedKolkata = state.addTimeZone(kolkata)
    #expect(addedKolkata)
    #expect(state.cities.count == 5)
    let addedDuplicate = state.addTimeZone(kolkata)
    let addedTokyo = state.addTimeZone(tokyo)
    let addedSeventh = state.addTimeZone(dubai)
    #expect(!addedDuplicate)
    #expect(addedTokyo)
    #expect(!addedSeventh)
    #expect(state.cities.count == MeetingState.maximumCityCount)
  }

  @Test func mainPickerHeightTracksTheTimeZoneCount() {
    let oneZoneHeight = MeetingFinderLayout.panelSize(for: 1).height
    let sixZoneHeight = MeetingFinderLayout.panelSize(for: 6).height

    #expect(TimelineMetrics.availableHeight(for: 1) == 58)
    #expect(TimelineMetrics.availableHeight(for: 6) == 228)
    #expect(sixZoneHeight - oneZoneHeight == 5 * TimelineMetrics.rowHeight)
    #expect(TimelineMetrics.cellHeight(for: 6) == 28)
    #expect(TimelineMetrics.timeLabelGap == 10)

    let currentFrame = CGRect(x: 40, y: 200, width: 572, height: sixZoneHeight)
    let resizedFrame = MeetingFinderLayout.panelFrame(preservingTopOf: currentFrame, for: 1)
    #expect(resizedFrame.maxY == currentFrame.maxY)
    #expect(resizedFrame.height == oneZoneHeight)
  }

  @Test func panelResizePreservesTopAndAvoidsCompetingNativeAnimation() {
    let original = CGRect(x: 40, y: 300, width: 572, height: 420)
    let resize = MeetingFinderLayout.panelResize(from: original, for: 6)

    #expect(resize.frame.maxY == original.maxY)
    #expect(resize.frame.size == MeetingFinderLayout.panelSize(for: 6))
    #expect(!resize.animates)
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

  @Test func draggedTimeZoneUsesTheTopReorderLayer() {
    let session = TimeZoneReorderSession(cityID: "san-francisco", sourceIndex: 0)

    #expect(ReorderPresentation.layer(for: "san-francisco", session: session) > 0)
    #expect(ReorderPresentation.layer(for: "london", session: session) == 0)
    #expect(
      ReorderPresentation.timelineRowsLayer(for: session)
        > ReorderPresentation.selectorLayer
    )
  }

  private static let summer = ISO8601DateFormatter().date(from: "2026-07-15T00:00:00Z")!
  private static let utc = TimeZone(secondsFromGMT: 0)!
}
