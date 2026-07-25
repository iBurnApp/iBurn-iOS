import Foundation
import GRDB

/// Links a single event *occurrence* to the EventKit event (`EKEvent`) created for it.
///
/// The app creates one calendar event per occurrence (matching legacy behaviour, where
/// YapDatabase split each API event into per-occurrence records). PlayaDB stores one row
/// per API event plus an `event_occurrences` child table, so calendar bookkeeping carries
/// its own occurrence key.
///
/// ## Why the occurrence key is a date string, not `event_occurrences.id`
///
/// `event_occurrences.id` is an `AUTOINCREMENT` rowid that `importFromData` deletes and
/// reissues wholesale on every data refresh, so it is not stable across imports. The
/// natural key that *is* stable is (event uid, occurrence start instant): start times come
/// straight from the API and are never rewritten during import (only end times are, see
/// `PlayaDBImpl.correctedOccurrenceTimes`). `occurrenceKey(for:)` renders that instant as a
/// fixed ISO-8601 UTC string so the key is independent of device locale, time zone, and of
/// however GRDB happens to serialize `Date` in the occurrences table.
///
/// The `event_calendar_entries` table is deliberately never cleared by `importFromData`,
/// so entries survive data refreshes exactly like favorites and user map pins.
public struct EventCalendarEntry: Codable, Equatable, Hashable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "event_calendar_entries"

    public enum Columns: String, CodingKey, ColumnExpression {
        case eventId = "event_id"
        case occurrenceKey = "occurrence_key"
        case ekEventIdentifier = "ek_event_identifier"
    }

    private enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case occurrenceKey = "occurrence_key"
        case ekEventIdentifier = "ek_event_identifier"
    }

    /// `EventObject.uid` of the parent event.
    public var eventId: String

    /// Stable identifier for the occurrence within its event (see `occurrenceKey(for:)`).
    public var occurrenceKey: String

    /// `EKEvent.eventIdentifier` of the calendar event created for this occurrence.
    public var ekEventIdentifier: String

    public init(eventId: String, occurrenceKey: String, ekEventIdentifier: String) {
        self.eventId = eventId
        self.occurrenceKey = occurrenceKey
        self.ekEventIdentifier = ekEventIdentifier
    }

    /// Convenience initializer that derives both key components from an occurrence.
    public init(occurrence: EventObjectOccurrence, ekEventIdentifier: String) {
        self.init(
            eventId: occurrence.event.uid,
            occurrenceKey: Self.occurrenceKey(for: occurrence.startDate),
            ekEventIdentifier: ekEventIdentifier
        )
    }

    // MARK: - Occurrence Key

    /// Formatter for occurrence keys: ISO-8601 internet date-time in UTC, second
    /// resolution (e.g. `2025-08-28T19:00:00Z`). Fixed so keys written by one build
    /// always match keys computed by another, regardless of device settings.
    private static let occurrenceKeyFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Stable key for an occurrence, derived from its start instant.
    ///
    /// Two occurrences of the same event that start at the same instant would collide,
    /// but the API never emits duplicates like that; a collision would simply overwrite
    /// the earlier entry rather than corrupt anything.
    public static func occurrenceKey(for startDate: Date) -> String {
        occurrenceKeyFormatter.string(from: startDate)
    }
}

// MARK: - Occurrence Convenience

public extension EventObjectOccurrence {
    /// Key used to store this occurrence's EventKit identifier (see ``EventCalendarEntry``).
    var calendarOccurrenceKey: String {
        EventCalendarEntry.occurrenceKey(for: startDate)
    }
}
