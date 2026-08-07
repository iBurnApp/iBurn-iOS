//
//  MapSearchInputBar.swift
//  iBurn
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Active state of the bottom-anchored search: a real editable field in a glass
//  capsule plus a Cancel button. Positioned by pinning to `keyboardLayoutGuide`,
//  which tracks the keyboard for free — no inputAccessoryView plumbing, and it
//  settles onto the safe-area bottom when the keyboard is down.
//

import UIKit

final class MapSearchInputBar: UIView {

    let textField = UITextField()
    private let cancelButton = UIButton(type: .system)
    private let capsule: UIVisualEffectView
    private let iconView = UIImageView()

    var onTextChange: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onSubmit: (() -> Void)?

    override init(frame: CGRect) {
        capsule = Self.makeCapsule()
        super.init(frame: frame)

        backgroundColor = .clear

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        textField.placeholder = NSLocalizedString("Search art, camps, and events", comment: "placeholder for the bottom map search field")
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.returnKeyType = .search
        textField.clearButtonMode = .whileEditing
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        let capsuleStack = UIStackView(arrangedSubviews: [iconView, textField])
        capsuleStack.axis = .horizontal
        capsuleStack.spacing = 8
        capsuleStack.alignment = .center
        capsuleStack.translatesAutoresizingMaskIntoConstraints = false
        capsule.contentView.addSubview(capsuleStack)

        cancelButton.setTitle(NSLocalizedString("Cancel", comment: "dismiss the map search"), for: .normal)
        cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        let outerStack = UIStackView(arrangedSubviews: [capsule, cancelButton])
        outerStack.axis = .horizontal
        outerStack.spacing = 10
        outerStack.alignment = .center
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            outerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            capsuleStack.leadingAnchor.constraint(equalTo: capsule.contentView.leadingAnchor, constant: 14),
            capsuleStack.trailingAnchor.constraint(equalTo: capsule.contentView.trailingAnchor, constant: -14),
            capsuleStack.topAnchor.constraint(equalTo: capsule.contentView.topAnchor),
            capsuleStack.bottomAnchor.constraint(equalTo: capsule.contentView.bottomAnchor),
            capsule.heightAnchor.constraint(equalToConstant: 48),

            // Pins the bar's own height to its content. Without this the bar is only
            // anchored at the bottom while the view above it is anchored at the top,
            // which leaves the split between them ambiguous — Autolayout resolves it by
            // stretching the bar over most of the screen.
            heightAnchor.constraint(equalTo: capsule.heightAnchor, constant: 16),
        ])

        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capsule.layer.cornerRadius = capsule.bounds.height / 2
    }

    func applyTheme() {
        let colors = Appearance.currentColors
        iconView.tintColor = colors.detailColor
        textField.textColor = colors.primaryColor
        cancelButton.tintColor = colors.primaryColor
    }

    // MARK: - Glass

    /// A `UIVisualEffectView` either way, so `contentView` is a stable place to hang
    /// subviews regardless of which effect the OS supports.
    private static func makeCapsule() -> UIVisualEffectView {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = true
            effect = glass
        } else {
            effect = UIBlurEffect(style: .systemThinMaterial)
        }
        let view = UIVisualEffectView(effect: effect)
        view.clipsToBounds = true
        return view
    }

    // MARK: - Actions

    @objc private func textChanged() {
        onTextChange?(textField.text ?? "")
    }

    @objc private func handleCancel() {
        textField.text = ""
        onTextChange?("")
        onCancel?()
    }
}

extension MapSearchInputBar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onSubmit?()
        return true
    }
}
