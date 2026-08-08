//
//  TabController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/14/22.
//  Copyright © 2022 iBurn. All rights reserved.
//

import UIKit

@objc public final class TabController: UITabBarController {

    /// The five roots the app always builds, in tab-bar order. Kept so the prototype
    /// layouts can rearrange them without the app delegate rebuilding anything.
    private var roots: [UIViewController] = []

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshTheme()
    }

    /// Installs the app's root view controllers and arranges them for the active
    /// prototype layout. Replaces assigning `viewControllers` directly.
    @objc public func configure(withRootViewControllers viewControllers: [UIViewController]) {
        roots = viewControllers
        applySearchLayout()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applySearchLayout),
            name: .mapSearchLayoutDidChange,
            object: nil
        )
    }

    /// `.searchTab` trades the Events tab for a `UISearchTab`; every other layout keeps
    /// the plain five-tab arrangement. Events is the tab that gives way because it's the
    /// one you go looking for by name — search and the More list both reach it — whereas
    /// Map, Nearby and Favorites are all "what's around me right now" surfaces you want
    /// one tap away. `MoreViewController` grows an Events row to match.
    @objc public func applySearchLayout() {
        guard !roots.isEmpty else { return }
        let selectedRoot = selectedViewController

        if MapSearchLayout.current == .searchTab, #available(iOS 26.0, *) {
            var carried = roots
            if let displacedIndex = displacedRootIndex {
                carried.remove(at: displacedIndex)
            }
            var newTabs: [UITab] = carried.enumerated().map { index, viewController in
                UITab(
                    title: viewController.tabBarItem.title ?? "",
                    image: viewController.tabBarItem.image,
                    identifier: "iBurn.tab.\(index)"
                ) { _ in viewController }
            }

            let searchTab = UISearchTab { _ in
                GlobalSearchTabFactory.makeSearchTabRoot(dependencies: BRCAppDelegate.shared.dependencies)
            }
            searchTab.automaticallyActivatesSearch = true
            newTabs.append(searchTab)

            tabs = newTabs
        } else {
            // Clear any tabs left over from a previous `.searchTab` run before falling
            // back to the plain view-controller arrangement.
            if #available(iOS 18.0, *) {
                tabs = []
            }
            self.viewControllers = roots
        }

        // Keep the user on whichever tab they were looking at. Switching to `.searchTab`
        // drops the Events tab, so anyone standing on it falls back to the map rather
        // than being dumped into the search field.
        if let selectedRoot, let index = self.viewControllers?.firstIndex(of: selectedRoot) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
    }

    /// Position of the root the search tab displaces. Matched by type rather than index so
    /// reordering the tabs in `BRCAppDelegate.setupDefaultTabBarController` can't silently
    /// drop the wrong one; both the SwiftUI and legacy Events screens are recognized.
    private var displacedRootIndex: Int? {
        roots.firstIndex { root in
            let leaf = (root as? UINavigationController)?.viewControllers.first ?? root
            return leaf is EventListHostingController || leaf is EventListViewController
        }
    }

    /// Whether the search tab has taken the Events slot, so `MoreViewController` knows to
    /// offer Events itself. Static because More is rebuilt independently of this instance.
    static var eventsIsDisplacedFromTabBar: Bool {
        guard MapSearchLayout.current == .searchTab else { return false }
        if #available(iOS 26.0, *) { return true }
        return false
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
