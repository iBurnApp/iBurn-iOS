//
//  LegacyCalendarIdentifierStore.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

/// Read/clear access to the EKEvent identifiers the *legacy* stack bookkept in
/// YapDatabase metadata (`BRCEventMetadata.calendarEventIdentifier`).
///
/// Installs that favorited events before the PlayaDB calendar service shipped have
/// their EKEvent identifiers only in Yap. `EventCalendarService` uses this to take
/// those entries over one way — it removes the orphaned EKEvents and clears the
/// stored identifiers — so a user who unfavorites under the new stack doesn't end up
/// with calendar entries nothing owns any more.
///
/// Deliberately protocol-ized with plain `String` signatures: members whose
/// serialized signatures mention `YapDatabaseReadWriteTransaction` are silently
/// dropped when the test target imports the app module (see
/// `Docs/2026-07-11-swiftui-lists-default-on.md`). All Yap types stay inside
/// closure bodies.
protocol LegacyCalendarIdentifierStore {
    /// EKEvent identifiers stored on every legacy per-occurrence object
    /// (`"<apiUID>-<index>"`) belonging to this API event.
    func identifiers(forEventUID apiEventUID: String) async -> [String]

    /// Clears `calendarEventIdentifier` on every legacy per-occurrence object for
    /// this API event. Objects that have no identifier are left untouched.
    func clearIdentifiers(forEventUID apiEventUID: String) async
}

/// YapDatabase-backed `LegacyCalendarIdentifierStore`.
final class YapLegacyCalendarIdentifierStore: LegacyCalendarIdentifierStore {

    private let connection: YapDatabaseConnection

    init(connection: YapDatabaseConnection) {
        self.connection = connection
    }

    func identifiers(forEventUID apiEventUID: String) async -> [String] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            var identifiers: [String] = []
            connection.asyncRead({ transaction in
                let collection = BRCEventObject.yapCollection
                let keys = FavoriteSyncServiceImpl.occurrenceKeys(
                    from: transaction.allKeys(inCollection: collection),
                    apiUID: apiEventUID
                )
                for key in keys {
                    guard let event = transaction.object(forKey: key, inCollection: collection) as? BRCEventObject,
                          let metadata = event.metadata(with: transaction) as? BRCEventMetadata,
                          let identifier = metadata.calendarEventIdentifier,
                          !identifier.isEmpty else {
                        continue
                    }
                    identifiers.append(identifier)
                }
            }, completionBlock: {
                continuation.resume(returning: identifiers)
            })
        }
    }

    func clearIdentifiers(forEventUID apiEventUID: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.asyncReadWrite({ transaction in
                let collection = BRCEventObject.yapCollection
                let keys = FavoriteSyncServiceImpl.occurrenceKeys(
                    from: transaction.allKeys(inCollection: collection),
                    apiUID: apiEventUID
                )
                for key in keys {
                    guard let event = transaction.object(forKey: key, inCollection: collection) as? BRCEventObject,
                          let existing = event.metadata(with: transaction) as? BRCEventMetadata,
                          existing.calendarEventIdentifier != nil else {
                        continue
                    }
                    // `metadataCopy` is `instancetype` (`[self copy]`), so the copy keeps
                    // the BRCEventMetadata subclass.
                    let metadata = existing.metadataCopy()
                    metadata.calendarEventIdentifier = nil
                    event.replace(metadata, transaction: transaction)
                }
            }, completionBlock: {
                continuation.resume()
            })
        }
    }
}
