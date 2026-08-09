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

    /// The floating heart that stands in for the Favorites tab under the `.searchTab`
    /// layout. Lives on the tab bar controller's own view rather than any child, so it is
    /// there on every tab, and is created lazily — layouts that keep Favorites on the bar
    /// never build it.
    private lazy var favoritesButton: FavoritesFloatingButton = {
        let button = FavoritesFloatingButton { [weak self] in
            self?.presentFavorites()
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private var favoritesButtonInstalled = false

    /// Whether the search field has taken the tab bar's place. Set from the search tab
    /// root's search controller, which is the only thing that reports the transition.
    private var searchIsActive = false {
        didSet {
            guard searchIsActive != oldValue else { return }
            updateFavoritesButtonVisibility()
        }
    }

    /// The button only if it has actually been built, so theme refreshes don't bring one
    /// into existence on a layout that doesn't want it.
    private var favoritesButtonIfInstalled: FavoritesFloatingButton? {
        favoritesButtonInstalled ? favoritesButton : nil
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshTheme()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Catches the bar moving off screen, which nothing announces. Search activation
        // does *not* re-lay out this view — that arrives via `searchIsActive` instead.
        updateFavoritesButtonVisibility()
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
    /// Which tabs are on the bar is `TabConfiguration.current`'s decision alone —
    /// including the Favorites tab the `.searchTab` layout takes away by default, which is
    /// folded into that configuration (see `TabConfiguration.layoutHiddenByDefault`) so a
    /// user who drags Favorites back onto the bar actually gets it. All this adds on top is
    /// the `UISearchTab` itself and the floating Favorites button that replaces the tab.
    /// Anything off the bar also shows up as a `MoreViewController` row.
    @objc public func rebuildTabs() {
        guard !roots.isEmpty else { return }
        let selectedRoot = selectedViewController
        let previousIdentifier = selectedRoot.flatMap(TabIdentifier.identifier(forRoot:))

        let configuration = TabConfiguration.current
        // `current` already clamps to capacity; the prefix is a last-resort guard so a
        // future bug can cost an unrecognized trailing root, but never put UIKit's
        // native More overflow (`•••`) on the bar next to the app's own More tab.
        let arranged = Array(arrangedRoots(for: configuration).prefix(TabConfiguration.visibleCapacity))
        var usesSearchTab = false

        if MapSearchLayout.current == .searchTab, #available(iOS 26.0, *) {
            usesSearchTab = true
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
        updateFavoritesButton()
    }

    // MARK: - Floating Favorites button

    /// Adds the button on first need and re-applies the visibility rule. Called from every
    /// rebuild, which covers both notifications that can change the answer: the layout
    /// switch and the user's tab customization.
    private func updateFavoritesButton() {
        guard FavoritesFABVisibility.isVisible else {
            if favoritesButtonInstalled { favoritesButton.isHidden = true }
            return
        }
        installFavoritesButtonIfNeeded()
        updateFavoritesButtonVisibility()
    }

    private func installFavoritesButtonIfNeeded() {
        guard !favoritesButtonInstalled else { return }
        favoritesButtonInstalled = true
        view.addSubview(favoritesButton)
        NSLayoutConstraint.activate([
            favoritesButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            // Anchored to the bar itself rather than the safe area: the iOS 26 tab bar
            // floats, and pinning to its top keeps the same gap whether or not an
            // accessory is installed, and follows the bar when it slides away.
            //
            // The gap is 36 rather than a snug 12 because the map — the tab this button
            // spends most of its life over — parks MapLibre's attribution ⓘ in exactly
            // this corner, and that button has to stay tappable.
            favoritesButton.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -36),
        ])
    }

    /// The button rides above the tab bar, so it is only ever on screen when the bar is:
    /// activating search replaces the bar with a search field that then follows the
    /// keyboard up the screen, and anything that hides the bar moves it off the bottom
    /// edge.
    private func updateFavoritesButtonVisibility() {
        guard favoritesButtonInstalled else { return }
        guard FavoritesFABVisibility.isVisible, !searchIsActive else {
            favoritesButton.isHidden = true
            return
        }
        favoritesButton.isHidden = tabBar.isHidden
            || tabBar.alpha == 0
            || tabBar.frame.minY >= view.bounds.height
    }

    /// Favorites as a sheet, built from the same factory the tab and the More row use so
    /// all three paths land on one screen. `.large` only — it's a full list with search,
    /// and detail pushes happen inside the sheet's own navigation controller.
    @objc public func presentFavorites() {
        guard presentedViewController == nil else { return }
        let favoritesVC = BRCAppDelegate.shared.createFavoritesViewController()
        favoritesVC.title = "Favorites"
        let navigationController = NavigationController(rootViewController: favoritesVC)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
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
        let searchTab = UISearchTab { [weak self] _ in
            GlobalSearchTabFactory.makeSearchTabRoot(
                dependencies: BRCAppDelegate.shared.dependencies,
                searchActivationDidChange: { [weak self] isActive in
                    self?.searchIsActive = isActive
                }
            )
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
    /// switching to `.searchTab`, which drops Favorites by default) falls back to the map
    /// rather than leaving the selection on a screen that's no longer on the bar.
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

    /// Whether a tab is off the bar and therefore needs a `MoreViewController` row.
    ///
    /// One question, one answer: the effective configuration already accounts for both
    /// reasons a tab can be missing (the user hid it, or the active search layout hides it
    /// by default), so More can't disagree with the bar in any combination. Static because
    /// More is rebuilt independently of this instance.
    static func isDisplacedFromTabBar(_ identifier: TabIdentifier) -> Bool {
        !TabConfiguration.current.visible.contains(identifier)
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
        favoritesButtonIfInstalled?.applyTheme()
        refreshGlobalTheme()
        Appearance.setGlobalAppearance()
    }
}

extension TabController: ThemeRefreshable {}
