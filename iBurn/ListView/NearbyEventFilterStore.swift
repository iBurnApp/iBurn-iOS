//
//  NearbyEventFilterStore.swift
//  iBurn
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  The one event filter both Nearby surfaces share: the full-screen Nearby list
//  (`NearbyViewModel`) and the on-map nearby card (`NearbyCardViewModel`).
//
//  The two screens already share one time window (`isInNearbyWindow`) so they can't list
//  different events; the user's filter choices have to be shared for the same reason —
//  capping duration on the Nearby screen and leaving the card uncapped would put a 12-hour
//  amenity listing back on the map the moment the user swiped to it.
//

import Combine
import Foundation
import MapKit
import PlayaDB

@MainActor
final class NearbyEventFilterStore: ObservableObject {

    /// The instance both view models bind to by default. A shared object (rather than a
    /// notification) means a change made in the Nearby sheet republishes to the card that
    /// is still alive underneath it in the map tab's navigation stack.
    static let shared = NearbyEventFilterStore()

    /// User-editable filter. Persisted on every change; observers restart their event
    /// observation so the new cap is applied in SQL, not client-side.
    @Published var filter: EventFilter {
        didSet {
            guard filter != oldValue else { return }
            EventFilterStorage.saveFilter(filter, key: storageKey, defaults: defaults)
        }
    }

    private let storageKey: String
    private let defaults: UserDefaults

    init(storageKey: String = "nearbyEventFilter", defaults: UserDefaults = .standard) {
        self.storageKey = storageKey
        self.defaults = defaults

        var loaded = EventFilterStorage.loadFilter(key: storageKey, defaults: defaults)
            ?? EventFilter.nearbyDefaults
        // The duration preference lives under its own key so the 6h default reaches fresh
        // AND existing installs; overlay it whether or not a blob existed.
        loaded.maxDuration = EventFilterStorage.loadMaxDuration(filterKey: storageKey, defaults: defaults)
        loaded.includeExpired = true
        self.filter = loaded
    }

    /// True when any control the Nearby filter sheet exposes differs from its default.
    /// Drives the toolbar button's filled icon.
    var hasNonDefaultFilters: Bool {
        !filter.matchesSheetDefaults(.nearbyDefaults, includingExpired: false)
    }

    /// The filter to hand a region observation.
    ///
    /// Everything the user chose (max duration, event types, favorites) is applied in SQL;
    /// the time gate is deliberately NOT — `isInNearbyWindow` evaluates it in memory at the
    /// effective (time-shiftable) date, so `includeExpired` must stay `true` here or a warp
    /// into the past would be emptied out by a wall-clock expiry predicate.
    func observationFilter(region: MKCoordinateRegion) -> EventFilter {
        var f = filter
        f.region = region
        f.includeExpired = true
        f.happeningNow = false
        f.startingWithinHours = nil
        f.searchText = nil
        f.startDate = nil
        f.endDate = nil
        f.activeWindow = nil
        return f
    }
}
