//
//  LegacyCalendarIdentifierStore.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// Read/clear access to the EKEvent identifiers the *legacy* stack bookkept in
/// YapDatabase metadata (`BRCEventMetadata.calendarEventIdentifier`).
///
/// Installs that favorited events before the PlayaDB calendar service shipped had
/// their EKEvent identifiers only in Yap. `EventCalendarService` uses this to take
/// those entries over one way — it removes the orphaned EKEvents and clears the
/// stored identifiers — so a user who unfavorites under the new stack doesn't end up
/// with calendar entries nothing owns any more.
///
/// The YapDatabase-backed implementation was deleted with the rest of the legacy
/// stack, so the app passes `nil` today and the takeover is inert; the protocol is
/// kept because the takeover logic (and its tests) still describe a real upgrade
/// path, and because a future migration reader could implement it.
protocol LegacyCalendarIdentifierStore {
    /// EKEvent identifiers stored on every legacy per-occurrence object
    /// (`"<apiUID>-<index>"`) belonging to this API event.
    func identifiers(forEventUID apiEventUID: String) async -> [String]

    /// Clears `calendarEventIdentifier` on every legacy per-occurrence object for
    /// this API event. Objects that have no identifier are left untouched.
    func clearIdentifiers(forEventUID apiEventUID: String) async
}
