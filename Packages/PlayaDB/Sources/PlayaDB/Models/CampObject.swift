import Foundation
import CoreLocation
import SharingGRDB

/// Theme camp object with complete API field mapping
@Table("camp_objects")
public struct CampObject: DataObject {
    // MARK: - Primary Data (from PlayaAPI.Camp)
    
    /// Unique identifier (auto-mapped to uid column)
    public var uid: String
    
    /// Name of the camp (auto-mapped to name column)
    public var name: String
    
    /// Year of the camp (auto-mapped to year column)
    public var year: Int
    
    /// Website URL (auto-mapped to url column)
    public var url: URL?
    
    /// Contact email (auto-mapped to contact_email column)
    public var contactEmail: String?
    
    /// Camp's hometown (auto-mapped to hometown column)
    public var hometown: String?
    
    /// Description of the camp (auto-mapped to description column)
    public var description: String?
    
    /// Landmark information (auto-mapped to landmark column)
    public var landmark: String?
    
    /// Location string description (auto-mapped to location_string column)
    public var locationString: String?
    
    // MARK: - Location Data (from PlayaAPI.CampLocation)
    
    /// Location string (auto-mapped to location_location_string column)
    public var locationLocationString: String?
    
    /// Frontage information (auto-mapped to frontage column)
    public var frontage: String?
    
    /// Street intersection (auto-mapped to intersection column)
    public var intersection: String?
    
    /// Intersection type (auto-mapped to intersection_type column)
    public var intersectionType: String?
    
    /// Camp dimensions (auto-mapped to dimensions column)
    public var dimensions: String?
    
    /// Exact location details (auto-mapped to exact_location column)
    public var exactLocation: String?
    
    /// GPS latitude (auto-mapped to gps_latitude column)
    public var gpsLatitude: Double?
    
    /// GPS longitude (auto-mapped to gps_longitude column)
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
@Table("camp_images")
public struct CampImage {
    /// Auto-incremented ID (auto-mapped to id column)
    public var id: Int64?
    
    /// Reference to parent camp object (auto-mapped to camp_id column)
    public var campId: String
    
    /// Thumbnail image URL (auto-mapped to thumbnail_url column)
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
}

// MARK: - Computed Properties

public extension CampImage {
    /// Whether this image has a thumbnail URL
    var hasThumbnail: Bool {
        thumbnailUrl != nil
    }
}