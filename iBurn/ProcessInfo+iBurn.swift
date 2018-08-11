//
//  ProcessInfo+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/11/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

public extension ProcessInfo {
    /// whether or not we should fake the current date for testing Events
    @objc public static var mockDateEnabled: Bool {
        guard let mock = ProcessInfo.processInfo.environment["MOCK_DATE"],
            mock == "1" else {
            return false
        }
        return true
    }
}
