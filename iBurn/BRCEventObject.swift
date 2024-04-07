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

extension BRCEventObject {
    /// Boxed `BRCEventType` values that are selectable within `BRCEventsFilterTableViewController`
    @objc public static var allVisibleEventTypes: [NSNumber] {
        BRCEventType.allCases
            .filter { $0.isVisible }
            .sorted {
                $0.displayString < $1.displayString
            }
            .map { NSNumber(value: $0.rawValue) }
    }
}

extension BRCEventObject {
    /** convert BRCEventType to display string */
    @objc public static func stringForEventType(_ type: BRCEventType) -> String {
        type.description
    }
}

extension BRCEventObject {
    /// Whether or not an event pin should show up on the main map screen
    public func shouldShowOnMap(_ now: Date = .present) -> Bool {
        let event = self
        // show events starting soon or happening now, but not ending soon
        return !event.hasEnded(.present) && (event.isStartingSoon(.present) || event.isHappeningRightNow(.present)) && !event.isEndingSoon(.present)
    }
}
