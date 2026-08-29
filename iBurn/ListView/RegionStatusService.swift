//
//  RegionStatusService.swift
//  iBurn
//
//  Created by Claude Code on 7/11/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaAPI
import PlayaDB

/// Abstracts the "has the device physically entered the Burning Man region" check
/// so view models can be tested with a mocked region state.
protocol RegionStatusService {
    /// True once the device has physically entered the Burning Man region
    /// (set by `BRCAppDelegate.enteredBurningManRegion`). In-memory only;
    /// resets on app relaunch, matching legacy behavior.
    var hasEnteredBurningManRegion: Bool { get }
}

/// Factory for building the default `RegionStatusService`.
enum RegionStatusServiceFactory {
    static func makeService() -> RegionStatusService {
        RegionStatusServiceImpl()
    }
}

private struct RegionStatusServiceImpl: RegionStatusService {
    var hasEnteredBurningManRegion: Bool {
        BRCLocations.hasEnteredBurningManRegion
    }
}

extension EventFilter {
    /// The Burning Man API code for "Mature Audiences" events.
    static let adultEventTypeCode = EventType.matureAudiences.rawValue

    /// Sentinel inclusion set that matches no real event type. Used when the user's
    /// own type selection collapses to nothing after removing the adult type — an
    /// empty `eventTypeCodes` set would be treated as "no filtering" by PlayaDB.
    private static let matchNothingEventTypeCodes: Set<String> = ["__adult-gated__"]

    /// Returns a copy of this filter that excludes "Mature Audiences" (`adlt`) events.
    ///
    /// Replicates the legacy YapDatabase gate in
    /// `BRCDatabaseManager.eventsFilteredByExpiration:eventTypes:artHostedOnly:`:
    /// adult events are hidden until the device has physically entered the
    /// Burning Man region. Because `eventTypeCodes` is an inclusion list,
    /// "all types" (nil) becomes "every known API type except adlt".
    func excludingAdultEvents() -> EventFilter {
        var filter = self
        var codes = filter.eventTypeCodes
            ?? Set(EventType.allCases.map { $0.rawValue })
        codes.remove(Self.adultEventTypeCode)
        filter.eventTypeCodes = codes.isEmpty ? Self.matchNothingEventTypeCodes : codes
        return filter
    }
}
