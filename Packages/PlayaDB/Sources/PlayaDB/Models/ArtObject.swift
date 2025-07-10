import Foundation
import CoreLocation
import GRDB

/// Art installation object with complete API field mapping
public struct ArtObject: DataObject, Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "art_objects"
    
    // MARK: - Column Mapping
    
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case uid
        case name
        case year
        case url
        case contactEmail = "contact_email"
        case hometown
        case description
        case artist
        case category
        case program
        case donationLink = "donation_link"
        case locationString = "location_string"
        case locationHour = "location_hour"
        case locationMinute = "location_minute"
        case locationDistance = "location_distance"
        case locationCategory = "location_category"
        case gpsLatitude = "gps_latitude"
        case gpsLongitude = "gps_longitude"
        case guidedTours = "guided_tours"
        case selfGuidedTourMap = "self_guided_tour_map"
    }
    
    // MARK: - Primary Data (from PlayaAPI.Art)
    
    /// Unique identifier
    public var uid: String
    
    /// Name of the art installation
    public var name: String
    
    /// Year of the installation
    public var year: Int
    
    /// Website URL
    public var url: URL?
    
    /// Contact email
    public var contactEmail: String?
    
    /// Artist's hometown
    public var hometown: String?
    
    /// Description of the installation
    public var description: String?
    
    /// Artist name
    public var artist: String?
    
    /// Category of the installation
    public var category: String?
    
    /// Program information
    public var program: String?
    
    /// Donation link
    public var donationLink: URL?
    
    /// Location string description
    public var locationString: String?
    
    // MARK: - Location Data (from PlayaAPI.ArtLocation)
    
    /// Time-based hour position
    public var locationHour: Int?
    
    /// Time-based minute position
    public var locationMinute: Int?
    
    /// Distance from center in feet
    public var locationDistance: Int?
    
    /// Location category
    public var locationCategory: String?
    
    /// GPS latitude
    public var gpsLatitude: Double?
    
    /// GPS longitude
    public var gpsLongitude: Double?
    
    // MARK: - Tour Information
    
    /// Whether guided tours are available
    public var guidedTours: Bool
    
    /// Whether self-guided tour map is available
    public var selfGuidedTourMap: Bool
    
    public init(
        uid: String,
        name: String,
        year: Int,
        url: URL? = nil,
        contactEmail: String? = nil,
        hometown: String? = nil,
        description: String? = nil,
        artist: String? = nil,
        category: String? = nil,
        program: String? = nil,
        donationLink: URL? = nil,
        locationString: String? = nil,
        locationHour: Int? = nil,
        locationMinute: Int? = nil,
        locationDistance: Int? = nil,
        locationCategory: String? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil,
        guidedTours: Bool = false,
        selfGuidedTourMap: Bool = false
    ) {
        self.uid = uid
        self.name = name
        self.year = year
        self.url = url
        self.contactEmail = contactEmail
        self.hometown = hometown
        self.description = description
        self.artist = artist
        self.category = category
        self.program = program
        self.donationLink = donationLink
        self.locationString = locationString
        self.locationHour = locationHour
        self.locationMinute = locationMinute
        self.locationDistance = locationDistance
        self.locationCategory = locationCategory
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
        self.guidedTours = guidedTours
        self.selfGuidedTourMap = selfGuidedTourMap
    }
}

// MARK: - DataObject Protocol Conformance

public extension ArtObject {
    /// DataObject type
    var objectType: DataObjectType { .art }
    
    /// Geographic location from GPS coordinates
    var location: CLLocation? {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    /// Whether this art installation has location information
    var hasLocation: Bool {
        gpsLatitude != nil && gpsLongitude != nil
    }
}

// MARK: - Computed Properties

public extension ArtObject {
    /// Whether this art installation has any images
    var hasImages: Bool {
        !images.isEmpty
    }
    
    /// Whether this art installation has GPS coordinates
    var hasGPSLocation: Bool {
        location != nil
    }
    
    /// Whether this art installation has time-based addressing
    var hasTimeBasedAddress: Bool {
        locationHour != nil
    }
    
    /// Whether this art installation offers any kind of tours
    var hasTours: Bool {
        guidedTours || selfGuidedTourMap
    }
    
    /// Whether this art installation has contact information
    var hasContact: Bool {
        contactEmail != nil || url != nil
    }
    
    /// Whether this art installation has artist information
    var hasArtist: Bool {
        artist != nil && !artist!.isEmpty
    }
    
    /// Whether this art installation has category information
    var hasCategory: Bool {
        category != nil && !category!.isEmpty
    }
    
    /// Time-based address string (e.g., "3:00 & 500'")
    var timeBasedAddress: String? {
        guard let hour = locationHour else { return nil }
        let minute = locationMinute ?? 0
        let distance = locationDistance ?? 0
        
        let timeString = String(format: "%d:%02d", hour, minute)
        return "\(timeString) & \(distance)'"
    }
}

// MARK: - Relationships

public extension ArtObject {
    /// Associated images (would be populated via relationship)
    var images: [ArtImage] {
        // This would be populated by the database layer
        // For now, return empty array
        []
    }
}

/// Art image model
public struct ArtImage: Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "art_images"
    
    // MARK: - Column Mapping
    
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case artId = "art_id"
        case thumbnailUrl = "thumbnail_url"
        case galleryRef = "gallery_ref"
    }
    /// Auto-incremented ID
    public var id: Int64?
    
    /// Reference to parent art object
    public var artId: String
    
    /// Thumbnail image URL
    public var thumbnailUrl: URL?
    
    /// Gallery reference
    public var galleryRef: String?
    
    public init(
        id: Int64? = nil,
        artId: String,
        thumbnailUrl: URL? = nil,
        galleryRef: String? = nil
    ) {
        self.id = id
        self.artId = artId
        self.thumbnailUrl = thumbnailUrl
        self.galleryRef = galleryRef
    }
    
    // Update id after insertion
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Computed Properties

public extension ArtImage {
    /// Whether this image has a thumbnail URL
    var hasThumbnail: Bool {
        thumbnailUrl != nil
    }
    
    /// Whether this image has a gallery reference
    var hasGalleryRef: Bool {
        galleryRef != nil && !galleryRef!.isEmpty
    }
}