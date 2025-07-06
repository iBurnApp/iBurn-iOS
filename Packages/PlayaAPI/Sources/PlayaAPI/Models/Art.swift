import Foundation

/// Represents an art installation from the Burning Man API
public struct Art: Codable, Hashable, Sendable {
    public let uid: ArtID
    public let name: String
    public let year: Int
    public let url: URL?
    public let contactEmail: String?
    public let hometown: String?
    public let description: String?
    public let artist: String?
    public let category: String?
    public let program: String?
    public let donationLink: URL?
    public let location: ArtLocation?
    public let locationString: String?
    public let images: [ArtImage]
    public let guidedTours: Bool
    public let selfGuidedTourMap: Bool
    
    public init(
        uid: ArtID,
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
        location: ArtLocation? = nil,
        locationString: String? = nil,
        images: [ArtImage] = [],
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
        self.location = location
        self.locationString = locationString
        self.images = images
        self.guidedTours = guidedTours
        self.selfGuidedTourMap = selfGuidedTourMap
    }
}

// MARK: - Computed Properties

public extension Art {
    /// Whether this art installation has any images
    var hasImages: Bool {
        !images.isEmpty
    }
    
    /// Whether this art installation has location information
    var hasLocation: Bool {
        location != nil || locationString != nil
    }
    
    /// Whether this art installation has GPS coordinates
    var hasGPSLocation: Bool {
        location?.hasGPSCoordinates == true
    }
    
    /// Whether this art installation offers any kind of tours
    var hasTours: Bool {
        guidedTours || selfGuidedTourMap
    }
    
    /// Whether this art installation has contact information
    var hasContact: Bool {
        contactEmail != nil || url != nil
    }
}