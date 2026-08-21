//
//  EventStoreProviding.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import EventKit

// MARK: - Value Types

/// Calendar permission state, mirroring `EKAuthorizationStatus` but decoupled from
/// EventKit so tests can drive every branch without entitlements.
enum CalendarAuthorization: Equatable {
    case notDetermined
    /// `denied` or `restricted` — nothing can be written.
    case denied
    /// iOS 17+ write-only access: events can be created, but not read back or removed.
    case writeOnly
    /// Full access (pre-iOS 17 `authorized`).
    case fullAccess

    /// Whether new events may be created.
    var allowsWriting: Bool {
        switch self {
        case .writeOnly, .fullAccess: return true
        case .notDetermined, .denied: return false
        }
    }

    /// Whether existing events may be looked up (and therefore removed).
    var allowsReading: Bool { self == .fullAccess }
}

/// Result of looking up a previously created calendar event.
enum CalendarEventLookup: Equatable {
    /// The event is still in the user's calendar.
    case found
    /// The event is gone (deleted by the user, or the calendar was removed).
    case notFound
    /// The store cannot answer the question (write-only access). Callers should
    /// trust their own bookkeeping rather than recreating the event.
    case unavailable
}

/// Everything needed to create one `EKEvent`, expressed without EventKit types so
/// the reconcile logic can be unit tested against a spy store.
struct CalendarEventDraft: Equatable {
    var title: String
    var location: String?
    var notes: String?
    var url: URL?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var timeZone: TimeZone?
    /// Relative alarm offsets in seconds (negative = before the start date).
    var alarmOffsets: [TimeInterval]
}

enum CalendarEventStoreError: Error {
    /// The device has no default calendar for new events.
    case noDefaultCalendar
    /// EventKit saved the event but returned no identifier to track it by.
    case missingEventIdentifier
    /// Writing was attempted without permission.
    case notAuthorized
}

// MARK: - Protocol

/// Narrow wrapper around `EKEventStore`, injectable so `EventCalendarService` can be
/// tested without calendar entitlements.
protocol EventStoreProviding {
    /// Current permission state.
    var authorization: CalendarAuthorization { get }

    /// Returns whether events may be written, optionally prompting the user when the
    /// status is undetermined.
    ///
    /// Matches legacy `BRCEventObject.eventStore`: an undetermined status shows the
    /// permission prompt and reports failure for *this* attempt (the prompt is
    /// asynchronous, so nothing is written until the user acts and favorites again).
    ///
    /// - Parameter promptIfNeeded: Whether an undetermined status may show the in-app
    ///   pre-prompt. Only passes that *add* to the calendar should ask: nothing can be
    ///   in the calendar without access having been granted at write time, so a removal
    ///   pass without access has nothing to do and must stay silent.
    ///
    /// Implementations must show the pre-prompt at most once per app launch — repeated
    /// favoriting while the status stays `.notDetermined` (the user dismissed the
    /// pre-prompt without answering the system alert) must not re-prompt.
    func ensureAccess(promptIfNeeded: Bool) async -> Bool

    /// Whether a previously created event still exists.
    func lookupEvent(identifier: String) -> CalendarEventLookup

    /// Creates a calendar event and returns its `EKEvent.eventIdentifier`.
    func createEvent(_ draft: CalendarEventDraft) throws -> String

    /// Removes a previously created event. Returns whether an event was actually removed.
    @discardableResult
    func removeEvent(identifier: String) throws -> Bool
}

// MARK: - EventKit Implementation

/// `EventStoreProviding` backed by a real `EKEventStore`.
final class EKEventStoreProvider: EventStoreProviding {

    private let store: EKEventStore
    private let prompt: () -> Void
    /// Guards `hasPrompted`, which is read from whatever queue a reconcile lands on.
    private let promptLock = NSLock()
    /// Whether the in-app pre-prompt was already shown during this app launch.
    private var hasPrompted = false

    /// - Parameters:
    ///   - store: The EventKit store. One long-lived store is reused for the app's
    ///     lifetime (legacy created a fresh one per operation).
    ///   - prompt: Shows the permission UI. Defaults to the app's `BRCPermissions`
    ///     prompt, dispatched to the main queue like the legacy implementation.
    init(store: EKEventStore = EKEventStore(),
         prompt: @escaping () -> Void = {
             DispatchQueue.main.async {
                 BRCPermissions.promptForEvents({})
             }
         }) {
        self.store = store
        self.prompt = prompt
    }

    var authorization: CalendarAuthorization {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            switch status {
            case .notDetermined: return .notDetermined
            case .restricted, .denied: return .denied
            case .fullAccess: return .fullAccess
            case .writeOnly: return .writeOnly
            @unknown default: return .denied
            }
        }
        // Pre-iOS 17 the only "yes" is `.authorized` (raw value 3, the same raw value
        // iOS 17 reuses for `.fullAccess`). Matched by raw value so the deprecated
        // case name never has to be referenced.
        switch status.rawValue {
        case 0: return .notDetermined
        case 3: return .fullAccess
        default: return .denied
        }
    }

    func ensureAccess(promptIfNeeded: Bool) async -> Bool {
        let status = authorization
        if status.allowsWriting { return true }
        // A real `.denied` never prompts (iOS wouldn't show the system alert anyway), and
        // a removal pass never prompts — see the protocol docs.
        guard status == .notDetermined, promptIfNeeded else { return false }
        // The pre-prompt's "Close" button doesn't ask EventKit for anything, so the
        // status stays `.notDetermined` forever. Without this latch every subsequent
        // favorite would pop the modal again.
        guard claimPrompt() else { return false }
        // Legacy behavior: prompt, then bail out of this pass. The prompt is
        // asynchronous UI, so there is nothing to write until the user responds.
        prompt()
        return false
    }

    /// Returns true exactly once per app launch.
    private func claimPrompt() -> Bool {
        promptLock.lock()
        defer { promptLock.unlock() }
        if hasPrompted { return false }
        hasPrompted = true
        return true
    }

    func lookupEvent(identifier: String) -> CalendarEventLookup {
        guard authorization.allowsReading else { return .unavailable }
        return store.event(withIdentifier: identifier) == nil ? .notFound : .found
    }

    func createEvent(_ draft: CalendarEventDraft) throws -> String {
        guard authorization.allowsWriting else { throw CalendarEventStoreError.notAuthorized }
        guard let calendar = store.defaultCalendarForNewEvents else {
            throw CalendarEventStoreError.noDefaultCalendar
        }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = draft.title
        event.location = draft.location
        event.notes = draft.notes
        event.url = draft.url
        event.timeZone = draft.timeZone
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.isAllDay = draft.isAllDay
        for offset in draft.alarmOffsets {
            event.addAlarm(EKAlarm(relativeOffset: offset))
        }
        try store.save(event, span: .thisEvent)
        guard let identifier = event.eventIdentifier, !identifier.isEmpty else {
            throw CalendarEventStoreError.missingEventIdentifier
        }
        return identifier
    }

    @discardableResult
    func removeEvent(identifier: String) throws -> Bool {
        // Removing requires reading the event first, which write-only access forbids.
        guard authorization.allowsReading else { return false }
        guard let event = store.event(withIdentifier: identifier) else { return false }
        try store.remove(event, span: .thisEvent)
        return true
    }
}
