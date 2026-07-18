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

    // Custom decoding: `url` and `donationLink` are user-entered free text and are
    // salvaged leniently rather than decoded strictly (see `LenientURL`). Encoding
    // stays synthesized/unchanged.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(ArtID.self, forKey: .uid)
        name = try container.decode(String.self, forKey: .name)
        year = try container.decode(Int.self, forKey: .year)
        url = try container.decodeLenientURLIfPresent(forKey: .url)
        contactEmail = try container.decodeIfPresent(String.self, forKey: .contactEmail)
        hometown = try container.decodeIfPresent(String.self, forKey: .hometown)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        program = try container.decodeIfPresent(String.self, forKey: .program)
        donationLink = try container.decodeLenientURLIfPresent(forKey: .donationLink)
        location = try container.decodeIfPresent(ArtLocation.self, forKey: .location)
        locationString = try container.decodeIfPresent(String.self, forKey: .locationString)
        images = try container.decode([ArtImage].self, forKey: .images)
        guidedTours = try container.decode(Bool.self, forKey: .guidedTours)
        selfGuidedTourMap = try container.decode(Bool.self, forKey: .selfGuidedTourMap)
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