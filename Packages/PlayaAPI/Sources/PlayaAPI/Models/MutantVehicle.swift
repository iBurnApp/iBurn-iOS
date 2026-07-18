import Foundation

/// Represents a mutant vehicle from the Burning Man API
public struct MutantVehicle: Codable, Hashable, Sendable {
    public let uid: MutantVehicleID
    public let name: String
    public let year: Int
    public let url: URL?
    public let donationLink: URL?
    public let contactEmail: String?
    public let hometown: String?
    public let description: String?
    public let artist: String?
    public let images: [MutantVehicleImage]
    public let tags: [String]

    public init(
        uid: MutantVehicleID,
        name: String,
        year: Int,
        url: URL? = nil,
        donationLink: URL? = nil,
        contactEmail: String? = nil,
        hometown: String? = nil,
        description: String? = nil,
        artist: String? = nil,
        images: [MutantVehicleImage] = [],
        tags: [String] = []
    ) {
        self.uid = uid
        self.name = name
        self.year = year
        self.url = url
        self.donationLink = donationLink
        self.contactEmail = contactEmail
        self.hometown = hometown
        self.description = description
        self.artist = artist
        self.images = images
        self.tags = tags
    }

    // Custom decoding: `url` and `donationLink` are user-entered free text and are
    // salvaged leniently rather than decoded strictly (see `LenientURL`). Encoding
    // stays synthesized/unchanged.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(MutantVehicleID.self, forKey: .uid)
        name = try container.decode(String.self, forKey: .name)
        year = try container.decode(Int.self, forKey: .year)
        url = try container.decodeLenientURLIfPresent(forKey: .url)
        donationLink = try container.decodeLenientURLIfPresent(forKey: .donationLink)
        contactEmail = try container.decodeIfPresent(String.self, forKey: .contactEmail)
        hometown = try container.decodeIfPresent(String.self, forKey: .hometown)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        images = try container.decode([MutantVehicleImage].self, forKey: .images)
        tags = try container.decode([String].self, forKey: .tags)
    }
}

// MARK: - Computed Properties

public extension MutantVehicle {
    var hasImages: Bool {
        !images.isEmpty
    }

    var hasContact: Bool {
        contactEmail != nil || url != nil
    }

    var hasTags: Bool {
        !tags.isEmpty
    }
}

/// Represents a mutant vehicle image
public struct MutantVehicleImage: Codable, Hashable, Sendable {
    public let thumbnailUrl: URL?

    public init(thumbnailUrl: URL? = nil) {
        self.thumbnailUrl = thumbnailUrl
    }
}
