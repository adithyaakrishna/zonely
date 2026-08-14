import AppKit
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

  @Test func worldwideCityResultUsesTheResolvedTimeZone() throws {
    let results = CityTimeZoneSearch.options(
      from: [
        GeocodedCityCandidate(
          cityName: "Pune",
          administrativeArea: "Maharashtra",
          country: "India",
          timeZoneIdentifier: "Asia/Kolkata"
        )
      ],
      query: "Pune"
    )
    let pune = try #require(results.first)

    #expect(pune.cityName == "Pune")
    #expect(pune.detail == "Maharashtra, India")
    #expect(pune.id == "Asia/Kolkata")
  }

  @Test func worldwideCityResultsComeBeforeCatalogMatchesAndDeduplicateTimeZones() {
    let catalogResult = TimeZoneOption(
      id: "Europe/London",
      cityName: "London",
      detail: "United Kingdom Time",
      utcOffsetMinutes: 0
    )
    let cityResult = TimeZoneOption(
      id: "Europe/London",
      cityName: "Cambridge",
      detail: "England, United Kingdom",
      utcOffsetMinutes: 0
    )

    let merged = TimeZoneCatalog.merging(
      catalogResults: [catalogResult],
      cityResults: [cityResult]
    )

    #expect(merged == [cityResult])
  }

  @MainActor
  @Test func selectedWorldwideCityNamePersistsAcrossLaunches() throws {
    let suiteName = "MeetingStateTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let london = try #require(TimeZone(identifier: "Europe/London"))
    let model = MeetingViewModel(defaults: defaults, timeZone: london)
    model.addTimeZone(
      TimeZoneOption(
        id: "Asia/Kolkata",
        cityName: "Pune",
        detail: "Maharashtra, India",
        utcOffsetMinutes: 330
      ))

    let restoredModel = MeetingViewModel(defaults: defaults, timeZone: london)
    let restoredPune = try #require(
      restoredModel.state.cities.first { $0.id == "Asia/Kolkata" })
    #expect(restoredPune.name == "Pune")
  }

  @Test func seededCitiesPutTheSystemTimeZoneFirst() throws {
    let kolkata = try #require(TimeZone(identifier: "Asia/Kolkata"))
    let seeded = MeetingState.seededCities(for: kolkata)

    #expect(
      seeded.map(\.id) == [
        "Asia/Kolkata", "America/Los_Angeles", "America/New_York", "Europe/London",
      ])
    #expect(seeded.first?.name == "Kolkata")
    #expect(seeded.map(\.colorIndex) == [0, 1, 2, 3])
  }

  @Test func seededCitiesDoNotDuplicateAMatchingDefault() throws {
    let london = try #require(TimeZone(identifier: "Europe/London"))
    let seeded = MeetingState.seededCities(for: london)

    #expect(seeded.map(\.id) == ["Europe/London", "America/Los_Angeles", "America/New_York"])
  }

  @MainActor
  @Test func launchSeedsTheSystemTimeZoneWhenNothingIsStored() throws {
    let suiteName = "MeetingStateTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let kolkata = try #require(TimeZone(identifier: "Asia/Kolkata"))

    let model = MeetingViewModel(defaults: defaults, timeZone: kolkata)

    #expect(model.state.cities.first?.id == "Asia/Kolkata")
    #expect(!model.state.cities.contains { $0.id == "America/Sao_Paulo" })
  }

  @MainActor
  @Test func storedCitiesWinOverSeeding() throws {
    let suiteName = "MeetingStateTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let kolkata = try #require(TimeZone(identifier: "Asia/Kolkata"))
    let sydney = try #require(TimeZone(identifier: "Australia/Sydney"))

    let model = MeetingViewModel(defaults: defaults, timeZone: kolkata)
    model.addTimeZone(
      TimeZoneOption(
        id: "America/Sao_Paulo",
        cityName: "São Paulo",
        detail: "Brazil",
        utcOffsetMinutes: -180
      ))

    let restoredModel = MeetingViewModel(defaults: defaults, timeZone: sydney)
    #expect(restoredModel.state.cities.first?.id == "Asia/Kolkata")
    #expect(!restoredModel.state.cities.contains { $0.id == "Australia/Sydney" })
  }

  @MainActor
  @Test func themeColorsResolveDifferentlyPerAppearance() throws {
    let lightAppearance = try #require(NSAppearance(named: .aqua))
    let darkAppearance = try #require(NSAppearance(named: .darkAqua))
    let dynamicColor = Theme.dynamicNSColor(
      light: NSColor(red: 0.935, green: 0.935, blue: 0.94, alpha: 1),
      dark: NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
    )

    var lightResolved: NSColor?
    lightAppearance.performAsCurrentDrawingAppearance {
      lightResolved = dynamicColor.usingColorSpace(.sRGB)
    }
    var darkResolved: NSColor?
    darkAppearance.performAsCurrentDrawingAppearance {
      darkResolved = dynamicColor.usingColorSpace(.sRGB)
    }

    let light = try #require(lightResolved)
    let dark = try #require(darkResolved)
    #expect(light != dark)
    #expect(abs(light.redComponent - 0.935) < 0.01)
    #expect(abs(dark.redComponent - 0.13) < 0.01)

    func resolvedCityColor(at index: Int, appearance: NSAppearance) throws -> NSColor {
      let city = City(
        id: "Test/City/\(index)",
        name: "Test City \(index)",
        utcOffsetMinutes: 0,
        colorIndex: index
      )
      var resolved: NSColor?
      appearance.performAsCurrentDrawingAppearance {
        resolved = NSColor(city.color).usingColorSpace(.sRGB)
      }
      return try #require(resolved)
    }

    let expectedPalette: [(red: CGFloat, green: CGFloat, blue: CGFloat)] = [
      (0.16, 0.45, 0.94),
      (0.47, 0.17, 0.95),
      (0.94, 0.00, 0.31),
      (0.96, 0.51, 0.00),
      (0.00, 0.62, 0.58),
      (0.42, 0.67, 0.08),
    ]

    for (index, expected) in expectedPalette.enumerated() {
      let lightCityColor = try resolvedCityColor(at: index, appearance: lightAppearance)
      let darkCityColor = try resolvedCityColor(at: index, appearance: darkAppearance)

      for resolved in [lightCityColor, darkCityColor] {
        #expect(abs(resolved.redComponent - expected.red) < 0.01)
        #expect(abs(resolved.greenComponent - expected.green) < 0.01)
        #expect(abs(resolved.blueComponent - expected.blue) < 0.01)
      }
    }

    #expect(Theme.selectorOuterBorderWidth(for: .light) == 1.25)
    #expect(Theme.selectorInnerBorderWidth(for: .light) == 0.45)
    #expect(Theme.selectorOuterBorderWidth(for: .dark) == 0.8)
    #expect(Theme.selectorInnerBorderWidth(for: .dark) == 0.25)
  }

  @Test func utcHourMatchesTheClockHourOfTheMoment() {
    #expect(MeetingState.utcHour(at: Self.summerAfternoon) == 14)
    #expect(MeetingState.utcHour(at: Self.summer) == 0)
  }

  @MainActor
  @Test func launchSelectsTheCurrentUTCHour() throws {
    let suiteName = "MeetingStateTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let model = MeetingViewModel(defaults: defaults, now: Self.summerAfternoon)
    #expect(model.state.selectedUTCHour == 14)
  }

  @MainActor
  @Test func openingThePanelMovesSelectionToTheCurrentUTCHour() throws {
    let suiteName = "MeetingStateTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let model = MeetingViewModel(defaults: defaults, now: Self.summer)
    model.select(hour: 5)
    model.selectCurrentTime(at: Self.summerAfternoon)
    #expect(model.state.selectedUTCHour == 14)
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
  private static let summerAfternoon = ISO8601DateFormatter().date(
    from: "2026-07-15T14:37:22Z")!
  private static let utc = TimeZone(secondsFromGMT: 0)!
}
