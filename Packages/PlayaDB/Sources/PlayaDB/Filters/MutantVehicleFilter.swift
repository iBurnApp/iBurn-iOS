import Foundation

/// Filter options for querying mutant vehicle objects
public struct MutantVehicleFilter: Hashable, Codable {
    /// Filter by year
    public var year: Int?

    /// Full-text search across name, description, artist, etc.
    public var searchText: String?

    /// Only show favorited mutant vehicles
    public var onlyFavorites: Bool

    /// Filter by a specific tag
    public var tag: String?

    public init(
        year: Int? = nil,
        searchText: String? = nil,
        onlyFavorites: Bool = false,
        tag: String? = nil
    ) {
        self.year = year
        self.searchText = searchText
        self.onlyFavorites = onlyFavorites
        self.tag = tag
    }

    /// Filter that matches all mutant vehicles (no filtering)
    public static var all: MutantVehicleFilter {
        MutantVehicleFilter()
    }
}
