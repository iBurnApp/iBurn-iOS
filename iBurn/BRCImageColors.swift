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
    
    static let adult = BRCImageColors(backgroundColor: UIColor(hex: 0x222222),
                                      primaryColor: UIColor(hex: 0xD92F2F),
                                      secondaryColor: UIColor(hex: 0xE17C84),
                                      detailColor: UIColor(hex: 0xEAC8C8))
    static let party2 = BRCImageColors(backgroundColor: UIColor(hex: 0x101034),
                                      primaryColor: UIColor(hex: 0x3957CE),
                                      secondaryColor: UIColor(hex: 0x59A0EF),
                                      detailColor: UIColor(hex: 0xCECCF2))
    static let food = BRCImageColors(backgroundColor: UIColor(hex: 0xD40404),
                                     primaryColor: UIColor(hex: 0xFBC92C),
                                     secondaryColor: UIColor(hex: 0xFBF9F9),
                                     detailColor: UIColor(hex: 0xFBF9F9))
    static let ceremony = BRCImageColors(backgroundColor: UIColor(hex: 0xCDCCD2),
                                         primaryColor: UIColor(hex: 0x43492C),
                                         secondaryColor: UIColor(hex: 0xFBF9F9),
                                         detailColor: UIColor(hex: 0xFBF9F9))
    static let fire = BRCImageColors(backgroundColor: UIColor(hex: 0xFBBB0C),
                                         primaryColor: UIColor(hex: 0x740C04),
                                         secondaryColor: UIColor(hex: 0xA61B04),
                                         detailColor: UIColor(hex: 0xD33204))
    static let party = BRCImageColors(backgroundColor: UIColor(hex: 0xE9D8F6),
                                     primaryColor: UIColor(hex: 0x34C4DA),
                                     secondaryColor: UIColor(hex: 0xB7329F),
                                     detailColor: UIColor(hex: 0x8D4A60))
    static let kid = BRCImageColors(backgroundColor: UIColor(hex: 0xFDE74C),
                                      primaryColor: UIColor(hex: 0xC3423F),
                                      secondaryColor: UIColor(hex: 0x9BC53D),
                                      detailColor: UIColor(hex: 0x5BC0EB))
    static let game = BRCImageColors(backgroundColor: UIColor(hex: 0xF0F8EA),
                                    primaryColor: UIColor(hex: 0xE4572E),
                                    secondaryColor: UIColor(hex: 0xF52F57),
                                    detailColor: UIColor(hex: 0xA8C686))
    static let parade = BRCImageColors(backgroundColor: UIColor(hex: 0x8D6A9F),
                                     primaryColor: UIColor(hex: 0xBB342F),
                                     secondaryColor: UIColor(hex: 0xDDA448),
                                     detailColor: UIColor(hex: 0x8CBCB9))
    static let support = BRCImageColors(backgroundColor: UIColor(hex: 0x50A2A7),
                                       primaryColor: UIColor(hex: 0xBB0A21),
                                       secondaryColor: UIColor(hex: 0xE9B44C),
                                       detailColor: UIColor(hex: 0xE4D6A7))
    static let performance = BRCImageColors(backgroundColor: UIColor(hex: 0xFEFFED),
                                        primaryColor: UIColor(hex: 0xC55F53),
                                        secondaryColor: UIColor(hex: 0x489B9B),
                                        detailColor: UIColor(hex: 0x392232))
    static let workshop = BRCImageColors(backgroundColor: UIColor(hex: 0x5F0F40),
                                            primaryColor: UIColor(hex: 0xFB8B24),
                                            secondaryColor: UIColor(hex: 0xE36414),
                                            detailColor: UIColor(hex: 0xBB0A21))
    
    static let plain = BRCImageColors(backgroundColor: .white,
                                      primaryColor: .darkText,
                                      secondaryColor: .darkText,
                                      detailColor: .lightGray)
    
    static let plainDark = BRCImageColors(backgroundColor: .black,
                                      primaryColor: .white,
                                      secondaryColor: .white,
                                      detailColor: .white)
    
    static let light = BRCImageColors(backgroundColor: .white,
                                      primaryColor: UIColor(hex: 0xdb8700),
                                      secondaryColor: .darkText,
                                      detailColor: .lightGray)
    
    static let dark = BRCImageColors(backgroundColor: UIColor(hex: 0x202020),
                                          primaryColor: UIColor(hex: 0xdb8700),
                                          secondaryColor: .white,
                                          detailColor: .lightGray)
    
    @objc public static func colors(for eventType: BRCEventType) -> BRCImageColors {
        switch Appearance.theme {
        case .light:
            return plain
        case .dark:
            return plainDark
        case .system:
            switch UIScreen.main.traitCollection.userInterfaceStyle {
            case .unspecified:
                return plainDark
            case .light:
                return plain
            case .dark:
                return plainDark
            @unknown default:
                return plainDark
            }
        }
    }
    
    @objc public static func oldColors(for eventType: BRCEventType) -> BRCImageColors {
        switch eventType {
        case .adult:
            return adult
        case .ceremony:
            return ceremony
        case .fire:
            return fire
        case .food:
            return food
        case .game:
            return game
        case .kid:
            return kid
        case .none, .unknown:
            break
        case .parade:
            return parade
        case .party:
            return party
        case .performance:
            return performance
        case .support:
            return support
        case .workshop:
            return workshop
        case .crafts:
            return plain
        case .coffee:
            return plain
        case .healing:
            return plain
        case .LGBT:
            return plain
        case .liveMusic:
            return plain
        case .RIDE:
            return plain
        case .repair:
            return plain
        case .sustainability:
            return plain
        case .meditation:
            return plain
        case .other:
            return plain
        @unknown default:
            return plain
        }
        return plain
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
