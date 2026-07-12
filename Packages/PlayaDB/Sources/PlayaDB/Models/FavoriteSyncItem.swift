import Foundation

/// A single favorite state for last-writer-wins sync between devices
/// (e.g. iOS <-> watchOS over WatchConnectivity).
public struct FavoriteSyncItem: Codable, Equatable, Sendable {
    /// `DataObjectType` rawValue of the object this favorite refers to.
    public let objectType: String

    /// UID of the object this favorite refers to.
    public let objectId: String

    /// The favorite state at `updatedAt`.
    public let isFavorite: Bool

    /// The `favorite_updated_at` stamp — when the favorite state was last
    /// explicitly changed. Used for last-writer-wins conflict resolution.
    public let updatedAt: Date

    public init(objectType: String, objectId: String, isFavorite: Bool, updatedAt: Date) {
        self.objectType = objectType
        self.objectId = objectId
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
    }
}
