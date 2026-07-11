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
}

/// Hook invoked with each Yap event object's uniqueID after its favorite metadata has been
/// written and committed. The production hook (see `FavoriteSyncServiceFactory.shared`)
/// resolves the event in its own transaction and calls
/// `BRCEventObject.refreshCalendarEntry(_:)`, which creates/removes the EKEvent calendar
/// entry (tracked via `BRCEventMetadata.calendarEventIdentifier`). Injectable so tests can
/// avoid EventKit.
///
/// Deliberately a top-level typealias whose signature contains no YapDatabase or
/// bridging-header types: members whose serialized signatures reference those (e.g.
/// `YapDatabaseReadWriteTransaction`) fail to resolve when the test target imports this
/// module, silently dropping the member ("has no member" / "no accessible initializers").
typealias FavoriteSyncCalendarRefreshHook = (_ yapUID: String, _ isFavorite: Bool) -> Void

// MARK: - Implementation

final class FavoriteSyncServiceImpl: FavoriteSyncService {

    private let connection: YapDatabaseConnection
    private let calendarRefreshHook: FavoriteSyncCalendarRefreshHook

    init(connection: YapDatabaseConnection,
         calendarRefreshHook: @escaping FavoriteSyncCalendarRefreshHook) {
        self.connection = connection
        self.calendarRefreshHook = calendarRefreshHook
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
                let occurrencePrefix = apiUID + "-"
                let matchingKeys = transaction.allKeys(inCollection: collection).filter { key in
                    if key == apiUID { return true }
                    guard key.hasPrefix(occurrencePrefix) else { return false }
                    let suffix = key.dropFirst(occurrencePrefix.count)
                    return !suffix.isEmpty && suffix.allSatisfy { $0.isASCII && $0.isNumber }
                }
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
}

// MARK: - Factory

/// Factory for accessing the shared FavoriteSyncService instance
enum FavoriteSyncServiceFactory {
    /// The shared service instance, backed by the app's YapDatabase read-write connection.
    /// Resolved lazily so `BRCDatabaseManager` is only touched on first use.
    static let shared: FavoriteSyncService = FavoriteSyncServiceImpl(
        connection: BRCDatabaseManager.shared.readWriteConnection,
        calendarRefreshHook: { yapUID, _ in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                let event = transaction.object(forKey: yapUID, inCollection: BRCEventObject.yapCollection)
                (event as? BRCEventObject)?.refreshCalendarEntry(transaction)
            }
        }
    )

    /// Builds a service backed by a custom connection and calendar hook (for testing).
    static func makeService(
        connection: YapDatabaseConnection,
        calendarRefreshHook: @escaping FavoriteSyncCalendarRefreshHook
    ) -> FavoriteSyncService {
        FavoriteSyncServiceImpl(connection: connection, calendarRefreshHook: calendarRefreshHook)
    }
}
