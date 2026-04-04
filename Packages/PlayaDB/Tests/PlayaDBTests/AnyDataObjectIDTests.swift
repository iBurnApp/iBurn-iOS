import XCTest
@testable import PlayaDB
import PlayaAPI

final class AnyDataObjectIDTests: XCTestCase {
    func testInitFromObjectTypeAndUID() {
        XCTAssertEqual(AnyDataObjectID(objectType: .art, uid: "a").uid, "a")
        XCTAssertEqual(AnyDataObjectID(objectType: .camp, uid: "c").uid, "c")
        XCTAssertEqual(AnyDataObjectID(objectType: .event, uid: "e").uid, "e")
        XCTAssertEqual(AnyDataObjectID(objectType: .mutantVehicle, uid: "m").uid, "m")
    }

    func testRoundTripCodable() throws {
        let values: [AnyDataObjectID] = [
            .art(ArtID("a1")),
            .camp(CampID("c1")),
            .event(EventID("e1")),
            .mutantVehicle(MutantVehicleID("m1")),
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([AnyDataObjectID].self, from: data)
        XCTAssertEqual(decoded, values)
    }

    func testUIDAndObjectType() {
        let id = AnyDataObjectID.art("abc")
        XCTAssertEqual(id.uid, "abc")
        XCTAssertEqual(id.objectType, .art)
    }

    func testMutantVehicleIDAndObjectType() {
        let id = AnyDataObjectID.mutantVehicle(MutantVehicleID("mv1"))
        XCTAssertEqual(id.uid, "mv1")
        XCTAssertEqual(id.objectType, .mutantVehicle)
    }
}

