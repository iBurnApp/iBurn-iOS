//
//  MapSearchLayout.swift
//  iBurn
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Prototype switch for where the global search entry point lives. iOS 26 gives us
//  two native "search at the bottom" shapes and they pull the rest of the map chrome
//  in different directions, so we ship both behind a debug preference and compare.
//

import Foundation

/// Where the global search affordance is anchored.
enum MapSearchLayout: String, CaseIterable {
    /// Ships today: `navigationItem.searchController` under the nav bar title.
    case navigationBar

    /// The search field rides in a `UITabAccessory` directly above the tab bar.
    case bottomAccessory

    /// A `UISearchTab` sits beside the tab bar; tapping it collapses the tab bar
    /// into a search field. Native, but costs a tab slot, so Events comes off the bar
    /// by default and lives in More (Customize Tabs can put it back).
    case searchTab

    var displayName: String {
        switch self {
        case .navigationBar: return "Top (current)"
        case .bottomAccessory: return "Bottom accessory"
        case .searchTab: return "Search tab"
        }
    }

    var summary: String {
        switch self {
        case .navigationBar:
            return "Search bar under the navigation bar title."
        case .bottomAccessory:
            return "Search field in a Liquid Glass accessory above the tab bar."
        case .searchTab:
            return "Search button beside the tab bar; Events moves into More by default."
        }
    }

    /// Both bottom layouts need the nav bar's search controller detached and the
    /// on-map controls lifted clear of the taller bottom chrome.
    var isBottomAnchored: Bool {
        self != .navigationBar
    }

    /// Only the tab-bar-anchored layouts exist on iOS 26; older systems always get
    /// the navigation bar. Callers should route through `resolved` rather than
    /// reading the stored preference directly.
    var isAvailable: Bool {
        guard isBottomAnchored else { return true }
        if #available(iOS 26.0, *) { return true }
        return false
    }

    var resolved: MapSearchLayout {
        isAvailable ? self : .navigationBar
    }

    // MARK: - Storage

    static var current: MapSearchLayout {
        get {
            let raw = PreferenceServiceFactory.shared.getValue(Preferences.UserInterface.mapSearchLayout)
            return (MapSearchLayout(rawValue: raw) ?? .navigationBar).resolved
        }
        set {
            PreferenceServiceFactory.shared.setValue(newValue.rawValue, for: Preferences.UserInterface.mapSearchLayout)
            NotificationCenter.default.post(name: .mapSearchLayoutDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    /// Posted when the prototype layout changes so the tab controller and map can
    /// rebuild their chrome without an app relaunch.
    static let mapSearchLayoutDidChange = Notification.Name("MapSearchLayoutDidChange")
}
