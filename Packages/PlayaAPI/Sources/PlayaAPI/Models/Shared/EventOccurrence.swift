import Foundation

/// Represents a specific time occurrence of an event
public struct EventOccurrence: Codable, Hashable, Sendable {
    public let startTime: Date?
    public let endTime: Date?
    
    public init(startTime: Date? = nil, endTime: Date? = nil) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Computed Properties

public extension EventOccurrence {
    /// Duration of the event occurrence in seconds
    var duration: TimeInterval? {
        guard let startTime = startTime, let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Whether the event occurrence is currently happening
    func isCurrentlyHappening(_ now: Date = Date()) -> Bool {
        guard let startTime = startTime, let endTime = endTime else { return false }
        return now >= startTime && now <= endTime
    }
    
    /// Whether the event occurrence has already ended
    func hasEnded(_ now: Date = Date()) -> Bool {
        guard let endTime = endTime else { return false }
        return now > endTime
    }
    
    /// Whether the event occurrence is in the future
    func isFuture(_ now: Date = Date()) -> Bool {
        guard let startTime = startTime else { return false }
        return now < startTime
    }
    
    /// Whether this occurrence has valid time information
    var hasValidTimes: Bool {
        startTime != nil && endTime != nil
    }
}