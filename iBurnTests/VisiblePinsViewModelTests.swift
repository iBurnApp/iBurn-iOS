//
//  VisiblePinsViewModelTests.swift
//  iBurnTests
//
//  Unit tests for the map's "Visible Pins" list: grouping map annotations into
//  Art / Camps / Events / Map Pins sections, de-duping repeated annotations,
//  ignoring annotations with no PlayaDB payload, and ordering rows.
//

import XCTest
import CoreLocation
import MapLibre
@testable import PlayaDB
@testable import iBurn

@MainActor
final class VisiblePinsViewModelTests: XCTestCase {

    private var playaDB: PlayaDBImpl!

    // Shared longitude so distance varies only by latitude (~111 km per degree).
    private let baseLon = -119.2
    private let userLocation = CLLocation(latitude: 40.78, longitude: -119.2)

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Builders

    private func makeViewModel(
        annotations: [MLNAnnotation],
        location: CLLocation? = nil
    ) -> VisiblePinsViewModel {
        VisiblePinsViewModel(
            annotations: annotations,
            playaDB: playaDB,
            locationProvider: MockLocationProvider(mockLocation: location)
        )
    }

    private func artAnnotation(uid: String, name: String, lat: Double = 40.781) throws -> PlayaObjectAnnotation {
        let art = ArtObject(uid: uid, name: name, year: 2026, gpsLatitude: lat, gpsLongitude: baseLon)
        return try XCTUnwrap(PlayaObjectAnnotation(art: art))
    }

    private func campAnnotation(uid: String, name: String, lat: Double = 40.782) throws -> PlayaObjectAnnotation {
        let camp = CampObject(uid: uid, name: name, year: 2026, gpsLatitude: lat, gpsLongitude: baseLon)
        return try XCTUnwrap(PlayaObjectAnnotation(camp: camp))
    }

    private func eventAnnotation(uid: String, name: String, lat: Double = 40.783) throws -> PlayaObjectAnnotation {
        let event = EventObject(
            uid: uid,
            name: name,
            year: 2026,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            gpsLatitude: lat,
            gpsLongitude: baseLon
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let occurrence = EventOccurrence(eventId: uid, startTime: start, endTime: start.addingTimeInterval(3600))
        let combined = EventObjectOccurrence(event: event, occurrence: occurrence, host: nil)
        return try XCTUnwrap(PlayaObjectAnnotation(event: combined))
    }

    private func userPin(id: String, title: String?, lat: Double = 40.784, type: BRCMapPointType = .userStar) -> BRCUserMapPoint {
        let pin = BRCUserMapPoint(
            title: title,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: baseLon),
            type: type
        )
        pin.pinId = id
        return pin
    }

    // MARK: - Grouping

    func testGroupsAnnotationsIntoTypeSections() throws {
        let viewModel = makeViewModel(annotations: [
            try artAnnotation(uid: "art-1", name: "Temple"),
            try campAnnotation(uid: "camp-1", name: "Camp Cool"),
            try eventAnnotation(uid: "event-1", name: "Dance Party"),
            userPin(id: "pin-1", title: "My Bike"),
        ])

        let sections = viewModel.sections
        XCTAssertEqual(sections.map(\.title), ["Art", "Camps", "Events", "Map Pins"])
        XCTAssertEqual(sections.map { $0.items.count }, [1, 1, 1, 1])
        XCTAssertFalse(viewModel.isEmpty)
    }

    func testSectionsAreOmittedWhenEmpty() throws {
        let viewModel = makeViewModel(annotations: [
            try campAnnotation(uid: "camp-1", name: "Camp Cool"),
        ])

        XCTAssertEqual(viewModel.sections.map(\.title), ["Camps"])
    }

    func testEmptyAnnotationsProduceNoSections() {
        let viewModel = makeViewModel(annotations: [])

        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertTrue(viewModel.isEmpty)
    }

    // MARK: - De-duplication

    func testDuplicateObjectAnnotationsAreDeDuped() throws {
        // The same art can be emitted by both the "all art" and "favorites" observations.
        let viewModel = makeViewModel(annotations: [
            try artAnnotation(uid: "art-1", name: "Temple"),
            try artAnnotation(uid: "art-1", name: "Temple"),
            try artAnnotation(uid: "art-2", name: "The Man"),
        ])

        let art = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(art.items.count, 2)
    }

    func testDuplicateUserPinsAreDeDupedByPinID() {
        // Two BRCUserMapPoint instances for the same PlayaDB row: identity is `pinId`,
        // not the per-instance random `yapKey`.
        let viewModel = makeViewModel(annotations: [
            userPin(id: "pin-1", title: "My Bike"),
            userPin(id: "pin-1", title: "My Bike"),
        ])

        XCTAssertEqual(viewModel.sections.first?.items.count, 1)
    }

    // MARK: - Unsupported annotations

    func testAnnotationsWithoutPayloadAreIgnored() {
        let payloadless = PlayaObjectAnnotation(
            id: AnyDataObjectID(objectType: .art, uid: "art-1"),
            coordinate: CLLocationCoordinate2D(latitude: 40.78, longitude: -119.2),
            title: "Temple",
            subtitle: nil
        )

        let viewModel = makeViewModel(annotations: [payloadless])

        XCTAssertTrue(viewModel.sections.isEmpty)
    }

    // MARK: - Ordering

    func testSortsNearestFirstWhenLocationIsAvailable() throws {
        // Larger latitude delta == farther from the user at 40.78.
        let viewModel = makeViewModel(
            annotations: [
                try artAnnotation(uid: "far", name: "Aardvark", lat: 40.79),
                try artAnnotation(uid: "near", name: "Zebra", lat: 40.7801),
            ],
            location: userLocation
        )

        let art = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(art.items.map(\.name), ["Zebra", "Aardvark"])
    }

    func testSortsAlphabeticallyWithoutLocation() throws {
        let viewModel = makeViewModel(annotations: [
            try artAnnotation(uid: "z", name: "Zebra", lat: 40.7801),
            try artAnnotation(uid: "a", name: "Aardvark", lat: 40.79),
        ])

        let art = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(art.items.map(\.name), ["Aardvark", "Zebra"])
    }

    // MARK: - User pin display

    func testUntitledUserPinFallsBackToTypeName() throws {
        let viewModel = makeViewModel(annotations: [
            userPin(id: "pin-1", title: nil, type: .userBike),
            userPin(id: "pin-2", title: "   ", type: .userHome),
        ])

        let pins = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(Set(pins.items.map(\.name)), ["Bike", "Home"])
    }

    func testUserPinItemsHaveNoDetailSubject() throws {
        let viewModel = makeViewModel(annotations: [userPin(id: "pin-1", title: "My Bike")])

        let item = try XCTUnwrap(viewModel.sections.first?.items.first)
        XCTAssertNil(item.detailSubject)
        XCTAssertNil(item.favoriteUID)
    }
}
