import Foundation

/// Represents a specific time occurrence of an event
public struct EventOccurrence: Codable, Hashable, Sendable {
    public let startTime: Date
    public let endTime: Date
    
    public init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Computed Properties

public extension EventOccurrence {
    /// Duration of the event occurrence in seconds
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    /// Whether the event occurrence is currently happening
    var isCurrentlyHappening: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    /// Whether the event occurrence has already ended
    var hasEnded: Bool {
        Date() > endTime
    }
    
    /// Whether the event occurrence is in the future
    var isFuture: Bool {
        Date() < startTime
    }
}