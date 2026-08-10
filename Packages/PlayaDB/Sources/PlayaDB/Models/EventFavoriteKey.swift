import Foundation

/// Identity scheme for **per-occurrence** event favorites.
///
/// ## Why favorites are keyed per occurrence
///
/// A recurring API event ("Yoga", every morning at 09:00) is one row in `event_objects`
/// plus N rows in `event_occurrences`. Favoriting used to be keyed by the parent event
/// uid alone, so tapping the heart on Tuesday's yoga also lit up Wednesday's, Thursday's,
/// and every other one. Users want the single session they picked. Favorites therefore
/// key on `(event uid, occurrence start instant)`.
///
/// ## Why the composite uses a date string
///
/// `event_occurrences.id` is an AUTOINCREMENT rowid that `importFromData` deletes and
/// reissues wholesale on every data refresh, so it is not stable — array positions are
/// worse. The natural key that *is* stable is the occurrence's start instant, which comes
/// straight from the API and is never rewritten during import. This reuses
/// ``EventCalendarEntry/occurrenceKey(for:)`` verbatim, so a favorite and its calendar
/// entry name the same occurrence with the same string.
///
/// ## What is and isn't per-occurrence
///
/// Only the **favorite bit** (`is_favorite` / `favorite_updated_at`) lives on the
/// occurrence-keyed row. Notes, visit status, and view history stay on the parent event's
/// row — "I visited this event" and "my note about this event" are statements about the
/// event, and splitting them would fragment Recently Viewed and the Visits list for no
/// user benefit. `PlayaDBImpl` merges the two when it inflates metadata for an occurrence.
///
/// ## Legacy compatibility
///
/// Databases written before this change carry favorites on the bare parent uid. Reads
/// resolve an occurrence's favorite state as:
///
/// 1. the occurrence-keyed row, when one exists (it always wins — that is how
///    unfavoriting a single occurrence of a legacy series favorite works); otherwise
/// 2. the parent event row's `is_favorite` (a legacy series favorite lights every
///    occurrence that has no opinion of its own); otherwise
/// 3. not favorited.
///
/// `PlayaDBImpl.foldLegacyEventFavorites` promotes rule 2 into explicit rule-1 rows at
/// open time, but the fallback stays in place permanently: it also covers occurrences
/// added by a later data refresh, and peers still running an older build.
public enum EventFavoriteKey {
    /// Separator between the event uid and the occurrence key.
    ///
    /// `#` is deliberately different from the `_` that `EventObjectOccurrence.uid` uses
    /// and from the `-` legacy Yap occurrence uids use, so a composite favorite id can
    /// never be confused with either (and so the pre-existing
    /// `migrateOccurrenceKeyedMetadata` fold, which matches on `_`, ignores these).
    public static let separator: Character = "#"

    /// Composite `object_metadata.object_id` for one occurrence.
    public static func objectID(eventUID: String, occurrenceKey: String) -> String {
        "\(eventUID)\(separator)\(occurrenceKey)"
    }

    /// Composite `object_metadata.object_id` for an occurrence starting at `startDate`.
    public static func objectID(eventUID: String, startDate: Date) -> String {
        objectID(eventUID: eventUID, occurrenceKey: EventCalendarEntry.occurrenceKey(for: startDate))
    }

    /// Splits a composite id back into its parts, or nil when `objectID` is a bare
    /// event uid.
    ///
    /// Splits on the *last* separator: occurrence keys never contain `#`, so this stays
    /// correct even for the (unseen) case of an API uid that does.
    public static func split(_ objectID: String) -> (eventUID: String, occurrenceKey: String)? {
        guard let index = objectID.lastIndex(of: separator) else { return nil }
        let eventUID = String(objectID[..<index])
        let occurrenceKey = String(objectID[objectID.index(after: index)...])
        guard !eventUID.isEmpty, !occurrenceKey.isEmpty else { return nil }
        return (eventUID, occurrenceKey)
    }

    /// Whether this id names a single occurrence rather than a whole event.
    public static func isComposite(_ objectID: String) -> Bool {
        split(objectID) != nil
    }

    /// The event uid an id belongs to, composite or not.
    public static func eventUID(from objectID: String) -> String {
        split(objectID)?.eventUID ?? objectID
    }
}

// MARK: - Occurrence Convenience

public extension EventObjectOccurrence {
    /// Stable key for this occurrence within its event (the ISO-8601 UTC start instant).
    ///
    /// Same string as ``EventCalendarEntry`` uses, on purpose.
    var occurrenceKey: String {
        EventCalendarEntry.occurrenceKey(for: startDate)
    }

    /// `object_metadata.object_id` under which this occurrence's favorite bit is stored.
    ///
    /// This is also the key `PlayaDB.favoriteIdentifiers(among:)` returns for event
    /// occurrences, so UI that keeps a set of "which rows are favorited" matches on it.
    var favoriteIdentity: String {
        EventFavoriteKey.objectID(eventUID: event.uid, occurrenceKey: occurrenceKey)
    }
}
