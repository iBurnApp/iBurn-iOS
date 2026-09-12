//
//  DataUpdateServiceTests.swift
//  iBurnTests
//
//  Created by Claude Code on 9/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
import PlayaAPI
import PlayaDB
@testable import iBurn

/// Test data shared by the cases below. Lives outside the @MainActor test class so
/// these statics stay nonisolated and usable from default arguments.
private enum Fixtures {

    /// Non-failable URL construction: no force unwraps in test code.
    static func makeURL(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/invalid/\(string)")
    }

    static let updateURL = makeURL("https://example.com/data/update.json")
    static let bundleStamp = "2026-08-20T10:00:00-07:00"
    static let serverStamp = "2026-08-27T10:00:00-07:00"

    static func artJSON(uid: String, name: String) -> Data {
        Data("""
        [{
            "uid": "\(uid)",
            "name": "\(name)",
            "year": 2026,
            "url": null,
            "contact_email": null,
            "hometown": "Reno, NV",
            "description": "Test installation.",
            "artist": "Test Artist",
            "category": "Open Playa",
            "program": "Honorarium",
            "donation_link": null,
            "location": {
                "hour": 3,
                "minute": 30,
                "distance": 2000,
                "category": "Open Playa",
                "gps_latitude": 40.786,
                "gps_longitude": -119.203
            },
            "location_string": "3:30 2000', Open Playa",
            "images": [],
            "guided_tours": false,
            "self_guided_tour_map": false
        }]
        """.utf8)
    }

    static func campJSON(uid: String, name: String) -> Data {
        Data("""
        [{
            "uid": "\(uid)",
            "name": "\(name)",
            "year": 2026,
            "url": null,
            "contact_email": null,
            "hometown": "Oakland, CA",
            "description": "Test camp.",
            "landmark": null,
            "location": {
                "frontage": "Esplanade",
                "intersection": "6:30",
                "intersection_type": "&",
                "dimensions": "75 x 110",
                "exact_location": "Mid-block facing 10:00"
            },
            "location_string": "Esplanade & 6:30",
            "images": []
        }]
        """.utf8)
    }

    static func eventJSON(uid: String, title: String) -> Data {
        Data("""
        [{
            "uid": "\(uid)",
            "title": "\(title)",
            "event_id": 12345,
            "description": "Test event.",
            "event_type": { "label": "Class/Workshop", "abbr": "work" },
            "year": 2026,
            "print_description": "",
            "slug": "\(uid)-slug",
            "hosted_by_camp": null,
            "located_at_art": null,
            "other_location": "",
            "check_location": false,
            "url": null,
            "all_day": false,
            "contact": null,
            "occurrence_set": [{ "start_time": "2026-08-27T09:00:00-07:00", "end_time": "2026-08-27T10:00:00-07:00" }]
        }]
        """.utf8)
    }

    static func updateJSON(
        art: String = bundleStamp,
        camps: String = bundleStamp,
        events: String = bundleStamp,
        eventsFile: String = "event.json"
    ) -> Data {
        Data("""
        {
            "art": {"file": "art.json", "updated": "\(art)"},
            "camps": {"file": "camp.json", "updated": "\(camps)"},
            "events": {"file": "\(eventsFile)", "updated": "\(events)"}
        }
        """.utf8)
    }

    static var bundledData: StubBundledData {
        StubBundledData(
            art: artJSON(uid: "art-bundled", name: "Bundled Art"),
            camp: campJSON(uid: "camp-bundled", name: "Bundled Camp"),
            event: eventJSON(uid: "event-bundled", title: "Bundled Event"),
            mv: nil,
            updateInfo: updateJSON()
        )
    }
}

/// Exercises `DataUpdateServiceImpl` — the PlayaDB-native replacement for
/// `BRCDataImporter`'s over-the-air update path. Everything the service touches
/// (network, on-disk cache, bundled data, preferences) is injected, so these run
/// against an in-memory PlayaDB with no network and no UserDefaults writes.
@MainActor
final class DataUpdateServiceTests: XCTestCase {

    // MARK: - Harness

    private var playaDB: PlayaDB!
    private var fetcher: FakeDataFetcher!
    private var cache: InMemoryOTACache!
    private var preferences: FakePreferences!
    private var clock: Date!

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try createInMemoryPlayaDB()
        fetcher = FakeDataFetcher()
        cache = InMemoryOTACache()
        preferences = FakePreferences()
        clock = Date(timeIntervalSince1970: 1_787_000_000)
    }

    override func tearDown() async throws {
        playaDB = nil
        fetcher = nil
        cache = nil
        preferences = nil
        try await super.tearDown()
    }

    private func makeService(updatesURL: URL? = Fixtures.updateURL) -> DataUpdateServiceImpl {
        // Captured by value: the clock is fixed for the lifetime of a test, and a
        // value capture keeps the closure free of actor-isolated state.
        let fixedNow = clock ?? Date()
        return DataUpdateServiceImpl(
            playaDB: playaDB,
            updatesURL: updatesURL,
            fetcher: fetcher,
            cache: cache,
            bundledData: Fixtures.bundledData,
            preferences: preferences,
            throttleInterval: 24 * 60 * 60,
            now: { fixedNow },
            notificationCenter: NotificationCenter(),
            onDidImport: nil
        )
    }

    /// Seeds PlayaDB from the "bundled" dataset, the way the seeder does at first launch.
    private func importBundledBaseline() async throws {
        let bundled = Fixtures.bundledData
        let art = try XCTUnwrap(bundled.art)
        let camp = try XCTUnwrap(bundled.camp)
        let event = try XCTUnwrap(bundled.event)
        try await playaDB.importFromData(
            artData: art,
            campData: camp,
            eventData: event,
            mvData: nil,
            updateData: bundled.updateInfo
        )
    }

    // MARK: - Throttle & preferences

    func testNonForcedCheckIsSkippedWhenDownloadsAreDisabled() async throws {
        preferences.areDownloadsDisabled = true
        let outcome = try await makeService().checkForUpdates(force: false)
        XCTAssertEqual(outcome, .skippedDisabled)
        XCTAssertTrue(fetcher.requestedURLs.isEmpty)
    }

    func testNonForcedCheckIsThrottledWithinTheInterval() async throws {
        preferences.lastUpdateCheck = clock.addingTimeInterval(-60 * 60)
        let outcome = try await makeService().checkForUpdates(force: false)
        XCTAssertEqual(outcome, .skippedThrottled)
        XCTAssertTrue(fetcher.requestedURLs.isEmpty)
    }

    func testForcedCheckBypassesThrottleAndDisabledPreference() async throws {
        try await importBundledBaseline()
        preferences.areDownloadsDisabled = true
        preferences.lastUpdateCheck = clock.addingTimeInterval(-60)
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON())

        let outcome = try await makeService().checkForUpdates(force: true)
        XCTAssertEqual(outcome, .upToDate)
        XCTAssertEqual(fetcher.requestedURLs, [Fixtures.updateURL])
        XCTAssertEqual(preferences.lastUpdateCheck, clock)
    }

    func testMissingUpdateURLThrows() async throws {
        do {
            _ = try await makeService(updatesURL: nil).checkForUpdates(force: true)
            XCTFail("Expected missingUpdateURL")
        } catch let error as DataUpdateError {
            guard case .missingUpdateURL = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Newer-than comparison

    func testServerDataNoNewerThanTheDatabaseDownloadsNothing() async throws {
        try await importBundledBaseline()
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON())

        let outcome = try await makeService().checkForUpdates(force: false)
        XCTAssertEqual(outcome, .upToDate)
        XCTAssertEqual(fetcher.requestedURLs, [Fixtures.updateURL], "No per-type file should be fetched")
        XCTAssertTrue(cache.entries.isEmpty)
    }

    /// The heart of the merge story: only the changed type is downloaded, but the
    /// full-replace import still has to keep the other types alive (from the bundle).
    func testOnlyChangedTypesAreDownloadedAndUnchangedTypesSurviveTheImport() async throws {
        try await importBundledBaseline()
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON(events: Fixtures.serverStamp))
        let eventURL = Fixtures.makeURL("https://example.com/data/event.json")
        fetcher.responses[eventURL] = .success(Fixtures.eventJSON(uid: "event-ota", title: "OTA Event"))

        let outcome = try await makeService().checkForUpdates(force: false)
        XCTAssertEqual(outcome, .updated([.event]))
        XCTAssertEqual(fetcher.requestedURLs, [Fixtures.updateURL, eventURL])

        // Server data replaced the events...
        let events = try await playaDB.fetchEvents()
        XCTAssertEqual(events.map { $0.event.uid }, ["event-ota"])
        // ...while art and camps came from the bundle rather than being wiped.
        let art = try await playaDB.fetchArt()
        XCTAssertEqual(art.map { $0.uid }, ["art-bundled"])
        let camps = try await playaDB.fetchCamps()
        XCTAssertEqual(camps.map { $0.uid }, ["camp-bundled"])

        // The synthesized update.json carried the per-type stamps through, so a
        // second check sees nothing new.
        let repeatOutcome = try await makeService().checkForUpdates(force: true)
        XCTAssertEqual(repeatOutcome, .upToDate)
    }

    // MARK: - URL resolution

    func testRelativeFileNamesResolveAgainstTheUpdateJSONFolder() {
        let folder = Fixtures.updateURL.deletingLastPathComponent()
        let resolved = DataUpdateServiceImpl.resolveFileURL("event.json", relativeTo: folder)
        XCTAssertEqual(resolved.absoluteString, "https://example.com/data/event.json")
    }

    func testAbsoluteFileURLsInUpdateJSONAreUsedVerbatim() async throws {
        try await importBundledBaseline()
        let absolute = "https://cdn.example.org/2026/event-v2.json"
        fetcher.responses[Fixtures.updateURL] = .success(
            Fixtures.updateJSON(events: Fixtures.serverStamp, eventsFile: absolute)
        )
        let absoluteURL = Fixtures.makeURL(absolute)
        fetcher.responses[absoluteURL] = .success(Fixtures.eventJSON(uid: "event-cdn", title: "CDN Event"))

        let outcome = try await makeService().checkForUpdates(force: false)
        XCTAssertEqual(outcome, .updated([.event]))
        XCTAssertEqual(fetcher.requestedURLs.last, absoluteURL)

        XCTAssertEqual(
            DataUpdateServiceImpl.resolveFileURL(absolute, relativeTo: Fixtures.updateURL.deletingLastPathComponent()),
            absoluteURL
        )
    }

    // MARK: - Persistence & resume

    func testDownloadedDataIsPersistedForResume() async throws {
        try await importBundledBaseline()
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON(events: Fixtures.serverStamp))
        let eventURL = Fixtures.makeURL("https://example.com/data/event.json")
        fetcher.responses[eventURL] = .success(Fixtures.eventJSON(uid: "event-ota", title: "OTA Event"))

        _ = try await makeService().checkForUpdates(force: false)

        let entry = try XCTUnwrap(cache.entry(for: .event))
        XCTAssertEqual(entry.file, "event.json")
        XCTAssertNotNil(cache.data(for: .event))
    }

    /// An update that downloaded but never made it into the database (crash, failed
    /// import) is finished from the cache instead of being downloaded again — even
    /// when the server is now unreachable.
    func testInterruptedUpdateResumesFromCacheWithoutRefetching() async throws {
        try await importBundledBaseline()
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON(events: Fixtures.serverStamp))
        let eventURL = Fixtures.makeURL("https://example.com/data/event.json")
        fetcher.responses[eventURL] = .success(Fixtures.eventJSON(uid: "event-ota", title: "OTA Event"))

        // First pass: download lands in the cache, but the database is thrown away
        // before the import could be observed (simulates an interrupted launch).
        _ = try await makeService().checkForUpdates(force: false)
        playaDB = try createInMemoryPlayaDB()
        try await importBundledBaseline()

        fetcher.reset()
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON(events: Fixtures.serverStamp))
        fetcher.responses[eventURL] = .failure(URLError(.notConnectedToInternet))

        let outcome = try await makeService().checkForUpdates(force: true)
        XCTAssertEqual(outcome, .updated([.event]))
        XCTAssertEqual(fetcher.requestedURLs, [Fixtures.updateURL], "Cached download should not be refetched")

        let events = try await playaDB.fetchEvents()
        XCTAssertEqual(events.map { $0.event.uid }, ["event-ota"])
    }

    func testFailedDownloadOfEveryChangedTypeThrows() async throws {
        try await importBundledBaseline()
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON(events: Fixtures.serverStamp))
        fetcher.responses[Fixtures.makeURL("https://example.com/data/event.json")] =
            .failure(URLError(.timedOut))

        do {
            _ = try await makeService().checkForUpdates(force: false)
            XCTFail("Expected downloadFailed")
        } catch let error as DataUpdateError {
            guard case .downloadFailed = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        // The database keeps the data it had.
        let events = try await playaDB.fetchEvents()
        XCTAssertEqual(events.map { $0.event.uid }, ["event-bundled"])
    }

    // MARK: - Reset

    func testResetClearsTheCacheAndReimportsBundledData() async throws {
        try await importBundledBaseline()
        fetcher.responses[Fixtures.updateURL] = .success(Fixtures.updateJSON(events: Fixtures.serverStamp))
        fetcher.responses[Fixtures.makeURL("https://example.com/data/event.json")] =
            .success(Fixtures.eventJSON(uid: "event-ota", title: "OTA Event"))
        _ = try await makeService().checkForUpdates(force: false)

        try await makeService().resetToBundledData()

        XCTAssertEqual(cache.clearCount, 1)
        XCTAssertTrue(cache.entries.isEmpty)
        XCTAssertNil(preferences.lastUpdateCheck, "Reset should also clear the throttle")
        let events = try await playaDB.fetchEvents()
        XCTAssertEqual(events.map { $0.event.uid }, ["event-bundled"])
    }

    // MARK: - On-disk cache

    func testFileCacheRoundTripsThroughDiskAndDropsOrphanedManifestEntries() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OTACacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let entry = OTACacheEntry(file: "event.json", updated: Date(timeIntervalSince1970: 1_780_000_000))
        let payload = Data("[]".utf8)
        let writer = OTADataFileCache(directory: directory)
        try writer.store(payload, for: .event, entry: entry)

        // A fresh instance reads the manifest back off disk.
        let reader = OTADataFileCache(directory: directory)
        XCTAssertEqual(reader.entry(for: .event), entry)
        XCTAssertEqual(reader.data(for: .event), payload)

        // A manifest entry whose payload vanished must not be trusted, or the
        // service would skip a download it still needs.
        try FileManager.default.removeItem(at: directory.appendingPathComponent("event.json"))
        let afterLoss = OTADataFileCache(directory: directory)
        XCTAssertNil(afterLoss.entry(for: .event))

        try writer.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }
}

// MARK: - Test doubles

private final class FakeDataFetcher: DataFetching {
    var responses: [URL: Result<Data, Error>] = [:]
    private(set) var requestedURLs: [URL] = []

    func reset() {
        responses = [:]
        requestedURLs = []
    }

    func fetchData(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        switch responses[url] {
        case .success(let data): return data
        case .failure(let error): throw error
        case nil: throw URLError(.fileDoesNotExist)
        }
    }
}

private final class InMemoryOTACache: OTADataCaching {
    private(set) var entries: [String: OTACacheEntry] = [:]
    private var payloads: [String: Data] = [:]
    private(set) var clearCount = 0

    func data(for type: DataObjectType) -> Data? {
        payloads[type.rawValue]
    }

    func store(_ data: Data, for type: DataObjectType, entry: OTACacheEntry) throws {
        payloads[type.rawValue] = data
        entries[type.rawValue] = entry
    }

    func clear() throws {
        entries = [:]
        payloads = [:]
        clearCount += 1
    }
}

private struct StubBundledData: BundledDataProviding {
    let art: Data?
    let camp: Data?
    let event: Data?
    let mv: Data?
    let updateInfo: Data?

    func data(for type: DataObjectType) -> Data? {
        switch type {
        case .art: return art
        case .camp: return camp
        case .event: return event
        case .mutantVehicle: return mv
        }
    }

    func updateInfoData() -> Data? { updateInfo }
}

private final class FakePreferences: DataUpdatePreferencing {
    var areDownloadsDisabled = false
    var lastUpdateCheck: Date?
}
