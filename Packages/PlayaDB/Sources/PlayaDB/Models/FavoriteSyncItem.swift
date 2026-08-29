import Foundation

/// A single object's syncable metadata state for last-writer-wins sync between
/// devices (e.g. iOS <-> watchOS over WatchConnectivity). Carries the favorite
/// and visit-status fields, each with its own change stamp so the two fields
/// merge independently.
public struct FavoriteSyncItem: Codable, Equatable, Sendable {
    /// `DataObjectType` rawValue of the object this item refers to.
    public let objectType: String

    /// UID of the object this item refers to.
    public let objectId: String

    /// The favorite state at `favoriteUpdatedAt`.
    public let isFavorite: Bool

    /// The `favorite_updated_at` stamp — when the favorite state was last
    /// explicitly changed. nil = favorite never explicitly set, so the
    /// favorite field carries no information for merging.
    public let favoriteUpdatedAt: Date?

    /// Raw `VisitStatus` value at `visitStatusUpdatedAt` (default 0 = unvisited).
    public let visitStatus: Int

    /// The `visit_status_updated_at` stamp — when the visit status was last
    /// explicitly changed. nil = visit status never explicitly set, so the
    /// visit field carries no information for merging.
    public let visitStatusUpdatedAt: Date?

    public init(
        objectType: String,
        objectId: String,
        isFavorite: Bool,
        favoriteUpdatedAt: Date?,
        visitStatus: Int = 0,
        visitStatusUpdatedAt: Date? = nil
    ) {
        self.objectType = objectType
        self.objectId = objectId
        self.isFavorite = isFavorite
        self.favoriteUpdatedAt = favoriteUpdatedAt
        self.visitStatus = visitStatus
        self.visitStatusUpdatedAt = visitStatusUpdatedAt
    }
}
