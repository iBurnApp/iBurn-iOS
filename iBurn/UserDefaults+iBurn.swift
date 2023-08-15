//
//  UserDefaults+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/2/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation

extension UserDefaults {
    private enum Keys: String {
        case locationHistoryDisabled
        case downloadsEnabled
        case navigationModeDisabled
    }
    
    static var isLocationHistoryDisabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.locationHistoryDisabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.locationHistoryDisabled.rawValue)
        }
    }
    
    @objc static var areDownloadsEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.downloadsEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.downloadsEnabled.rawValue)
        }
    }
    
    
    @objc static var isNavigationModeDisabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.navigationModeDisabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.navigationModeDisabled.rawValue)
        }
    }
}
