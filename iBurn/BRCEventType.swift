//
//  BRCEventType.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

@objc enum BRCEventType: Int, CaseIterable {
    case unknown
    case none
    case workshop
    case performance
    case support
    case party
    case ceremony
    case game
    case fire
    case adult
    case kid
    case parade
    case other
    case food
    case crafts
    case coffee
    case healing
    case lgbt
    case liveMusic
    case ride
    case repair
    case sustainability
    case meditation
    
    init?(jsonValue: String) {
        guard let type = BRCEventType.allCases.first(where: { $0.jsonValue == jsonValue }) else {
            return nil
        }
        self = type
    }
    
    var jsonValue: String {
        switch self {
        case .unknown: return ""
        case .none: return "none"
        case .workshop: return "work"
        case .performance: return "perf"
        case .support: return "care"
        case .party: return "prty"
        case .ceremony: return "cere"
        case .game: return "game"
        case .fire: return "fire"
        case .adult: return "adlt"
        case .kid: return "kid"
        case .parade: return "para"
        case .other: return "food"
        case .food: return "othr"
        case .crafts: return "arts"
        case .coffee: return "tea"
        case .healing: return "heal"
        case .lgbt: return "LGBT"
        case .liveMusic: return "live"
        case .ride: return "RIDE"
        case .repair: return "repr"
        case .sustainability: return "sust"
        case .meditation: return "yoga"
        }
    }
    
    var isVisible: Bool {
        switch self {
        case .unknown, .none:
            return false
        case .coffee, .healing, .lgbt: // no longer used in 2023
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
        case .lgbt:
            return "🌈"
        case .liveMusic:
            return "🎺"
        case .ride:
            return "💗"
        case .repair:
            return "🔨"
        case .sustainability:
            return "♻️"
        case .meditation:
            return "🧘"
        }
    }
    
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
        case .lgbt:
            return "LGBTQIA2S+"
        case .liveMusic:
            return "Live Music"
        case .ride:
            return "Diversity & Inclusion"
        case .repair:
            return "Repair"
        case .sustainability:
            return "Sustainability/Greening Your Burn"
        case .meditation:
            return "Yoga/Movement/Fitness"
        }
    }
    
    public var description: String {
        "\(emoji) \(displayString)"
    }
}
