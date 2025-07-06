import Foundation

/// Represents update information from the Burning Man API
public struct UpdateInfo: Codable, Hashable, Sendable {
    public let art: FileUpdateInfo?
    public let camps: FileUpdateInfo?
    public let events: FileUpdateInfo?
    
    public init(art: FileUpdateInfo? = nil, camps: FileUpdateInfo? = nil, events: FileUpdateInfo? = nil) {
        self.art = art
        self.camps = camps
        self.events = events
    }
}

/// Represents update information for a specific data file
public struct FileUpdateInfo: Codable, Hashable, Sendable {
    public let file: String
    public let updated: Date
    
    public init(file: String, updated: Date) {
        self.file = file
        self.updated = updated
    }
}

// MARK: - Computed Properties

public extension UpdateInfo {
    /// The most recent update date across all data types
    var lastUpdated: Date? {
        [art?.updated, camps?.updated, events?.updated]
            .compactMap { $0 }
            .max()
    }
    
    /// Whether any data has been updated
    var hasUpdates: Bool {
        art != nil || camps != nil || events != nil
    }
}