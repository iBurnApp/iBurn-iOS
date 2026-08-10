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
        button.tintColor = Appearance.currentColors.primaryColor
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
