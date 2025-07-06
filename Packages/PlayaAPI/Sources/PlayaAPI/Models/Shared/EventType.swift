import Foundation

/// Event type abbreviations used by the Burning Man API
public enum EventType: String, Codable, CaseIterable, Sendable {
    case artsAndCrafts = "arts"
    case adultOriented = "adul"
    case burningCeremony = "burn"
    case foodAndDrink = "food"
    case gamesAndCompetition = "game"
    case kidsEvent = "kids"
    case parade = "para"
    case performanceAndTheater = "perf"
    case musicAndParty = "prty"
    case socialMeet = "soci"
    case wellness = "well"
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
