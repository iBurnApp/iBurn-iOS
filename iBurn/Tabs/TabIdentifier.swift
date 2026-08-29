//
//  TabIdentifier.swift
//  iBurn
//
//  Created by Claude Code on 8/8/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import UIKit

/// Stable identity for the roots `BRCAppDelegate.setupDefaultTabBarController` builds.
/// Raw values are persisted in the tab-order preference, so they must never change.
enum TabIdentifier: String, CaseIterable {
    case map
    case nearby
    case favorites
    case events
    case more

    var title: String {
        switch self {
        case .map: return "Map"
        case .nearby: return "Nearby"
        case .favorites: return "Favorites"
        case .events: return "Events"
        case .more: return "More"
        }
    }

    /// Asset catalog name, matching the `tabBarItem.image` the app delegate assigns.
    var imageName: String {
        switch self {
        case .map: return "BRCMapIcon"
        case .nearby: return "BRCCompassIcon"
        case .favorites: return "BRCHeartIcon"
        case .events: return "BRCEventIcon"
        case .more: return "BRCMoreIcon"
        }
    }

    /// Map is a deep-link target and the app's home surface; More hosts the screen that
    /// undoes hiding. Letting either off the tab bar would strand the user.
    var isHideable: Bool {
        switch self {
        case .map, .more: return false
        case .nearby, .favorites, .events: return true
        }
    }

    /// Identifier handed to `UITab` on iOS 18+, so a rebuild can restore the selected tab
    /// without relying on positions that reordering invalidates.
    var tabIdentifier: String {
        "iBurn.tab.\(rawValue)"
    }

    /// The reverse of `tabIdentifier`, for the `UITab` delegate callbacks — a tab reports
    /// itself by identifier string, and the search tab's own identifier matches nothing here.
    static func identifier(forTabIdentifier tabIdentifier: String) -> TabIdentifier? {
        allCases.first { $0.tabIdentifier == tabIdentifier }
    }

    /// Matches a tab root (usually a `NavigationController`) to its identifier by leaf type.
    /// Both the SwiftUI and legacy implementations of each list are recognized.
    static func identifier(forRoot root: UIViewController) -> TabIdentifier? {
        let leaf = (root as? UINavigationController)?.viewControllers.first ?? root
        if leaf is MainMapViewController { return .map }
        if leaf is NearbyListHostingController || leaf is NearbyViewController { return .nearby }
        if leaf is FavoritesListHostingController || leaf is FavoritesViewController { return .favorites }
        if leaf is EventListHostingController || leaf is EventListViewController { return .events }
        if leaf is MoreViewController { return .more }
        return nil
    }
}
