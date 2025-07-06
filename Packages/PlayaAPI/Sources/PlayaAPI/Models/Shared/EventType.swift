import Foundation

/// Represents the type/category of an event
public struct EventType: Codable, Hashable, Sendable {
    public let label: String
    public let abbreviation: String
    
    public init(label: String, abbreviation: String) {
        self.label = label
        self.abbreviation = abbreviation
    }
    
    enum CodingKeys: String, CodingKey {
        case label
        case abbreviation = "abbr"
    }
}

// MARK: - Common Event Types

public extension EventType {
    static let musicParty = EventType(label: "Music/Party", abbreviation: "prty")
    static let classWorkshop = EventType(label: "Class/Workshop", abbreviation: "work")
    static let adultOriented = EventType(label: "Adult Oriented", abbreviation: "adul")
    static let kidsEvent = EventType(label: "Kids Event", abbreviation: "kids")
    static let foodDrink = EventType(label: "Food & Drink", abbreviation: "food")
    static let socialMeet = EventType(label: "Social Meet", abbreviation: "soci")
    static let performanceTheater = EventType(label: "Performance/Theater", abbreviation: "perf")
    static let gamesCompetition = EventType(label: "Games/Competition", abbreviation: "game")
    static let wellness = EventType(label: "Wellness", abbreviation: "well")
    static let parade = EventType(label: "Parade", abbreviation: "para")
    static let burningCeremony = EventType(label: "Burning Ceremony", abbreviation: "burn")
}