import Foundation

/// Represents a theme camp from the Burning Man API
public struct Camp: Codable, Hashable, Sendable {
    public let uid: CampID
    public let name: String
    public let year: Int
    public let url: URL?
    public let contactEmail: String?
    public let hometown: String?
    public let description: String?
    public let landmark: String?
    public let location: CampLocation?
    public let locationString: String?
    public let images: [CampImage]
    
    public init(
        uid: CampID,
        name: String,
        year: Int,
        url: URL? = nil,
        contactEmail: String? = nil,
        hometown: String? = nil,
        description: String? = nil,
        landmark: String? = nil,
        location: CampLocation? = nil,
        locationString: String? = nil,
        images: [CampImage] = []
    ) {
        self.uid = uid
        self.name = name
        self.year = year
        self.url = url
        self.contactEmail = contactEmail
        self.hometown = hometown
        self.description = description
        self.landmark = landmark
        self.location = location
        self.locationString = locationString
        self.images = images
    }
}

// MARK: - Computed Properties

public extension Camp {
    /// Whether this camp has any images
    var hasImages: Bool {
        !images.isEmpty
    }
    
    /// Whether this camp has location information
    var hasLocation: Bool {
        location != nil || locationString != nil
    }
    
    /// Whether this camp has detailed location information
    var hasDetailedLocation: Bool {
        location?.hasCompleteAddress == true
    }
    
    /// Whether this camp has a distinctive landmark
    var hasLandmark: Bool {
        landmark != nil && !landmark!.isEmpty
    }
    
    /// Whether this camp has contact information
    var hasContact: Bool {
        contactEmail != nil || url != nil
    }
    
    /// Whether this camp has a description
    var hasDescription: Bool {
        description != nil && !description!.isEmpty
    }
}