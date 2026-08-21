//
//  FloatingActionButton.swift
//  iBurn
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  The floating button above the tab bar. On the iOS 26 `.searchTab` layout the search
//  tab eats a bar slot, and Favorites gives that slot up (see
//  `TabConfiguration.layoutHiddenByDefault`) in exchange for this — a circular glass
//  button pinned above the search circle that presents a list as a sheet from whatever
//  tab you're on. Which list it opens is the user's choice (see
//  `FloatingActionButtonSettings`); Favorites is only the default.
//

import UIKit

/// What the floating button opens. Raw values are persisted, so they must never change.
enum FloatingActionButtonAction: String, CaseIterable, Identifiable {
    case favorites
    case events
    case nearby

    var id: String { rawValue }

    /// The tab this action duplicates. One entry point, never two: the button hides
    /// whenever this tab is on the bar.
    var tab: TabIdentifier {
        switch self {
        case .favorites: return .favorites
        case .events: return .events
        case .nearby: return .nearby
        }
    }

    var title: String { tab.title }

    /// Outline SF Symbol echoing the tab's own icon (`TabIdentifier.imageName`). Outline
    /// rather than filled: the button is a glass circle sitting on live content, and the
    /// lighter stroke reads as chrome instead of as a selected state.
    var symbolName: String {
        switch self {
        case .favorites: return "heart"
        case .events: return "calendar"
        // The compass rose, which is what `BRCCompassIcon` draws on the Nearby tab.
        // `location` would be the obvious pick but renders the same arrow the map's
        // tracking button already uses, two of which on one screen mean different things.
        case .nearby: return "safari"
        }
    }

    /// The same screen the tab and the More row build, so all three paths land on one list.
    @MainActor
    func makeViewController() -> UIViewController {
        let viewController: UIViewController
        switch self {
        case .favorites: viewController = BRCAppDelegate.shared.createFavoritesViewController()
        case .events: viewController = BRCAppDelegate.shared.createEventsViewController()
        case .nearby: viewController = BRCAppDelegate.shared.createNearbyViewController()
        }
        viewController.title = title
        return viewController
    }
}

/// The user's floating-button settings, stored as preferences and announced on write so
/// the live button can follow an edit made in Customize Tabs without a screen change.
enum FloatingActionButtonSettings {
    static var isEnabled: Bool {
        get { PreferenceServiceFactory.shared.getValue(Preferences.UserInterface.floatingButtonEnabled) }
        set {
            guard newValue != isEnabled else { return }
            PreferenceServiceFactory.shared.setValue(newValue, for: Preferences.UserInterface.floatingButtonEnabled)
            NotificationCenter.default.post(name: .floatingActionButtonDidChange, object: nil)
        }
    }

    /// Falls back to Favorites for anything unrecognized — a downgrade, or a hand-edited
    /// defaults plist, shouldn't leave the button pointing at nothing.
    static var action: FloatingActionButtonAction {
        get {
            let raw = PreferenceServiceFactory.shared.getValue(Preferences.UserInterface.floatingButtonAction)
            return FloatingActionButtonAction(rawValue: raw) ?? .favorites
        }
        set {
            guard newValue != action else { return }
            PreferenceServiceFactory.shared.setValue(newValue.rawValue, for: Preferences.UserInterface.floatingButtonAction)
            NotificationCenter.default.post(name: .floatingActionButtonDidChange, object: nil)
        }
    }
}

/// When the floating button belongs on screen.
///
/// Three conditions, kept as a pure function so the rule can be tested without a window:
/// the layout has to be the one that spends a bar slot on search, the user has to want the
/// button at all, and the screen it opens has to actually be off the bar. A user who drags
/// that screen's tab back on via Customize Tabs keeps the tab and loses the button — one
/// entry point, never two.
enum FloatingActionButtonVisibility {
    static func isVisible(searchTabActive: Bool, enabled: Bool, actionDisplaced: Bool) -> Bool {
        searchTabActive && enabled && actionDisplaced
    }

    /// The rule against the live configuration.
    @MainActor
    static var isVisible: Bool {
        isVisible(
            searchTabActive: TabConfiguration.searchTabOccupiesBarSlot,
            enabled: FloatingActionButtonSettings.isEnabled,
            actionDisplaced: TabController.isDisplacedFromTabBar(FloatingActionButtonSettings.action.tab)
        )
    }
}

/// Whether the tab bar's current state says the button has to go away.
///
/// The button rides above the bar, so it follows the bar off screen — but only when the
/// measurement means something. `configure(withRootViewControllers:)` runs before the window
/// is assigned a root view controller, and at that moment every frame is `.zero`: the bar's
/// `minY` (0) is `>=` the view's height (0), which reads as "the bar has slid off the bottom"
/// and hid the button. Normally the first real layout pass corrected that invisibly; on a slow
/// launch, mid tab-bar animation, no further pass arrived and the button stayed missing on the
/// first tab until the user switched tabs.
///
/// So a view with no geometry yet is "unknown", not "off screen": the frame test is skipped and
/// the button is left visible, pending a layout pass that can actually measure. `isHidden` and
/// `alpha` are not measurements — they're states the bar was explicitly put into — so they
/// still hide the button whatever the geometry says.
enum FloatingActionButtonBarVisibility {
    /// - Parameters:
    ///   - barFrameMinY: The bar's top edge in the containing view's coordinates, or nil when
    ///     no meaningful conversion exists (different windows, or no real geometry yet).
    ///   - viewHeight: The containing view's height; 0 means the geometry isn't real yet.
    static func isHidden(
        tabBarHidden: Bool,
        tabBarAlpha: CGFloat,
        barFrameMinY: CGFloat?,
        viewHeight: CGFloat
    ) -> Bool {
        if tabBarHidden || tabBarAlpha == 0 { return true }
        guard viewHeight > 0, let barFrameMinY else { return false }
        return barFrameMinY >= viewHeight
    }
}

/// What the floating button's bottom edge is allowed to hang from.
///
/// The button wants to ride just above the tab bar, but `tabBar` is only a legal constraint
/// partner when it is actually inside the tab bar controller's view. On iPad running iOS 26 the
/// bar is hoisted out of that hierarchy into a floating top bar, and constraining to it there
/// throws `NSGenericException: … no common ancestor` before the app ever draws a frame. The
/// same is true, less dramatically, whenever the bar is docked somewhere other than the bottom:
/// "above the bar" would put the button under the status bar.
///
/// So: hang from the bar only when it is both in-hierarchy *and* at the bottom; otherwise fall
/// back to the view's own bottom safe area, which always exists and is always an ancestor.
enum FloatingActionButtonPlacement: Equatable {
    /// Pinned `barGap` above the tab bar's top edge.
    case aboveTabBar
    /// Pinned `barGap` above the view's bottom safe-area edge.
    case bottomSafeArea

    static func placement(tabBarIsInHierarchy: Bool, tabBarIsDockedAtBottom: Bool) -> Self {
        tabBarIsInHierarchy && tabBarIsDockedAtBottom ? .aboveTabBar : .bottomSafeArea
    }
}

/// When favoriting something anywhere in the app makes the floating button glow.
///
/// The flourish is an "it landed in there" gesture — the heart you tapped flying home to the
/// button that opens Favorites. That only reads if the button *is* the way to Favorites, so a
/// button configured to open Events or Nearby stays still: a glow pointing at a calendar
/// after you favorite a camp is a promise the button doesn't keep.
///
/// Removals don't glow either. The animation says "saved"; playing it while something leaves
/// the list would make the button a change-notifier instead of a destination.
///
/// Nothing is queued: a favorite made while the button is off screen (wrong layout, user
/// turned it off, Favorites is on the bar as a real tab) simply doesn't glow, because there's
/// nothing to glow at and no moment later where the animation would still mean anything.
enum FloatingActionButtonGlow {
    static func shouldGlow(
        isVisible: Bool,
        action: FloatingActionButtonAction,
        favoriteWasAdded: Bool
    ) -> Bool {
        isVisible && favoriteWasAdded && action == .favorites
    }
}

/// A glass circle with an outline glyph in it, matching the map's `SidebarButtonsView`
/// treatment but larger: this one is a primary entry point standing in for a tab, not an
/// on-map utility, so it reads at FAB size rather than the map column's 40pt.
final class FloatingActionButton: UIView {

    static let diameter: CGFloat = 56

    /// Distance from the safe-area trailing edge to the button's trailing edge.
    static let trailingInset: CGFloat = 16

    /// Gap between the button's bottom and the top of the tab bar.
    static let barGap: CGFloat = 12

    private let button = UIButton(type: .system)
    private var action: (() -> Void)?

    /// The halo behind the glass, invisible until a favorite lands. Its own view rather than
    /// a layer on the glass: the bloom has to spill *outside* the circle, and the glass view
    /// clips to its corner radius so anything drawn there is cut off at the edge.
    private let glow = UIView()

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)

        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = true
            effect = glass
        } else {
            effect = UIBlurEffect(style: .systemThinMaterial)
        }
        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.isUserInteractionEnabled = false
        glow.alpha = 0
        glow.layer.cornerRadius = Self.diameter / 2
        glow.layer.shadowOffset = .zero
        glow.layer.shadowRadius = 16
        glow.layer.shadowOpacity = 1
        addSubview(glow)

        let container = UIVisualEffectView(effect: effect)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        container.layer.cornerRadius = Self.diameter / 2
        addSubview(container)

        button.accessibilityIdentifier = "floatingActionButton"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
        container.contentView.addSubview(button)

        NSLayoutConstraint.activate([
            glow.leadingAnchor.constraint(equalTo: leadingAnchor),
            glow.trailingAnchor.constraint(equalTo: trailingAnchor),
            glow.topAnchor.constraint(equalTo: topAnchor),
            glow.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
            button.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
        ])

        configure(for: .favorites)
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Points the button at a screen: glyph, accessibility label, and nothing else — the
    /// tap handler asks `FloatingActionButtonSettings` for the current action, so a button
    /// that missed a configure still opens the right list.
    func configure(for action: FloatingActionButtonAction) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: action.symbolName, withConfiguration: config), for: .normal)
        button.accessibilityLabel = NSLocalizedString(action.title, comment: "floating action button")
    }

    func applyTheme() {
        let colors = Appearance.currentColors
        // The unselected tab-item color, not the accent. The button stands in for a tab, and
        // the accent is what the bar uses to mean *selected* — wearing it made the button
        // read as the current screen from whichever tab you were actually on.
        //
        // `secondaryColor` (`.label`) rather than the `detailColor` that
        // `Appearance.applyTabBarAppearance` nominally assigns to `unselectedItemTintColor`:
        // the iOS 26 floating bar — the only layout this button exists on — ignores that
        // appearance and draws its unselected items in `label`. Sampling the shipped bar,
        // every unselected glyph including the search circle right below this button comes
        // out at #1E1813, while `detailColor`/`.secondaryLabel` renders #888689 and reads as
        // disabled beside them. Matching what the bar actually draws is the point.
        button.tintColor = colors.secondaryColor
        // The halo keeps the accent: it's a momentary event, not chrome, and it's the one
        // place on this button where "highlighted" is the intended reading.
        glow.backgroundColor = colors.primaryColor
        glow.layer.shadowColor = colors.primaryColor.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // `shadowColor` is a CGColor, which doesn't follow light/dark on its own.
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        glow.layer.shadowColor = Appearance.currentColors.primaryColor.resolvedColor(with: traitCollection).cgColor
    }

    /// A brief confirmation flourish for a favorite added anywhere in the app: the button
    /// swells and a halo blooms out of it and fades, ~0.75s end to end. See
    /// `FloatingActionButtonGlow` for when this is allowed to run at all.
    ///
    /// Under Reduce Motion nothing scales — the halo alone fades up and out, so the
    /// confirmation still registers without any movement on screen.
    func playFavoriteAddedGlow() {
        // A button that isn't on screen has nothing to confirm, and an animation left
        // running on a hidden view would play to no one.
        guard !isHidden, window != nil else { return }

        glow.layer.removeAllAnimations()
        layer.removeAllAnimations()
        transform = .identity
        glow.transform = .identity

        guard !UIAccessibility.isReduceMotionEnabled else {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                self.glow.alpha = 0.5
            } completion: { _ in
                UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState, .curveEaseIn]) {
                    self.glow.alpha = 0
                }
            }
            return
        }

        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.glow.alpha = 0.55
            self.glow.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
            self.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.55,
                delay: 0,
                usingSpringWithDamping: 0.55,
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState]
            ) {
                self.transform = .identity
            }
            UIView.animate(withDuration: 0.5, delay: 0.05, options: [.beginFromCurrentState, .curveEaseIn]) {
                self.glow.alpha = 0
                self.glow.transform = CGAffineTransform(scaleX: 1.45, y: 1.45)
            } completion: { _ in
                self.glow.transform = .identity
            }
        }
    }

    @objc private func buttonPressed() {
        action?()
    }
}

extension Notification.Name {
    /// Posted when the user turns the floating button on or off, or changes what it opens,
    /// so `TabController` can re-run the visibility rule and the map can re-place its
    /// attribution ⓘ.
    static let floatingActionButtonDidChange = Notification.Name("FloatingActionButtonDidChange")
}
