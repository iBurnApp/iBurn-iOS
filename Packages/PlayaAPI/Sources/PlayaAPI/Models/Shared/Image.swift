import Foundation

/// Represents an art image
public struct ArtImage: Codable, Hashable, Sendable {
    public let thumbnailUrl: URL?
    public let galleryRef: String?
    
    public init(thumbnailUrl: URL? = nil, galleryRef: String? = nil) {
        self.thumbnailUrl = thumbnailUrl
        self.galleryRef = galleryRef
    }
}

/// Represents a camp image (simpler than art images)
public struct CampImage: Codable, Hashable, Sendable {
    public let thumbnailUrl: URL?
    
    public init(thumbnailUrl: URL? = nil) {
        self.thumbnailUrl = thumbnailUrl
    }
}