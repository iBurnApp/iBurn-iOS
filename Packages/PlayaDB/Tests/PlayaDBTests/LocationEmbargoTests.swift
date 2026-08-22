import CoreLocation
import XCTest
@testable import PlayaDB

/// The two-tier BMorg location embargo, as a pure function of (tier, now,
/// passcode, in-region). This is the seam the watch app gates every distance,
/// Nearby query, and Navigate affordance on, so the boundary behaviour is the
/// whole contract: one second early is a ToS violation, one second late is a
/// user-visible regression.
///
/// The rule under test is per-tier:
///
/// - camp: `passcodeUnlocked || now >= unlock`
/// - art:  `passcodeUnlocked || (inRegion && now >= unlock)`
///
/// For art the date half alone must never unlock anything — the device clock is
/// user-settable, and a calendar-only gate is defeated in Settings. Camps were
/// relaxed to a date-only unlock on 2026-08-22 so the week-early camp address
/// release is usable while planning from home.
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

    // MARK: - Tier dates (for a device that is on the playa)

    func testEverythingLockedBeforeTheCampWindow() throws {
        let now = try date("2026-08-10T12:00:00Z")
        XCTAssertFalse(embargo.canShowCampLocations(now: now, passcodeUnlocked: false, inRegion: true))
        XCTAssertFalse(embargo.canShowArtLocations(now: now, passcodeUnlocked: false, inRegion: true))
    }

    /// Inclusive at the instant itself: `>=`, matching `BRCEmbargo`.
    func testCampTierUnlocksExactlyAtCampLocationUnlock() throws {
        let oneSecondEarly = campUnlock.addingTimeInterval(-1)
        XCTAssertFalse(embargo.canShowCampLocations(now: oneSecondEarly, passcodeUnlocked: false, inRegion: true))
        XCTAssertTrue(embargo.canShowCampLocations(now: campUnlock, passcodeUnlocked: false, inRegion: true))
        XCTAssertFalse(embargo.canShowArtLocations(now: campUnlock, passcodeUnlocked: false, inRegion: true))
    }

    func testCampWindowShowsCampsButNotArt() throws {
        let now = try date("2026-08-25T12:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: now, passcodeUnlocked: false, inRegion: true))
        XCTAssertFalse(embargo.canShowArtLocations(now: now, passcodeUnlocked: false, inRegion: true))
    }

    func testArtTierUnlocksExactlyAtEventStart() {
        XCTAssertFalse(embargo.canShowArtLocations(
            now: artUnlock.addingTimeInterval(-1), passcodeUnlocked: false, inRegion: true
        ))
        XCTAssertTrue(embargo.canShowArtLocations(now: artUnlock, passcodeUnlocked: false, inRegion: true))
    }

    func testEverythingUnlockedOnceGatesOpen() throws {
        let now = try date("2026-08-31T12:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: now, passcodeUnlocked: false, inRegion: true))
        XCTAssertTrue(embargo.canShowArtLocations(now: now, passcodeUnlocked: false, inRegion: true))
    }

    func testPasscodeUnlocksBothTiersEarly() throws {
        let now = try date("2026-08-10T12:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: now, passcodeUnlocked: true, inRegion: false))
        XCTAssertTrue(embargo.canShowArtLocations(now: now, passcodeUnlocked: true, inRegion: false))
    }

    /// Mutant vehicles (and anything else off both tiers) were never embargoed.
    func testUnrestrictedTierIsAlwaysVisible() throws {
        let now = try date("2020-01-01T00:00:00Z")
        XCTAssertTrue(embargo.canShowLocations(
            tier: .unrestricted, now: now, passcodeUnlocked: false, inRegion: false
        ))
        XCTAssertNil(embargo.unlockDate(for: .unrestricted))
    }

    // MARK: - What each half unlocks on its own

    /// The regression test the strict rule exists for: a clock rolled forward
    /// past gates open, on a device that has never been to Black Rock City,
    /// still shows no *art* placement.
    func testDateAloneNeverUnlocksArtWithoutTheRegion() throws {
        for now in [campUnlock, artUnlock, try date("2026-09-02T12:00:00Z"), try date("2030-01-01T00:00:00Z")] {
            XCTAssertFalse(
                embargo.canShowArtLocations(now: now, passcodeUnlocked: false, inRegion: false),
                "art must stay locked off-playa at \(now)"
            )
        }
    }

    /// …and the camp tier, relaxed 2026-08-22, unlocks off-playa on the date
    /// alone — but not one second early.
    func testDateAloneUnlocksCampsOffPlayaFromTheCampDate() throws {
        for now in [campUnlock, artUnlock, try date("2026-09-02T12:00:00Z"), try date("2030-01-01T00:00:00Z")] {
            XCTAssertTrue(
                embargo.canShowCampLocations(now: now, passcodeUnlocked: false, inRegion: false),
                "camps must be visible off-playa at \(now)"
            )
        }
        XCTAssertFalse(embargo.canShowCampLocations(
            now: campUnlock.addingTimeInterval(-1), passcodeUnlocked: false, inRegion: false
        ))
        XCTAssertFalse(embargo.canShowCampLocations(
            now: try date("2026-08-10T12:00:00Z"), passcodeUnlocked: false, inRegion: false
        ))
    }

    /// The region alone unlocks nothing: showing up in the desert in July
    /// unlocks neither tier.
    func testRegionAloneNeverUnlocksBeforeTheDates() throws {
        let now = try date("2026-07-04T12:00:00Z")
        XCTAssertFalse(embargo.canShowCampLocations(now: now, passcodeUnlocked: false, inRegion: true))
        XCTAssertFalse(embargo.canShowArtLocations(now: now, passcodeUnlocked: false, inRegion: true))
    }

    /// The tier-shaped half of the rule, stated directly.
    func testOnlyTheArtTierRequiresTheRegion() {
        XCTAssertTrue(embargo.requiresRegion(for: .art))
        XCTAssertFalse(embargo.requiresRegion(for: .camp))
        XCTAssertFalse(embargo.requiresRegion(for: .unrestricted))
    }

    /// Both halves, per tier: on playa, camps open a week before art does.
    func testRegionPlusDateUnlocksTierByTier() throws {
        XCTAssertTrue(embargo.canShowCampLocations(now: campUnlock, passcodeUnlocked: false, inRegion: true))
        XCTAssertFalse(embargo.canShowArtLocations(now: campUnlock, passcodeUnlocked: false, inRegion: true))
        XCTAssertTrue(embargo.canShowArtLocations(now: artUnlock, passcodeUnlocked: false, inRegion: true))
    }

    /// The passcode is the only bypass, and it needs neither half.
    func testPasscodeUnlocksWithoutRegionOrDate() throws {
        let longBefore = try date("2020-01-01T00:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: longBefore, passcodeUnlocked: true, inRegion: false))
        XCTAssertTrue(embargo.canShowArtLocations(now: longBefore, passcodeUnlocked: true, inRegion: false))
    }

    // MARK: - Missing CampLocationUnlock

    /// A year whose settings predate the tier split gets the old, stricter
    /// behaviour: camps stay locked until the gates, not from some earlier date.
    func testMissingCampUnlockFallsBackToTheArtTier() throws {
        let fallback = makeEmbargo(campUnlock: nil)
        XCTAssertEqual(fallback.schedule.campLocationUnlock, artUnlock)

        let insideCampWindow = try date("2026-08-25T12:00:00Z")
        XCTAssertFalse(fallback.canShowCampLocations(now: insideCampWindow, passcodeUnlocked: false, inRegion: true))
        XCTAssertTrue(fallback.canShowCampLocations(now: artUnlock, passcodeUnlocked: false, inRegion: true))
    }

    /// Defence against a mis-edited plist: camps can never stay locked past the
    /// moment everything else opens.
    func testCampUnlockLaterThanGatesStillOpensAtTheGates() throws {
        let broken = makeEmbargo(campUnlock: try date("2026-09-05T07:00:00Z"))
        XCTAssertTrue(broken.canShowCampLocations(now: artUnlock, passcodeUnlocked: false, inRegion: true))
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
        XCTAssertTrue(embargo.canShowLocation(
            for: camp(), now: insideCampWindow, passcodeUnlocked: false, inRegion: true
        ))
        XCTAssertFalse(embargo.canShowLocation(
            for: art(), now: insideCampWindow, passcodeUnlocked: false, inRegion: true
        ))
        XCTAssertTrue(embargo.canShowLocation(for: event(hostedByCamp: "camp-1"),
                                              now: insideCampWindow,
                                              passcodeUnlocked: false,
                                              inRegion: true))
        XCTAssertFalse(embargo.canShowLocation(for: event(locatedAtArt: "art-1"),
                                               now: insideCampWindow,
                                               passcodeUnlocked: false,
                                               inRegion: true))

        let afterGates = try date("2026-08-31T12:00:00Z")
        XCTAssertTrue(embargo.canShowLocation(
            for: art(), now: afterGates, passcodeUnlocked: false, inRegion: true
        ))
        XCTAssertTrue(embargo.canShowLocation(for: event(locatedAtArt: "art-1"),
                                              now: afterGates,
                                              passcodeUnlocked: false,
                                              inRegion: true))

        // Same objects, same instant, off playa: camps yes (date-only tier),
        // art no.
        XCTAssertTrue(embargo.canShowLocation(
            for: camp(), now: afterGates, passcodeUnlocked: false, inRegion: false
        ))
        XCTAssertFalse(embargo.canShowLocation(
            for: art(), now: afterGates, passcodeUnlocked: false, inRegion: false
        ))
    }

    // MARK: - Am I at Burning Man? (the GPS half)

    /// 2026 Man coordinate, as shipped in `iBurn/YearSettings.plist`.
    private var manCenter: EmbargoRegion {
        EmbargoRegion(centerLatitude: 40.783242, centerLongitude: -119.207871)
    }

    /// Center camp-ish, the coordinate the simulator is parked at for the watch
    /// runtime check.
    private func blackRockCity() -> CLLocation {
        CLLocation(latitude: 40.7864, longitude: -119.2065)
    }

    private func reno() -> CLLocation {
        CLLocation(latitude: 39.5296, longitude: -119.8138)
    }

    func testRegionContainsThePlayaAndNotReno() {
        XCTAssertTrue(manCenter.contains(blackRockCity()))
        XCTAssertFalse(manCenter.contains(reno()))
    }

    /// ~0.3° of latitude is ~33 km (inside the 5 * 8046.72 m radius), ~0.5° is
    /// ~55 km (outside it).
    func testRegionEdgeIsTheBRCLocationsRadius() {
        XCTAssertEqual(EmbargoRegion.defaultRadius, 5 * 8046.72, accuracy: 0.001)
        let justInside = CLLocation(latitude: 40.783242 + 0.30, longitude: -119.207871)
        let wellOutside = CLLocation(latitude: 40.783242 + 0.50, longitude: -119.207871)
        XCTAssertTrue(manCenter.contains(justInside))
        XCTAssertFalse(manCenter.contains(wellOutside))
    }

    /// A fix that never resolved reads as (0, 0), which is a real coordinate in
    /// the Atlantic — it must not be treated as "somewhere", let alone the playa.
    func testNullIslandAndInvalidCoordinatesAreOutsideTheRegion() {
        XCTAssertFalse(manCenter.contains(CLLocation(latitude: 0, longitude: 0)))
        XCTAssertFalse(manCenter.contains(CLLocation(latitude: 200, longitude: 500)))
    }

    func testIsInRegionAnswersFromAFix() {
        XCTAssertTrue(LocationEmbargo.isInRegion(location: blackRockCity(), region: manCenter))
        XCTAssertFalse(LocationEmbargo.isInRegion(location: reno(), region: manCenter))
    }

    /// No fix and no region are both "I don't know where you are", which is not
    /// the playa.
    func testIsInRegionFailsClosedWithoutAFixOrARegion() {
        XCTAssertFalse(LocationEmbargo.isInRegion(location: nil, region: manCenter))
        XCTAssertFalse(LocationEmbargo.isInRegion(location: blackRockCity(), region: nil))
        XCTAssertFalse(LocationEmbargo.isInRegion(location: nil, region: nil))
    }

    /// End-to-end shape of the watch's composition: on playa, mid-event, both
    /// tiers open; the same fix a month early opens nothing.
    func testRegionFixDrivesTheInRegionHalf() throws {
        let onPlaya = LocationEmbargo.isInRegion(location: blackRockCity(), region: manCenter)
        let duringEvent = try date("2026-09-02T12:00:00Z")
        XCTAssertTrue(embargo.canShowCampLocations(now: duringEvent, passcodeUnlocked: false, inRegion: onPlaya))
        XCTAssertTrue(embargo.canShowArtLocations(now: duringEvent, passcodeUnlocked: false, inRegion: onPlaya))

        let earlyAugust = try date("2026-08-01T12:00:00Z")
        XCTAssertFalse(embargo.canShowCampLocations(now: earlyAugust, passcodeUnlocked: false, inRegion: onPlaya))
        XCTAssertFalse(embargo.canShowArtLocations(now: earlyAugust, passcodeUnlocked: false, inRegion: onPlaya))

        let offPlaya = LocationEmbargo.isInRegion(location: reno(), region: manCenter)
        XCTAssertFalse(embargo.canShowArtLocations(now: duringEvent, passcodeUnlocked: false, inRegion: offPlaya))
        // Camps ride the date alone, so Reno sees camp addresses mid-event.
        XCTAssertTrue(embargo.canShowCampLocations(now: duringEvent, passcodeUnlocked: false, inRegion: offPlaya))
    }

    /// A year whose settings can't be read yields no `LocationEmbargo` at all,
    /// so the watch's `guard let embargo else { tier == .unrestricted }` hides
    /// every coordinate — even standing at the Man mid-event.
    func testMissingScheduleFailsClosedEvenInRegion() throws {
        let missing = URL(fileURLWithPath: "/nonexistent/YearSettings.plist")
        XCTAssertNil(EmbargoSchedule.load(contentsOf: missing))
        XCTAssertNil(EmbargoRegion.load(contentsOf: missing))

        let shown = EmbargoSchedule.load(contentsOf: missing)
            .map(LocationEmbargo.init(schedule:))?
            .canShowArtLocations(
                now: try date("2026-09-02T12:00:00Z"),
                passcodeUnlocked: false,
                inRegion: LocationEmbargo.isInRegion(location: blackRockCity(), region: manCenter)
            )
        XCTAssertNil(shown)
        XCTAssertFalse(shown ?? false)
    }

    // MARK: - Reading the schedule out of a bundle

    private func writeSettings(campUnlock: Date?, manCenter: Bool = false) throws -> URL {
        var settings: [String: Any] = ["EventStart": artUnlock, "PlayaYear": "2026"]
        if let campUnlock {
            settings["CampLocationUnlock"] = campUnlock
        }
        if manCenter {
            settings["ManCenterLatitude"] = 40.783242
            settings["ManCenterLongitude"] = -119.207871
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
    func testRegionLoadsTheManCenterFromAPlist() throws {
        let url = try writeSettings(campUnlock: campUnlock, manCenter: true)
        let region = try XCTUnwrap(EmbargoRegion.load(contentsOf: url))
        XCTAssertEqual(region.centerLatitude, 40.783242, accuracy: 0.000001)
        XCTAssertEqual(region.centerLongitude, -119.207871, accuracy: 0.000001)
        XCTAssertEqual(region.radius, EmbargoRegion.defaultRadius, accuracy: 0.001)
    }

    /// No centre means no region, which means no GPS auto-unlock — the same
    /// fail-closed shape the schedule uses.
    func testRegionIsNilWhenThePlistOmitsTheManCenter() throws {
        let url = try writeSettings(campUnlock: campUnlock)
        XCTAssertNil(EmbargoRegion.load(contentsOf: url))
        XCTAssertNil(EmbargoRegion.load(contentsOf: URL(fileURLWithPath: "/nonexistent/YearSettings.plist")))
    }

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

        // Same file carries the Man coordinate the watch's auto-unlock rides on.
        let region = try XCTUnwrap(EmbargoRegion.load(contentsOf: plist))
        XCTAssertTrue(region.contains(blackRockCity()))
        XCTAssertFalse(region.contains(reno()))
    }
}
