//
//  BRCEventObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/11/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation

extension BRCEventObject {
    /// e.g. "10:00AM - 4:00PM"
    @objc public var startAndEndString: String {
        let timeOnly = DateFormatter.timeOnly
        return "\(timeOnly.string(from: startDate)) - \(timeOnly.string(from: endDate))"
    }
    
    public var startWeekdayString: String {
        let dayOfWeek = DateFormatter.dayOfWeek
        return dayOfWeek.string(from: startDate)
    }
}
