import Foundation

/// Represents an art image
public struct ArtImage: Codable, Hashable, Sendable {
    public let thumbnailUrl: URL?
    public let galleryRef: String?

    public init(thumbnailUrl: URL? = nil, galleryRef: String? = nil) {
        self.thumbnailUrl = thumbnailUrl
        self.galleryRef = galleryRef
    }

    // `thumbnail_url` is bmorg-generated but not always a URL: while their image
    // pipeline runs it holds the literal string "processing" (seen live in 2026),
    // which `URL` happily decodes as a schemeless relative URL that can never load.
    // Salvage leniently (see `LenientURL`) so such values become "no image" instead.
    // Encoding stays synthesized/unchanged.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        thumbnailUrl = try container.decodeLenientURLIfPresent(forKey: .thumbnailUrl)
        galleryRef = try container.decodeIfPresent(String.self, forKey: .galleryRef)
    }
}

/// Represents a camp image (simpler than art images)
public struct CampImage: Codable, Hashable, Sendable {
    public let thumbnailUrl: URL?

    public init(thumbnailUrl: URL? = nil) {
        self.thumbnailUrl = thumbnailUrl
    }

    // See `ArtImage.init(from:)` — "processing" placeholder values decode to nil.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        thumbnailUrl = try container.decodeLenientURLIfPresent(forKey: .thumbnailUrl)
    }
}