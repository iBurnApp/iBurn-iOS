//
//  EventFilterStorage.swift
//  iBurn
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Shared persistence for the event filter sheet's settings. Two screens now own an
//  `EventFilter` the user can edit through `EventFilterSheet` — the Events tab
//  (`EventListViewModel`) and Nearby (`NearbyEventFilterStore`) — and both need the same
//  "unset default vs. explicitly Any" duration semantics, so the rules live here once.
//

import Foundation
import PlayaDB

enum EventFilterStorage {

    // MARK: - Max Duration

    /// Default max event-occurrence duration for the app's browse surfaces: hide
    /// occurrences longer than 6h (all-day / half-day "amenity listing" pseudo-events —
    /// open camps, mailboxes, charging stations). Applied to fresh AND existing installs
    /// until the user chooses their own value.
    ///
    /// This default deliberately lives in the app's preference layer and NOT in PlayaDB's
    /// `EventFilter`, whose package default stays `nil` (no limit) so other consumers
    /// (watch, detail screens) are unaffected.
    static let defaultMaxDuration: TimeInterval = 6 * 3600

    /// Persisted duration choice. Stored under its own UserDefaults key rather than inside
    /// the EventFilter blob so "never chosen" (key absent → 6h default) stays distinct from
    /// "explicitly Any" (`.unlimited` → no limit). Synthesized Codable omits nil optionals,
    /// so a `nil` maxDuration inside the blob would be indistinguishable from a pre-existing
    /// install whose blob predates the field — collapsing both to the default.
    private enum StoredMaxDuration: Codable {
        case limited(TimeInterval)
        case unlimited
    }

    /// Where the duration preference for a given filter blob key lives.
    static func durationStorageKey(for filterKey: String) -> String {
        "\(filterKey).maxDuration"
    }

    /// The stored cap for `filterKey`, or `defaultMaxDuration` when the user has never
    /// chosen one. `nil` means the user explicitly picked "Any".
    static func loadMaxDuration(
        filterKey: String,
        defaults: UserDefaults = .standard
    ) -> TimeInterval? {
        guard let data = defaults.data(forKey: durationStorageKey(for: filterKey)),
              let stored = try? JSONDecoder().decode(StoredMaxDuration.self, from: data) else {
            // Unset (fresh or pre-existing install) → apply the default.
            return defaultMaxDuration
        }
        switch stored {
        case .limited(let seconds): return seconds
        case .unlimited: return nil
        }
    }

    static func saveMaxDuration(
        _ maxDuration: TimeInterval?,
        filterKey: String,
        defaults: UserDefaults = .standard
    ) {
        let stored: StoredMaxDuration = maxDuration.map(StoredMaxDuration.limited) ?? .unlimited
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: durationStorageKey(for: filterKey))
    }

    // MARK: - Filter Blob

    /// Decode the persisted filter, with the separately-stored max duration overlaid.
    /// Returns `nil` when nothing has been persisted yet so the caller can pick its own
    /// base filter; the duration default still applies in that case via `loadMaxDuration`.
    static func loadFilter(
        key: String,
        defaults: UserDefaults = .standard
    ) -> EventFilter? {
        guard let data = defaults.data(forKey: key),
              var filter = try? JSONDecoder().decode(EventFilter.self, from: data) else {
            return nil
        }
        filter.maxDuration = loadMaxDuration(filterKey: key, defaults: defaults)
        return filter
    }

    /// Persist the user-owned parts of `filter`.
    ///
    /// Dates and search text are per-observation state, not preferences, so they're
    /// stripped. `maxDuration` is written separately (see `saveMaxDuration`) so its
    /// "unset vs. Any" distinction survives; it is stripped from the blob to keep a
    /// single source of truth.
    static func saveFilter(
        _ filter: EventFilter,
        key: String,
        defaults: UserDefaults = .standard
    ) {
        var persistFilter = filter
        persistFilter.startDate = nil
        persistFilter.endDate = nil
        persistFilter.searchText = nil
        persistFilter.activeWindow = nil
        persistFilter.maxDuration = nil
        if let data = try? JSONEncoder().encode(persistFilter) {
            defaults.set(data, forKey: key)
        }
        saveMaxDuration(filter.maxDuration, filterKey: key, defaults: defaults)
    }
}

// MARK: - Sheet defaults

extension EventFilter {
    /// Baseline for the Events tab's filter sheet: hide expired, all favorites, all types,
    /// 6h duration cap.
    static var eventListDefaults: EventFilter {
        EventFilter(includeExpired: false, maxDuration: EventFilterStorage.defaultMaxDuration)
    }

    /// Baseline for Nearby's filter sheet. `includeExpired` is `true` because Nearby's time
    /// gate is the now-window evaluated at the (possibly time-shifted) effective date — the
    /// SQL expiry predicate compares against real wall-clock now and would empty the list
    /// whenever the user warps to a past moment. The sheet hides that toggle for Nearby.
    static var nearbyDefaults: EventFilter {
        EventFilter(includeExpired: true, maxDuration: EventFilterStorage.defaultMaxDuration)
    }

    /// Whether every control `EventFilterSheet` exposes still matches `defaults`.
    ///
    /// Drives both the sheet's Reset-button visibility and the toolbar button's filled/
    /// outlined icon, so the two can't disagree about what "filtered" means.
    /// `includingExpired: false` for sheets that hide the expired toggle.
    func matchesSheetDefaults(_ defaults: EventFilter, includingExpired: Bool = true) -> Bool {
        (!includingExpired || includeExpired == defaults.includeExpired)
            && onlyFavorites == defaults.onlyFavorites
            && eventTypeCodes == defaults.eventTypeCodes
            && maxDuration == defaults.maxDuration
    }
}
