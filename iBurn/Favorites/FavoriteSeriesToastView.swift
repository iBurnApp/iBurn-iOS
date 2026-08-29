//
//  FavoriteSeriesToastView.swift
//  iBurn
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import UIKit

/// Bottom-anchored card offering to extend a single-occurrence favorite to the whole
/// series. Deliberately small, non-modal, and dismissible — it must never stand between
/// someone and the list they were scrolling.
///
/// Plain UIKit rather than a `UIHostingController`: the toast lives in the app's window
/// alongside a UIKit tab controller and is measured against the tab bar's real frame, so
/// there is nothing for SwiftUI to contribute here beyond another layout system to
/// reconcile with. A `UIVisualEffectView` and three subviews say the same thing.
final class FavoriteSeriesToastView: UIView {

    private let onAction: () -> Void
    private let onDismiss: () -> Void

    init(toast: FavoriteSeriesToast,
         onAction: @escaping () -> Void,
         onDismiss: @escaping () -> Void) {
        self.onAction = onAction
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        build(toast: toast)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Layout

    private func build(toast: FavoriteSeriesToast) {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        blur.layer.cornerRadius = 18
        blur.layer.cornerCurve = .continuous
        blur.clipsToBounds = true
        blur.layer.borderWidth = 1
        blur.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let heart = UIImageView(image: UIImage(systemName: "heart.fill"))
        heart.tintColor = .systemPink
        heart.contentMode = .scaleAspectFit
        heart.setContentHuggingPriority(.required, for: .horizontal)
        heart.isAccessibilityElement = false

        let title = UILabel()
        title.text = toast.message
        title.font = .preferredFont(forTextStyle: .subheadline)
        title.adjustsFontForContentSizeCategory = true
        title.numberOfLines = 2
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = toast.remainingCount == 1
            ? "It has one other occurrence."
            : "It has \(toast.remainingCount) other occurrences."
        subtitle.font = .preferredFont(forTextStyle: .caption1)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.numberOfLines = 1
        subtitle.textColor = .secondaryLabel

        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical
        text.spacing = 2

        var actionConfig = UIButton.Configuration.borderedProminent()
        actionConfig.title = toast.actionTitle
        actionConfig.cornerStyle = .capsule
        actionConfig.baseBackgroundColor = .systemPink
        actionConfig.buttonSize = .small
        let action = UIButton(configuration: actionConfig, primaryAction: UIAction { [weak self] _ in
            self?.onAction()
        })
        action.titleLabel?.adjustsFontForContentSizeCategory = true
        action.setContentCompressionResistancePriority(.required, for: .horizontal)
        action.setContentHuggingPriority(.required, for: .horizontal)

        var dismissConfig = UIButton.Configuration.plain()
        dismissConfig.image = UIImage(systemName: "xmark")
        dismissConfig.baseForegroundColor = .secondaryLabel
        dismissConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        let dismiss = UIButton(configuration: dismissConfig, primaryAction: UIAction { [weak self] _ in
            self?.onDismiss()
        })
        dismiss.accessibilityLabel = "Dismiss"
        dismiss.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [heart, text, action, dismiss])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(row)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            row.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -10),
            row.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -10),

            heart.widthAnchor.constraint(equalToConstant: 18),
            heart.heightAnchor.constraint(equalToConstant: 18),
        ])

        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
    }
}
