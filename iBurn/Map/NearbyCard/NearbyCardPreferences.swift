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

// MARK: - Visibility

/// What the footer's hide button just did.
///
/// The two cases exist because the button means different things depending on whether a
/// person is standing on the map: with one down it retires the drop, without one it switches
/// the card off for good. Only the second is a settings change, and only the second needs the
/// map to explain where the card went.
enum NearbyCardHideAction: Equatable {
    /// The dropped pin was retired; the stored preference is untouched.
    case clearDroppedPin
    /// The card itself was switched off, and stays off until the map filter turns it back on.
    case disableCard

    var disablesCard: Bool { self == .disableCard }
}

/// The two rules that decide whether the nearby card is on screen and what hiding it means.
///
/// Pure functions over the only two inputs that matter — the stored preference and whether a
/// dropped pin is currently sourcing the card — so the behaviour can be reasoned about (and
/// tested) without a view model, a map, or `UserDefaults`.
enum NearbyCardVisibility {

    /// A dropped pin shows the card even when the preference has it switched off.
    ///
    /// Dropping the person is a direct request to look at somewhere else, and the answer
    /// arrives in the card — so refusing to draw it because the user once hid the *"what's
    /// around me"* card leaves the drop with nowhere to land. The show is transient: nothing
    /// is written back, and removing the person returns the card to whatever the preference
    /// says.
    static func isVisible(cardEnabled: Bool, overrideActive: Bool) -> Bool {
        cardEnabled || overrideActive
    }

    /// What "Hide" does, given whether a person is currently standing on the map.
    ///
    /// While a drop is active, hiding is scoped to the drop: the person comes off the map and
    /// the card falls back to its stored state. The persisted preference therefore only ever
    /// changes when the card is hidden in its normal, device-sourced state — checking out
    /// another spot can't silently turn off "what's near me".
    static func hideAction(overrideActive: Bool) -> NearbyCardHideAction {
        overrideActive ? .clearDroppedPin : .disableCard
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
