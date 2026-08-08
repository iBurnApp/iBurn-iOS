//
//  TabConfiguration.swift
//  iBurn
//
//  Created by Claude Code on 8/8/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// The user's tab bar arrangement: which roots are on the bar, in what order, and which
/// ones were pushed into the More list instead.
struct TabConfiguration: Equatable {
    /// Tabs on the bar, left to right.
    let visible: [TabIdentifier]

    /// Tabs the user removed from the bar. `MoreViewController` offers them as rows.
    let hidden: [TabIdentifier]

    static let `default` = TabConfiguration(visible: TabIdentifier.allCases, hidden: [])

    /// Full arrangement in customization order: the bar first, then the hidden tabs.
    var ordered: [TabIdentifier] {
        visible + hidden
    }

    func isHidden(_ identifier: TabIdentifier) -> Bool {
        hidden.contains(identifier)
    }

    // MARK: - Sanitizing

    /// Rebuilds a configuration from stored raw values, tolerating anything a downgrade,
    /// a removed tab, or a hand-edited defaults plist can leave behind:
    /// unknown ids are dropped, duplicates collapse to their first appearance, ids the
    /// build knows about but the stored order omits are appended in canonical order, and
    /// tabs that aren't hideable are forced back onto the bar.
    static func sanitized(order rawOrder: [String], hidden rawHidden: [String]) -> TabConfiguration {
        var ordered: [TabIdentifier] = []
        for raw in rawOrder {
            guard let identifier = TabIdentifier(rawValue: raw), !ordered.contains(identifier) else { continue }
            ordered.append(identifier)
        }
        for identifier in TabIdentifier.allCases where !ordered.contains(identifier) {
            ordered.append(identifier)
        }

        let hiddenSet = Set(rawHidden.compactMap(TabIdentifier.init(rawValue:)).filter(\.isHideable))
        return TabConfiguration(
            visible: ordered.filter { !hiddenSet.contains($0) },
            hidden: ordered.filter { hiddenSet.contains($0) }
        )
    }

    // MARK: - Storage

    /// Order of every known tab, bar first then hidden. Raw `TabIdentifier` values.
    static let orderPreference = Preference<[String]>(
        key: "userInterface.tabBar.order",
        defaultValue: TabIdentifier.allCases.map(\.rawValue),
        description: "Tab bar order, including tabs the user moved into More"
    )

    /// Raw `TabIdentifier` values the user removed from the tab bar.
    static let hiddenPreference = Preference<[String]>(
        key: "userInterface.tabBar.hidden",
        defaultValue: [],
        description: "Tabs the user moved off the tab bar and into the More list"
    )

    static var current: TabConfiguration {
        get {
            let service = PreferenceServiceFactory.shared
            return sanitized(
                order: service.getValue(orderPreference),
                hidden: service.getValue(hiddenPreference)
            )
        }
        set {
            let sanitized = TabConfiguration.sanitized(
                order: newValue.ordered.map(\.rawValue),
                hidden: newValue.hidden.map(\.rawValue)
            )
            let service = PreferenceServiceFactory.shared
            service.setValue(sanitized.ordered.map(\.rawValue), for: orderPreference)
            service.setValue(sanitized.hidden.map(\.rawValue), for: hiddenPreference)
            NotificationCenter.default.post(name: .tabConfigurationDidChange, object: nil)
        }
    }

    static func resetToDefault() {
        current = .default
    }
}

extension Notification.Name {
    /// Posted when the user reorders or hides a tab, so `TabController` can rebuild the
    /// bar and `MoreViewController` can pick up the matching overflow rows.
    static let tabConfigurationDidChange = Notification.Name("TabConfigurationDidChange")
}
