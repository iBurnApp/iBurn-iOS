//
//  APIObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

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
        do {
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        } catch {
            // really?
            do {
                if let titleNumber = try container.decodeIfPresent(Decimal.self, forKey: .title) {
                    self.title = "\(titleNumber)"
                }
            } catch {
                debugPrint("This item deserves no title \(error)")
            }
        }
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
