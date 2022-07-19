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

extension BRCEventType: CaseIterable {
    /// Warning - this must be manually maintained if new cases are added
    public static var allCases: [BRCEventType] {
        let firstCase: BRCEventType = .unknown
        let lastCase: BRCEventType = .meditation
        return (firstCase.rawValue...lastCase.rawValue).compactMap {
            BRCEventType(rawValue: $0)
        }
    }
}

extension BRCEventObject {
    /// Boxed `BRCEventType` values that are selectable within `BRCEventsFilterTableViewController`
    @objc public static var allVisibleEventTypes: [NSNumber] {
        BRCEventType.allCases
            .filter { $0 != .unknown && $0 != .none }
            .map { NSNumber(value: $0.rawValue) }
    }
}
