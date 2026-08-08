//
//  NearbyCardPreferences.swift
//  iBurn
//
//  Created by Claude Code on 8/8/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  User configuration for the on-map nearby card: whether it shows at all, and which
//  kinds of objects it is allowed to surface. Both are reachable from the map's filter
//  screen, which is the only place the card can be turned back on once its close button
//  has hidden it.
//

import Foundation

// MARK: - Preferences

extension Preferences {
    /// Settings for the on-map nearby card overlay.
    ///
    /// Declared here rather than in `Preferences.swift` so the card owns its own
    /// configuration; the keys stay in the `userInterface.` namespace regardless.
    enum NearbyCard {
        static let enabled = Preference<Bool>(
            key: "userInterface.nearbyCard.enabled",
            defaultValue: true,
            description: "Show the nearby card on the map"
        )

        static let showArt = Preference<Bool>(
            key: "userInterface.nearbyCard.showArt",
            defaultValue: true,
            description: "Let the nearby card list art"
        )

        static let showCamps = Preference<Bool>(
            key: "userInterface.nearbyCard.showCamps",
            defaultValue: true,
            description: "Let the nearby card list camps"
        )

        static let showEvents = Preference<Bool>(
            key: "userInterface.nearbyCard.showEvents",
            defaultValue: true,
            description: "Let the nearby card list events"
        )
    }
}

// MARK: - Type selection

/// Which object types the nearby card may surface.
///
/// Stored as three independent Bool preferences (rather than one encoded value) so each
/// row in the map filter screen maps to exactly one key, and so an unset key falls back
/// to `true` on its own.
struct NearbyCardTypes: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let art = NearbyCardTypes(rawValue: 1 << 0)
    static let camps = NearbyCardTypes(rawValue: 1 << 1)
    static let events = NearbyCardTypes(rawValue: 1 << 2)

    static let all: NearbyCardTypes = [.art, .camps, .events]

    init(showArt: Bool, showCamps: Bool, showEvents: Bool) {
        var types: NearbyCardTypes = []
        if showArt { types.insert(.art) }
        if showCamps { types.insert(.camps) }
        if showEvents { types.insert(.events) }
        self = types
    }

    /// The current selection, read straight from the preference service.
    static func current(_ service: PreferenceService = PreferenceServiceFactory.shared) -> NearbyCardTypes {
        NearbyCardTypes(
            showArt: service.getValue(Preferences.NearbyCard.showArt),
            showCamps: service.getValue(Preferences.NearbyCard.showCamps),
            showEvents: service.getValue(Preferences.NearbyCard.showEvents)
        )
    }
}
