//
//  MapEventPinTests.swift
//  iBurnTests
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Three map-pin bugs, one seam each:
//
//  1. Event callouts read "Hosted by Camp" — the region path built pins from bare
//     `EventObject`s, which carry only their host's *id*, so `primaryLocationString` had
//     nothing to name and returned a placeholder.
//  2. Turning the filter sheet's Events toggle off left happening-now pins on a zoomed-in
//     map, because only the observation layer ever read that setting.
//  3. Finished events kept their pins until the user panned, because nothing re-evaluated
//     the clock.
//

import Foundation
import PlayaDB
import XCTest
@testable import iBurn

final class MapEventPinTests: XCTestCase {

    private let brcLatitude = 40.7931
    private let brcLongitude = -119.2179

    // MARK: - Fixtures

    private func camp(uid: String = "camp-1",
                      name: String = "Palinka Lounge",
                      address: String? = "5:57 & Bodhi") -> CampObject {
        CampObject(
            uid: uid,
            name: name,
            year: 2026,
            locationString: address,
            gpsLatitude: brcLatitude,
            gpsLongitude: brcLongitude
        )
    }

    private func event(uid: String = "event-1",
                       name: String = "Palinka Hour",
                       eventTypeCode: String = "food",
                       hostedByCamp: String? = "camp-1",
                       locatedAtArt: String? = nil,
                       otherLocation: String = "") -> EventObject {
        EventObject(
            uid: uid,
            name: name,
            year: 2026,
            eventTypeLabel: "Food",
            eventTypeCode: eventTypeCode,
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt,
            otherLocation: otherLocation,
            gpsLatitude: brcLatitude,
            gpsLongitude: brcLongitude
        )
    }

    private func occurrence(_ event: EventObject,
                            host: (any PlaceDataObject)?,
                            start: Date,
                            end: Date,
                            id: Int64 = 1) -> EventObjectOccurrence {
        EventObjectOccurrence(
            event: event,
            occurrence: EventOccurrence(id: id,
                                        eventId: event.uid,
                                        startTime: start,
                                        endTime: end),
            host: host
        )
    }

    /// A running occurrence at a named, addressed camp.
    private func runningOccurrence(now: Date,
                                   event: EventObject? = nil,
                                   host: (any PlaceDataObject)? = nil) -> EventObjectOccurrence {
        occurrence(event ?? self.event(),
                   host: host ?? camp(),
                   start: now.addingTimeInterval(-30 * 60),
                   end: now.addingTimeInterval(90 * 60))
    }

    // MARK: - Bug 1: the callout subtitle

    func testCalloutSubtitleNamesTheHostAndItsAddressBeforeTheTime() {
        let now = Date()
        let occ = runningOccurrence(now: now)

        let subtitle = PlayaObjectAnnotation.calloutSubtitle(for: occ,
                                                             now: now,
                                                             canShowAddress: true)

        XCTAssertEqual(subtitle, "Palinka Lounge · 5:57 & Bodhi · \(occ.startAndEndString)")
        XCTAssertFalse(subtitle.contains("Hosted by Camp"),
                       "The placeholder that started all this must not survive anywhere")
    }

    func testCalloutSubtitleDropsTheAddressWhileEmbargoed() {
        let now = Date()
        let occ = runningOccurrence(now: now)

        let subtitle = PlayaObjectAnnotation.calloutSubtitle(for: occ,
                                                             now: now,
                                                             canShowAddress: false)

        XCTAssertEqual(subtitle, "Palinka Lounge · \(occ.startAndEndString)")
        XCTAssertFalse(subtitle.contains("5:57"), "A locked camp contributes its name only")
    }

    /// Not running yet means the day has to be said too — "8:00 AM - 10:00 AM" is ambiguous
    /// across eight days of burn week.
    func testCalloutSubtitleKeepsTheWeekdayForAnEventThatHasNotStarted() {
        let now = Date()
        let occ = occurrence(event(),
                             host: camp(),
                             start: now.addingTimeInterval(20 * 60),
                             end: now.addingTimeInterval(80 * 60))

        let subtitle = PlayaObjectAnnotation.calloutSubtitle(for: occ,
                                                             now: now,
                                                             canShowAddress: true)

        XCTAssertEqual(subtitle,
                       "Palinka Lounge · 5:57 & Bodhi · \(occ.startWeekdayString) \(occ.startAndEndString)")
    }

    /// No joined host: the event's own free-text location is all there is to name.
    func testCalloutSubtitleFallsBackToTheEventsOwnLocation() {
        let now = Date()
        let occ = occurrence(event(hostedByCamp: nil, otherLocation: "Center Camp"),
                             host: nil,
                             start: now.addingTimeInterval(-10 * 60),
                             end: now.addingTimeInterval(50 * 60))

        let subtitle = PlayaObjectAnnotation.calloutSubtitle(for: occ,
                                                             now: now,
                                                             canShowAddress: true)

        XCTAssertEqual(subtitle, "Center Camp · \(occ.startAndEndString)")
    }

    /// The model-level fix, checked on both sides: the inflated occurrence can name its host,
    /// the bare row admits it cannot.
    func testPrimaryLocationStringNoLongerReturnsPlaceholders() {
        let bare = event()
        XCTAssertNil(bare.primaryLocationString)
        XCTAssertEqual(event(hostedByCamp: nil, otherLocation: "Center Camp").primaryLocationString,
                       "Center Camp")

        let now = Date()
        XCTAssertEqual(runningOccurrence(now: now).primaryLocationString,
                       "Palinka Lounge · 5:57 & Bodhi")
        XCTAssertEqual(occurrence(event(), host: camp(address: nil), start: now, end: now)
                        .primaryLocationString,
                       "Palinka Lounge")
    }

    /// The whole point of routing the region path through the occurrence initializer.
    func testEventAnnotationBuiltFromAnOccurrenceCarriesTheRichSubtitle() throws {
        let now = Date()
        let occ = runningOccurrence(now: now)
        let annotation = try XCTUnwrap(PlayaObjectAnnotation(event: occ, now: now))

        let subtitle = try XCTUnwrap(annotation.subtitle)
        XCTAssertTrue(subtitle.hasPrefix("Palinka Lounge"))
        XCTAssertEqual(annotation.title, "Palinka Hour")
    }

    // MARK: - Bug 2: the Events toggle and the event-type filter

    private func regionTitles(objects: [any PlayaDataObject],
                              active: [String: EventObjectOccurrence],
                              showEvents: Bool = true,
                              selectedEventTypeCodes: Set<String>? = nil,
                              now: Date) -> [String] {
        MapRegionAnnotationFilter.annotations(
            from: objects,
            zoomLevel: 18,
            activeEventOccurrences: active,
            showArtOnlyZoomedIn: true,
            showCampsOnlyZoomedIn: true,
            showEvents: showEvents,
            selectedEventTypeCodes: selectedEventTypeCodes,
            artAllowed: true,
            campAllowed: true,
            now: now
        ).compactMap(\.title)
    }

    func testRegionEventsDisappearWhenTheEventsToggleIsOff() {
        let now = Date()
        let subject = event()
        let active = ["event-1": runningOccurrence(now: now, event: subject)]

        XCTAssertEqual(regionTitles(objects: [subject], active: active, showEvents: true, now: now),
                       ["Palinka Hour"])
        XCTAssertEqual(regionTitles(objects: [subject], active: active, showEvents: false, now: now),
                       [],
                       "The filter sheet's Events toggle has to reach the zoomed-in path too")
    }

    func testRegionEventsHonorTheSelectedEventTypes() {
        let now = Date()
        let food = event(uid: "event-food", name: "Pancakes", eventTypeCode: "food")
        let party = event(uid: "event-party", name: "Sound Camp", eventTypeCode: "prty")
        let active = [
            "event-food": runningOccurrence(now: now, event: food),
            "event-party": runningOccurrence(now: now, event: party)
        ]

        XCTAssertEqual(
            regionTitles(objects: [food, party], active: active,
                         selectedEventTypeCodes: ["food"], now: now),
            ["Pancakes"]
        )
        // nil is the `EventFilter.eventTypeCodes` convention for "every type".
        XCTAssertEqual(
            regionTitles(objects: [food, party], active: active,
                         selectedEventTypeCodes: nil, now: now),
            ["Pancakes", "Sound Camp"]
        )
    }

    // MARK: - Bug 3: which occurrence, and when to look again

    func testActiveOccurrencesPrefersTheRunningOccurrenceAndDropsFinishedOnes() throws {
        let now = Date()
        let subject = event()
        let finished = occurrence(subject, host: camp(),
                                  start: now.addingTimeInterval(-3 * 60 * 60),
                                  end: now.addingTimeInterval(-2 * 60 * 60), id: 1)
        let running = occurrence(subject, host: camp(),
                                 start: now.addingTimeInterval(-20 * 60),
                                 end: now.addingTimeInterval(60 * 60), id: 2)
        let later = occurrence(subject, host: camp(),
                               start: now.addingTimeInterval(20 * 60),
                               end: now.addingTimeInterval(80 * 60), id: 3)

        let active = MapRegionAnnotationFilter.activeOccurrences(
            from: [finished, later, running],
            now: now
        )

        XCTAssertEqual(active.count, 1, "One pin per event, whichever occurrence is live")
        XCTAssertEqual(try XCTUnwrap(active["event-1"]).occurrence.id, 2)
    }

    /// Re-evaluating at a later `now` is what actually takes an expired pin off the map.
    func testAnOccurrencePastItsEndLeavesTheActiveSet() {
        let now = Date()
        let running = runningOccurrence(now: now)

        XCTAssertEqual(
            MapRegionAnnotationFilter.activeOccurrences(from: [running], now: now).count,
            1
        )
        let afterItEnded = running.endDate.addingTimeInterval(60)
        XCTAssertEqual(
            MapRegionAnnotationFilter.activeOccurrences(from: [running], now: afterItEnded).count,
            0
        )
    }

    func testNextMinuteBoundaryIsTheDefaultWhenNothingElseIsCloser() {
        // 12:00:10 → 12:01:00, which is 50s away and inside the ceiling.
        let now = Date(timeIntervalSinceReferenceDate: 12 * 60 + 10)
        let next = MapEventRefreshBoundary.nextFireDate(occurrences: [], now: now)
        XCTAssertEqual(next.timeIntervalSince(now), 50, accuracy: 0.001)
    }

    func testNextFireDatePicksTheNearestOccurrenceEdge() {
        // A minute boundary 55s out, and an end time 22s out: the end time wins.
        let now = Date(timeIntervalSinceReferenceDate: 12 * 60 + 5)
        let occ = occurrence(event(), host: camp(),
                             start: now.addingTimeInterval(-60 * 60),
                             end: now.addingTimeInterval(22))

        let next = MapEventRefreshBoundary.nextFireDate(occurrences: [occ], now: now)

        XCTAssertEqual(next.timeIntervalSince(now), 22, accuracy: 0.001)
    }

    func testNextFireDateClampsToTheFloor() {
        let now = Date(timeIntervalSinceReferenceDate: 12 * 60 + 5)
        // Ends in two seconds: the edge is real, but waking up for it is not worth it.
        let occ = occurrence(event(), host: camp(),
                             start: now.addingTimeInterval(-60 * 60),
                             end: now.addingTimeInterval(2))

        let next = MapEventRefreshBoundary.nextFireDate(occurrences: [occ], now: now)

        XCTAssertEqual(next.timeIntervalSince(now),
                       MapEventRefreshBoundary.floorInterval,
                       accuracy: 0.001)
    }

    func testNextFireDateClampsToTheCeiling() {
        // Exactly on a minute boundary, so the next one is a full 60s out, and the only
        // occurrence is days away — the ceiling is what keeps the map ticking at all.
        let now = Date(timeIntervalSinceReferenceDate: 12 * 60)
        let occ = occurrence(event(), host: camp(),
                             start: now.addingTimeInterval(3 * 24 * 60 * 60),
                             end: now.addingTimeInterval(3 * 24 * 60 * 60 + 3600))

        let next = MapEventRefreshBoundary.nextFireDate(occurrences: [occ], now: now)

        XCTAssertEqual(next.timeIntervalSince(now),
                       MapEventRefreshBoundary.ceilingInterval,
                       accuracy: 0.001)
    }

    /// The "starting soon" / "ending soon" thresholds change a pin's colour with nothing else
    /// happening, so they are edges too.
    func testNextFireDateCountsTheStatusThresholdsAsEdges() {
        let now = Date(timeIntervalSinceReferenceDate: 12 * 60)
        // Starts in 30 minutes and 20 seconds: the starting-soon threshold is 20s away.
        let occ = occurrence(event(), host: camp(),
                             start: now.addingTimeInterval(EventPinStatus.startingSoonThreshold + 20),
                             end: now.addingTimeInterval(EventPinStatus.startingSoonThreshold + 3620))

        let next = MapEventRefreshBoundary.nextFireDate(occurrences: [occ], now: now)

        XCTAssertEqual(next.timeIntervalSince(now), 20, accuracy: 0.001)
    }

    // MARK: - The observation layer's clock re-check

    func testHappeningNowPredicateMatchesTheSqlItReplaced() {
        let now = Date()
        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceIsHappeningNow(
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(60),
            now: now
        ))
        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceIsHappeningNow(
            startDate: now.addingTimeInterval(-120),
            endDate: now.addingTimeInterval(-60),
            now: now
        ), "An occurrence that already ended is not happening now")
        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceIsHappeningNow(
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(120),
            now: now
        ))
    }
}
