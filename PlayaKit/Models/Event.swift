//
//  Event.swift
//  PlayaKit
//
//  Created by Chris Ballinger on 12/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

public class Event: APIObject, EventProtocol {
    
    // MARK: Private Properties
    
    /// Unique id of camp host
    public var hostedByCamp: String?
    /// Unique id of art host
    public var hostedByArt: String?
    private var eventTypeInternal: EventTypeInternal = EventTypeInternal.unknown
    
    // MARK: Init
    
    public override init(title: String,
                         year: Int = Calendar.current.component(.year, from: Date()),
                         uniqueId: String = UUID().uuidString) {
        super.init(title: title, year: year, uniqueId: uniqueId)
    }
    
    // MARK: EventProtocol
    
    public var occurrences: [EventOccurrence] = []
    
    public var eventType: EventType {
        return eventTypeInternal.type
    }
    
    // MARK: Codable
    
    public enum CodingKeys: String, CodingKey {
        case hostedByCamp = "hosted_by_camp"
        case hostedByArt = "located_at_art"
        case title
        case eventType = "event_type"
        case occurrences = "occurrence_set"
    }
    
    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let codingKeys = Event.CodingKeys.self
        let container = try decoder.container(keyedBy: codingKeys)
        
        do {
            eventTypeInternal = try container.decode(EventTypeInternal.self, forKey: .eventType)
        } catch let error {
            debugPrint("Error decoding event type for \(uniqueId) \(error)")
        }
        do {
            occurrences = try container.decodeIfPresent([EventOccurrence].self, forKey: .occurrences) ?? []
        } catch let error {
            debugPrint("Error decoding event occurrences for \(uniqueId) \(error)")
        }
        title = try container.decode(String.self, forKey: .title)
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        let codingKeys = Event.CodingKeys.self
        var container = encoder.container(keyedBy: codingKeys)
        try container.encodeIfPresent(hostedByCamp, forKey: .hostedByCamp)
        try container.encodeIfPresent(hostedByArt, forKey: .hostedByArt)
        try container.encode(eventTypeInternal, forKey: .eventType)
        try container.encode(occurrences, forKey: .occurrences)
    }
}

public struct EventOccurrence: Codable {
    public let start: Date
    public let end: Date
    private static let dateFormatter = DateFormatter.apiFormatter
    
    // MARK: Codable
    private enum CodingKeys: String, CodingKey {
        case start
        case end
        case startString = "start_time"
        case endString = "end_time"
    }
    
    public func encode(to encoder: Encoder) throws {
        let codingKeys = EventOccurrence.CodingKeys.self
        var container = encoder.container(keyedBy: codingKeys)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
    }
    
    
    public init(from decoder: Decoder) throws {
        let codingKeys = EventOccurrence.CodingKeys.self
        let container = try decoder.container(keyedBy: codingKeys)
        
        // If possible take the fast path
        if let start = try container.decodeIfPresent(Date.self, forKey: .start),
            let end = try container.decodeIfPresent(Date.self, forKey: .end) {
            self.start = start
            self.end = end
        } else if let startString = try container.decodeIfPresent(String.self, forKey: .startString),
            let endString = try container.decodeIfPresent(String.self, forKey: .endString),
            let start = EventOccurrence.dateFormatter.date(from: startString),
            let end = EventOccurrence.dateFormatter.date(from: endString) {
            // Raw API responses
            // 2017-08-29T10:00:00-07:00
            self.start = start
            self.end = end
        } else {
            throw DecodeError.dateFormatting
        }
    }
}

public enum EventType: String, Codable {
    case unknown
    case workshop = "work"
    case performance = "perf"
    case support = "care"
    case party = "prty"
    case ceremony = "cere"
    case game
    case fire
    case adult = "adlt"
    case kid
    case parade = "para"
    case food
    case other = "othr"
}

private struct EventTypeInternal: Codable {
    static let unknown = EventTypeInternal(type: .unknown)
    let type: EventType
    private enum CodingKeys: String, CodingKey {
        case type = "abbr"
    }
}

private extension DateFormatter {
    static var apiFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter.timeZone = TimeZone(abbreviation: "PST")
        return dateFormatter
    }
}
