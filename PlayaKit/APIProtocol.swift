//
//  APIProtocol.swift
//  PlayaKit
//
//  Created by Chris Ballinger on 9/30/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

public enum DecodeError: Error {
    case dateFormatting
}

public protocol APIProtocol {
    /// unique 'uid' returned from PlayaEvents API
    var uniqueId: String { get }
    var title: String { get }
    var detailDescription: String? { get }
    var email: String? { get }
    var url: URL? { get }
    var location: PlayaLocation? { get }
    var year: Int { get }
}

public protocol CampProtocol: APIProtocol {
    var campLocation: CampLocation? { get }
    var burnerMapLocation: CampLocation? { get }
    var hometown: String? { get }
}

//public enum ArtCategory: String {
//    case openPlaya = "Open Playa"
//    case cafeArt = "Cafe Art"
//    case plaza = "Plaza"
//    case mobile = "Mobile"
//    case keyhole = "Keyhole"
//}

public protocol ArtProtocol: APIProtocol {
    var artLocation: ArtLocation? { get }
    var artistName: String { get }
    var artistHometown: String { get }
    var images: [URL] { get }
    var donationURL: URL? { get }
    /// e.g. "Open Playa", "Cafe Art", "Plaza", or "Mobile"
    // var category: ArtCategory { get }
}

private extension DateFormatter {
    static var apiFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter.timeZone = TimeZone(abbreviation: "PST")
        return dateFormatter
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
}

public protocol EventProtocol: APIProtocol {
    var occurrences: [EventOccurrence] { get }
    func hostedByCamp(_ transaction: YapDatabaseReadTransaction) -> CampProtocol?
    func hostedByArt(_ transaction: YapDatabaseReadTransaction) -> ArtProtocol?
    var eventType: EventType { get }
}
