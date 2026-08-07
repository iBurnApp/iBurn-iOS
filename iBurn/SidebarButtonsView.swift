//
//  SidebarButtonsView.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/15/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//
//  The floating control column on the left edge of the map: drop a pin, find my
//  bike, find my camp. Rebuilt on SF Symbols in glass circles — the old
//  BButton/FontAwesome squares read as flat stickers next to the Liquid Glass
//  nearby card and tab bar.
//

import UIKit
import PureLayout
import CocoaLumberjack

class SidebarButtonsView: UIView {
    enum ButtonType: CaseIterable {
        case pin
        case bike
        case home

        /// Order is bottom-up: the most-used control sits closest to the thumb.
        static let allTypes: [ButtonType] = [.pin, .bike, .home]

        var symbolName: String {
            switch self {
            case .pin: return "star"
            case .bike: return "bicycle"
            case .home: return "house.fill"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .pin: return NSLocalizedString("Drop a pin", comment: "map sidebar button")
            case .bike: return NSLocalizedString("Find my bike", comment: "map sidebar button")
            case .home: return NSLocalizedString("Find my camp", comment: "map sidebar button")
            }
        }

        var mapPointType: BRCMapPointType? {
            switch self {
            case .pin: return nil
            case .bike: return .userBike
            case .home: return .userHome
            }
        }
    }

    static let buttonDiameter: CGFloat = 44
    private static let spacing: CGFloat = 12

    /// Intrinsic height for the whole column, so callers don't hardcode a magic number.
    static var columnHeight: CGFloat {
        let count = CGFloat(ButtonType.allTypes.count)
        return count * buttonDiameter + (count - 1) * spacing
    }

    private var buttons: [UIButton: ButtonType] = [:]

    public var findNearestAction: ((_ mapPointType: BRCMapPointType, _ sender: UIButton) -> Void)?
    public var placePinAction: ((_ sender: UIButton) -> Void)?

    init() {
        super.init(frame: .zero)

        var views: [UIView] = []
        for type in ButtonType.allTypes {
            let (container, button) = Self.makeButton(for: type)
            button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
            buttons[button] = type
            views.append(container)
        }

        let stackView = UIStackView(arrangedSubviews: views.reversed())
        stackView.axis = .vertical
        stackView.spacing = Self.spacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()

        applyTheme()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        let colors = Appearance.currentColors
        for button in buttons.keys {
            button.tintColor = colors.primaryColor
        }
    }

    // MARK: - Construction

    private static func makeButton(for type: ButtonType) -> (UIView, UIButton) {
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
        container.layer.cornerRadius = buttonDiameter / 2

        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: type.symbolName, withConfiguration: config), for: .normal)
        button.accessibilityLabel = type.accessibilityLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        container.contentView.addSubview(button)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: buttonDiameter),
            container.heightAnchor.constraint(equalToConstant: buttonDiameter),
            button.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
        ])

        return (container, button)
    }

    // MARK: - Actions

    @objc private func buttonPressed(_ sender: UIButton) {
        guard let buttonType = buttons[sender] else {
            DDLogError("Button type not found!")
            return
        }
        if let mapPointType = buttonType.mapPointType {
            findNearestAction?(mapPointType, sender)
        } else if buttonType == .pin {
            placePinAction?(sender)
        }
    }
}
