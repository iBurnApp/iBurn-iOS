//
//  GlobalSearchFilterTests.swift
//  iBurnTests
//
//  Pure-logic coverage for the global search filter model and the results scrubber:
//  day → SQL bounds, time-of-day banding (including the midnight wrap), the
//  one-row-per-event collapse, and the rail's stop computation.
//

import XCTest
@testable import iBurn
@testable import PlayaDB

final class GlobalSearchFilterTests: XCTestCase {

    private var calendar: Calendar { .current }

    // MARK: - Fixtures

    /// A date on an arbitrary but fixed day, at the given local hour.
    private func date(day: Int, hour: Int, minute: Int = 0) throws -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = hour
        components.minute = minute
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func occurrence(
        eventUID: String,
        occurrenceID: Int64,
        start: Date,
        durationHours: Double = 1
    ) -> EventObjectOccurrence {
        let event = EventObject(
            uid: eventUID,
            name: "Event \(eventUID)",
            year: 2026,
            eventTypeLabel: "Class/Workshop",
            eventTypeCode: "work"
        )
        let occurrence = EventOccurrence(
            id: occurrenceID,
            eventId: eventUID,
            startTime: start,
            endTime: start.addingTimeInterval(durationHours * 3600)
        )
        return EventObjectOccurrence(event: event, occurrence: occurrence)
    }

    // MARK: - Day Bounds

    func testDefaultFilterHasNoDayBounds() {
        let filter = GlobalSearchFilter()
        XCTAssertNil(filter.dayBounds)
        XCTAssertTrue(filter.isDefault)
    }

    func testDayBoundsCoverExactlyOneCalendarDay() throws {
        let midAfternoon = try date(day: 30, hour: 15, minute: 42)
        let filter = GlobalSearchFilter(day: midAfternoon)
        let bounds = try XCTUnwrap(filter.dayBounds)

        XCTAssertEqual(bounds.start, calendar.startOfDay(for: midAfternoon))
        XCTAssertEqual(bounds.end.timeIntervalSince(bounds.start), 24 * 3600, accuracy: 3600,
                       "End should be the next day's start (DST-tolerant)")
        XCTAssertEqual(calendar.startOfDay(for: bounds.end),
                       try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: bounds.start)))
    }

    func testDayBoundsAreIndependentOfTimeOfDayWithinTheDay() throws {
        let earlyBounds = try XCTUnwrap(GlobalSearchFilter(day: try date(day: 30, hour: 1)).dayBounds)
        let lateBounds = try XCTUnwrap(GlobalSearchFilter(day: try date(day: 30, hour: 23)).dayBounds)
        XCTAssertEqual(earlyBounds.start, lateBounds.start)
        XCTAssertEqual(earlyBounds.end, lateBounds.end)
    }

    // MARK: - EventFilter Construction

    func testEventFilterCarriesDayBoundsToSQL() throws {
        let day = try date(day: 30, hour: 12)
        let filter = GlobalSearchFilter(day: day)
        let eventFilter = GlobalSearchViewModel.eventFilter(query: "yoga", filter: filter)

        XCTAssertEqual(eventFilter.searchText, "yoga")
        XCTAssertTrue(eventFilter.includeExpired, "Search shows past events too")
        XCTAssertEqual(eventFilter.startDate, calendar.startOfDay(for: day))
        XCTAssertEqual(eventFilter.endDate,
                       try XCTUnwrap(calendar.date(byAdding: .day, value: 1,
                                                   to: calendar.startOfDay(for: day))))
    }

    func testEventFilterHasNoDateBoundsForAnyDay() {
        let eventFilter = GlobalSearchViewModel.eventFilter(query: "yoga", filter: GlobalSearchFilter())
        XCTAssertNil(eventFilter.startDate)
        XCTAssertNil(eventFilter.endDate)
    }

    func testEventFilterForwardsFavoritesAndHappeningNow() {
        let filter = GlobalSearchFilter(onlyFavorites: true, happeningNow: true)
        let eventFilter = GlobalSearchViewModel.eventFilter(query: "yoga", filter: filter)
        XCTAssertTrue(eventFilter.onlyFavorites)
        XCTAssertTrue(eventFilter.happeningNow)
    }

    func testTimeOfDayIsNotExpressedInSQL() throws {
        // The band is an hour-of-day predicate, so it must not narrow the date range —
        // otherwise "Late night, any day" would silently become "late night on one day".
        let filter = GlobalSearchFilter(timeOfDay: .lateNight)
        let eventFilter = GlobalSearchViewModel.eventFilter(query: "yoga", filter: filter)
        XCTAssertNil(eventFilter.startDate)
        XCTAssertNil(eventFilter.endDate)
    }

    // MARK: - Time-of-Day Bands

    func testAnyTimeMatchesEveryHour() {
        for hour in 0..<24 {
            XCTAssertTrue(SearchTimeOfDay.any.contains(hour: hour), "Any should accept \(hour)")
        }
    }

    func testNamedBandsHaveTheDocumentedHours() {
        XCTAssertTrue(SearchTimeOfDay.morning.contains(hour: 6))
        XCTAssertTrue(SearchTimeOfDay.morning.contains(hour: 11))
        XCTAssertFalse(SearchTimeOfDay.morning.contains(hour: 5))
        XCTAssertFalse(SearchTimeOfDay.morning.contains(hour: 12))

        XCTAssertTrue(SearchTimeOfDay.afternoon.contains(hour: 12))
        XCTAssertTrue(SearchTimeOfDay.afternoon.contains(hour: 16))
        XCTAssertFalse(SearchTimeOfDay.afternoon.contains(hour: 17))

        XCTAssertTrue(SearchTimeOfDay.evening.contains(hour: 17))
        XCTAssertTrue(SearchTimeOfDay.evening.contains(hour: 21))
        XCTAssertFalse(SearchTimeOfDay.evening.contains(hour: 22))
    }

    func testLateNightWrapsPastMidnight() {
        XCTAssertTrue(SearchTimeOfDay.lateNight.contains(hour: 22))
        XCTAssertTrue(SearchTimeOfDay.lateNight.contains(hour: 23))
        XCTAssertTrue(SearchTimeOfDay.lateNight.contains(hour: 0), "Midnight is late night")
        XCTAssertTrue(SearchTimeOfDay.lateNight.contains(hour: 3))
        XCTAssertTrue(SearchTimeOfDay.lateNight.contains(hour: 5))
        XCTAssertFalse(SearchTimeOfDay.lateNight.contains(hour: 6), "6am hands off to morning")
        XCTAssertFalse(SearchTimeOfDay.lateNight.contains(hour: 12))
        XCTAssertFalse(SearchTimeOfDay.lateNight.contains(hour: 21))
    }

    func testNamedBandsPartitionTheDay() {
        let named: [SearchTimeOfDay] = [.morning, .afternoon, .evening, .lateNight]
        for hour in 0..<24 {
            let matches = named.filter { $0.contains(hour: hour) }
            XCTAssertEqual(matches.count, 1, "Hour \(hour) should belong to exactly one band")
        }
    }

    func testBandMatchesDatesNotJustHours() throws {
        let lateNightStart = try date(day: 30, hour: 23, minute: 30)
        let pastMidnight = try date(day: 31, hour: 1)
        XCTAssertTrue(SearchTimeOfDay.lateNight.contains(lateNightStart, calendar: calendar))
        XCTAssertTrue(SearchTimeOfDay.lateNight.contains(pastMidnight, calendar: calendar))
        XCTAssertFalse(SearchTimeOfDay.morning.contains(pastMidnight, calendar: calendar))
    }

    // MARK: - Dedupe

    func testDedupeKeepsOneRowPerEvent() throws {
        let occurrences = [
            occurrence(eventUID: "e1", occurrenceID: 1, start: try date(day: 30, hour: 9)),
            occurrence(eventUID: "e1", occurrenceID: 2, start: try date(day: 31, hour: 9)),
            occurrence(eventUID: "e2", occurrenceID: 3, start: try date(day: 31, hour: 10)),
        ]
        let deduped = GlobalSearchViewModel.dedupedOccurrences(
            occurrences, filter: GlobalSearchFilter(), calendar: calendar
        )
        XCTAssertEqual(deduped.map(\.event.uid), ["e1", "e2"])
        XCTAssertEqual(deduped.first?.occurrence.id, 1, "Earliest occurrence wins by default")
    }

    func testDedupeKeepsEarliestOccurrenceMatchingTheBand() throws {
        // Same event at 9am and 11pm. Under "Late night" the 11pm one is the row to show;
        // filtering after the collapse would have dropped the event entirely.
        let occurrences = [
            occurrence(eventUID: "e1", occurrenceID: 1, start: try date(day: 30, hour: 9)),
            occurrence(eventUID: "e1", occurrenceID: 2, start: try date(day: 30, hour: 23)),
            occurrence(eventUID: "e1", occurrenceID: 3, start: try date(day: 31, hour: 23)),
        ]
        let deduped = GlobalSearchViewModel.dedupedOccurrences(
            occurrences, filter: GlobalSearchFilter(timeOfDay: .lateNight), calendar: calendar
        )
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.occurrence.id, 2,
                       "Earliest LATE-NIGHT occurrence, not the earliest overall")
    }

    func testDedupeDropsEventsWithNoMatchingOccurrence() throws {
        let occurrences = [
            occurrence(eventUID: "e1", occurrenceID: 1, start: try date(day: 30, hour: 9)),
            occurrence(eventUID: "e2", occurrenceID: 2, start: try date(day: 30, hour: 23)),
        ]
        let deduped = GlobalSearchViewModel.dedupedOccurrences(
            occurrences, filter: GlobalSearchFilter(timeOfDay: .lateNight), calendar: calendar
        )
        XCTAssertEqual(deduped.map(\.event.uid), ["e2"])
    }

    func testDedupeWithAnyTimeKeepsEverything() throws {
        let occurrences = [
            occurrence(eventUID: "e1", occurrenceID: 1, start: try date(day: 30, hour: 3)),
            occurrence(eventUID: "e2", occurrenceID: 2, start: try date(day: 30, hour: 14)),
            occurrence(eventUID: "e3", occurrenceID: 3, start: try date(day: 30, hour: 20)),
        ]
        let deduped = GlobalSearchViewModel.dedupedOccurrences(
            occurrences, filter: GlobalSearchFilter(), calendar: calendar
        )
        XCTAssertEqual(deduped.count, 3)
    }

    // MARK: - Filter Persistence Compatibility

    func testFilterDecodesPayloadWrittenBeforeDayAndTimeExisted() throws {
        let legacy = Data(#"{"onlyFavorites":true,"happeningNow":false}"#.utf8)
        let decoded = try JSONDecoder().decode(GlobalSearchFilter.self, from: legacy)
        XCTAssertTrue(decoded.onlyFavorites)
        XCTAssertFalse(decoded.happeningNow)
        XCTAssertNil(decoded.day)
        XCTAssertEqual(decoded.timeOfDay, .any)
    }

    func testFilterRoundTripsThroughCoding() throws {
        let original = GlobalSearchFilter(
            onlyFavorites: true,
            happeningNow: false,
            day: try date(day: 30, hour: 0),
            timeOfDay: .evening
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GlobalSearchFilter.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertFalse(decoded.isDefault)
    }

    func testDayOrTimeMakesFilterNonDefault() throws {
        XCTAssertFalse(GlobalSearchFilter(day: try date(day: 30, hour: 0)).isDefault)
        XCTAssertFalse(GlobalSearchFilter(timeOfDay: .morning).isDefault)
        XCTAssertTrue(GlobalSearchFilter(timeOfDay: .any).isDefault)
    }

    // MARK: - Results Index Rail

    private func section(_ type: DataObjectType, title: String, names: [String]) -> SearchResultSection {
        let items: [SearchResultItem] = names.enumerated().map { index, name in
            let uid = "\(type.rawValue)-\(index)"
            switch type {
            case .art:
                return .art(ArtObject(uid: uid, name: name, year: 2026))
            case .camp:
                return .camp(CampObject(uid: uid, name: name, year: 2026))
            case .mutantVehicle:
                return .mutantVehicle(MutantVehicleObject(uid: uid, name: name, year: 2026))
            case .event:
                let start = Date(timeIntervalSince1970: 1_756_000_000 + Double(index) * 3600)
                return .event(occurrence(eventUID: uid, occurrenceID: Int64(index), start: start))
            }
        }
        return SearchResultSection(id: type, title: title, items: items)
    }

    private func eventSection(starts: [Date]) -> SearchResultSection {
        let items: [SearchResultItem] = starts.enumerated().map { index, start in
            .event(occurrence(eventUID: "event-\(index)", occurrenceID: Int64(index), start: start))
        }
        return SearchResultSection(id: .event, title: "Events", items: items)
    }

    /// A date at the given BRC-local hour on a known weekday.
    private func brcDate(day: Int, hour: Int) throws -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = hour
        return try XCTUnwrap(SearchResultIndex.brcCalendar.date(from: components))
    }

    private func names(_ count: Int, prefix: String) -> [String] {
        (0..<count).map { "\(prefix)\($0)" }
    }

    // MARK: Index titles

    func testLetterTitleUsesUppercasedFirstLetter() {
        XCTAssertEqual(SearchResultIndex.letterTitle(for: "Anonymous Village"), "A")
        XCTAssertEqual(SearchResultIndex.letterTitle(for: "astro cats"), "A")
        XCTAssertEqual(SearchResultIndex.letterTitle(for: "Zoo"), "Z")
    }

    func testLetterTitleBucketsNonLettersIntoHash() {
        // Matches the Yap grouping block: "123!@#$ goes to the top in #".
        XCTAssertEqual(SearchResultIndex.letterTitle(for: "1000 Camp"), "#")
        XCTAssertEqual(SearchResultIndex.letterTitle(for: "!Bang"), "#")
        XCTAssertEqual(SearchResultIndex.letterTitle(for: "🔥 Camp"), "#")
        XCTAssertEqual(SearchResultIndex.letterTitle(for: ""), "#")
    }

    func testEventTitleIsDayInitialPlusTwelveHourClock() throws {
        // 2026-08-31 is a Monday.
        XCTAssertEqual(SearchResultIndex.eventTitle(for: try brcDate(day: 31, hour: 6)), "M6")
        XCTAssertEqual(SearchResultIndex.eventTitle(for: try brcDate(day: 31, hour: 13)), "M1")
        XCTAssertEqual(SearchResultIndex.eventTitle(for: try brcDate(day: 31, hour: 0)), "M12",
                       "Midnight reads as 12, matching the legacy transformer")
        XCTAssertEqual(SearchResultIndex.eventTitle(for: try brcDate(day: 31, hour: 12)), "M12")
    }

    func testEventTitlesDistinguishDays() throws {
        // 2026-08-30 is a Sunday, 2026-08-31 a Monday.
        let sunday = SearchResultIndex.eventTitle(for: try brcDate(day: 30, hour: 9))
        let monday = SearchResultIndex.eventTitle(for: try brcDate(day: 31, hour: 9))
        XCTAssertEqual(sunday, "S9")
        XCTAssertEqual(monday, "M9")
        XCTAssertNotEqual(sunday, monday, "Same hour on different days needs distinct stops")
    }

    func testIndexTitleDispatchesPerType() throws {
        let camp = SearchResultItem.camp(CampObject(uid: "c", name: "Zoo", year: 2026))
        XCTAssertEqual(SearchResultIndex.indexTitle(for: camp), "Z")

        let event = SearchResultItem.event(
            occurrence(eventUID: "e", occurrenceID: 1, start: try brcDate(day: 31, hour: 8))
        )
        XCTAssertEqual(SearchResultIndex.indexTitle(for: event), "M8")
    }

    // MARK: Spelled titles

    func testSpelledEventTitleIsDayAbbreviationAndHour() throws {
        XCTAssertEqual(SearchResultIndex.spelledEventTitle(for: try brcDate(day: 31, hour: 9)), "Mon 9a")
        XCTAssertEqual(SearchResultIndex.spelledEventTitle(for: try brcDate(day: 31, hour: 16)), "Mon 4p")
        XCTAssertEqual(SearchResultIndex.spelledEventTitle(for: try brcDate(day: 31, hour: 0)), "Mon 12a")
        XCTAssertEqual(SearchResultIndex.spelledEventTitle(for: try brcDate(day: 31, hour: 12)), "Mon 12p")
    }

    func testSpelledTitleFallsBackToTheLetterForNonEvents() {
        let camp = SearchResultItem.camp(CampObject(uid: "c", name: "Zoo", year: 2026))
        XCTAssertEqual(SearchResultIndex.spelledTitle(for: camp), "Z")
    }

    func testMarkerGlyphsMatchAppIconography() {
        XCTAssertEqual(SearchResultIndex.markerGlyph(for: .art), .assetIcon("BRCArtIcon"))
        XCTAssertEqual(SearchResultIndex.markerGlyph(for: .camp), .assetIcon("BRCCampIcon"))
        XCTAssertEqual(SearchResultIndex.markerGlyph(for: .event), .assetIcon("BRCEventIcon"))
        XCTAssertEqual(SearchResultIndex.markerGlyph(for: .mutantVehicle), .symbolIcon("car.fill"))
    }

    // MARK: Stops

    func testEachSectionStartsWithATypeMarker() {
        let sections = [
            section(.art, title: "Art", names: ["Aeshtah", "Bell"]),
            section(.camp, title: "Camps", names: ["Anchor", "Zoo"]),
        ]
        let stops = SearchResultIndex.stops(for: sections)
        XCTAssertEqual(stops.map(\.glyph), [
            .assetIcon("BRCArtIcon"), .text("A"), .text("B"),
            .assetIcon("BRCCampIcon"), .text("A"), .text("Z"),
        ])
        XCTAssertEqual(stops.filter(\.isSectionMarker).count, 2)
    }

    func testTypeMarkerAnchorsToItsSectionsFirstRow() {
        let sections = [
            section(.art, title: "Art", names: ["Aeshtah", "Bell"]),
            section(.camp, title: "Camps", names: ["Anchor", "Zoo"]),
        ]
        let stops = SearchResultIndex.stops(for: sections)
        XCTAssertEqual(stops[0].anchorID, sections[0].items[0].id)
        XCTAssertEqual(stops[3].anchorID, sections[1].items[0].id)
    }

    func testStopsCollapseConsecutiveRuns() {
        let sections = [section(.camp, title: "Camps", names: ["Alpha", "Anchor", "Beta", "Cedar"])]
        let stops = SearchResultIndex.stops(for: sections)
        XCTAssertEqual(stops.dropFirst().map(\.glyph), [.text("A"), .text("B"), .text("C")])
        XCTAssertEqual(stops[1].anchorID, sections[0].items[0].id,
                       "A anchors to the first A row, not the last")
        XCTAssertEqual(stops[2].anchorID, sections[0].items[2].id)
    }

    func testBubbleLabelsNameTheSectionAndTheStop() throws {
        let sections = [
            section(.camp, title: "Camps", names: ["Beta"]),
            eventSection(starts: [try brcDate(day: 31, hour: 9)]),
        ]
        let stops = SearchResultIndex.stops(for: sections)
        XCTAssertEqual(stops.map(\.bubbleLabel), ["Camps", "Camps — B", "Events", "Events — Mon 9a"])
    }

    // MARK: Entries

    func testIndexHiddenForShortLists() {
        let sections = [section(.camp, title: "Camps", names: ["Alpha", "Beta", "Cedar"])]
        XCTAssertTrue(SearchResultIndex.entries(for: sections, maxCount: 40).isEmpty)
    }

    func testIndexHiddenForNoResults() {
        XCTAssertTrue(SearchResultIndex.entries(for: [], maxCount: 40).isEmpty)
    }

    func testEveryStopIsLabelledWhenTheyFit() {
        let letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]
        let sections = [section(.camp, title: "Camps", names: letters.map { $0 + "amp" })]
        let entries = SearchResultIndex.entries(for: sections, maxCount: 40)
        XCTAssertEqual(entries.first?.glyph, .assetIcon("BRCCampIcon"))
        XCTAssertEqual(entries.dropFirst().map(\.glyph), letters.map { IndexRailGlyph.text($0) })
        XCTAssertFalse(entries.contains { $0.isBullet })
        XCTAssertEqual(entries.map(\.id), Array(0..<(letters.count + 1)), "Slots are stable ids")
    }

    func testCrowdedIndexCollapsesToBulletsWithinBudget() throws {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let sections = [section(.camp, title: "Camps", names: letters.map { $0 + "amp" })]
        let entries = SearchResultIndex.entries(for: sections, maxCount: 12)

        XCTAssertEqual(entries.count, 12, "Never draws more slots than it was given")
        XCTAssertTrue(entries.contains { $0.isBullet }, "Crowded rails collapse")
        XCTAssertEqual(entries.first?.glyph, .assetIcon("BRCCampIcon"), "Markers survive the trim")
        XCTAssertEqual(entries.dropFirst().first?.glyph, .text("A"))
        XCTAssertEqual(entries.last?.glyph, .text("Z"), "The rail still spans the whole list")
    }

    func testTypeMarkersAreNeverCollapsed() throws {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let sections = [
            section(.art, title: "Art", names: letters.map { $0 + "rt" }),
            section(.camp, title: "Camps", names: letters.map { $0 + "amp" }),
            section(.mutantVehicle, title: "Vehicles", names: letters.map { $0 + "ehicle" }),
        ]
        let entries = SearchResultIndex.entries(for: sections, maxCount: 20)
        XCTAssertEqual(entries.count, 20)
        let markers = entries.map(\.glyph).filter { glyph in
            if case .assetIcon = glyph { return true }
            if case .symbolIcon = glyph { return true }
            return false
        }
        XCTAssertEqual(markers, [
            .assetIcon("BRCArtIcon"), .assetIcon("BRCCampIcon"), .symbolIcon("car.fill"),
        ], "A restarting A-Z run is unreadable without its type marker")
    }

    func testEveryEntryCarriesATargetAndALabel() {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let sections = [section(.camp, title: "Camps", names: letters.map { $0 + "amp" })]
        for entry in SearchResultIndex.entries(for: sections, maxCount: 12) {
            XCTAssertFalse(entry.anchorID.isEmpty)
            XCTAssertFalse(entry.bubbleLabel.isEmpty)
            XCTAssertNotEqual(entry.bubbleLabel, "•", "The bubble names the real stop")
        }
    }

    func testEntryAnchorsStayInListOrder() {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let sections = [
            section(.camp, title: "Camps", names: letters.map { $0 + "amp" }),
            section(.mutantVehicle, title: "Vehicles", names: letters.map { $0 + "ehicle" }),
        ]
        let rowOrder = sections.flatMap { $0.items.map(\.id) }
        let entries = SearchResultIndex.entries(for: sections, maxCount: 16)
        let positions = entries.compactMap { rowOrder.firstIndex(of: $0.anchorID) }
        XCTAssertEqual(positions.count, entries.count)
        XCTAssertEqual(positions, positions.sorted(), "Scrubbing down must never jump backwards")
    }

    func testEventStopsAreNumbersAcrossASection() throws {
        let starts = try (6..<20).map { try brcDate(day: 31, hour: $0) }
        let entries = SearchResultIndex.entries(for: [eventSection(starts: starts)], maxCount: 40)
        XCTAssertEqual(entries.first?.glyph, .assetIcon("BRCEventIcon"))
        XCTAssertEqual(entries.dropFirst().map(\.glyph),
                       ["M6", "M7", "M8", "M9", "M10", "M11", "M12",
                        "M1", "M2", "M3", "M4", "M5", "M6", "M7"].map { IndexRailGlyph.text($0) })
    }

    func testMixedResultsGiveIconsLettersThenNumbers() throws {
        let sections = [
            section(.camp, title: "Camps", names: ["Alpha", "Beta", "Cedar", "Delta", "Echo", "Fox"]),
            eventSection(starts: try (6..<14).map { try brcDate(day: 31, hour: $0) }),
        ]
        let entries = SearchResultIndex.entries(for: sections, maxCount: 40)
        XCTAssertEqual(entries.prefix(7).map(\.glyph), [
            .assetIcon("BRCCampIcon"), .text("A"), .text("B"), .text("C"),
            .text("D"), .text("E"), .text("F"),
        ])
        XCTAssertEqual(entries.dropFirst(7).map(\.glyph), [
            .assetIcon("BRCEventIcon"), .text("M6"), .text("M7"), .text("M8"),
            .text("M9"), .text("M10"), .text("M11"), .text("M12"), .text("M1"),
        ])
    }

    func testMaxEntriesScalesWithHeight() {
        XCTAssertEqual(SearchResultIndex.maxEntries(forHeight: 0), 0)
        let tall = SearchResultIndex.maxEntries(forHeight: 700)
        let short = SearchResultIndex.maxEntries(forHeight: 200)
        XCTAssertGreaterThan(tall, short)
        XCTAssertGreaterThanOrEqual(tall, 27, "A full A-Z rail plus its marker should fit a phone")
    }

    func testTooLittleRoomHidesTheRail() {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let sections = [section(.camp, title: "Camps", names: letters.map { $0 + "amp" })]
        XCTAssertTrue(SearchResultIndex.entries(for: sections, maxCount: 1).isEmpty)
    }

    func testRailIsEnabledOnlyWhenItCanTakeYouSomewhere() {
        let oneStop = [section(.camp, title: "Camps", names: names(20, prefix: "Alpha "))]
        XCTAssertFalse(SearchResultIndex.isEnabled(for: oneStop),
                       "One letter under one marker still moves you nowhere new")

        let manyStops = [section(.camp, title: "Camps", names: ["Alpha", "Beta", "Cedar"])]
        XCTAssertFalse(SearchResultIndex.isEnabled(for: manyStops), "Too few rows")

        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        XCTAssertTrue(SearchResultIndex.isEnabled(
            for: [section(.camp, title: "Camps", names: letters.map { $0 + "amp" })]
        ))
    }

    // MARK: Prebuilt stops

    /// The render path feeds stops the view model already built rather than deriving them
    /// per body evaluation, so the two entry points have to agree exactly.
    func testEntriesFromPrebuiltStopsMatchTheSectionOverload() {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let sections = [
            section(.camp, title: "Camps", names: letters.map { $0 + "amp" }),
            section(.art, title: "Art", names: names(14, prefix: "Art ")),
        ]
        let stops = SearchResultIndex.stops(for: sections)
        let totalRows = sections.reduce(0) { $0 + $1.items.count }

        for maxCount in [2, 8, 12, 20, 40] {
            XCTAssertEqual(
                SearchResultIndex.entries(stops: stops, totalRows: totalRows, maxCount: maxCount)
                    .map(\.anchorID),
                SearchResultIndex.entries(for: sections, maxCount: maxCount).map(\.anchorID),
                "maxCount \(maxCount)"
            )
        }
    }

    func testIsEnabledFromPrebuiltStopsMatchesTheSectionOverload() {
        let letters = (0..<26).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let cases = [
            [section(.camp, title: "Camps", names: names(20, prefix: "Alpha "))],
            [section(.camp, title: "Camps", names: ["Alpha", "Beta", "Cedar"])],
            [section(.camp, title: "Camps", names: letters.map { $0 + "amp" })],
            [],
        ]
        for sections in cases {
            XCTAssertEqual(
                SearchResultIndex.isEnabled(
                    stops: SearchResultIndex.stops(for: sections),
                    totalRows: sections.reduce(0) { $0 + $1.items.count }
                ),
                SearchResultIndex.isEnabled(for: sections)
            )
        }
    }

    // MARK: - Name Sorting

    func testSortedByNameIsCaseInsensitive() {
        let items: [SearchResultItem] = [
            .camp(CampObject(uid: "1", name: "Zoo", year: 2026)),
            .camp(CampObject(uid: "2", name: "aardvark", year: 2026)),
            .camp(CampObject(uid: "3", name: "Beta", year: 2026)),
        ]
        XCTAssertEqual(
            GlobalSearchViewModel.sortedByName(items).map(\.name),
            ["aardvark", "Beta", "Zoo"],
            "SQLite binary order would have put aardvark after Zoo, breaking the A-Z rail"
        )
    }

    func testSortedByNameKeepsTheIndexMonotonic() {
        let items: [SearchResultItem] = [
            .camp(CampObject(uid: "1", name: "Zoo", year: 2026)),
            .camp(CampObject(uid: "2", name: "aardvark", year: 2026)),
        ]
        let titles = GlobalSearchViewModel.sortedByName(items)
            .map { SearchResultIndex.indexTitle(for: $0) }
        XCTAssertEqual(titles, ["A", "Z"])
    }
}
