//
//  FavoritesFloatingButton.swift
//  iBurn
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  The floating heart above the tab bar. On the iOS 26 `.searchTab` layout the search
//  tab eats a bar slot, and Favorites gives that slot up (see
//  `TabConfiguration.layoutHiddenByDefault`) in exchange for this — a Slack-style
//  circular button pinned to the trailing edge that presents Favorites as a sheet from
//  whatever tab you're on.
//

import UIKit

/// When the floating Favorites button belongs on screen.
///
/// Two conditions, kept as a pure function so the rule can be tested without a window:
/// the layout has to be the one that took Favorites off the bar, and Favorites has to
/// actually be off the bar. A user who drags Favorites back on via Customize Tabs keeps
/// the tab and loses the button — one entry point, never two.
enum FavoritesFABVisibility {
    static func isVisible(searchTabActive: Bool, favoritesDisplaced: Bool) -> Bool {
        searchTabActive && favoritesDisplaced
    }

    /// The rule against the live configuration.
    @MainActor
    static var isVisible: Bool {
        isVisible(
            searchTabActive: TabConfiguration.searchTabOccupiesBarSlot,
            favoritesDisplaced: TabController.isDisplacedFromTabBar(.favorites)
        )
    }
}

/// A glass circle with a heart in it, matching the map's `SidebarButtonsView` treatment
/// but larger: this one is a primary entry point standing in for a tab, not an on-map
/// utility, so it reads at Slack-FAB size rather than the map column's 40pt.
final class FavoritesFloatingButton: UIView {

    static let diameter: CGFloat = 56

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

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "heart.fill", withConfiguration: config), for: .normal)
        button.accessibilityLabel = NSLocalizedString("Favorites", comment: "floating favorites button")
        button.accessibilityIdentifier = "favoritesFloatingButton"
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

        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        button.tintColor = Appearance.currentColors.primaryColor
    }

    @objc private func buttonPressed() {
        action?()
    }
}
