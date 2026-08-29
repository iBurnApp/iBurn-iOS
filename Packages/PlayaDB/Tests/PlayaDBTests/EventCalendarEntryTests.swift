import XCTest
import Foundation
import GRDB
@testable import PlayaDB
import PlayaAPITestHelpers

/// Covers migration `v5-calendar-entries`: per-occurrence EventKit identifier
/// storage, its CRUD surface, and the guarantee that entries survive a re-import.
final class EventCalendarEntryTests: XCTestCase {
    private var playaDB: PlayaDBImpl!

    private var dbQueue: any DatabaseWriter { playaDB.dbQueue }

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
        try await importMockData()
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    private func importMockData() async throws {
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    // MARK: - Occurrence Key

    func testOccurrenceKeyIsStableISO8601UTC() throws {
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2025-08-28T12:00:00-07:00")
        )

        XCTAssertEqual(EventCalendarEntry.occurrenceKey(for: date), "2025-08-28T19:00:00Z")
    }

    func testOccurrenceKeyMatchesImportedOccurrence() async throws {
        let occurrences = try await playaDB.fetchEvents()
        let occurrence = try XCTUnwrap(occurrences.first)

        let entry = EventCalendarEntry(occurrence: occurrence, ekEventIdentifier: "ek-1")

        XCTAssertEqual(entry.eventId, occurrence.event.uid)
        XCTAssertEqual(entry.occurrenceKey, occurrence.calendarOccurrenceKey)
        XCTAssertEqual(
            entry.occurrenceKey,
            EventCalendarEntry.occurrenceKey(for: occurrence.startDate)
        )
    }

    /// The whole point of a date-derived key: `event_occurrences.id` is reissued by
    /// every import, so a rowid-based key would be orphaned after a data refresh.
    func testOccurrenceKeySurvivesReimportWhileRowIDsChange() async throws {
        let before = try await playaDB.fetchEvents()
        let occurrenceBefore = try XCTUnwrap(before.first)
        let keyBefore = occurrenceBefore.calendarOccurrenceKey

        // Bump the autoincrement counter so re-inserted occurrences get new rowids.
        try await dbQueue.write { db in
            var throwaway = EventOccurrence(
                eventId: occurrenceBefore.event.uid,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600)
            )
            try throwaway.insert(db)
        }

        try await importMockData()

        let after = try await playaDB.fetchEvents()
        let occurrenceAfter = try XCTUnwrap(after.first { $0.event.uid == occurrenceBefore.event.uid })

        XCTAssertNotEqual(
            occurrenceAfter.occurrence.id,
            occurrenceBefore.occurrence.id,
            "Import should reissue occurrence rowids — that is why they cannot key calendar entries"
        )
        XCTAssertEqual(occurrenceAfter.calendarOccurrenceKey, keyBefore,
                       "The date-derived occurrence key must be stable across imports")
    }

    // MARK: - CRUD

    func testSaveAndFetchCalendarEntries() async throws {
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: "2025-08-28T19:00:00Z", ekEventIdentifier: "ek-a")
        )
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: "2025-08-29T19:00:00Z", ekEventIdentifier: "ek-b")
        )
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-2", occurrenceKey: "2025-08-28T19:00:00Z", ekEventIdentifier: "ek-c")
        )

        let entries = try await playaDB.fetchCalendarEntries(eventId: "event-1")

        XCTAssertEqual(entries.map(\.ekEventIdentifier), ["ek-a", "ek-b"])
        XCTAssertTrue(entries.allSatisfy { $0.eventId == "event-1" })
    }

    func testFetchCalendarEntriesForUnknownEventIsEmpty() async throws {
        let entries = try await playaDB.fetchCalendarEntries(eventId: "nope")
        XCTAssertTrue(entries.isEmpty)
    }

    func testSaveUpsertsOnCompositeKey() async throws {
        let key = "2025-08-28T19:00:00Z"
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: key, ekEventIdentifier: "ek-old")
        )
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: key, ekEventIdentifier: "ek-new")
        )

        let entries = try await playaDB.fetchCalendarEntries(eventId: "event-1")

        XCTAssertEqual(entries.count, 1, "Re-saving the same occurrence must replace, not duplicate")
        XCTAssertEqual(entries.first?.ekEventIdentifier, "ek-new")
    }

    func testDeleteCalendarEntriesRemovesOnlyThatEvent() async throws {
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: "2025-08-28T19:00:00Z", ekEventIdentifier: "ek-a")
        )
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: "2025-08-29T19:00:00Z", ekEventIdentifier: "ek-b")
        )
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-2", occurrenceKey: "2025-08-28T19:00:00Z", ekEventIdentifier: "ek-c")
        )

        try await playaDB.deleteCalendarEntries(eventId: "event-1")

        let remainingForEvent1 = try await playaDB.fetchCalendarEntries(eventId: "event-1")
        let remainingOverall = try await playaDB.fetchAllCalendarEntries()

        XCTAssertTrue(remainingForEvent1.isEmpty)
        XCTAssertEqual(remainingOverall.map(\.ekEventIdentifier), ["ek-c"])
    }

    func testDeleteCalendarEntriesForUnknownEventIsNoOp() async throws {
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: "2025-08-28T19:00:00Z", ekEventIdentifier: "ek-a")
        )

        try await playaDB.deleteCalendarEntries(eventId: "event-missing")

        let entries = try await playaDB.fetchAllCalendarEntries()
        XCTAssertEqual(entries.count, 1)
    }

    func testFetchAllCalendarEntriesIsOrderedDeterministically() async throws {
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-2", occurrenceKey: "2025-08-28T19:00:00Z", ekEventIdentifier: "ek-c")
        )
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: "2025-08-29T19:00:00Z", ekEventIdentifier: "ek-b")
        )
        try await playaDB.saveCalendarEntry(
            EventCalendarEntry(eventId: "event-1", occurrenceKey: "2025-08-28T19:00:00Z", ekEventIdentifier: "ek-a")
        )

        let entries = try await playaDB.fetchAllCalendarEntries()

        XCTAssertEqual(entries.map(\.ekEventIdentifier), ["ek-a", "ek-b", "ek-c"])
    }

    // MARK: - Import Survival

    func testCalendarEntriesSurviveReimport() async throws {
        let occurrences = try await playaDB.fetchEvents()
        let occurrence = try XCTUnwrap(occurrences.first)
        let entry = EventCalendarEntry(occurrence: occurrence, ekEventIdentifier: "ek-persisted")
        try await playaDB.saveCalendarEntry(entry)

        // A full data refresh deletes and reinserts every object table.
        try await importMockData()

        let entries = try await playaDB.fetchCalendarEntries(eventId: occurrence.event.uid)

        XCTAssertEqual(entries, [entry], "importFromData must not clear event_calendar_entries")

        // And the surviving key still resolves to a live occurrence.
        let refreshed = try await playaDB.fetchOccurrences(forEventUID: occurrence.event.uid)
        XCTAssertTrue(
            refreshed.contains { $0.calendarOccurrenceKey == entry.occurrenceKey },
            "The stored occurrence key must still match an occurrence after re-import"
        )
    }
}
