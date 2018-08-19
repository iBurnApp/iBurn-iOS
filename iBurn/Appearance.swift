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
        }
    }
    private var colors: AppColors {
        didSet {
            UserSettings.contrast = colors
        }
    }
    
    private override init() {
        self.theme = UserSettings.theme
        self.colors = UserSettings.contrast
    }
    
    @objc public static var colors: BRCImageColors {
        let colors: BRCImageColors
        switch theme {
        case .light:
            colors = .plain
        case .dark:
            colors = .plainDark
        }
        return colors
    }

    @objc public static var barStyle: UIBarStyle {
        let barStyle: UIBarStyle
        switch theme {
        case .light:
            barStyle = .default
        case .dark:
            barStyle = .black
        }
        return barStyle
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


