//
//  MapTabReselection.swift
//  iBurn
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// What tapping the Map tab does when the Map tab is already the one you're looking at.
///
/// Stock iOS behavior for a re-tap is "take me back to the top of this tab", and the map's
/// version of the top has two layers: the pushed screens above it, then the camera. So the
/// first re-tap pops whatever the map pushed (a detail screen, a list) and the next one —
/// now that the map itself is what's on screen — flies the camera home to the city. Doing
/// both at once would throw away a pan the user might still want while they're reading a
/// detail screen, and recentering under a pushed screen would be invisible.
///
/// Kept as a pure function because the two tab systems the app runs on (`viewControllers`
/// below iOS 26, `UITab` on the search-tab layout) report a tap through different delegate
/// callbacks, and this is the part that shouldn't be written twice.
enum MapTabReselection {

    enum Outcome: Equatable {
        /// Not a re-tap of the map: let UIKit do its normal thing.
        case ignore
        /// The map has pushed something. Unwind to the map first.
        case popToRoot
        /// The map is already what's on screen. Fly the camera back to the default city view.
        case recenter
    }

    /// - Parameters:
    ///   - selected: Which tab the tap is asking for, if the app recognizes it.
    ///   - isAlreadySelected: Whether that tab is the one currently selected — i.e. this is a
    ///     re-tap rather than a switch.
    ///   - navigationStackDepth: How many view controllers the map tab's navigation
    ///     controller is holding. 1 means the map itself is on screen.
    static func outcome(
        selected: TabIdentifier?,
        isAlreadySelected: Bool,
        navigationStackDepth: Int
    ) -> Outcome {
        guard selected == .map, isAlreadySelected else { return .ignore }
        return navigationStackDepth > 1 ? .popToRoot : .recenter
    }
}
