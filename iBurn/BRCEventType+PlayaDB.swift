//
//  BRCEventType+PlayaDB.swift
//  iBurn
//
//  Maps BRCEventType enum values to PlayaDB event type code strings.
//

import Foundation

extension BRCEventType {
    /// PlayaDB event type code string for this event type.
    /// Mapping sourced from BRCEventObject.m eventTypeJSONTransformer.
    var playaDBCode: String? {
        switch self {
        case .workshop:       return "work"
        case .performance:    return "perf"
        case .support:        return "care"
        case .party:          return "prty"
        case .ceremony:       return "cere"
        case .game:           return "game"
        case .fire:           return "fire"
        case .adult:          return "adlt"
        case .kid:            return "kid"
        case .parade:         return "para"
        case .food:           return "food"
        case .other:          return "othr"
        case .crafts:         return "arts"
        case .coffee:         return "tea"
        case .healing:        return "heal"
        case .LGBT:           return "LGBT"
        case .liveMusic:      return "live"
        case .RIDE:           return "RIDE"
        case .repair:         return "repr"
        case .sustainability: return "sust"
        case .meditation:     return "yoga"
        case .unknown, .none: return nil
        @unknown default:     return nil
        }
    }

    /// Convert an array of BRCEventType to `Set<String>?` for `EventFilter.eventTypeCodes`.
    /// Returns `nil` when all visible types are selected (meaning "no filter").
    static func eventTypeCodes(from types: [BRCEventType]) -> Set<String>? {
        let codes = Set(types.compactMap(\.playaDBCode))
        let allCodes = Set(
            BRCEventObject.allVisibleEventTypes
                .compactMap { BRCEventType(rawValue: $0.uintValue)?.playaDBCode }
        )
        return codes == allCodes ? nil : codes
    }
}
