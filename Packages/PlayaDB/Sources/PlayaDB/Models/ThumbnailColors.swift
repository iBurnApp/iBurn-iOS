import Foundation
import GRDB

/// Cached thumbnail-extracted colors for data objects.
/// Stores RGBA components for four semantic colors: background, primary, secondary, detail.
public struct ThumbnailColors: Codable, FetchableRecord, MutablePersistableRecord, Equatable {
    public static let databaseTableName = "thumbnail_colors"

    public enum Columns: String, CodingKey, ColumnExpression {
        case objectId = "object_id"
        case bgRed = "bg_red"
        case bgGreen = "bg_green"
        case bgBlue = "bg_blue"
        case bgAlpha = "bg_alpha"
        case primaryRed = "primary_red"
        case primaryGreen = "primary_green"
        case primaryBlue = "primary_blue"
        case primaryAlpha = "primary_alpha"
        case secondaryRed = "secondary_red"
        case secondaryGreen = "secondary_green"
        case secondaryBlue = "secondary_blue"
        case secondaryAlpha = "secondary_alpha"
        case detailRed = "detail_red"
        case detailGreen = "detail_green"
        case detailBlue = "detail_blue"
        case detailAlpha = "detail_alpha"
    }

    private typealias CodingKeys = Columns

    // MARK: - Properties

    public var objectId: String
    public var bgRed: Double
    public var bgGreen: Double
    public var bgBlue: Double
    public var bgAlpha: Double
    public var primaryRed: Double
    public var primaryGreen: Double
    public var primaryBlue: Double
    public var primaryAlpha: Double
    public var secondaryRed: Double
    public var secondaryGreen: Double
    public var secondaryBlue: Double
    public var secondaryAlpha: Double
    public var detailRed: Double
    public var detailGreen: Double
    public var detailBlue: Double
    public var detailAlpha: Double

    // MARK: - Init

    public init(
        objectId: String,
        bgRed: Double, bgGreen: Double, bgBlue: Double, bgAlpha: Double,
        primaryRed: Double, primaryGreen: Double, primaryBlue: Double, primaryAlpha: Double,
        secondaryRed: Double, secondaryGreen: Double, secondaryBlue: Double, secondaryAlpha: Double,
        detailRed: Double, detailGreen: Double, detailBlue: Double, detailAlpha: Double
    ) {
        self.objectId = objectId
        self.bgRed = bgRed
        self.bgGreen = bgGreen
        self.bgBlue = bgBlue
        self.bgAlpha = bgAlpha
        self.primaryRed = primaryRed
        self.primaryGreen = primaryGreen
        self.primaryBlue = primaryBlue
        self.primaryAlpha = primaryAlpha
        self.secondaryRed = secondaryRed
        self.secondaryGreen = secondaryGreen
        self.secondaryBlue = secondaryBlue
        self.secondaryAlpha = secondaryAlpha
        self.detailRed = detailRed
        self.detailGreen = detailGreen
        self.detailBlue = detailBlue
        self.detailAlpha = detailAlpha
    }
}
