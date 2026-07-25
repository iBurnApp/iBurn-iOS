//
//  FavoriteSyncService.swift
//  iBurn
//
//  Created by Claude Code on 7/11/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

/// The kind of object whose favorite state is being mirrored into the legacy database.
enum FavoriteSyncObjectType {
    case art
    case camp
    case event
    case mutantVehicle
}

/// Mirrors PlayaDB (GRDB) favorite changes into legacy YapDatabase metadata so both
/// databases stay in agreement while legacy surfaces (e.g. `VisitListViewController`,
/// `AudioTourViewController`, and the legacy list fallback) still render from Yap.
///
/// PlayaDB is the source of truth; this mirror is best-effort and must never block the UI.
protocol FavoriteSyncService {
    /// Mirror a favorite state change into YapDatabase.
    ///
    /// - Parameters:
    ///   - type: The kind of object. `.mutantVehicle` is a no-op (there is no legacy Yap class).
    ///   - uid: The PlayaDB uid (i.e. the raw API uid). For events, pass the *unsuffixed*
    ///     API uid; every Yap per-occurrence object (`"<apiUID>-<index>"`, see
    ///     `BRCRecurringEventObject.eventObjects()`) is updated, and the calendar entry
    ///     for each occurrence is refreshed to match (EKEvent created/removed).
    ///   - isFavorite: The new favorite state from PlayaDB.
    func mirrorFavorite(type: FavoriteSyncObjectType, uid: String, isFavorite: Bool) async

    /// Mirror a visit status change into YapDatabase.
    ///
    /// - Parameters:
    ///   - type: The kind of object. `.mutantVehicle` is a no-op (there is no legacy Yap class).
    ///   - uid: The PlayaDB uid (i.e. the raw API uid). For events, pass the *unsuffixed*
    ///     API uid; every Yap per-occurrence object (`"<apiUID>-<index>"`) is updated.
    ///   - visitStatus: The new raw visit status from PlayaDB (`BRCVisitStatus` rawValue,
    ///     0 = unvisited, 1 = visited, 2 = wantToVisit).
    ///
    /// Unlike `mirrorFavorite` there is no calendar involvement. Writes are skipped when
    /// the stored value already matches, so repeated mirroring causes no Yap churn.
    func mirrorVisitStatus(type: FavoriteSyncObjectType, uid: String, visitStatus: Int) async

    /// Mirror user notes into YapDatabase.
    ///
    /// - Parameters:
    ///   - type: The kind of object. `.mutantVehicle` is a no-op (there is no legacy Yap class).
    ///   - uid: The PlayaDB uid (i.e. the raw API uid). For events, pass the *unsuffixed*
    ///     API uid; every Yap per-occurrence object (`"<apiUID>-<index>"`) is updated. Writing
    ///     the bare uid directly would match no Yap key at all, which is why notes must come
    ///     through here rather than through a direct collection write.
    ///   - notes: The new note text from PlayaDB (empty string clears it, matching the
    ///     legacy detail screen's behavior).
    ///
    /// Like `mirrorVisitStatus` there is no calendar involvement, and writes are skipped when
    /// the stored value already matches.
    func mirrorNotes(type: FavoriteSyncObjectType, uid: String, notes: String) async
}

/// Hook invoked with each Yap event object's uniqueID after its favorite metadata has been
/// written and committed. The production hook (see `FavoriteSyncServiceFactory.shared`)
/// routes through `EventCalendarHookRouter`: with
/// `Preferences.FeatureFlags.usePlayaDBCalendarSync` on (the default) the uid is normalized
/// to its API uid and handed to `EventCalendarService`, which owns the EKEvents and stores
/// their identifiers in PlayaDB; with the flag off it resolves the event in its own
/// transaction and calls legacy `BRCEventObject.refreshCalendarEntry(_:)` (identifiers in
/// `BRCEventMetadata.calendarEventIdentifier`). Injectable so tests can avoid EventKit.
///
/// Deliberately a top-level typealias whose signature contains no YapDatabase or
/// bridging-header types: members whose serialized signatures reference those (e.g.
/// `YapDatabaseReadWriteTransaction`) fail to resolve when the test target imports this
/// module, silently dropping the member ("has no member" / "no accessible initializers").
typealias FavoriteSyncCalendarRefreshHook = (_ yapUID: String, _ isFavorite: Bool) -> Void

/// Hook invoked after a visit-status mirror has committed *and* actually changed something.
/// The production hook (see `FavoriteSyncServiceFactory.shared`) calls
/// `BRCDatabaseManager.refreshVisitStatusGroupedView`, whose versionTag bump is the only way
/// the legacy Visit List's grouped view re-sorts an object into its new group. Injectable so
/// tests can run against a temp database without touching the shared `BRCDatabaseManager`.
///
/// Same no-YapDatabase-types-in-the-signature rule as `FavoriteSyncCalendarRefreshHook`.
typealias FavoriteSyncVisitStatusDidChangeHook = () -> Void

// MARK: - Implementation

final class FavoriteSyncServiceImpl: FavoriteSyncService {

    private let connection: YapDatabaseConnection
    private let calendarRefreshHook: FavoriteSyncCalendarRefreshHook
    private let visitStatusDidChangeHook: FavoriteSyncVisitStatusDidChangeHook

    init(connection: YapDatabaseConnection,
         calendarRefreshHook: @escaping FavoriteSyncCalendarRefreshHook,
         visitStatusDidChangeHook: @escaping FavoriteSyncVisitStatusDidChangeHook = {}) {
        self.connection = connection
        self.calendarRefreshHook = calendarRefreshHook
        self.visitStatusDidChangeHook = visitStatusDidChangeHook
    }

    // MARK: FavoriteSyncService

    func mirrorFavorite(type: FavoriteSyncObjectType, uid: String, isFavorite: Bool) async {
        switch type {
        case .art:
            await mirror(uid: uid, collection: BRCArtObject.yapCollection, isFavorite: isFavorite)
        case .camp:
            await mirror(uid: uid, collection: BRCCampObject.yapCollection, isFavorite: isFavorite)
        case .event:
            await mirrorEvent(apiUID: uid, isFavorite: isFavorite)
        case .mutantVehicle:
            // Mutant vehicles have no legacy YapDatabase representation; nothing to mirror.
            return
        }
    }

    func mirrorVisitStatus(type: FavoriteSyncObjectType, uid: String, visitStatus: Int) async {
        let didChange: Bool
        switch type {
        case .art:
            didChange = await mirrorVisitStatus(uid: uid, collection: BRCArtObject.yapCollection, visitStatus: visitStatus)
        case .camp:
            didChange = await mirrorVisitStatus(uid: uid, collection: BRCCampObject.yapCollection, visitStatus: visitStatus)
        case .event:
            didChange = await mirrorEventVisitStatus(apiUID: uid, visitStatus: visitStatus)
        case .mutantVehicle:
            // Mutant vehicles have no legacy YapDatabase representation; nothing to mirror.
            return
        }
        // The legacy Visit List renders from a grouped view whose grouping block only re-runs
        // when its versionTag changes, so a metadata-only write leaves rows in their old
        // group. Fired post-commit (and only when something changed) to match
        // DetailDataService.updateVisitStatus.
        if didChange {
            visitStatusDidChangeHook()
        }
    }

    func mirrorNotes(type: FavoriteSyncObjectType, uid: String, notes: String) async {
        switch type {
        case .art:
            await mirrorNotes(uid: uid, collection: BRCArtObject.yapCollection, notes: notes)
        case .camp:
            await mirrorNotes(uid: uid, collection: BRCCampObject.yapCollection, notes: notes)
        case .event:
            await mirrorEventNotes(apiUID: uid, notes: notes)
        case .mutantVehicle:
            // Mutant vehicles have no legacy YapDatabase representation; nothing to mirror.
            return
        }
    }

    // MARK: Uid Mapping

    /// Converts a Yap `BRCEventObject.uniqueID` back to its API (PlayaDB) uid.
    ///
    /// `BRCRecurringEventObject.eventObjects()` splits one API event into per-occurrence
    /// Yap objects with uniqueIDs of the form `"<apiUID>-<index>"`. PlayaDB stores events
    /// under the bare API uid, so lookups with a suffixed uid silently fail. This strips a
    /// single trailing `-<digits>` suffix; uids without one are returned unchanged.
    static func apiEventUID(fromYapUID uid: String) -> String {
        guard let dashIndex = uid.lastIndex(of: "-") else { return uid }
        let suffix = uid[uid.index(after: dashIndex)...]
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && $0.isNumber }) else { return uid }
        return String(uid[..<dashIndex])
    }

    /// Selects the Yap keys belonging to one API event: exact equality with the API uid
    /// (defensive) or the `"<apiUID>-<digits>"` per-occurrence pattern. Deliberately takes
    /// plain strings so no YapDatabase type appears in a member signature.
    static func occurrenceKeys(from allKeys: [String], apiUID: String) -> [String] {
        let occurrencePrefix = apiUID + "-"
        return allKeys.filter { key in
            if key == apiUID { return true }
            guard key.hasPrefix(occurrencePrefix) else { return false }
            let suffix = key.dropFirst(occurrencePrefix.count)
            return !suffix.isEmpty && suffix.allSatisfy { $0.isASCII && $0.isNumber }
        }
    }

    // MARK: Private

    private func mirror(uid: String, collection: String, isFavorite: Bool) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.asyncReadWrite({ transaction in
                guard let object = transaction.object(forKey: uid, inCollection: collection) as? BRCDataObject else {
                    return
                }
                let metadata = object.metadata(with: transaction).metadataCopy()
                metadata.isFavorite = isFavorite
                object.replace(metadata, transaction: transaction)
            }, completionBlock: {
                continuation.resume()
            })
        }
    }

    /// Fans an event favorite out to *all* Yap occurrence objects derived from the API uid.
    ///
    /// Yap stores one `BRCEventObject` per occurrence, keyed `"<apiUID>-<index>"`, so a
    /// single PlayaDB favorite maps to N Yap objects. Keys are matched by exact equality
    /// with the API uid (defensive) or by the `"<apiUID>-<digits>"` pattern.
    private func mirrorEvent(apiUID: String, isFavorite: Bool) async {
        let updatedKeys: [String] = await withCheckedContinuation { continuation in
            var mirroredKeys: [String] = []
            connection.asyncReadWrite({ transaction in
                let collection = BRCEventObject.yapCollection
                let matchingKeys = Self.occurrenceKeys(
                    from: transaction.allKeys(inCollection: collection),
                    apiUID: apiUID
                )
                for key in matchingKeys {
                    guard let event = transaction.object(forKey: key, inCollection: collection) as? BRCEventObject else {
                        continue
                    }
                    let metadata = event.metadata(with: transaction).metadataCopy()
                    metadata.isFavorite = isFavorite
                    event.replace(metadata, transaction: transaction)
                    mirroredKeys.append(key)
                }
            }, completionBlock: {
                continuation.resume(returning: mirroredKeys)
            })
        }
        // Match legacy detail behavior: favoriting creates an EKEvent (per occurrence),
        // unfavoriting removes it and clears the stored identifier. Invoked after the
        // metadata write has committed so the hook's own transaction sees the new state.
        for key in updatedKeys {
            calendarRefreshHook(key, isFavorite)
        }
    }

    /// Writes `visitStatus` into a single Yap object's metadata. Skips the write (and the
    /// resulting Yap change notification churn) when the stored value already matches.
    /// Returns whether anything was actually written.
    @discardableResult
    private func mirrorVisitStatus(uid: String, collection: String, visitStatus: Int) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var didWrite = false
            connection.asyncReadWrite({ transaction in
                guard let object = transaction.object(forKey: uid, inCollection: collection) as? BRCDataObject else {
                    return
                }
                let existing = object.metadata(with: transaction)
                guard existing.visitStatus != visitStatus else { return }
                let metadata = existing.metadataCopy()
                metadata.visitStatus = visitStatus
                object.replace(metadata, transaction: transaction)
                didWrite = true
            }, completionBlock: {
                continuation.resume(returning: didWrite)
            })
        }
    }

    /// Fans an event visit status out to *all* Yap occurrence objects derived from the API
    /// uid, using the same `"<apiUID>-<digits>"` key matching as `mirrorEvent`. No calendar
    /// hook is involved (visit status has no EKEvent side effects). Per-key writes are
    /// skipped when the stored value already matches. Returns whether anything was written.
    @discardableResult
    private func mirrorEventVisitStatus(apiUID: String, visitStatus: Int) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var didWrite = false
            connection.asyncReadWrite({ transaction in
                let collection = BRCEventObject.yapCollection
                let matchingKeys = Self.occurrenceKeys(
                    from: transaction.allKeys(inCollection: collection),
                    apiUID: apiUID
                )
                for key in matchingKeys {
                    guard let event = transaction.object(forKey: key, inCollection: collection) as? BRCEventObject else {
                        continue
                    }
                    let existing = event.metadata(with: transaction)
                    guard existing.visitStatus != visitStatus else { continue }
                    let metadata = existing.metadataCopy()
                    metadata.visitStatus = visitStatus
                    event.replace(metadata, transaction: transaction)
                    didWrite = true
                }
            }, completionBlock: {
                continuation.resume(returning: didWrite)
            })
        }
    }

    /// Writes `notes` into a single Yap object's metadata, skipping no-op writes.
    private func mirrorNotes(uid: String, collection: String, notes: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.asyncReadWrite({ transaction in
                guard let object = transaction.object(forKey: uid, inCollection: collection) as? BRCDataObject else {
                    return
                }
                let existing = object.metadata(with: transaction)
                guard existing.userNotes != notes else { return }
                let metadata = existing.metadataCopy()
                metadata.userNotes = notes
                object.replace(metadata, transaction: transaction)
            }, completionBlock: {
                continuation.resume()
            })
        }
    }

    /// Fans event notes out to *all* Yap occurrence objects derived from the API uid, using
    /// the same `"<apiUID>-<digits>"` key matching as `mirrorEvent`. PlayaDB keeps one note
    /// per event, so every occurrence gets the same text. No calendar hook is involved.
    private func mirrorEventNotes(apiUID: String, notes: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.asyncReadWrite({ transaction in
                let collection = BRCEventObject.yapCollection
                let matchingKeys = Self.occurrenceKeys(
                    from: transaction.allKeys(inCollection: collection),
                    apiUID: apiUID
                )
                for key in matchingKeys {
                    guard let event = transaction.object(forKey: key, inCollection: collection) as? BRCEventObject else {
                        continue
                    }
                    let existing = event.metadata(with: transaction)
                    guard existing.userNotes != notes else { continue }
                    let metadata = existing.metadataCopy()
                    metadata.userNotes = notes
                    event.replace(metadata, transaction: transaction)
                }
            }, completionBlock: {
                continuation.resume()
            })
        }
    }
}

// MARK: - Factory

/// Factory for accessing the shared FavoriteSyncService instance
enum FavoriteSyncServiceFactory {
    /// The shared service instance, backed by the app's YapDatabase read-write connection.
    /// Resolved lazily so `BRCDatabaseManager` is only touched on first use.
    static let shared: FavoriteSyncService = FavoriteSyncServiceImpl(
        connection: BRCDatabaseManager.shared.readWriteConnection,
        // Single owner per flag state: PlayaDB-native EventCalendarService by default,
        // legacy Yap `refreshCalendarEntry` when the flag is off. See
        // `EventCalendarHookRouter` for the routing (and its tests).
        calendarRefreshHook: EventCalendarHookRouter.makeCalendarRefreshHook(
            isPlayaDBSyncEnabled: { EventCalendarServiceFactory.isPlayaDBSyncEnabled },
            playaDBReconcile: { apiEventUID, isFavorite in
                Task { @MainActor in
                    EventCalendarServiceFactory.shared.reconcileInBackground(
                        eventUID: apiEventUID,
                        isFavorite: isFavorite
                    )
                }
            },
            legacyRefresh: { yapUID, _ in
                BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                    let event = transaction.object(forKey: yapUID, inCollection: BRCEventObject.yapCollection)
                    (event as? BRCEventObject)?.refreshCalendarEntry(transaction)
                }
            }
        ),
        visitStatusDidChangeHook: {
            BRCDatabaseManager.shared.refreshVisitStatusGroupedView(completionBlock: nil)
        }
    )

    /// Builds a service backed by a custom connection and hooks (for testing).
    static func makeService(
        connection: YapDatabaseConnection,
        calendarRefreshHook: @escaping FavoriteSyncCalendarRefreshHook,
        visitStatusDidChangeHook: @escaping FavoriteSyncVisitStatusDidChangeHook = {}
    ) -> FavoriteSyncService {
        FavoriteSyncServiceImpl(
            connection: connection,
            calendarRefreshHook: calendarRefreshHook,
            visitStatusDidChangeHook: visitStatusDidChangeHook
        )
    }
}
