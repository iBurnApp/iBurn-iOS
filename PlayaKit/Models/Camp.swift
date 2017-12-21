//
//  Camp.swift
//  PlayaKit
//
//  Created by Chris Ballinger on 12/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import CocoaLumberjack

public class Camp: APIObject, CampProtocol {
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
                         uniqueId: String = UUID().uuidString) {
        super.init(title: title, year: year, uniqueId: uniqueId)
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
