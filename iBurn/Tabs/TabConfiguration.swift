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

    /// The same arrangement with `identifiers` moved off the bar, keeping their relative
    /// order. Used to fold the active search layout's default into a stored configuration.
    func movingToHidden(_ identifiers: [TabIdentifier]) -> TabConfiguration {
        let moving = Set(identifiers.filter(\.isHideable))
        guard !moving.isEmpty else { return self }
        return TabConfiguration(
            visible: visible.filter { !moving.contains($0) },
            hidden: ordered.filter { moving.contains($0) || hidden.contains($0) }
        )
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

    /// Raw `TabIdentifier` values whose bar visibility the user set by hand.
    ///
    /// The active search layout can take a tab off the bar on its own (see
    /// `layoutHiddenByDefault`), and that default has to be distinguishable from a user
    /// who *wants* that tab on the bar — otherwise the layout would either override the
    /// user forever or stop applying the moment anything else was customized. An id in
    /// here is exempt from layout defaults, so the user's choice survives layout switches;
    /// an id that isn't follows whatever the active layout wants.
    static let visibilityOverridesPreference = Preference<[String]>(
        key: "userInterface.tabBar.visibilityOverrides",
        defaultValue: [],
        description: "Tabs whose tab-bar visibility the user chose explicitly"
    )

    /// Tabs the active search layout keeps off the bar unless the user says otherwise.
    ///
    /// The iOS 26 `.searchTab` layout spends a bar slot on search, and Events is the tab
    /// that gives way: it's the one you go looking for by name (search and the More list
    /// both reach it), where Map, Nearby and Favorites are "what's around me right now"
    /// surfaces you want one tap away.
    static var layoutHiddenByDefault: [TabIdentifier] {
        guard MapSearchLayout.current == .searchTab else { return [] }
        if #available(iOS 26.0, *) { return [.events] }
        return []
    }

    /// What a user who has never customized sees on the active layout. `Reset` compares
    /// against this rather than `.default`, which describes storage, not the bar.
    static var layoutDefault: TabConfiguration {
        TabConfiguration.default.movingToHidden(layoutHiddenByDefault)
    }

    /// Whether the user has customized anything at all — arrangement or an explicit
    /// visibility choice. `Reset` still has work to do while this is false, even when the
    /// bar happens to look like the layout default: an explicit "Events off the bar" and
    /// the layout's own default look identical until the layout changes.
    static var isUntouched: Bool {
        current == layoutDefault && visibilityOverrides.isEmpty
    }

    /// Raw ids the user has explicitly shown or hidden.
    private static var visibilityOverrides: Set<TabIdentifier> {
        get {
            Set(PreferenceServiceFactory.shared
                .getValue(visibilityOverridesPreference)
                .compactMap(TabIdentifier.init(rawValue:)))
        }
        set {
            PreferenceServiceFactory.shared.setValue(
                TabIdentifier.allCases.filter(newValue.contains).map(\.rawValue),
                for: visibilityOverridesPreference
            )
        }
    }

    /// The effective arrangement: what the user stored, with the active layout's defaults
    /// folded in for any tab they never decided about themselves.
    static var current: TabConfiguration {
        get {
            let service = PreferenceServiceFactory.shared
            let stored = sanitized(
                order: service.getValue(orderPreference),
                hidden: service.getValue(hiddenPreference)
            )
            let chosen = visibilityOverrides
            return stored.movingToHidden(layoutHiddenByDefault.filter { !chosen.contains($0) })
        }
        set {
            let sanitized = TabConfiguration.sanitized(
                order: newValue.ordered.map(\.rawValue),
                hidden: newValue.hidden.map(\.rawValue)
            )
            // Any tab whose visibility this write flips away from what's on screen was
            // flipped by the user, so it stops following the layout default from here on.
            let previous = current
            let flipped = TabIdentifier.allCases.filter {
                previous.isHidden($0) != sanitized.isHidden($0)
            }
            let chosen = visibilityOverrides.union(flipped)

            // Tabs that are only off the bar because the active layout put them there
            // aren't stored as user-hidden — otherwise editing anything else would freeze
            // a layout default into the user's preferences and it would never come back.
            let layoutHidden = Set(layoutHiddenByDefault.filter { !chosen.contains($0) })

            let service = PreferenceServiceFactory.shared
            service.setValue(sanitized.ordered.map(\.rawValue), for: orderPreference)
            service.setValue(sanitized.hidden.filter { !layoutHidden.contains($0) }.map(\.rawValue), for: hiddenPreference)
            visibilityOverrides = chosen
            NotificationCenter.default.post(name: .tabConfigurationDidChange, object: nil)
        }
    }

    /// Back to canonical order with nothing user-hidden *and* no user overrides, so the
    /// active layout's defaults apply again. Deliberately bypasses the `current` setter,
    /// which would read this as the user re-deciding every tab it puts back.
    static func resetToDefault() {
        let service = PreferenceServiceFactory.shared
        service.setValue(TabConfiguration.default.ordered.map(\.rawValue), for: orderPreference)
        service.setValue([], for: hiddenPreference)
        service.setValue([], for: visibilityOverridesPreference)
        NotificationCenter.default.post(name: .tabConfigurationDidChange, object: nil)
    }
}

extension Notification.Name {
    /// Posted when the user reorders or hides a tab, so `TabController` can rebuild the
    /// bar and `MoreViewController` can pick up the matching overflow rows.
    static let tabConfigurationDidChange = Notification.Name("TabConfigurationDidChange")
}
