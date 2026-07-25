//
//  EventCalendarService.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaDB

/// Keeps the device calendar (EventKit) in agreement with PlayaDB event favorites.
///
/// One `EKEvent` is created per event *occurrence*, matching legacy behavior
/// (`BRCEventObject.scheduleNotification:`, where YapDatabase stored one object per
/// occurrence). The EventKit identifiers are bookkept in PlayaDB's
/// `event_calendar_entries` table (`EventCalendarEntry`), which survives data imports.
///
/// Replaces the Yap-metadata bookkeeping (`BRCEventMetadata.calendarEventIdentifier`)
/// when `Preferences.FeatureFlags.usePlayaDBCalendarSync` is on.
protocol EventCalendarService {
    /// Reconciles the calendar entries of one API event with `isFavorite`.
    ///
    /// - Favorite: creates an EKEvent for every occurrence that doesn't already have a
    ///   live one, and records its identifier in PlayaDB.
    /// - Unfavorite: removes every EKEvent recorded for the event and deletes the rows.
    ///
    /// Idempotent: repeat calls with the same state are no-ops, and an EKEvent the user
    /// deleted by hand is recreated on the next favorite reconcile (legacy semantics).
    ///
    /// - Parameter eventUID: The *API* event uid (PlayaDB `EventObject.uid`), not a
    ///   legacy per-occurrence uid — use `FavoriteSyncServiceImpl.apiEventUID(fromYapUID:)`
    ///   to normalize.
    func reconcile(eventUID: String, isFavorite: Bool) async

    /// Fire-and-forget `reconcile` for synchronous call sites (e.g. the
    /// `FavoriteSyncCalendarRefreshHook`, which cannot await).
    func reconcileInBackground(eventUID: String, isFavorite: Bool)
}

// MARK: - Implementation

/// Actor so concurrent reconciles can't race into duplicate EKEvents. The legacy
/// favorite hook fires once per occurrence key, so the same event arrives N times in
/// a row; identical in-flight requests are coalesced instead of redone.
actor EventCalendarServiceImpl: EventCalendarService {

    /// Legacy reminder offsets: 1.5 hours and 10 minutes before the start.
    static let alarmOffsets: [TimeInterval] = [-90 * 60, -10 * 60]

    private let playaDB: PlayaDB
    private let eventStore: EventStoreProviding
    private let legacyIdentifierStore: LegacyCalendarIdentifierStore?
    private let embargoAllowsLocation: () -> Bool

    private struct PendingReconcile {
        let id: Int
        let isFavorite: Bool
        let task: Task<Void, Never>
    }

    private var pending: [String: PendingReconcile] = [:]
    private var nextPendingID = 0

    /// - Parameters:
    ///   - playaDB: Source of event occurrences and of the calendar-entry bookkeeping.
    ///   - eventStore: EventKit wrapper (injectable for tests).
    ///   - legacyIdentifierStore: Yap-side identifiers to take over, if the legacy
    ///     database is available. Pass nil to disable the takeover.
    ///   - embargoAllowsLocation: Whether playa addresses may be written into the
    ///     calendar. Defaults to the app's embargo state.
    init(playaDB: PlayaDB,
         eventStore: EventStoreProviding,
         legacyIdentifierStore: LegacyCalendarIdentifierStore?,
         embargoAllowsLocation: @escaping () -> Bool = { BRCEmbargo.allowEmbargoedData() }) {
        self.playaDB = playaDB
        self.eventStore = eventStore
        self.legacyIdentifierStore = legacyIdentifierStore
        self.embargoAllowsLocation = embargoAllowsLocation
    }

    // MARK: EventCalendarService

    func reconcile(eventUID: String, isFavorite: Bool) async {
        // The favorite hook fans out one call per legacy occurrence key; join an
        // identical in-flight pass instead of repeating the whole reconcile.
        if let existing = pending[eventUID], existing.isFavorite == isFavorite {
            await existing.task.value
            return
        }

        let previous = pending[eventUID]?.task
        nextPendingID += 1
        let id = nextPendingID
        let task = Task { [weak self] in
            // A state change queues behind the pass it supersedes so the calendar
            // never sees favorite/unfavorite work interleaved.
            if let previous { await previous.value }
            await self?.performReconcile(eventUID: eventUID, isFavorite: isFavorite)
        }
        pending[eventUID] = PendingReconcile(id: id, isFavorite: isFavorite, task: task)
        await task.value
        if pending[eventUID]?.id == id {
            pending[eventUID] = nil
        }
    }

    nonisolated func reconcileInBackground(eventUID: String, isFavorite: Bool) {
        Task { await self.reconcile(eventUID: eventUID, isFavorite: isFavorite) }
    }

    // MARK: Reconcile

    private func performReconcile(eventUID: String, isFavorite: Bool) async {
        guard !eventUID.isEmpty else { return }
        // No permission means nothing can be created *or* removed; matching legacy,
        // an undetermined status prompts and this pass writes nothing.
        guard await eventStore.ensureAccess() else { return }

        if isFavorite {
            await addEntries(eventUID: eventUID)
        } else {
            await removeEntries(eventUID: eventUID)
        }
    }

    private func addEntries(eventUID: String) async {
        let occurrences: [EventObjectOccurrence]
        do {
            occurrences = try await playaDB.fetchOccurrences(forEventUID: eventUID)
        } catch {
            print("EventCalendarService: failed to load occurrences for \(eventUID): \(error)")
            return
        }
        guard !occurrences.isEmpty else { return }

        let existing = await fetchEntriesByOccurrenceKey(eventUID: eventUID)
        if existing.isEmpty {
            // Nothing of ours on file: anything in the calendar for this event came
            // from the legacy Yap stack. Take it over before creating replacements so
            // the user doesn't end up with two copies of every occurrence.
            await takeOverLegacyEntries(eventUID: eventUID)
        }

        let includeLocation = embargoAllowsLocation()
        for occurrence in occurrences {
            let key = occurrence.calendarOccurrenceKey
            if let identifier = existing[key], eventStore.lookupEvent(identifier: identifier) != .notFound {
                // Still in the calendar (or unverifiable under write-only access):
                // leave it alone, exactly like legacy's "event already exists" check.
                continue
            }
            let draft = Self.makeDraft(for: occurrence, includeLocation: includeLocation)
            do {
                let identifier = try eventStore.createEvent(draft)
                let entry = EventCalendarEntry(occurrence: occurrence, ekEventIdentifier: identifier)
                try await playaDB.saveCalendarEntry(entry)
            } catch {
                print("EventCalendarService: failed to add calendar entry for \(eventUID) @ \(key): \(error)")
            }
        }
    }

    private func removeEntries(eventUID: String) async {
        let entries: [EventCalendarEntry]
        do {
            entries = try await playaDB.fetchCalendarEntries(eventId: eventUID)
        } catch {
            print("EventCalendarService: failed to load calendar entries for \(eventUID): \(error)")
            return
        }

        for entry in entries {
            do {
                try eventStore.removeEvent(identifier: entry.ekEventIdentifier)
            } catch {
                print("EventCalendarService: failed to remove calendar event \(entry.ekEventIdentifier): \(error)")
            }
        }

        if !entries.isEmpty {
            do {
                try await playaDB.deleteCalendarEntries(eventId: eventUID)
            } catch {
                print("EventCalendarService: failed to delete calendar entries for \(eventUID): \(error)")
            }
        } else {
            // Nothing on file here, so any calendar events for this favorite were
            // created by the legacy stack and are tracked only in Yap metadata.
            await takeOverLegacyEntries(eventUID: eventUID)
        }
    }

    /// One-way takeover of EKEvents bookkept by the legacy Yap stack: removes them and
    /// clears the stored identifiers so they can never be orphaned or double-created.
    private func takeOverLegacyEntries(eventUID: String) async {
        guard let legacyIdentifierStore else { return }
        let identifiers = await legacyIdentifierStore.identifiers(forEventUID: eventUID)
        guard !identifiers.isEmpty else { return }
        for identifier in identifiers {
            do {
                try eventStore.removeEvent(identifier: identifier)
            } catch {
                print("EventCalendarService: failed to remove legacy calendar event \(identifier): \(error)")
            }
        }
        await legacyIdentifierStore.clearIdentifiers(forEventUID: eventUID)
    }

    private func fetchEntriesByOccurrenceKey(eventUID: String) async -> [String: String] {
        do {
            let entries = try await playaDB.fetchCalendarEntries(eventId: eventUID)
            return entries.reduce(into: [:]) { $0[$1.occurrenceKey] = $1.ekEventIdentifier }
        } catch {
            print("EventCalendarService: failed to load calendar entries for \(eventUID): \(error)")
            return [:]
        }
    }

    // MARK: Draft Building

    /// Builds the calendar event content for one occurrence.
    ///
    /// Mirrors legacy `BRCEventObject.scheduleNotification:` — event title, playa
    /// address + host name as the location, event description as the notes, the event
    /// URL, Burning Man time zone, and the −90/−10 minute alarms.
    static func makeDraft(for occurrence: EventObjectOccurrence, includeLocation: Bool) -> CalendarEventDraft {
        CalendarEventDraft(
            title: occurrence.name,
            location: locationString(for: occurrence, includeLocation: includeLocation),
            notes: occurrence.description,
            url: occurrence.url,
            startDate: occurrence.startDate,
            endDate: occurrence.endDate,
            isAllDay: occurrence.allDay,
            timeZone: TimeZone.burningManTimeZone,
            alarmOffsets: alarmOffsets
        )
    }

    /// `"<playa address> - <host name>"`, degrading to whichever half exists.
    ///
    /// Legacy `scheduleNotification:` never consulted the embargo, but the newer
    /// "add to calendar" path (`EventEditControllerFactory.formatLocationString`) does
    /// and only writes the host name while locations are restricted. This follows the
    /// newer, embargo-respecting behavior — writing embargoed addresses into a synced
    /// calendar is exactly what the embargo exists to prevent.
    static func locationString(for occurrence: EventObjectOccurrence, includeLocation: Bool) -> String? {
        let hostName = occurrence.hostName?.nonEmpty
        guard includeLocation else { return hostName }

        // Host playa address first, then the event's own free-text location — the same
        // order `EventEditControllerFactory.formatLocationString` uses.
        let address = occurrence.hostAddress?.nonEmpty ?? occurrence.otherLocation.nonEmpty

        switch (address, hostName) {
        case let (address?, hostName?): return "\(address) - \(hostName)"
        case let (address?, nil): return address
        case let (nil, hostName?): return hostName
        case (nil, nil): return nil
        }
    }
}

private extension String {
    /// Self unless it is empty (or only whitespace).
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

// MARK: - Hook Routing

/// Builds the `FavoriteSyncCalendarRefreshHook` used by `FavoriteSyncServiceFactory`.
///
/// Exactly one stack owns calendar entries at a time: with
/// `Preferences.FeatureFlags.usePlayaDBCalendarSync` on, every favorite change routes
/// into `EventCalendarService` (keyed by the API uid, so the per-occurrence fan-out
/// collapses into one reconcile); with the flag off, the legacy Yap
/// `refreshCalendarEntry` hook runs unchanged, once per occurrence key.
///
/// Extracted (and injected) so the routing can be unit tested without EventKit.
enum EventCalendarHookRouter {
    static func makeCalendarRefreshHook(
        isPlayaDBSyncEnabled: @escaping () -> Bool,
        playaDBReconcile: @escaping (_ apiEventUID: String, _ isFavorite: Bool) -> Void,
        legacyRefresh: @escaping (_ yapUID: String, _ isFavorite: Bool) -> Void
    ) -> FavoriteSyncCalendarRefreshHook {
        return { yapUID, isFavorite in
            guard isPlayaDBSyncEnabled() else {
                legacyRefresh(yapUID, isFavorite)
                return
            }
            let apiUID = FavoriteSyncServiceImpl.apiEventUID(fromYapUID: yapUID)
            playaDBReconcile(apiUID, isFavorite)
        }
    }
}

// MARK: - Factory

/// Factory for the app-wide `EventCalendarService`.
enum EventCalendarServiceFactory {
    /// Whether calendar entries are owned by the PlayaDB-native service.
    static var isPlayaDBSyncEnabled: Bool {
        PreferenceServiceFactory.shared.getValue(Preferences.FeatureFlags.usePlayaDBCalendarSync)
    }

    /// Builds a service backed by the real EventKit store and the legacy Yap database.
    static func makeService(playaDB: PlayaDB) -> EventCalendarService {
        EventCalendarServiceImpl(
            playaDB: playaDB,
            eventStore: EKEventStoreProvider(),
            legacyIdentifierStore: YapLegacyCalendarIdentifierStore(
                connection: BRCDatabaseManager.shared.readWriteConnection
            )
        )
    }

    /// Builds a service with custom collaborators (for testing).
    static func makeService(
        playaDB: PlayaDB,
        eventStore: EventStoreProviding,
        legacyIdentifierStore: LegacyCalendarIdentifierStore?,
        embargoAllowsLocation: @escaping () -> Bool = { true }
    ) -> EventCalendarService {
        EventCalendarServiceImpl(
            playaDB: playaDB,
            eventStore: eventStore,
            legacyIdentifierStore: legacyIdentifierStore,
            embargoAllowsLocation: embargoAllowsLocation
        )
    }

    /// The app-wide instance, resolved from the dependency container so it shares the
    /// single `PlayaDB` handle (and therefore a single coalescing domain).
    @MainActor
    static var shared: EventCalendarService {
        BRCAppDelegate.shared.dependencies.eventCalendarService
    }
}
