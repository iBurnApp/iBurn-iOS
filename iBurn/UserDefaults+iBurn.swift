//
//  UserDefaults+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/2/19.
//  Copyright 2019 Burning Man Earth. All rights reserved.
//

import Foundation

extension UserDefaults {
    enum Keys: String {
        case locationHistoryDisabled
        case downloadsDisabled
        case navigationModeDisabled
        case lastUpdateCheck
    }
    
    static var isLocationHistoryDisabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Keys.locationHistoryDisabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.locationHistoryDisabled.rawValue)
        }
    }
    
    /// Whether or not automatic data updates are disabled. Always returns false after the event is over
    @objc static var areDownloadsDisabled: Bool {
        get {
            if YearSettings.isEventOver {
                print("Event is over, disabling remote data updates")
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.downloadsDisabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.downloadsDisabled.rawValue)
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
    
    /// Used for rate-limiting remote API data update checks to every 24 hours
    @objc static var lastUpdateCheck: Date? {
        get {
            return UserDefaults.standard.object(forKey: Keys.lastUpdateCheck.rawValue) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lastUpdateCheck.rawValue)
        }
    }

    @objc static var enteredEmbargoPasscode: Bool {
        get {
            return UserDefaults.standard.enteredEmbargoPasscode()
        }
        set {
            UserDefaults.standard.setEnteredEmbargoPasscode(newValue)
        }
    }
}
