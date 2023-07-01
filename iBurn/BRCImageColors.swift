//
//  Colors.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/15/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

extension UIColor {
    public convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16)
        let g = CGFloat((hex & 0xFF00) >> 8)
        let b = CGFloat(hex & 0xFF)
        self.init(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: alpha)
    }
}

extension BRCImageColors {
    private static let light = BRCImageColors(backgroundColor: .white,
                                      primaryColor: UIColor(hex: 0xdb8700),
                                      secondaryColor: .darkText,
                                      detailColor: .lightGray)
    
    private static let dark = BRCImageColors(backgroundColor: UIColor(hex: 0x202020),
                                          primaryColor: UIColor(hex: 0xdb8700),
                                          secondaryColor: .white,
                                          detailColor: .lightGray)
    
    static let dynamic = BRCImageColors(
        backgroundColor: .init(dynamicProvider: { traitCollection in
            colors().backgroundColor
    }),
        primaryColor: .init(dynamicProvider: { traitCollection in
            colors().primaryColor
        }),
        secondaryColor: .init(dynamicProvider: { traitCollection in
            colors().secondaryColor
        }),
        detailColor: .init(dynamicProvider: { traitCollection in
            colors().detailColor
        })
    )
    
    private static func colors(theme: AppTheme = Appearance.theme) -> BRCImageColors {
        switch theme {
        case .light:
            return light
        case .dark:
            return dark
        case .system:
            switch UIScreen.main.traitCollection.userInterfaceStyle {
            case .unspecified, .light:
                return light
            case .dark:
                return dark
            @unknown default:
                return light
            }
        }
    }
    
    @objc public static func colors(for eventType: BRCEventType) -> BRCImageColors {
        .dynamic
    }
}

extension BRCEventObjectTableViewCell {
    public override func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        backgroundColor = colors.backgroundColor
        descriptionLabel.textColor = colors.secondaryColor
        titleLabel.textColor = colors.primaryColor
        hostLabel?.textColor = colors.detailColor
        eventTypeLabel.textColor = colors.primaryColor
        locationLabel.textColor = colors.detailColor
        subtitleLabel.textColor = colors.detailColor
        rightSubtitleLabel.textColor = colors.detailColor
    }
}
