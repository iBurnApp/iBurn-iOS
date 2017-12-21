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


public class APIObject: APIProtocol, Codable {
   
    // MARK: APIProtocol Properties
    
    public var uniqueId: String
    public var location: PlayaLocation?
    public var year: Int = 0
    public var title: String = ""
    public var detailDescription: String?
    public var email: String?
    public var url: URL?

    // MARK: Init
    
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
        case url
        case year = "year"
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uniqueId = try container.decode(String.self, forKey: .uniqueId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        detailDescription = try container.decodeIfPresent(String.self, forKey: .detailDescription)
        if let urlString = try container.decodeIfPresent(String.self, forKey: .url) {
            url = URL(string: urlString)
        }
        year = try container.decode(Int.self, forKey: .year)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uniqueId, forKey: .uniqueId)
        try container.encode(title, forKey: .title)
        try container.encode(year, forKey: .year)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(detailDescription, forKey: .detailDescription)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url)
    }
}


extension APIObject: YapObjectProtocol {
    public var yapKey: String {
        return uniqueId
    }
    
    public var yapCollection: String {
        return type(of: self).defaultYapCollection
    }
    
    public static var defaultYapCollection: String {
        return NSStringFromClass(self)
    }
    
    /// Fetches from class's default collection `defaultYapCollection`
    public static func fetch(_ transaction: YapDatabaseReadTransaction, key: String) -> Self? {
        let collection = self.defaultYapCollection
        let object = fetch(transaction, key: key, collection: collection)
        return object
    }
    
    public static func fetch(_ transaction: YapDatabaseReadTransaction, key: String, collection: String) -> Self? {
        let object = APIObject.fetch(transaction, key: key, collection: collection, ofType: self)
        return object
    }
    
    public func refetch(_ transaction: YapDatabaseReadTransaction) -> Self? {
        let object = refetch(transaction, ofType: type(of: self))
        return object
    }
}
