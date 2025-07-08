import Foundation

/// Event type abbreviations used by the Burning Man API
public enum EventType: String, Codable, CaseIterable, Sendable {
    case artsAndCrafts = "arts"
    case adultOriented = "adlt"
    case beverages = "tea"
    case foodAndDrink = "food"
    case kidsEvent = "kid"
    case musicAndParty = "prty"
    case other = "othr"
    case classAndWorkshop = "work"
}

/// Represents the type/category of an event
public struct EventTypeInfo: Codable, Hashable, Sendable {
    public let label: String?
    public let type: EventType?
    
    public init(label: String? = nil, type: EventType? = nil) {
        self.label = label
        self.type = type
    }
    
    enum CodingKeys: String, CodingKey {
        case label
        case type = "abbr"
    }
}
