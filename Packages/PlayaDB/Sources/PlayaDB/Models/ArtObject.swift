import Foundation
import CoreLocation
import SharingGRDB

/// Art installation object with complete API field mapping
@Table("art_objects")
public struct ArtObject: DataObject {
    // MARK: - Primary Data (from PlayaAPI.Art)
    
    /// Unique identifier (auto-mapped to uid column)
    public var uid: String
    
    /// Name of the art installation (auto-mapped to name column)
    public var name: String
    
    /// Year of the installation (auto-mapped to year column)
    public var year: Int
    
    /// Website URL (auto-mapped to url column)
    public var url: URL?
    
    /// Contact email (auto-mapped to contact_email column)
    public var contactEmail: String?
    
    /// Artist's hometown (auto-mapped to hometown column)
    public var hometown: String?
    
    /// Description of the installation (auto-mapped to description column)
    public var description: String?
    
    /// Artist name (auto-mapped to artist column)
    public var artist: String?
    
    /// Category of the installation (auto-mapped to category column)
    public var category: String?
    
    /// Program information (auto-mapped to program column)
    public var program: String?
    
    /// Donation link (auto-mapped to donation_link column)
    public var donationLink: URL?
    
    /// Location string description (auto-mapped to location_string column)
    public var locationString: String?
    
    // MARK: - Location Data (from PlayaAPI.ArtLocation)
    
    /// Time-based hour position (auto-mapped to location_hour column)
    public var locationHour: Int?
    
    /// Time-based minute position (auto-mapped to location_minute column)
    public var locationMinute: Int?
    
    /// Distance from center in feet (auto-mapped to location_distance column)
    public var locationDistance: Int?
    
    /// Location category (auto-mapped to location_category column)
    public var locationCategory: String?
    
    /// GPS latitude (auto-mapped to gps_latitude column)
    public var gpsLatitude: Double?
    
    /// GPS longitude (auto-mapped to gps_longitude column)
    public var gpsLongitude: Double?
    
    // MARK: - Tour Information
    
    /// Whether guided tours are available (auto-mapped to guided_tours column)
    public var guidedTours: Bool
    
    /// Whether self-guided tour map is available (auto-mapped to self_guided_tour_map column)
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
@Table("art_images")
public struct ArtImage {
    /// Auto-incremented ID (auto-mapped to id column)
    public var id: Int64?
    
    /// Reference to parent art object (auto-mapped to art_id column)
    public var artId: String
    
    /// Thumbnail image URL (auto-mapped to thumbnail_url column)
    public var thumbnailUrl: URL?
    
    /// Gallery reference (auto-mapped to gallery_ref column)
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