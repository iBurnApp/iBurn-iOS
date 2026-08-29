//
//  MapSearchAccessoryView.swift
//  iBurn
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Resting state of the bottom-anchored search: a search-field-shaped button that
//  lives inside the tab bar's `UITabAccessory`. The accessory supplies the Liquid
//  Glass background itself, so this view stays fully transparent — drawing our own
//  fill here is what makes an accessory look like a sticker pasted onto the glass.
//

import UIKit

final class MapSearchAccessoryView: UIControl {

    private let iconView = UIImageView()
    private let label = UILabel()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        label.text = NSLocalizedString("Search art, camps, and events", comment: "placeholder for the bottom map search field")
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        applyTheme()

        isAccessibilityElement = true
        // Both traits: it reads as search, but it opens a field rather than accepting
        // text itself, so it has to advertise as a button to be actionable.
        accessibilityTraits = [.button, .searchField]
        accessibilityLabel = NSLocalizedString("Search", comment: "accessibility label for the bottom map search field")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        let colors = Appearance.currentColors
        iconView.tintColor = colors.detailColor
        label.textColor = colors.detailColor
    }

    @objc private func handleTap() {
        onTap?()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.alpha = self.isHighlighted ? 0.5 : 1
            }
        }
    }
}
