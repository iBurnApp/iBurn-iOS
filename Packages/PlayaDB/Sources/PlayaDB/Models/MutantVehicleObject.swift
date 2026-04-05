import Foundation
import CoreLocation
import GRDB

/// Mutant vehicle object with complete API field mapping
public struct MutantVehicleObject: DataObject, Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration

    public static let databaseTableName = "mv_objects"

    // MARK: - Column Mapping

    public enum Columns: String,
                         CodingKey,
                         ColumnExpression,
                         DataObjectColumns,
                         WebUrlColumns,
                         ContactEmailColumns,
                         HometownColumns {
        // DataObjectColumns
        case uid
        case name
        case year
        case description

        // WebUrlColumns
        case url

        // ContactEmailColumns
        case contactEmail = "contact_email"

        // HometownColumns
        case hometown

        // MV-specific columns
        case artist
        case donationLink = "donation_link"
        case tagsText = "tags_text"
    }

    // Use Columns as CodingKeys
    private typealias CodingKeys = Columns

    // MARK: - Properties

    public var uid: String
    public var name: String
    public var year: Int
    public var url: URL?
    public var contactEmail: String?
    public var hometown: String?
    public var description: String?
    public var artist: String?
    public var donationLink: URL?
    public var tagsText: String?

    public init(
        uid: String,
        name: String,
        year: Int,
        url: URL? = nil,
        contactEmail: String? = nil,
        hometown: String? = nil,
        description: String? = nil,
        artist: String? = nil,
        donationLink: URL? = nil,
        tagsText: String? = nil
    ) {
        self.uid = uid
        self.name = name
        self.year = year
        self.url = url
        self.contactEmail = contactEmail
        self.hometown = hometown
        self.description = description
        self.artist = artist
        self.donationLink = donationLink
        self.tagsText = tagsText
    }
}

// MARK: - DataObject Protocol Conformance

public extension MutantVehicleObject {
    var objectType: DataObjectType { .mutantVehicle }

    /// Mutant vehicles are mobile -- no fixed location
    var location: CLLocation? { nil }

    var hasLocation: Bool { false }
}

// MARK: - Column Provider Conformance

extension MutantVehicleObject: DataObjectColumnProviding {
    public typealias ColumnSet = Columns
    public static var columnSet: Columns.Type { Columns.self }
}

// MARK: - Computed Properties

public extension MutantVehicleObject {
    var hasImages: Bool {
        !images.isEmpty
    }

    var hasContact: Bool {
        contactEmail != nil || url != nil
    }

    var hasArtist: Bool {
        artist != nil && !artist!.isEmpty
    }
}

// MARK: - Relationships

public extension MutantVehicleObject {
    /// Associated images (populated by the database layer)
    var images: [MutantVehicleImage] {
        []
    }

    /// Tags as an array, split from the denormalized `tagsText` column
    var tagsList: [String] {
        guard let tagsText, !tagsText.isEmpty else { return [] }
        return tagsText.components(separatedBy: " ").filter { !$0.isEmpty }
    }
}

/// Mutant vehicle image model
public struct MutantVehicleImage: Codable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "mv_images"

    public enum Columns: String, CodingKey, ColumnExpression {
        case id
        case mvId = "mv_id"
        case thumbnailUrl = "thumbnail_url"
    }

    private typealias CodingKeys = Columns

    public var id: Int64?
    public var mvId: String
    public var thumbnailUrl: URL?

    public init(id: Int64? = nil, mvId: String, thumbnailUrl: URL? = nil) {
        self.id = id
        self.mvId = mvId
        self.thumbnailUrl = thumbnailUrl
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Mutant vehicle tag model (normalized)
public struct MutantVehicleTag: Codable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "mv_tags"

    public enum Columns: String, CodingKey, ColumnExpression {
        case id
        case mvId = "mv_id"
        case tag
    }

    private typealias CodingKeys = Columns

    public var id: Int64?
    public var mvId: String
    public var tag: String

    public init(id: Int64? = nil, mvId: String, tag: String) {
        self.id = id
        self.mvId = mvId
        self.tag = tag
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
