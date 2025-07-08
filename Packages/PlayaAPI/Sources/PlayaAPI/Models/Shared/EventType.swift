import Foundation

/// Event type abbreviations used by the Burning Man API
public enum EventType: String, Codable, CaseIterable, Sendable {
    /// Ritual/Ceremony
    case ritualCeremony = "cere"
    
    /// Gathering/Party
    case gatheringParty = "prty"
    
    /// Class/Workshop
    case classWorkshop = "work"
    
    /// Games
    case games = "game"
    
    /// Food & Drink
    case foodAndDrink = "food"
    
    /// Mature Audiences
    case matureAudiences = "adlt"
    
    /// Performance
    case performance = "perf"
    
    /// Self Care
    case selfCare = "care"
    
    /// Fire/Spectacle
    case fireSpectacle = "fire"
    
    /// Parade
    case parade = "para"
    
    /// For Kids
    case forKids = "kid"
    
    /// None
    case none = "none"
    
    /// Miscellaneous
    case miscellaneous = "othr"
    
    /// Arts & Crafts
    case artsAndCrafts = "arts"
    
    /// Coffee/Tea
    case coffeeTea = "tea"
    
    /// Healing/Massage/Spa
    case healingMassageSpa = "heal"
    
    /// LGBTQIA2S+
    case lgbtqia2s = "LGBT"
    
    /// Live Music
    case liveMusic = "live"
    
    /// Diversity & Inclusion
    case diversityInclusion = "RIDE"
    
    /// Repair
    case repair = "repr"
    
    /// Sustainability/Greening Your Burn
    case sustainabilityGreening = "sust"
    
    /// Yoga/Movement/Fitness
    case yogaMovementFitness = "yoga"
}

/// Represents the type/category of an event
public struct EventTypeInfo: Codable, Hashable, Sendable {
    public let label: String
    public let type: EventType
    
    public init(label: String, type: EventType) {
        self.label = label
        self.type = type
    }
    
    enum CodingKeys: String, CodingKey {
        case label
        case type = "abbr"
    }
}
