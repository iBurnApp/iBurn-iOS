//
//  BRCEventType.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/11/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation

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

extension BRCEventType {
    /// `BRCEventType` values that are selectable in the event/map filter screens,
    /// sorted by display string.
    public static var allVisibleTypes: [BRCEventType] {
        BRCEventType.allCases
            .filter { $0.isVisible }
            .sorted { $0.displayString < $1.displayString }
    }
}

extension BRCEventType {
    var isVisible: Bool {
        switch self {
        case .unknown, .none:
            return false
        // These event types are no longer used in the data as of 2025
        case .healing, .LGBT, .performance, .support, .ceremony, .game, 
             .fire, .parade, .liveMusic, .RIDE, .repair, .sustainability, .meditation:
            return false
        // Only show event types that actually have events in 2025:
        case .workshop, .party, .other, .coffee, .food, .crafts, .adult, .kid:
            return true
        @unknown default:
            return false
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
            return "🔞"
        case .kid:
            return "👨‍👩‍👧‍👦"
        case .parade:
            return "🎏"
        case .food:
            return "🍔"
        case .crafts:
            return "🎨"
        case .coffee:
            return "🍹"
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
            return "Other"  // Matches 2025 data
        case .workshop:
            return "Class/Workshop"  // Matches 2025 data
        case .performance:
            return "Performance"
        case .support:
            return "Self Care"
        case .party:
            return "Music/Party"  // Updated to match 2025 data
        case .ceremony:
            return "Ritual/Ceremony"
        case .game:
            return "Games"
        case .fire:
            return "Fire/Spectacle"
        case .adult:
            return "Mature Audiences"  // Matches 2025 data
        case .kid:
            return "Kids Activities"  // Updated to match 2025 data
        case .parade:
            return "Parade"
        case .food:
            return "Food"  // Simplified to match 2025 data
        case .crafts:
            return "Arts & Crafts"  // Matches 2025 data
        case .coffee:
            return "Beverages"  // Updated to match 2025 data (tea = Beverages)
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
