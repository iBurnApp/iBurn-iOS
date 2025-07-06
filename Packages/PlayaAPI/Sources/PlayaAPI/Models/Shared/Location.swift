import Foundation

/// Represents art installation location with GPS coordinates
public struct ArtLocation: Codable, Hashable, Sendable {
    public let hour: Int?
    public let minute: Int?
    public let distance: Int?
    public let category: String?
    public let gpsLatitude: Double?
    public let gpsLongitude: Double?
    
    public init(
        hour: Int? = nil,
        minute: Int? = nil,
        distance: Int? = nil,
        category: String? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil
    ) {
        self.hour = hour
        self.minute = minute
        self.distance = distance
        self.category = category
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}

/// Represents camp location with detailed positioning
public struct CampLocation: Codable, Hashable, Sendable {
    public let frontage: String?
    public let intersection: String?
    public let intersectionType: String?
    public let dimensions: String?
    public let exactLocation: String?
    
    public init(
        frontage: String? = nil,
        intersection: String? = nil,
        intersectionType: String? = nil,
        dimensions: String? = nil,
        exactLocation: String? = nil
    ) {
        self.frontage = frontage
        self.intersection = intersection
        self.intersectionType = intersectionType
        self.dimensions = dimensions
        self.exactLocation = exactLocation
    }
}

// MARK: - Computed Properties

public extension ArtLocation {
    /// Whether this location has GPS coordinates
    var hasGPSCoordinates: Bool {
        gpsLatitude != nil && gpsLongitude != nil
    }
    
    /// Whether this location has time-based addressing
    var hasTimeBasedAddress: Bool {
        hour != nil
    }
}

public extension CampLocation {
    /// Whether this location has complete addressing
    var hasCompleteAddress: Bool {
        frontage != nil && intersection != nil
    }
}