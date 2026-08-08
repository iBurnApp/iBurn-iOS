//
//  TabController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/14/22.
//  Copyright © 2022 iBurn. All rights reserved.
//

import UIKit

@objc public final class TabController: UITabBarController {

    /// The five roots the app always builds, in canonical order. Kept so the prototype
    /// layouts and the user's tab customization can rearrange them without the app
    /// delegate rebuilding anything.
    private var roots: [UIViewController] = []

    /// One `UITab` per root view controller, for as long as the bar stays in the
    /// `UITab`-based layout. A `UITab` takes ownership of the view controller its provider
    /// returns, so building a *second* tab around a root that an existing tab already owns
    /// raises "UIViewController cannot be shared between multiple UITab" — which is what
    /// every rebuild after the first used to do (hiding a tab from Customize Tabs crashed
    /// the app). Rebuilds reorder these instead of making new ones. Typed `AnyObject`
    /// because stored properties can't carry an availability annotation.
    private var tabCache: [ObjectIdentifier: AnyObject] = [:]
    private var searchTabCache: AnyObject?

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshTheme()
    }

    /// Installs the app's root view controllers and arranges them for the active
    /// prototype layout. Replaces assigning `viewControllers` directly.
    @objc public func configure(withRootViewControllers viewControllers: [UIViewController]) {
        roots = viewControllers
        rebuildTabs()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildTabs),
            name: .mapSearchLayoutDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildTabs),
            name: .tabConfigurationDidChange,
            object: nil
        )
    }

    /// Arranges the roots for the user's tab configuration and the active search layout.
    ///
    /// `.searchTab` trades the Events tab for a `UISearchTab`; every other layout keeps
    /// whichever tabs the user left on the bar. Events is the tab that gives way because
    /// it's the one you go looking for by name — search and the More list both reach it —
    /// whereas Map, Nearby and Favorites are all "what's around me right now" surfaces you
    /// want one tap away. Anything dropped here shows up as a `MoreViewController` row.
    @objc public func rebuildTabs() {
        guard !roots.isEmpty else { return }
        let selectedRoot = selectedViewController
        let previousIdentifier = selectedRoot.flatMap(TabIdentifier.identifier(forRoot:))

        let configuration = TabConfiguration.current
        var arranged = arrangedRoots(for: configuration)
        var usesSearchTab = false

        if MapSearchLayout.current == .searchTab, #available(iOS 26.0, *) {
            usesSearchTab = true
            // A user-hidden Events tab is already gone from `arranged`; displacing it
            // again is a no-op rather than a second removal.
            if let displacedIndex = arranged.firstIndex(where: { TabIdentifier.identifier(forRoot: $0) == .events }) {
                arranged.remove(at: displacedIndex)
            }
            var newTabs: [UITab] = arranged.enumerated().map { index, viewController in
                tab(for: viewController, fallbackIndex: index)
            }
            newTabs.append(searchTab())

            tabs = newTabs
        } else {
            // Clear any tabs left over from a previous `.searchTab` run before falling
            // back to the plain view-controller arrangement. The cache goes with them:
            // the roots are about to be owned by `viewControllers` instead, so the next
            // `.searchTab` build has to wrap them in fresh tabs.
            if #available(iOS 18.0, *) {
                tabs = []
                tabCache.removeAll()
                searchTabCache = nil
            }
            self.viewControllers = arranged
        }

        restoreSelection(
            previousRoot: selectedRoot,
            previousIdentifier: previousIdentifier,
            usesSearchTab: usesSearchTab
        )
    }

    /// The one `UITab` wrapping this root, created on first use. See `tabCache`.
    @available(iOS 18.0, *)
    private func tab(for viewController: UIViewController, fallbackIndex: Int) -> UITab {
        let key = ObjectIdentifier(viewController)
        if let existing = tabCache[key] as? UITab { return existing }
        let tab = UITab(
            title: viewController.tabBarItem.title ?? "",
            image: viewController.tabBarItem.image,
            identifier: TabIdentifier.identifier(forRoot: viewController)?.tabIdentifier ?? "iBurn.tab.\(fallbackIndex)"
        ) { _ in viewController }
        tabCache[key] = tab
        return tab
    }

    /// The search tab, created on first use and reused for the same reason the others are.
    @available(iOS 26.0, *)
    private func searchTab() -> UISearchTab {
        if let existing = searchTabCache as? UISearchTab { return existing }
        let searchTab = UISearchTab { _ in
            GlobalSearchTabFactory.makeSearchTabRoot(dependencies: BRCAppDelegate.shared.dependencies)
        }
        searchTab.automaticallyActivatesSearch = true
        searchTabCache = searchTab
        return searchTab
    }

    /// `roots` reordered and filtered by the user's configuration. Roots this build can't
    /// identify are never dropped — they keep the tail of the bar — so an unrecognized
    /// screen can't disappear with no way back.
    private func arrangedRoots(for configuration: TabConfiguration) -> [UIViewController] {
        var remaining = roots
        var arranged: [UIViewController] = []
        for identifier in configuration.visible {
            guard let index = remaining.firstIndex(where: { TabIdentifier.identifier(forRoot: $0) == identifier }) else { continue }
            arranged.append(remaining.remove(at: index))
        }
        arranged.append(contentsOf: remaining.filter { TabIdentifier.identifier(forRoot: $0) == nil })
        return arranged
    }

    /// Keeps the user on whichever tab they were looking at. Hiding the selected tab (or
    /// switching to `.searchTab`, which drops Events) falls back to the map rather than
    /// leaving the selection on a screen that's no longer on the bar.
    private func restoreSelection(
        previousRoot: UIViewController?,
        previousIdentifier: TabIdentifier?,
        usesSearchTab: Bool
    ) {
        guard let previousRoot else {
            selectMapTab()
            return
        }

        if usesSearchTab, #available(iOS 18.0, *) {
            if let identifier = previousIdentifier,
               let tab = tabs.first(where: { $0.identifier == identifier.tabIdentifier }) {
                selectedTab = tab
                return
            }
            // No identifier means the search tab was selected, and it survives every rebuild.
            if previousIdentifier == nil, let searchTab = tabs.first(where: { $0 is UISearchTab }) {
                selectedTab = searchTab
                return
            }
            selectMapTab()
            return
        }

        if let index = viewControllers?.firstIndex(of: previousRoot) {
            selectedIndex = index
        } else {
            selectMapTab()
        }
    }

    /// Selects the map, wherever the user dragged it. The map can't be hidden, so this
    /// always lands somewhere sensible; deep links use it instead of assuming index 0.
    @objc public func selectMapTab() {
        if #available(iOS 18.0, *), !tabs.isEmpty {
            if let mapTab = tabs.first(where: { $0.identifier == TabIdentifier.map.tabIdentifier }) {
                selectedTab = mapTab
                return
            }
        }
        if let index = viewControllers?.firstIndex(where: { TabIdentifier.identifier(forRoot: $0) == .map }) {
            selectedIndex = index
        } else if viewControllers?.isEmpty == false {
            selectedIndex = 0
        }
    }

    /// Whether a tab is off the bar and therefore needs a `MoreViewController` row: either
    /// the user hid it, or the search tab took its slot. Static because More is rebuilt
    /// independently of this instance.
    static func isDisplacedFromTabBar(_ identifier: TabIdentifier) -> Bool {
        if TabConfiguration.current.isHidden(identifier) { return true }
        guard identifier == .events else { return false }
        guard MapSearchLayout.current == .searchTab else { return false }
        if #available(iOS 26.0, *) { return true }
        return false
    }

    static var eventsIsDisplacedFromTabBar: Bool {
        isDisplacedFromTabBar(.events)
    }
}

extension TabController {
    func refreshTheme() {
        viewControllers?.forEach {
            $0.refreshNavigationBarColors(false)
            $0.setColorTheme(Appearance.currentColors, animated: false)

        }
        tabBar.setColorTheme(Appearance.currentColors, animated: false)
        refreshGlobalTheme()
        Appearance.setGlobalAppearance()
    }
}

extension TabController: ThemeRefreshable {}
