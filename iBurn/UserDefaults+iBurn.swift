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
        case downloadsDisabled
    }
    
    static var isLocationHistoryDisabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.locationHistoryDisabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.locationHistoryDisabled.rawValue)
        }
    }
    
    @objc static var areDownloadsDisabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.downloadsDisabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.downloadsDisabled.rawValue)
        }
    }
}
