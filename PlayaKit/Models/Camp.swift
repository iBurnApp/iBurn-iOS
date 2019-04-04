//
//  Camp.swift
//  PlayaKit
//
//  Created by Chris Ballinger on 12/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

public class Camp: APIObject, CampProtocol {
    
    // MARK: CampProtocol
    
    public var burnerMapLocation: CampLocation?
    public var hometown: String?
    public var campLocation: CampLocation?
    
    // MARK: APIProtocol
    
    public override var location: PlayaLocation? {
        get {
            return campLocation
        }
        set {
            self.campLocation = newValue as? CampLocation
        }
    }
    
    // MARK: Init
    
    public override init(title: String,
                         year: Int = Calendar.current.component(.year, from: Date()),
                         uniqueId: String = UUID().uuidString) {
        super.init(title: title, year: year, uniqueId: uniqueId)
    }
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case location
        case burnerMapLocation = "burnermap_location"
        case hometown
    }
    
    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let codingKeys = Camp.CodingKeys.self
        let container = try decoder.container(keyedBy: codingKeys)
        hometown = try container.decodeIfPresent(String.self, forKey: .hometown)
        do {
            campLocation = try container.decodeIfPresent(CampLocation.self, forKey: .location)
            burnerMapLocation = try container.decodeIfPresent(CampLocation.self, forKey: .burnerMapLocation)
        } catch {
            //DDLogWarn("Error decoding camp location \(yapKey) \(error)")
        }
    }
}
