//
//  PlayaLocation.swift
//  PlayaKit
//
//  Created by Chris Ballinger on 9/30/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

public protocol PlayaLocation {
    /// e.g. "J & 4:15" for camps or "10:20 3200', Open Playa" for art
    var address: String { get }
    var coordinate: CLLocationCoordinate2D { get }
}

public struct ArtLocation: PlayaLocation, Codable {
    /// e.g. "10:20 3200', Open Playa"
    public let address: String
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
    private let latitude: CLLocationDegrees
    private let longitude: CLLocationDegrees
    
    /// e.g. "5"
    public let hour: Int
    /// e.g. "19"
    public let minute: Int
    /// e.g. "2260" in meters
    public let distance: CLLocationDistance
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case address = "string"
        case hour
        case minute
        case distance
        case latitude = "gps_latitude"
        case longitude = "gps_longitude"
    }
}

public struct CampLocation: PlayaLocation, Codable {
    /// e.g. "J & 4:15"
    public let address: String
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
    private let latitude: CLLocationDegrees
    private let longitude: CLLocationDegrees
    
    /// e.g. "J"
    public let frontage: String?
    /// e.g. "4:15"
    public let intersection: String?
    /// e.g. "100 x 50"
    public let dimensions: String?
    
    public enum IntersectionType: String, Codable {
        case and = "&"
        case at = "@"
    }
    /// e.g. "&" or "@"
    public let intersectionType: IntersectionType?
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case address = "string"
        case frontage
        case intersection
        case intersectionType = "intersection_type"
        case dimensions
        case latitude = "gps_latitude"
        case longitude = "gps_longitude"
    }
}
