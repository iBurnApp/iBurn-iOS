//
//  TabController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/14/22.
//  Copyright © 2022 iBurn. All rights reserved.
//

import PlayaDB
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

    /// Which of the two tab systems the last rebuild left the bar on. A tap arrives through
    /// a different delegate callback in each, and both callbacks exist on this one object,
    /// so this is what keeps a single tap from being handled twice.
    private var usesSearchTab = false

    /// The floating button that stands in for the tab the `.searchTab` layout takes away.
    /// Lives on the tab bar controller's own view rather than any child, so it is there on
    /// every tab, and is created lazily — layouts that keep the tab on the bar never build
    /// it.
    private lazy var floatingButton: FloatingActionButton = {
        let button = FloatingActionButton { [weak self] in
            self?.presentFloatingAction()
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private var floatingButtonInstalled = false

    /// Horizontal placement, driven by `alignFloatingButtonWithSearchTab()`: the button
    /// stacks directly above the detached search circle, so the constant is whatever the
    /// bar puts that circle at. Kept as a leading-edge offset because the trailing inset
    /// alone can't express "centered on something UIKit positions".
    private var floatingButtonCenterX: NSLayoutConstraint?

    /// Whether the search field has taken the tab bar's place. Set from the search tab
    /// root's search controller, which is the only thing that reports the transition.
    private var searchIsActive = false {
        didSet {
            guard searchIsActive != oldValue else { return }
            updateFloatingButtonVisibility()
        }
    }

    /// The button only if it has actually been built, so theme refreshes don't bring one
    /// into existence on a layout that doesn't want it.
    private var floatingButtonIfInstalled: FloatingActionButton? {
        floatingButtonInstalled ? floatingButton : nil
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshTheme()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Catches the bar moving off screen, which nothing announces. Search activation
        // does *not* re-lay out this view — that arrives via `searchIsActive` instead.
        updateFloatingButtonVisibility()
        alignFloatingButtonWithSearchTab()
    }

    /// Installs the app's root view controllers and arranges them for the active
    /// prototype layout. Replaces assigning `viewControllers` directly.
    @objc public func configure(withRootViewControllers viewControllers: [UIViewController]) {
        roots = viewControllers
        // Re-tap handling lives here rather than in the app delegate: it needs to know which
        // tab system the bar is currently running, which is this object's business alone.
        delegate = self
        rebuildTabs()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(favoriteDidChange(_:)),
            name: .playaDBFavoriteDidChange,
            object: nil
        )
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFloatingButton),
            name: .floatingActionButtonDidChange,
            object: nil
        )
    }

    /// Arranges the roots for the user's tab configuration and the active search layout.
    ///
    /// Which tabs are on the bar is `TabConfiguration.current`'s decision alone —
    /// including the Favorites tab the `.searchTab` layout takes away by default, which is
    /// folded into that configuration (see `TabConfiguration.layoutHiddenByDefault`) so a
    /// user who drags Favorites back onto the bar actually gets it. All this adds on top is
    /// the `UISearchTab` itself and the floating button that replaces the tab.
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
        defer { self.usesSearchTab = usesSearchTab }

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
        updateFloatingButton()
    }

    // MARK: - Floating action button

    /// Adds the button on first need, points it at the chosen screen, and re-applies the
    /// visibility rule. Called from every rebuild plus the floating-button notification,
    /// which together cover everything that can change the answer: the layout switch, the
    /// user's tab customization, and the button's own settings.
    @objc private func updateFloatingButton() {
        guard FloatingActionButtonVisibility.isVisible else {
            if floatingButtonInstalled { floatingButton.isHidden = true }
            return
        }
        installFloatingButtonIfNeeded()
        floatingButton.configure(for: FloatingActionButtonSettings.action)
        updateFloatingButtonVisibility()
        alignFloatingButtonWithSearchTab()
    }

    private func installFloatingButtonIfNeeded() {
        guard !floatingButtonInstalled else { return }
        floatingButtonInstalled = true
        view.addSubview(floatingButton)
        // Starts on the trailing inset — the same corner the button used before it learned
        // to find the search circle — so a bar that never reports a circle still puts the
        // button somewhere sensible. `alignFloatingButtonWithSearchTab()` takes over on the
        // first layout pass that can measure one.
        let centerX = floatingButton.centerXAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -(FloatingActionButton.trailingInset + FloatingActionButton.diameter / 2)
        )
        floatingButtonCenterX = centerX
        NSLayoutConstraint.activate([
            centerX,
            // Anchored to the bar itself rather than the safe area: the iOS 26 tab bar
            // floats, and pinning to its top keeps the same gap whether or not an
            // accessory is installed, and follows the bar when it slides away.
            floatingButton.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -FloatingActionButton.barGap),
        ])
    }

    /// Centers the button on the detached search circle at the trailing end of the bar.
    ///
    /// The circle is UIKit's, positioned by the bar's own metrics, and there is no public
    /// API for its frame — so this measures rather than assumes: it looks through the tab
    /// bar's view tree for the trailing-most round item and centers on it. Nothing here
    /// depends on private symbols or view-class names; if the search circle ever stops
    /// matching (a new bar layout, an accessory, a regular-width bar), no candidate is
    /// found and the button keeps the trailing inset it was installed with.
    private func alignFloatingButtonWithSearchTab() {
        guard floatingButtonInstalled, let centerX = floatingButtonCenterX else { return }
        guard let measured = searchTabCenterX() else { return }
        let target = measured - view.safeAreaLayoutGuide.layoutFrame.maxX
        // A layout pass writing a constraint constant re-enters layout, so only a real
        // move counts — otherwise the two would trade sub-point corrections forever.
        guard abs(centerX.constant - target) > 0.5 else { return }
        centerX.constant = target
        view.layoutIfNeeded()
    }

    /// Center of the trailing-most circular item in the tab bar, in `view` coordinates.
    ///
    /// "Circular item" is the whole test: square bounds in the size range UIKit uses for a
    /// bar item, sitting in the trailing quarter of the bar. On the `.searchTab` layout
    /// that is the search circle, which the bar draws detached from the pill holding the
    /// other tabs.
    private func searchTabCenterX() -> CGFloat? {
        guard TabConfiguration.searchTabOccupiesBarSlot else { return nil }
        // Layout runs top-down: by the time this controller hears `viewDidLayoutSubviews`
        // the bar has a frame but its own subtree hasn't been positioned yet, so measuring
        // it now reads a pile of zero rects. Forcing the bar to settle first is what makes
        // the measurement real — without it the button silently keeps its fallback inset.
        tabBar.layoutIfNeeded()
        let barBounds = tabBar.bounds
        guard barBounds.width > 0 else { return nil }
        let trailingRegion = barBounds.maxX - barBounds.width / 4

        var best: CGRect?
        func visit(_ parent: UIView) {
            for subview in parent.subviews {
                let frame = parent.convert(subview.frame, to: tabBar)
                let isRoundItem = frame.width >= 36 && frame.width <= 80 && abs(frame.width - frame.height) <= 10
                if isRoundItem, frame.midX > trailingRegion, frame.midX > (best?.midX ?? -.greatestFiniteMagnitude) {
                    best = frame
                }
                visit(subview)
            }
        }
        visit(tabBar)

        guard let best else { return nil }
        return tabBar.convert(CGPoint(x: best.midX, y: best.midY), to: view).x
    }

    /// The button rides above the tab bar, so it is only ever on screen when the bar is:
    /// activating search replaces the bar with a search field that then follows the
    /// keyboard up the screen, and anything that hides the bar moves it off the bottom
    /// edge.
    private func updateFloatingButtonVisibility() {
        guard floatingButtonInstalled else { return }
        guard FloatingActionButtonVisibility.isVisible, !searchIsActive else {
            floatingButton.isHidden = true
            return
        }
        floatingButton.isHidden = tabBar.isHidden
            || tabBar.alpha == 0
            || tabBar.frame.minY >= view.bounds.height
    }

    /// The chosen screen as a sheet, built from the same factory the tab and the More row
    /// use so all three paths land on one screen. `.large` only — these are full lists with
    /// search, and detail pushes happen inside the sheet's own navigation controller.
    @objc public func presentFloatingAction() {
        guard presentedViewController == nil else { return }
        let viewController = FloatingActionButtonSettings.action.makeViewController()
        let navigationController = NavigationController(rootViewController: viewController)
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

    // MARK: - Map tab re-tap

    /// The map tab's root, found the same way everything else here identifies a tab: by what
    /// the root's leaf view controller is, not by a position that reordering invalidates.
    private var mapRoot: UIViewController? {
        roots.first { TabIdentifier.identifier(forRoot: $0) == .map }
    }

    private var mapNavigationController: UINavigationController? {
        mapRoot as? UINavigationController
    }

    private var mapViewController: MainMapViewController? {
        mapNavigationController?.viewControllers.first as? MainMapViewController
            ?? mapRoot as? MainMapViewController
    }

    /// Runs `MapTabReselection`'s verdict. Both delegate callbacks funnel here so the two tab
    /// systems can't drift apart in behavior.
    private func handleTabSelection(candidate: TabIdentifier?, isAlreadySelected: Bool) {
        guard let navigationController = mapNavigationController else { return }
        let outcome = MapTabReselection.outcome(
            selected: candidate,
            isAlreadySelected: isAlreadySelected,
            navigationStackDepth: navigationController.viewControllers.count
        )
        switch outcome {
        case .ignore:
            break
        case .popToRoot:
            navigationController.popToRootViewController(animated: true)
        case .recenter:
            mapViewController?.centerMapAtManCoordinatesAnimated(true)
        }
    }

    // MARK: - Favorite glow

    /// Favoriting anything anywhere makes the floating button glow, when the button is the
    /// door to Favorites and is actually on screen. See `FloatingActionButtonGlow`.
    @objc private func favoriteDidChange(_ notification: Notification) {
        guard floatingButtonInstalled,
              let isFavorite = PlayaDBFavoriteChange.isFavorite(from: notification) else { return }
        let onScreen = FloatingActionButtonVisibility.isVisible && !floatingButton.isHidden
        guard FloatingActionButtonGlow.shouldGlow(
            isVisible: onScreen,
            action: FloatingActionButtonSettings.action,
            favoriteWasAdded: isFavorite
        ) else { return }
        floatingButton.playFavoriteAddedGlow()
    }
}

// MARK: - UITabBarControllerDelegate

extension TabController: UITabBarControllerDelegate {

    /// Classic `viewControllers` mode: everything below iOS 26, and every layout that keeps
    /// search off the bar. Re-tap is "the tap is asking for the tab that's already selected".
    public func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        guard !usesSearchTab else { return true }
        handleTabSelection(
            candidate: TabIdentifier.identifier(forRoot: viewController),
            isAlreadySelected: viewController === selectedViewController
        )
        return true
    }

    /// `UITab` mode (the iOS 26 search-tab layout). `shouldSelectTab` rather than
    /// `didSelectTab:previousTab:` because only the former is guaranteed to be asked when the
    /// tap doesn't change the selection — which is the entire case being handled.
    @available(iOS 18.0, *)
    public func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        guard usesSearchTab else { return true }
        handleTabSelection(
            candidate: TabIdentifier.identifier(forTabIdentifier: tab.identifier),
            isAlreadySelected: tab === selectedTab
        )
        return true
    }
}

extension TabController {
    func refreshTheme() {
        viewControllers?.forEach {
            $0.refreshNavigationBarColors(false)
            $0.setColorTheme(Appearance.currentColors, animated: false)

        }
        tabBar.setColorTheme(Appearance.currentColors, animated: false)
        floatingButtonIfInstalled?.applyTheme()
        refreshGlobalTheme()
        Appearance.setGlobalAppearance()
    }
}

extension TabController: ThemeRefreshable {}
