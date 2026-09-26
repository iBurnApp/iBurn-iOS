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

    /// One `UITab` per root view controller, kept for this controller's lifetime — across
    /// switches to the plain `viewControllers` layout and back, too. A `UITab` takes ownership of the view controller its provider
    /// returns, so building a *second* tab around a root that an existing tab already owns
    /// raises "UIViewController cannot be shared between multiple UITab" — which is what
    /// every rebuild after the first used to do (hiding a tab from Customize Tabs crashed
    /// the app). Rebuilds reorder these instead of making new ones.
    private var tabCache: [ObjectIdentifier: UITab] = [:]
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

    /// Vertical placement. Rebuilt whenever the tab bar moves between hierarchies or edges
    /// (iPad's floating top bar, rotation, size-class changes), because the constraint's
    /// partner view differs per placement — see `FloatingActionButtonPlacement`.
    private var floatingButtonBottom: NSLayoutConstraint?
    private var floatingButtonPlacement: FloatingActionButtonPlacement?

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

    public override func viewDidLoad() {
        super.viewDidLoad()
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingColorAppearance) { (self: Self, _: UITraitCollection) in
            self.refreshTheme()
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Catches the bar moving off screen, which nothing announces. Search activation
        // does *not* re-lay out this view — that arrives via `searchIsActive` instead.
        // The placement check rides along because the same pass is where a rotation or a
        // size-class change has just moved the bar between hierarchies.
        updateFloatingButtonPlacement()
        updateFloatingButtonVisibility()
        alignFloatingButtonWithSearchTab()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The button is installed from `configure(withRootViewControllers:)`, which the app
        // delegate calls *before* the window has a root view controller — everything measures
        // as zero there. This is the guaranteed pass with real geometry: whatever an early,
        // geometry-less pass decided, it gets re-decided here.
        view.setNeedsLayout()
        updateFloatingButtonPlacement()
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
        let wasUsingSearchTab = self.usesSearchTab

        let configuration = TabConfiguration.current
        // `current` already clamps to capacity; the prefix is a last-resort guard so a
        // future bug can cost an unrecognized trailing root, but never put UIKit's
        // native More overflow (`•••`) on the bar next to the app's own More tab.
        let arranged = Array(arrangedRoots(for: configuration).prefix(TabConfiguration.visibleCapacity))
        var usesSearchTab = false
        defer { self.usesSearchTab = usesSearchTab }

        // Whether UIKit was handed a new arrangement. Reassigning `tabs` or
        // `viewControllers` resets the bar's highlight while UIKit can keep the old
        // selected controller, so the selection has to be re-applied as a real change
        // afterwards (see `applySelection`). An unchanged arrangement is left alone
        // entirely — switching between the two classic layouts (Top ↔ Bottom accessory)
        // changes nothing on the bar.
        let didReassign: Bool
        if MapSearchLayout.current == .searchTab, #available(iOS 26.0, *) {
            usesSearchTab = true
            var newTabs: [UITab] = arranged.enumerated().map { index, viewController in
                tab(for: viewController, fallbackIndex: index)
            }
            newTabs.append(searchTab())

            didReassign = !wasUsingSearchTab || !tabs.elementsEqual(newTabs, by: ===)
            if didReassign {
                tabs = newTabs
            }
        } else {
            // Clear the tabs left over from a previous `.searchTab` run before falling
            // back to the plain view-controller arrangement. The cache deliberately
            // survives: a root stays bound to the first `UITab` that wrapped it even after
            // `tabs` is emptied and `viewControllers` takes it over, so switching back to
            // `.searchTab` must hand UIKit that same tab again. Wrapping the root in a
            // fresh tab there raised "UIViewController cannot be shared between multiple
            // UITab" (toggling the layout in Feature Flags crashed).
            if wasUsingSearchTab {
                tabs = []
            }
            let current = self.viewControllers ?? []
            didReassign = wasUsingSearchTab || !current.elementsEqual(arranged, by: ===)
            if didReassign {
                self.viewControllers = arranged
            }
        }

        restoreSelection(
            previousRoot: selectedRoot,
            usesSearchTab: usesSearchTab,
            // First configure has nothing to preserve and no stale highlight to fix.
            forceTransition: didReassign && selectedRoot != nil
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
        NSLayoutConstraint.activate([centerX])
        updateFloatingButtonPlacement()
    }

    /// Picks the vertical anchor that is legal *right now* and swaps the constraint if the
    /// answer changed.
    ///
    /// On iPhone the bar is a bottom-docked subview of this controller's view, so the button
    /// hangs off `tabBar.topAnchor` exactly as it always has — same gap, same pixel position,
    /// and it still follows the bar when the map slides it away. On iPad with iOS 26 the bar
    /// is a floating top bar living outside this view, where that constraint has no common
    /// ancestor and throws; there the button hangs off the view's own bottom safe area
    /// instead. Re-evaluated on every layout pass so rotation or a size-class change that
    /// moves the bar between those two worlds re-anchors rather than re-crashing.
    private func updateFloatingButtonPlacement() {
        guard floatingButtonInstalled else { return }
        // Before the window exists every frame is `.zero`, so "is the bar in the lower half"
        // answers no and the safe-area fallback would be committed as if it had been measured.
        // The button still needs *a* vertical constraint before the first layout pass, so take
        // the always-legal one — but don't record it, so the first pass that can measure
        // re-decides instead of finding a cached answer that matches.
        guard geometryIsKnown else {
            if floatingButtonBottom == nil { applyPlacement(.bottomSafeArea, record: false) }
            return
        }
        let placement = FloatingActionButtonPlacement.placement(
            tabBarIsInHierarchy: tabBarIsInHierarchy,
            tabBarIsDockedAtBottom: tabBarIsDockedAtBottom
        )
        guard placement != floatingButtonPlacement else { return }
        applyPlacement(placement, record: true)
    }

    /// Whether this view has been laid out in a window yet — i.e. whether measuring it means
    /// anything at all. See `FloatingActionButtonBarVisibility`.
    private var geometryIsKnown: Bool {
        view.window != nil && view.bounds.height > 0
    }

    private func applyPlacement(_ placement: FloatingActionButtonPlacement, record: Bool) {
        floatingButtonPlacement = record ? placement : nil

        floatingButtonBottom?.isActive = false
        let bottom: NSLayoutConstraint
        switch placement {
        case .aboveTabBar:
            bottom = floatingButton.bottomAnchor.constraint(
                equalTo: tabBar.topAnchor,
                constant: -FloatingActionButton.barGap
            )
        case .bottomSafeArea:
            bottom = floatingButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -FloatingActionButton.barGap
            )
        }
        floatingButtonBottom = bottom
        bottom.isActive = true
    }

    /// Whether the tab bar is a descendant of this controller's view — the only case in which
    /// it can legally take part in a constraint with the button.
    private var tabBarIsInHierarchy: Bool {
        tabBar.isDescendant(of: view)
    }

    /// Whether the bar sits in the lower half of the view, i.e. the button belongs above it.
    /// Measured rather than inferred from idiom so an unfamiliar bar layout degrades to the
    /// safe-area placement instead of guessing.
    private var tabBarIsDockedAtBottom: Bool {
        guard tabBarIsInHierarchy, let barFrame = tabBarFrameInView else { return false }
        return barFrame.midY > view.bounds.midY
    }

    /// The bar's frame in `view` coordinates, or nil when the two aren't in the same window
    /// and no meaningful conversion exists.
    private var tabBarFrameInView: CGRect? {
        guard let superview = tabBar.superview else { return nil }
        guard superview === view || (tabBar.window != nil && tabBar.window === view.window) else { return nil }
        return superview.convert(tabBar.frame, to: view)
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
        // Only meaningful when the button is stacked on the bar. A floating top bar puts the
        // search circle nowhere near the button's row, so its x is not a placement the button
        // should chase — it keeps the trailing inset instead.
        guard floatingButtonPlacement == .aboveTabBar else { return }
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
        let knownGeometry = geometryIsKnown
        floatingButton.isHidden = FloatingActionButtonBarVisibility.isHidden(
            tabBarHidden: tabBar.isHidden,
            tabBarAlpha: tabBar.alpha,
            barFrameMinY: knownGeometry ? tabBarFrameInView?.minY : nil,
            viewHeight: knownGeometry ? view.bounds.height : 0
        )
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
    private func tab(for viewController: UIViewController, fallbackIndex: Int) -> UITab {
        let key = ObjectIdentifier(viewController)
        if let existing = tabCache[key] { return existing }
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
    ///
    /// The previous root is matched by identity — through `tabCache` in `UITab` mode and
    /// `viewControllers` in classic mode — so a root this build can't identify survives a
    /// rebuild too. A previous root that isn't one of `roots` can only be the search
    /// tab's, and the search tab survives every `UITab` rebuild.
    private func restoreSelection(
        previousRoot: UIViewController?,
        usesSearchTab: Bool,
        forceTransition: Bool
    ) {
        if usesSearchTab {
            let target: UITab? = previousRoot.flatMap { root in
                if let tab = tabCache[ObjectIdentifier(root)], tabs.contains(where: { $0 === tab }) {
                    return tab
                }
                if !roots.contains(where: { $0 === root }) {
                    return tabs.first { $0 is UISearchTab }
                }
                return nil
            } ?? mapTab
            guard let target else { return }
            applySelection(tab: target, forceTransition: forceTransition)
            return
        }

        let target = previousRoot.flatMap { viewControllers?.firstIndex(of: $0) } ?? mapIndex
        guard let target else { return }
        applySelection(index: target, forceTransition: forceTransition)
    }

    /// The map's `UITab`, when the bar is running on tabs.
    private var mapTab: UITab? {
        tabs.first { $0.identifier == TabIdentifier.map.tabIdentifier }
    }

    /// The map's index in `viewControllers`, falling back to the first tab.
    private var mapIndex: Int? {
        guard let viewControllers, !viewControllers.isEmpty else { return nil }
        return viewControllers.firstIndex { TabIdentifier.identifier(forRoot: $0) == .map } ?? 0
    }

    /// Selects `target` in `UITab` mode. After `tabs` was reassigned, UIKit can report the
    /// old tab as still selected while the bar highlights another (or nothing), and setting
    /// `selectedTab` to the value it already reports is a no-op — so in that case the
    /// selection bounces through another tab first, which makes it a real change that
    /// the bar follows. The bounce never goes through the search tab, which would
    /// activate search.
    private func applySelection(tab target: UITab, forceTransition: Bool) {
        if forceTransition, selectedTab === target,
           let other = tabs.first(where: { $0 !== target && !($0 is UISearchTab) }) {
            UIView.performWithoutAnimation {
                selectedTab = other
            }
        }
        selectedTab = target
    }

    /// Selects `index` in classic `viewControllers` mode. Same bounce as the `UITab`
    /// variant: reassigning `viewControllers` can leave `selectedIndex` already reporting
    /// the target while the bar highlights the first item.
    private func applySelection(index target: Int, forceTransition: Bool) {
        let count = viewControllers?.count ?? 0
        guard target < count else { return }
        if forceTransition, selectedIndex == target, let other = (0..<count).first(where: { $0 != target }) {
            UIView.performWithoutAnimation {
                selectedIndex = other
            }
        }
        selectedIndex = target
    }

    /// Selects the map, wherever the user dragged it. The map can't be hidden, so this
    /// always lands somewhere sensible; deep links use it instead of assuming index 0.
    @objc public func selectMapTab() {
        if !tabs.isEmpty, let mapTab {
            selectedTab = mapTab
            return
        }
        if let mapIndex {
            selectedIndex = mapIndex
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
