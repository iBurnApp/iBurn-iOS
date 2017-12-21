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


public class APIObject: YapObjectProtocol, APIProtocol, Codable {
    public var uniqueId: String
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
                uniqueId: String = UUID().uuidString) {
        self.title = title
        self.year = year
        self.uniqueId = uniqueId
    }
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case uniqueId = "uid"
        case title = "name"
        case detailDescription = "description"
        case email = "contact_email"
        case urlString = "url"
        case year = "year"
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uniqueId = try container.decode(String.self, forKey: .uniqueId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        detailDescription = try container.decodeIfPresent(String.self, forKey: .detailDescription)
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
        year = try container.decode(Int.self, forKey: .year)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uniqueId, forKey: .uniqueId)
        try container.encode(title, forKey: .title)
        try container.encode(year, forKey: .year)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(detailDescription, forKey: .detailDescription)
        try container.encodeIfPresent(urlString, forKey: .urlString)
    }
}


extension APIObject: YapObjectFetching {
    /// Fetches from class's default collection `defaultYapCollection`
    public static func fetch(_ transaction: YapDatabaseReadTransaction, yapKey: String) -> Self? {
        let collection = self.defaultYapCollection
        let yapKeyCollection = YapKeyCollection(key: yapKey, collection: collection)
        let object = fetch(transaction, yapKeyCollection: yapKeyCollection)
        return object
    }
    
    public static func fetch(_ transaction: YapDatabaseReadTransaction, yapKeyCollection: YapKeyCollection) -> Self? {
        let object = APIObject.fetch(transaction, yapKeyCollection: yapKeyCollection, ofType: self)
        return object
    }
    
    public func refetch(_ transaction: YapDatabaseReadTransaction) -> Self? {
        let object = refetch(transaction, ofType: type(of: self))
        return object
    }
}

extension APIObject: YapStorable {
    
    public var yapKeyCollection: YapKeyCollection {
        return YapKeyCollection(key: uniqueId, collection: yapCollection)
    }
    
    open var yapCollection: String {
        return type(of: self).defaultYapCollection
    }
    
    open static var defaultYapCollection: String {
        return NSStringFromClass(self)
    }
}
