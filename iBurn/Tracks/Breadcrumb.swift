//
//  Breadcrumb.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation
import GRDB

struct Breadcrumb {
    var id: Int64?
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    private var latitude: Double
    private var longitude: Double
    var timestamp: Date
    
    static func from(_ location: CLLocation) -> Breadcrumb {
        return Breadcrumb(id: nil, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, timestamp: location.timestamp)
    }
}

// MARK: - Persistence
// Turn Player into a Codable Record.
// See https://github.com/groue/GRDB.swift/blob/master/README.md#records
extension Breadcrumb: Codable, FetchableRecord, MutablePersistableRecord {
    // Define database columns from CodingKeys
    internal enum Columns {
        static let id = Column(CodingKeys.id)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let timestamp = Column(CodingKeys.timestamp)
    }
    
    // Update a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
