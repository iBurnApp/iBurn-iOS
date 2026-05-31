import XCTest
import Foundation
@testable import PlayaDB

/// Unit tests for the `PlaceDataObject.address` fallback chains on `CampObject` and `ArtObject`.
final class PlaceDataObjectTests: XCTestCase {

    // MARK: - CampObject.address

    func testCampAddress_PrefersLocationStringOverIntersection() throws {
        let camp = CampObject(
            uid: "camp-1",
            name: "Test Camp",
            year: 2025,
            locationString: "7:30 & E",
            intersection: "Esplanade & 6:00"
        )

        let address = try XCTUnwrap(camp.address)
        XCTAssertEqual(address, "7:30 & E")
    }

    func testCampAddress_FallsBackToIntersectionWhenLocationStringNil() throws {
        let camp = CampObject(
            uid: "camp-2",
            name: "Test Camp",
            year: 2025,
            locationString: nil,
            intersection: "Esplanade & 6:00"
        )

        let address = try XCTUnwrap(camp.address)
        XCTAssertEqual(address, "Esplanade & 6:00")
    }

    func testCampAddress_NilWhenBothNil() {
        let camp = CampObject(
            uid: "camp-3",
            name: "Test Camp",
            year: 2025,
            locationString: nil,
            intersection: nil
        )

        XCTAssertNil(camp.address)
    }

    // MARK: - ArtObject.address

    func testArtAddress_PrefersLocationStringOverTimeBasedAddress() throws {
        let art = ArtObject(
            uid: "art-1",
            name: "Test Art",
            year: 2025,
            locationString: "Deep Playa",
            locationHour: 3,
            locationMinute: 0,
            locationDistance: 500
        )

        let address = try XCTUnwrap(art.address)
        XCTAssertEqual(address, "Deep Playa")
    }

    func testArtAddress_FallsBackToTimeBasedAddressWhenLocationStringNil() throws {
        let art = ArtObject(
            uid: "art-2",
            name: "Test Art",
            year: 2025,
            locationString: nil,
            locationHour: 3,
            locationMinute: 0,
            locationDistance: 500
        )

        let address = try XCTUnwrap(art.address)
        XCTAssertEqual(address, "3:00 & 500'")
    }

    func testArtAddress_FallsBackToTimeBasedAddress_HandlesNilMinuteAndDistance() throws {
        // Given: only locationHour is provided (minute and distance default to 0 in timeBasedAddress)
        let art = ArtObject(
            uid: "art-3",
            name: "Test Art",
            year: 2025,
            locationString: nil,
            locationHour: 6,
            locationMinute: nil,
            locationDistance: nil
        )

        let address = try XCTUnwrap(art.address)
        XCTAssertEqual(address, "6:00 & 0'")
    }

    func testArtAddress_NilWhenLocationStringAndLocationHourBothNil() {
        let art = ArtObject(
            uid: "art-4",
            name: "Test Art",
            year: 2025,
            locationString: nil,
            locationHour: nil
        )

        XCTAssertNil(art.address)
    }
}
