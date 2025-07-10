import Foundation
import CoreLocation
import GRDB

/// Theme camp object with complete API field mapping
public struct CampObject: DataObject, Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "camp_objects"
    
    // MARK: - Column Mapping
    
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case uid
        case name
        case year
        case url
        case contactEmail = "contact_email"
        case hometown
        case description
        case landmark
        case locationString = "location_string"
        case locationLocationString = "location_location_string"
        case frontage
        case intersection
        case intersectionType = "intersection_type"
        case dimensions
        case exactLocation = "exact_location"
        case gpsLatitude = "gps_latitude"
        case gpsLongitude = "gps_longitude"
    }
    
    // MARK: - Primary Data (from PlayaAPI.Camp)
    
    /// Unique identifier
    public var uid: String
    
    /// Name of the camp
    public var name: String
    
    /// Year of the camp
    public var year: Int
    
    /// Website URL
    public var url: URL?
    
    /// Contact email
    public var contactEmail: String?
    
    /// Camp's hometown
    public var hometown: String?
    
    /// Description of the camp
    public var description: String?
    
    /// Landmark information
    public var landmark: String?
    
    /// Location string description
    public var locationString: String?
    
    // MARK: - Location Data (from PlayaAPI.CampLocation)
    
    /// Location string
    public var locationLocationString: String?
    
    /// Frontage information
    public var frontage: String?
    
    /// Street intersection
    public var intersection: String?
    
    /// Intersection type
    public var intersectionType: String?
    
    /// Camp dimensions
    public var dimensions: String?
    
    /// Exact location details
    public var exactLocation: String?
    
    /// GPS latitude
    public var gpsLatitude: Double?
    
    /// GPS longitude
    public var gpsLongitude: Double?
    
    public init(
        uid: String,
        name: String,
        year: Int,
        url: URL? = nil,
        contactEmail: String? = nil,
        hometown: String? = nil,
        description: String? = nil,
        landmark: String? = nil,
        locationString: String? = nil,
        locationLocationString: String? = nil,
        frontage: String? = nil,
        intersection: String? = nil,
        intersectionType: String? = nil,
        dimensions: String? = nil,
        exactLocation: String? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil
    ) {
        self.uid = uid
        self.name = name
        self.year = year
        self.url = url
        self.contactEmail = contactEmail
        self.hometown = hometown
        self.description = description
        self.landmark = landmark
        self.locationString = locationString
        self.locationLocationString = locationLocationString
        self.frontage = frontage
        self.intersection = intersection
        self.intersectionType = intersectionType
        self.dimensions = dimensions
        self.exactLocation = exactLocation
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}

// MARK: - DataObject Protocol Conformance

public extension CampObject {
    /// DataObject type
    var objectType: DataObjectType { .camp }
    
    /// Geographic location from GPS coordinates
    var location: CLLocation? {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    /// Whether this camp has location information
    var hasLocation: Bool {
        gpsLatitude != nil && gpsLongitude != nil
    }
}

// MARK: - Computed Properties

public extension CampObject {
    /// Whether this camp has any images
    var hasImages: Bool {
        !images.isEmpty
    }
    
    /// Whether this camp has GPS coordinates
    var hasGPSLocation: Bool {
        location != nil
    }
    
    /// Whether this camp has complete addressing
    var hasCompleteAddress: Bool {
        frontage != nil && intersection != nil
    }
    
    /// Whether this camp has a distinctive landmark
    var hasLandmark: Bool {
        landmark != nil && !landmark!.isEmpty
    }
    
    /// Whether this camp has contact information
    var hasContact: Bool {
        contactEmail != nil || url != nil
    }
    
    /// Whether this camp has hometown information
    var hasHometown: Bool {
        hometown != nil && !hometown!.isEmpty
    }
    
    /// Whether this camp has dimension information
    var hasDimensions: Bool {
        dimensions != nil && !dimensions!.isEmpty
    }
    
    /// Whether this camp has exact location details
    var hasExactLocation: Bool {
        exactLocation != nil && !exactLocation!.isEmpty
    }
    
    /// Whether this camp has intersection information
    var hasIntersection: Bool {
        intersection != nil && !intersection!.isEmpty
    }
    
    /// Whether this camp has frontage information
    var hasFrontage: Bool {
        frontage != nil && !frontage!.isEmpty
    }
    
    /// Combined location information string
    var combinedLocationString: String? {
        var parts: [String] = []
        
        if let locationString = locationString {
            parts.append(locationString)
        }
        
        if let intersection = intersection {
            parts.append(intersection)
        }
        
        if let frontage = frontage {
            parts.append("Frontage: \(frontage)")
        }
        
        if let dimensions = dimensions {
            parts.append("Dimensions: \(dimensions)")
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

// MARK: - Relationships

public extension CampObject {
    /// Associated images (would be populated via relationship)
    var images: [CampImage] {
        // This would be populated by the database layer
        // For now, return empty array
        []
    }
}

/// Camp image model
public struct CampImage: Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "camp_images"
    
    // MARK: - Column Mapping
    
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case campId = "camp_id"
        case thumbnailUrl = "thumbnail_url"
    }
    /// Auto-incremented ID
    public var id: Int64?
    
    /// Reference to parent camp object
    public var campId: String
    
    /// Thumbnail image URL
    public var thumbnailUrl: URL?
    
    public init(
        id: Int64? = nil,
        campId: String,
        thumbnailUrl: URL? = nil
    ) {
        self.id = id
        self.campId = campId
        self.thumbnailUrl = thumbnailUrl
    }
    
    // Update id after insertion
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Computed Properties

public extension CampImage {
    /// Whether this image has a thumbnail URL
    var hasThumbnail: Bool {
        thumbnailUrl != nil
    }
}