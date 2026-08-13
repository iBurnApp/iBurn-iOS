import XCTest
@testable import PlayaDB

/// The two-tier BMorg location embargo, as a pure function of (tier, now,
/// passcode). This is the seam the watch app gates every distance, Nearby
/// query, and Navigate affordance on, so the boundary behaviour is the whole
/// contract: one second early is a ToS violation, one second late is a
/// user-visible regression.
final class LocationEmbargoTests: XCTestCase {

    // 2026: camps at 12:01 am PDT on the Sunday before, art at gate opening.
    private let campUnlock = Date(timeIntervalSince1970: 1_787_468_460) // 2026-08-23T07:01:00Z
    private let artUnlock = Date(timeIntervalSince1970: 1_788_073_200)  // 2026-08-30T07:00:00Z

    private func makeEmbargo(campUnlock: Date?) -> LocationEmbargo {
        LocationEmbargo(schedule: EmbargoSchedule(
            campLocationUnlock: campUnlock,
            artLocationUnlock: artUnlock
        ))
    }

    private var embargo: LocationEmbargo {
        makeEmbargo(campUnlock: campUnlock)
    }

    private func date(_ iso8601: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso8601))
    }

    // MARK: - Fixture sanity

    func testFixtureDatesMatchYearSettings() throws {
        XCTAssertEqual(campUnlock, try date("2026-08-23T07:01:00Z"))
        XCTAssertEqual(artUnlock, try date("2026-08-30T07:00:00Z"))
    }

    // MARK: - Tier dates

    func testEverythingLockedBeforeTheCampWindow() throws {
        let now = try date("2026-08-10T12:00:00Z")
        XCTAssertFalse(embargo.canShowCampLocations(now: now, passcodeUnlocked: false))
        XCTAssertFalse(embargo.canShowArtLocations(now: now, passcodeUnlocked: false))
    }

    /// Inclusive at the instant itself: `>=`, matching `BRCEmbargo`.
    func testCampTierUnlocksExactlyAtCampLocationUnlock() throws {
        let oneSecondEarly = campUnlock.addingTimeInterval(-1)
        XCTAssertFalse(embargo.canShowCampLocations(now: oneSecondEarly, passcodeUnlocked: false))
        XCTAssertTrue(embargo.canShowCampLocations(now: campUnlock, passcodeUnlocked: false))
        XCTAssertFalse(embargo.canShowArtLocations(now: campUnlock, passcodeUnlocked: false))
    }

    func testCampWindowShowsCampsButNotArt() throws {
        let now = try date("2026-08-25T12:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: now, passcodeUnlocked: false))
        XCTAssertFalse(embargo.canShowArtLocations(now: now, passcodeUnlocked: false))
    }

    func testArtTierUnlocksExactlyAtEventStart() {
        XCTAssertFalse(embargo.canShowArtLocations(now: artUnlock.addingTimeInterval(-1), passcodeUnlocked: false))
        XCTAssertTrue(embargo.canShowArtLocations(now: artUnlock, passcodeUnlocked: false))
    }

    func testEverythingUnlockedOnceGatesOpen() throws {
        let now = try date("2026-08-31T12:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: now, passcodeUnlocked: false))
        XCTAssertTrue(embargo.canShowArtLocations(now: now, passcodeUnlocked: false))
    }

    func testPasscodeUnlocksBothTiersEarly() throws {
        let now = try date("2026-08-10T12:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: now, passcodeUnlocked: true))
        XCTAssertTrue(embargo.canShowArtLocations(now: now, passcodeUnlocked: true))
    }

    /// Mutant vehicles (and anything else off both tiers) were never embargoed.
    func testUnrestrictedTierIsAlwaysVisible() throws {
        let now = try date("2020-01-01T00:00:00Z")
        XCTAssertTrue(embargo.canShowLocations(tier: .unrestricted, now: now, passcodeUnlocked: false))
        XCTAssertNil(embargo.unlockDate(for: .unrestricted))
    }

    // MARK: - Missing CampLocationUnlock

    /// A year whose settings predate the tier split gets the old, stricter
    /// behaviour: camps stay locked until the gates, not from some earlier date.
    func testMissingCampUnlockFallsBackToTheArtTier() throws {
        let fallback = makeEmbargo(campUnlock: nil)
        XCTAssertEqual(fallback.schedule.campLocationUnlock, artUnlock)

        let insideCampWindow = try date("2026-08-25T12:00:00Z")
        XCTAssertFalse(fallback.canShowCampLocations(now: insideCampWindow, passcodeUnlocked: false))
        XCTAssertTrue(fallback.canShowCampLocations(now: artUnlock, passcodeUnlocked: false))
    }

    /// Defence against a mis-edited plist: camps can never stay locked past the
    /// moment everything else opens.
    func testCampUnlockLaterThanGatesStillOpensAtTheGates() throws {
        let broken = makeEmbargo(campUnlock: try date("2026-09-05T07:00:00Z"))
        XCTAssertTrue(broken.canShowCampLocations(now: artUnlock, passcodeUnlocked: false))
    }

    // MARK: - Which tier an object rides

    private func camp() -> CampObject {
        CampObject(uid: "camp-1", name: "Camp Test", year: 2026)
    }

    private func art() -> ArtObject {
        ArtObject(uid: "art-1", name: "The Hitchin' Post", year: 2026)
    }

    private func event(hostedByCamp: String? = nil, locatedAtArt: String? = nil) -> EventObject {
        EventObject(
            uid: "event-1",
            name: "Test Event",
            year: 2026,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt
        )
    }

    private func occurrence(of event: EventObject) -> EventObjectOccurrence {
        EventObjectOccurrence(
            event: event,
            occurrence: EventOccurrence(
                eventId: event.uid,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                endTime: Date(timeIntervalSince1970: 1_700_003_600)
            ),
            host: nil
        )
    }

    func testCampsAndArtRideTheirOwnTiers() {
        XCTAssertEqual(camp().embargoTier, .camp)
        XCTAssertEqual(art().embargoTier, .art)
    }

    func testMutantVehiclesAreUnrestricted() {
        let vehicle = MutantVehicleObject(uid: "mv-1", name: "Bus", year: 2026)
        XCTAssertEqual(vehicle.embargoTier, .unrestricted)
    }

    func testCampHostedAndUnhostedEventsRideTheCampTier() {
        XCTAssertEqual(event(hostedByCamp: "camp-1").embargoTier, .camp)
        XCTAssertEqual(event().embargoTier, .camp)
    }

    /// An event at an art piece is the art piece's coordinate wearing a hat.
    func testArtLocatedEventsRideTheArtTier() {
        XCTAssertEqual(event(locatedAtArt: "art-1").embargoTier, .art)
    }

    /// The watch's event surfaces carry occurrences, not bare events.
    func testOccurrencesInheritTheirEventsTier() {
        XCTAssertEqual(occurrence(of: event(hostedByCamp: "camp-1")).embargoTier, .camp)
        XCTAssertEqual(occurrence(of: event(locatedAtArt: "art-1")).embargoTier, .art)
    }

    func testCanShowLocationForObjectFollowsTheObjectsTier() throws {
        let insideCampWindow = try date("2026-08-25T12:00:00Z")
        XCTAssertTrue(embargo.canShowLocation(for: camp(), now: insideCampWindow, passcodeUnlocked: false))
        XCTAssertFalse(embargo.canShowLocation(for: art(), now: insideCampWindow, passcodeUnlocked: false))
        XCTAssertTrue(embargo.canShowLocation(for: event(hostedByCamp: "camp-1"),
                                              now: insideCampWindow,
                                              passcodeUnlocked: false))
        XCTAssertFalse(embargo.canShowLocation(for: event(locatedAtArt: "art-1"),
                                               now: insideCampWindow,
                                               passcodeUnlocked: false))

        let afterGates = try date("2026-08-31T12:00:00Z")
        XCTAssertTrue(embargo.canShowLocation(for: art(), now: afterGates, passcodeUnlocked: false))
        XCTAssertTrue(embargo.canShowLocation(for: event(locatedAtArt: "art-1"),
                                              now: afterGates,
                                              passcodeUnlocked: false))
    }

    // MARK: - Reading the schedule out of a bundle

    private func writeSettings(campUnlock: Date?) throws -> URL {
        var settings: [String: Any] = ["EventStart": artUnlock, "PlayaYear": "2026"]
        if let campUnlock {
            settings["CampLocationUnlock"] = campUnlock
        }
        let data = try PropertyListSerialization.data(
            fromPropertyList: settings,
            format: .xml,
            options: 0
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("YearSettings-\(UUID().uuidString).plist")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testScheduleLoadsBothDatesFromAPlist() throws {
        let url = try writeSettings(campUnlock: campUnlock)
        let schedule = try XCTUnwrap(EmbargoSchedule.load(contentsOf: url))
        XCTAssertEqual(schedule.campLocationUnlock, campUnlock)
        XCTAssertEqual(schedule.artLocationUnlock, artUnlock)
    }

    func testScheduleFallsBackWhenThePlistOmitsCampLocationUnlock() throws {
        let url = try writeSettings(campUnlock: nil)
        let schedule = try XCTUnwrap(EmbargoSchedule.load(contentsOf: url))
        XCTAssertEqual(schedule.campLocationUnlock, artUnlock)
    }

    /// A missing resource yields `nil` rather than a permissive default, so the
    /// watch can fail closed on it.
    func testScheduleIsNilForAMissingOrUnusablePlist() throws {
        XCTAssertNil(EmbargoSchedule.load(contentsOf: URL(fileURLWithPath: "/nonexistent/YearSettings.plist")))

        let garbage = FileManager.default.temporaryDirectory
            .appendingPathComponent("garbage-\(UUID().uuidString).plist")
        try XCTUnwrap("not a plist".data(using: .utf8)).write(to: garbage)
        addTeardownBlock { try? FileManager.default.removeItem(at: garbage) }
        XCTAssertNil(EmbargoSchedule.load(contentsOf: garbage))

        let noEventStart = FileManager.default.temporaryDirectory
            .appendingPathComponent("partial-\(UUID().uuidString).plist")
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["PlayaYear": "2026"],
            format: .xml,
            options: 0
        )
        try data.write(to: noEventStart)
        addTeardownBlock { try? FileManager.default.removeItem(at: noEventStart) }
        XCTAssertNil(EmbargoSchedule.load(contentsOf: noEventStart))
    }

    /// The shipped `iBurn/YearSettings.plist` is the file both apps read; if the
    /// keys ever drift the watch fails closed and hides everything all season.
    func testShippedYearSettingsPlistParses() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PlayaDBTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // PlayaDB
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("iBurn/YearSettings.plist")
        let schedule = try XCTUnwrap(EmbargoSchedule.load(contentsOf: plist))
        XCTAssertLessThan(schedule.campLocationUnlock, schedule.artLocationUnlock)
    }
}
