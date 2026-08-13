//
//  ShareURLBuilderTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn
import CoreLocation
import PlayaDB

/// Covers the `iburnapp.com` share links emitted by the SwiftUI detail screen: the URLs must
/// match the format `BRCDeepLinkRouter` parses, and must never carry placement while the
/// embargo is locked.
final class ShareURLBuilderTests: XCTestCase {

    private let builder = ShareURLBuilderImpl(year: "2026")

    // MARK: - Helpers

    private func queryItems(_ url: URL) throws -> [String: String] {
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(components.queryItems)
        return Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
    }

    private func makeArt(gps: Bool = true) -> ArtObject {
        ArtObject(
            uid: "a2Id0000000cbObEAI",
            name: "Temple of Direction",
            year: 2026,
            description: "A quiet place",
            locationString: "12:00 & 2000'",
            gpsLatitude: gps ? 40.786400 : nil,
            gpsLongitude: gps ? -119.203400 : nil
        )
    }

    private func makeCamp() -> CampObject {
        CampObject(
            uid: "a1XVI000008zNKs2AM",
            name: "Camp Chaos",
            year: 2026,
            description: "Pancakes at dawn",
            locationString: "7:30 & E",
            gpsLatitude: 40.780100,
            gpsLongitude: -119.210500
        )
    }

    private func makeEvent(
        hostedByCamp: String? = nil,
        locatedAtArt: String? = nil,
        allDay: Bool = false
    ) -> EventObject {
        EventObject(
            uid: "event-123",
            name: "Sunrise Yoga",
            year: 2026,
            description: "Stretch it out",
            eventTypeLabel: "Class",
            eventTypeCode: "clas",
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt,
            allDay: allDay
        )
    }

    private func makeOccurrence(
        event: EventObject,
        host: (any PlaceDataObject)? = nil
    ) throws -> EventObjectOccurrence {
        let formatter = ISO8601DateFormatter()
        let start = try XCTUnwrap(formatter.date(from: "2026-08-31T14:00:00Z"))
        let end = try XCTUnwrap(formatter.date(from: "2026-08-31T15:30:00Z"))
        let occurrence = EventOccurrence(id: 7, eventId: event.uid, startTime: start, endTime: end)
        return EventObjectOccurrence(event: event, occurrence: occurrence, host: host)
    }

    // MARK: - Art

    func testArtShareURLUnlocked() throws {
        let payload = ShareURLPayload.art(makeArt(), canShowLocation: true)
        let url = try XCTUnwrap(builder.url(for: payload))

        XCTAssertEqual(url.host, "iburnapp.com")
        XCTAssertTrue(url.absoluteString.hasPrefix("https://iburnapp.com/art/?"), url.absoluteString)

        let items = try queryItems(url)
        XCTAssertEqual(items["uid"], "a2Id0000000cbObEAI")
        XCTAssertEqual(items["title"], "Temple of Direction")
        XCTAssertEqual(items["lat"], "40.786400")
        XCTAssertEqual(items["lng"], "-119.203400")
        XCTAssertEqual(items["addr"], "12:00 & 2000'")
        XCTAssertEqual(items["desc"], "A quiet place")
        XCTAssertEqual(items["year"], "2026")
    }

    func testArtShareURLOmitsLocationWhenEmbargoed() throws {
        let payload = ShareURLPayload.art(makeArt(), canShowLocation: false)
        let url = try XCTUnwrap(builder.url(for: payload))

        let items = try queryItems(url)
        XCTAssertEqual(items["uid"], "a2Id0000000cbObEAI")
        XCTAssertNil(items["lat"])
        XCTAssertNil(items["lng"])
        XCTAssertNil(items["addr"])
    }

    // MARK: - Camp

    func testCampShareURLUnlocked() throws {
        let payload = ShareURLPayload.camp(makeCamp(), canShowLocation: true)
        let url = try XCTUnwrap(builder.url(for: payload))

        XCTAssertTrue(url.absoluteString.hasPrefix("https://iburnapp.com/camp/?"), url.absoluteString)
        let items = try queryItems(url)
        XCTAssertEqual(items["uid"], "a1XVI000008zNKs2AM")
        XCTAssertEqual(items["title"], "Camp Chaos")
        XCTAssertEqual(items["addr"], "7:30 & E")
        XCTAssertEqual(items["lat"], "40.780100")
    }

    func testCampShareURLOmitsLocationWhenEmbargoed() throws {
        let payload = ShareURLPayload.camp(makeCamp(), canShowLocation: false)
        let url = try XCTUnwrap(builder.url(for: payload))

        let items = try queryItems(url)
        XCTAssertNil(items["lat"])
        XCTAssertNil(items["lng"])
        XCTAssertNil(items["addr"])
    }

    // MARK: - Events

    func testEventShareURLWithCampHost() throws {
        let camp = makeCamp()
        let event = makeEvent(hostedByCamp: camp.uid)
        let occurrence = try makeOccurrence(event: event, host: camp)
        let payload = ShareURLPayload.event(occurrence, canShowLocation: true)
        let url = try XCTUnwrap(builder.url(for: payload))

        XCTAssertTrue(url.absoluteString.hasPrefix("https://iburnapp.com/event/?"), url.absoluteString)
        let items = try queryItems(url)
        // Deep links address the event, not the synthesized occurrence id.
        XCTAssertEqual(items["uid"], "event-123")
        XCTAssertEqual(items["title"], "Sunrise Yoga")
        XCTAssertEqual(items["host"], "Camp Chaos")
        XCTAssertEqual(items["host_id"], camp.uid)
        XCTAssertEqual(items["host_type"], "camp")
        XCTAssertEqual(items["start"], "20260831T14:00:00")
        XCTAssertEqual(items["end"], "20260831T15:30:00")
        // Event has no GPS of its own, so the host camp's placement is used.
        XCTAssertEqual(items["lat"], "40.780100")
        XCTAssertEqual(items["addr"], "7:30 & E")
        XCTAssertNil(items["all_day"])
    }

    func testEventShareURLWithArtHost() throws {
        let art = makeArt()
        let event = makeEvent(locatedAtArt: art.uid, allDay: true)
        let occurrence = try makeOccurrence(event: event, host: art)
        let payload = ShareURLPayload.event(occurrence, canShowLocation: true)
        let url = try XCTUnwrap(builder.url(for: payload))

        let items = try queryItems(url)
        XCTAssertEqual(items["host"], "Temple of Direction")
        XCTAssertEqual(items["host_id"], art.uid)
        XCTAssertEqual(items["host_type"], "art")
        XCTAssertEqual(items["all_day"], "true")
    }

    func testEventShareURLOmitsLocationWhenEmbargoed() throws {
        let camp = makeCamp()
        let event = makeEvent(hostedByCamp: camp.uid)
        let occurrence = try makeOccurrence(event: event, host: camp)
        let payload = ShareURLPayload.event(occurrence, canShowLocation: false)
        let url = try XCTUnwrap(builder.url(for: payload))

        let items = try queryItems(url)
        XCTAssertNil(items["lat"])
        XCTAssertNil(items["lng"])
        XCTAssertNil(items["addr"])
        // Host identity is not placement, so it survives the embargo.
        XCTAssertEqual(items["host_id"], camp.uid)
        XCTAssertEqual(items["start"], "20260831T14:00:00")
    }

    func testEventObjectShareURLWithoutOccurrenceOmitsDates() throws {
        let event = makeEvent(hostedByCamp: "camp-uid")
        let payload = ShareURLPayload.event(
            event,
            host: .camp(uid: "camp-uid", name: "Camp Chaos"),
            canShowLocation: true
        )
        let url = try XCTUnwrap(builder.url(for: payload))

        let items = try queryItems(url)
        XCTAssertEqual(items["uid"], "event-123")
        XCTAssertNil(items["start"])
        XCTAssertNil(items["end"])
        XCTAssertEqual(items["host_type"], "camp")
    }

    // MARK: - Pins

    func testPinShareURL() throws {
        let payload = ShareURLPayload(
            kind: .pin,
            title: "Meet here",
            coordinate: CLLocationCoordinate2D(latitude: 40.786800, longitude: -119.206800),
            pinType: 3
        )
        let url = try XCTUnwrap(builder.url(for: payload))

        XCTAssertTrue(url.absoluteString.hasPrefix("https://iburnapp.com/pin?"), url.absoluteString)
        let items = try queryItems(url)
        XCTAssertEqual(items["lat"], "40.786800")
        XCTAssertEqual(items["lng"], "-119.206800")
        XCTAssertEqual(items["title"], "Meet here")
        XCTAssertEqual(items["type"], "3")
        XCTAssertEqual(items["year"], "2026")
    }

    // MARK: - Round trip through the deep link parser

    func testShareURLsRoundTripThroughRouter() throws {
        let router = BRCDeepLinkRouter.shared
        let payloads: [ShareURLPayload] = [
            .art(makeArt(), canShowLocation: true),
            .camp(makeCamp(), canShowLocation: true),
            try .event(makeOccurrence(event: makeEvent(hostedByCamp: makeCamp().uid), host: makeCamp()),
                       canShowLocation: true)
        ]

        for payload in payloads {
            let url = try XCTUnwrap(builder.url(for: payload))
            XCTAssertTrue(router.canHandleURL(url), "Router cannot handle \(url)")

            // The type component the router keys off of, and the uid it requires.
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let firstPathComponent = url.pathComponents.filter { $0 != "/" }.first
            XCTAssertEqual(firstPathComponent, payload.kind.rawValue)
            XCTAssertNotNil(components.queryItems?.first { $0.name == "uid" }?.value)
        }
    }

    func testDescriptionIsTruncated() throws {
        let longDescription = String(repeating: "x", count: 400)
        var payload = ShareURLPayload.camp(makeCamp(), canShowLocation: true)
        payload.detailDescription = longDescription
        let url = try XCTUnwrap(builder.url(for: payload))

        let items = try queryItems(url)
        XCTAssertEqual(items["desc"]?.count, 100)
    }

    func testMissingUIDProducesNoURL() {
        let payload = ShareURLPayload(kind: .art, uid: "", title: "No uid")
        XCTAssertNil(builder.url(for: payload))
    }
}
