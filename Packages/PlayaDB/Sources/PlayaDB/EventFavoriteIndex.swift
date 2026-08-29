import Foundation
import GRDB

/// A snapshot of every event-type `object_metadata` row, arranged so the
/// per-occurrence favorite question can be answered without another query.
///
/// One `SELECT object_id, is_favorite FROM object_metadata WHERE object_type = 'events'`
/// backs every favorite read: the list filters, `fetchFavoriteEvents`,
/// `favoriteIdentifiers(among:)`, and ListRow inflation. Doing the resolution in Swift
/// rather than SQL keeps the three-step rule in ``EventFavoriteKey`` written down once,
/// and avoids asking SQLite to re-derive ISO-8601 strings from stored dates.
///
/// The table is small (a row per object the user has ever favorited, viewed, visited, or
/// annotated), and only the two narrow columns are read.
struct EventFavoriteIndex {
    /// Occurrence-keyed rows: composite object_id → its `is_favorite`.
    /// Presence matters as much as the value — an explicit `false` row overrides the
    /// parent (that is how you unfavorite one occurrence of a legacy series favorite).
    private let occurrenceRows: [String: Bool]

    /// Parent-event rows: event uid → its `is_favorite`. The legacy series favorite.
    private let parentRows: [String: Bool]

    init(occurrenceRows: [String: Bool], parentRows: [String: Bool]) {
        self.occurrenceRows = occurrenceRows
        self.parentRows = parentRows
    }

    /// Reads the whole event slice of `object_metadata` in one query.
    static func load(_ db: Database) throws -> EventFavoriteIndex {
        let rows = try Row.fetchAll(db, sql: """
            SELECT object_id, is_favorite FROM object_metadata WHERE object_type = ?
            """, arguments: [DataObjectType.event.rawValue])

        var occurrenceRows: [String: Bool] = [:]
        var parentRows: [String: Bool] = [:]
        for row in rows {
            guard let objectID: String = row["object_id"] else { continue }
            let isFavorite: Bool = row["is_favorite"] ?? false
            if EventFavoriteKey.isComposite(objectID) {
                occurrenceRows[objectID] = isFavorite
            } else {
                parentRows[objectID] = isFavorite
            }
        }
        return EventFavoriteIndex(occurrenceRows: occurrenceRows, parentRows: parentRows)
    }

    /// Whether the occurrence identified by `favoriteIdentity` is favorited.
    /// See ``EventFavoriteKey`` for the precedence rule this implements.
    func isFavorite(identity: String) -> Bool {
        if let own = occurrenceRows[identity] { return own }
        return parentRows[EventFavoriteKey.eventUID(from: identity)] ?? false
    }

    func isFavorite(_ occurrence: EventObjectOccurrence) -> Bool {
        isFavorite(identity: occurrence.favoriteIdentity)
    }

    /// Whether *any* occurrence of this event could be favorited — the coarse prefilter
    /// that keeps `WHERE event_id IN (…)` selective before the exact rule runs in Swift.
    ///
    /// Deliberately over-inclusive: an event whose parent row is favorited but all of
    /// whose occurrences carry explicit `false` rows is a candidate here and is dropped
    /// by `isFavorite`.
    var candidateEventUIDs: Set<String> {
        var uids: Set<String> = []
        for (objectID, isFavorite) in occurrenceRows where isFavorite {
            uids.insert(EventFavoriteKey.eventUID(from: objectID))
        }
        for (uid, isFavorite) in parentRows where isFavorite {
            uids.insert(uid)
        }
        return uids
    }

    /// Whether the event has at least one favorited occurrence, given all its
    /// occurrence identities. Used for "is this series favorited at all" questions
    /// (e.g. a bare `EventObject` heart).
    func isAnyFavorite(eventUID: String, occurrenceIdentities: [String]) -> Bool {
        if occurrenceIdentities.isEmpty {
            return parentRows[eventUID] ?? false
        }
        return occurrenceIdentities.contains { isFavorite(identity: $0) }
    }
}
