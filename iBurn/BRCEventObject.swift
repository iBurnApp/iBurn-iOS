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
            .filter { $0.isVisible }
            .sorted {
                $0.displayString < $1.displayString
            }
            .map { NSNumber(value: $0.rawValue) }
    }
}

extension BRCEventType {
    var isVisible: Bool {
        switch self {
        case .unknown, .none:
            return false
        case .coffee, .healing, .LGBT: // no longer used in 2023
            return false
        default:
            return true
        }
    }
    
    var emoji: String {
        switch self {
        case .unknown, .none, .other:
            return "🤷"
        case .workshop:
            return "🧑‍🏫"
        case .performance:
            return "💃"
        case .support:
            return "🏥"
        case .party:
            return "🎉"
        case .ceremony:
            return "🔮"
        case .game:
            return "🎯"
        case .fire:
            return "🔥"
        case .adult:
            return "💋"
        case .kid:
            return "👨‍👩‍👧‍👦"
        case .parade:
            return "🎏"
        case .food:
            return "🍔"
        case .crafts:
            return "🎨"
        case .coffee:
            return "☕️"
        case .healing:
            return "💆"
        case .LGBT:
            return "🌈"
        case .liveMusic:
            return "🎺"
        case .RIDE:
            return "💗"
        case .repair:
            return "🔨"
        case .sustainability:
            return "♻️"
        case .meditation:
            return "🧘"
        @unknown default:
            return "🤷"
        }
    }
}

extension BRCEventType {
    /// org-defined display string
    var displayString: String {
        switch self {
        case .unknown, .none:
            return "Unknown"
        case .other:
            return "Miscellaneous"
        case .workshop:
            return "Class/Workshop"
        case .performance:
            return "Performance"
        case .support:
            return "Self Care"
        case .party:
            return "Gathering/Party"
        case .ceremony:
            return "Ritual/Ceremony"
        case .game:
            return "Games"
        case .fire:
            return "Fire/Spectacle"
        case .adult:
            return "Mature Audiences"
        case .kid:
            return "For Kids"
        case .parade:
            return "Parade"
        case .food:
            return "Food & Drink"
        case .crafts:
            return "Arts & Crafts"
        case .coffee:
            return "Coffee/Tea"
        case .healing:
            return "Healing/Massage/Spa"
        case .LGBT:
            return "LGBTQIA2S+"
        case .liveMusic:
            return "Live Music"
        case .RIDE:
            return "Diversity & Inclusion"
        case .repair:
            return "Repair"
        case .sustainability:
            return "Sustainability/Greening Your Burn"
        case .meditation:
            return "Yoga/Movement/Fitness"
        @unknown default:
            return "Unknown"
        }
    }
}

extension BRCEventType: CustomStringConvertible {
    public var description: String {
        "\(emoji) \(displayString)"
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
