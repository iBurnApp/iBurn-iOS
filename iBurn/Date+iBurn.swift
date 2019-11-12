//
//  Date+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/11/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation

extension NSDate {
    
    /// Returns current datetime, or mocked datetime if running test scheme
    @objc public class var present: Date {
        #if DEBUG
        if ProcessInfo.mockDateEnabled {
            return NSDate.brc_test()
        } else {
            return Date()
        }
        #else
        return Date()
        #endif
    }
}

extension Date {
    /// Returns current datetime, or mocked datetime if running test scheme
    public static var present: Date {
        return NSDate.present
    }
}
