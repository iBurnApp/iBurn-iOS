//
//  APIObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import YapDatabase
import CocoaLumberjack

public class APIObject: YapObject, APIProtocol, Codable {
    public var uniqueId: String {
        return self.yapKey
    }
    public var location: PlayaLocation?
    public var year: Int = 0
    public var title: String = ""
    public var detailDescription: String?
    public var email: String?
    public var urlString: String?
    
    public var url: URL? {
        if let urlString = urlString {
            return URL(string: urlString)
        } else {
            return nil
        }
    }
    
    public init(title: String,
                year: Int = Calendar.current.component(.year, from: Date()),
                yapKey: String = UUID().uuidString) {
        self.title = title
        self.year = year
        super.init(yapKey: yapKey)
    }
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case yapKey = "uid"
        case title = "name"
        case detailDescription = "description"
        case email = "contact_email"
        case urlString = "url"
        case year = "year"
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let yapKey = try container.decode(String.self, forKey: .yapKey)
        super.init(yapKey: yapKey)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        detailDescription = try container.decodeIfPresent(String.self, forKey: .detailDescription)
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
        year = try container.decode(Int.self, forKey: .year)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(yapKey, forKey: .yapKey)
        try container.encode(title, forKey: .title)
        try container.encode(year, forKey: .year)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(detailDescription, forKey: .detailDescription)
        try container.encodeIfPresent(urlString, forKey: .urlString)
    }
}

public class CampObject: APIObject, CampProtocol {
    public var campLocation: CampLocation?
    public override var location: PlayaLocation? {
        get {
            return campLocation
        }
        set {
            self.campLocation = newValue as? CampLocation
        }
    }
    
    public override init(title: String,
                year: Int = Calendar.current.component(.year, from: Date()),
                yapKey: String = UUID().uuidString) {
        super.init(title: title, year: year, yapKey: yapKey)
    }
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case location
        case burnerMapLocation = "burnermap_location"
        case hometown
    }
    
    public var burnerMapLocation: CampLocation?
    
    public var hometown: String?
    
    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let codingKeys = CampObject.CodingKeys.self
        let container = try decoder.container(keyedBy: codingKeys)
        hometown = try container.decodeIfPresent(String.self, forKey: .hometown)
        do {
            campLocation = try container.decodeIfPresent(CampLocation.self, forKey: .location)
            burnerMapLocation = try container.decodeIfPresent(CampLocation.self, forKey: .burnerMapLocation)
        } catch let error {
            DDLogWarn("Error decoding camp location \(yapKey) \(error)")
        }
    }
}

public class ArtObject: APIObject, ArtProtocol {
    public override var location: PlayaLocation? {
        get {
            return artLocation
        }
        set {
            self.artLocation = newValue as? ArtLocation
        }
    }
    public var artLocation: ArtLocation?
    public var artistName: String = ""
    public var artistHometown: String = ""
    public var donationURL: URL?
    private var imagesLocations: [ImageLocation] = []
    public var images: [URL] {
        return ImageLocation.URLs(imageLocations: imagesLocations)
    }
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case artistName = "artist"
        case artistHometown = "hometown"
        case images
        case location
        case donationURL = "donation_link"
    }
    
    private struct ImageLocation: Codable {
        let thumbnailURLString: String
        var thumbnailURL: URL? {
            return URL(string: thumbnailURLString)
        }
        static func URLs(imageLocations: [ImageLocation]) -> [URL] {
            var imageURLs: [URL] = []
            imageLocations.forEach {
                if let url = $0.thumbnailURL {
                    imageURLs.append(url)
                }
            }
            return imageURLs
        }
        
        // MARK: Codable
        enum CodingKeys: String, CodingKey {
            case thumbnailURLString = "thumbnail_url"
        }
    }
    
    public init(title: String,
                year: Int = Calendar.current.component(.year, from: Date()),
                artistName: String,
                artistHometown: String,
                yapKey: String = UUID().uuidString) {
        self.artistName = artistName
        self.artistHometown = artistHometown
        super.init(title: title, year: year, yapKey: yapKey)
    }
    
    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let codingKeys = ArtObject.CodingKeys.self
        let container = try decoder.container(keyedBy: codingKeys)
        // Rarely there will be a null artist name or hometown
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName) ?? ""
        artistHometown = try container.decodeIfPresent(String.self, forKey: .artistHometown) ?? ""
        do {
            artLocation = try container.decodeIfPresent(ArtLocation.self, forKey: .location)
        } catch let error {
            DDLogWarn("Error decoding artLocation \(yapKey) \(error)")
        }
        do {
            donationURL = try container.decodeIfPresent(URL.self, forKey: .donationURL)
        } catch let error {
            DDLogWarn("Error decoding donationURL \(yapKey) \(error)")
        }
        imagesLocations = try container.decodeIfPresent([ImageLocation].self, forKey: .images) ?? []
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        let codingKeys = ArtObject.CodingKeys.self
        var container = encoder.container(keyedBy: codingKeys)
        try container.encode(artistName, forKey: .artistName)
        try container.encode(artistHometown, forKey: .artistHometown)
        try container.encodeIfPresent(artLocation, forKey: .location)
        try container.encodeIfPresent(donationURL, forKey: .donationURL)
        try container.encode(imagesLocations, forKey: .images)
    }
}

public class EventObject: APIObject, EventProtocol {
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case hostedByCamp = "hosted_by_camp"
        case hostedByArt = "located_at_art"
        case title
        case eventType = "event_type"
        case occurrences = "occurrence_set"
    }
    
    private struct EventTypeInternal: Codable {
        static let unknown = EventTypeInternal(type: .unknown)
        let type: EventType
        private enum CodingKeys: String, CodingKey {
            case type = "abbr"
        }
    }
    
    public func hostedByCamp(_ transaction: YapDatabaseReadTransaction) -> CampProtocol? {
        guard let yapKey = self.hostedByCamp else { return nil }
        let camp = CampObject.fetch(transaction, yapKey: yapKey)
        return camp
    }
    
    public func hostedByArt(_ transaction: YapDatabaseReadTransaction) -> ArtProtocol? {
        guard let yapKey = self.hostedByArt else { return nil }
        let art = ArtObject.fetch(transaction, yapKey: yapKey)
        return art
    }
    
    /// Unique id of camp host
    private var hostedByCamp: String?
    /// Unique id of art host
    private var hostedByArt: String?
    
    public var occurrences: [EventOccurrence] = []
    private var eventTypeInternal: EventTypeInternal = EventTypeInternal.unknown
    public var eventType: EventType {
        return eventTypeInternal.type
    }
    
    public override init(title: String,
                year: Int = Calendar.current.component(.year, from: Date()),
                yapKey: String = UUID().uuidString) {
        super.init(title: title, year: year, yapKey: yapKey)
    }
    
    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let codingKeys = EventObject.CodingKeys.self
        let container = try decoder.container(keyedBy: codingKeys)
        
        do {
            eventTypeInternal = try container.decode(EventTypeInternal.self, forKey: .eventType)
        } catch let error {
            DDLogWarn("Error decoding event type for \(yapKey) \(error)")
        }
        do {
            occurrences = try container.decodeIfPresent([EventOccurrence].self, forKey: .occurrences) ?? []
        } catch let error {
            DDLogWarn("Error decoding event occurrences for \(yapKey) \(error)")
        }
        title = try container.decode(String.self, forKey: .title)
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        let codingKeys = EventObject.CodingKeys.self
        var container = encoder.container(keyedBy: codingKeys)
        try container.encodeIfPresent(hostedByCamp, forKey: .hostedByCamp)
        try container.encodeIfPresent(hostedByArt, forKey: .hostedByArt)
        try container.encode(eventTypeInternal, forKey: .eventType)
        try container.encode(occurrences, forKey: .occurrences)
    }
}
