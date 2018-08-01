//
//  Appearance.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit

@objc public class Appearance: NSObject {
    
    @objc public static var theme: AppTheme {
        set {
            Appearance.shared.theme = newValue
        }
        get {
            return Appearance.shared.theme
        }
    }
    
    @objc public static var contrast: AppColors {
        set {
            Appearance.shared.colors = newValue
        }
        get {
            return Appearance.shared.colors
        }
    }
    
    private static let shared = Appearance()
    private var theme: AppTheme {
        didSet {
            UserSettings.theme = theme
            setGlobalAppearance()
        }
    }
    private var colors: AppColors {
        didSet {
            UserSettings.contrast = colors
            setGlobalAppearance()
        }
    }
    
    private override init() {
        self.theme = UserSettings.theme
        self.colors = UserSettings.contrast
    }
    
    private func setGlobalAppearance() {
//        let colors: BRCImageColors
//        let barStyle: UIBarStyle
//        switch theme {
//        case .light:
//            colors = .plain
//            barStyle = .default
//        case .dark:
//            colors = .plainDark
//            barStyle = .black
//        }
    }

}


@objc public enum AppTheme: Int {
    case light
    case dark
}

@objc public enum AppColors: Int {
    case colorful
    case highContrast
}


