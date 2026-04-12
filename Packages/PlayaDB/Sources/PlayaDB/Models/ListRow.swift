import Foundation

/// Fully-inflated row for list views. Bundles the data object with all metadata
/// needed for rendering, fetched in a single GRDB read transaction.
public struct ListRow<T> {
    public let object: T
    public let metadata: ObjectMetadata?
    public let thumbnailColors: ThumbnailColors?

    /// Convenience: whether this object is favorited.
    public var isFavorite: Bool { metadata?.isFavorite ?? false }

    public init(object: T, metadata: ObjectMetadata?, thumbnailColors: ThumbnailColors?) {
        self.object = object
        self.metadata = metadata
        self.thumbnailColors = thumbnailColors
    }
}
