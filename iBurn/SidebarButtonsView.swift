//
//  SidebarButtonsView.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/15/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import BButton
import PureLayout
import CocoaLumberjack

class SidebarButtonsView: UIView {
    enum ButtonType {
        case pin
        case potty
        case bike
        case home
        case medical
        static let allTypes: [ButtonType] = [.pin, .potty, .bike, .home, .medical]
        var icon: FAIcon {
            switch self {
            case .pin:
                return FAIcon.FAMapMarker
            case .potty:
                return FAIcon.FAFemale
            case .bike:
                return FAIcon.FABicycle
            case .home:
                return FAIcon.FAHome
            case .medical:
                return FAIcon.FAMedkit
            }
        }
        var mapPointType: BRCMapPointType? {
            switch self {
            case .pin:
                return nil
            case .potty:
                return .toilet
            case .bike:
                return .userBike
            case .home:
                return .userHome
            case .medical:
                return .medical
            }
        }
    }
    private var buttons: [BButton : ButtonType] = [:]
    
    public var findNearest: ((_ mapPointType: BRCMapPointType, _ sender: BButton) -> Void)?
    public var placePin: ((_ sender: BButton) -> Void)?
    
    init() {
        super.init(frame: CGRect.zero)
        var views: [BButton] = []
        ButtonType.allTypes.forEach { type in
            let frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            let icon = type.icon
            guard let button = BButton(frame: frame, type: .default, style: .bootstrapV3, icon: icon, fontSize: 20) else { return }
            button.alpha = 0.8
            button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
            views.append(button)
            buttons[button] = type
        }
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.axis = .vertical
        stackView.distribution = .equalCentering
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
    }
    
    @objc private func buttonPressed(sender: BButton) {
        guard let buttonType = buttons[sender] else {
            DDLogError("Button type not found!")
            return
        }
        if let mapPointType = buttonType.mapPointType {
            if let findNearest = findNearest {
                findNearest(mapPointType, sender)
            }
        } else if buttonType == .pin {
            if let placePin = placePin {
                placePin(sender)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
