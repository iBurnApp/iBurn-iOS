import PlayaColors
import PlayaDB

extension ThumbnailColors {
    /// Bridges an extraction result into the row shape PlayaDB persists.
    ///
    /// Mirrors the app-side `ThumbnailColors(objectId:brcColors:)` initializer; both
    /// store straight sRGB components with alpha pinned to 1, since the extractor only
    /// ever proposes opaque colours.
    init(objectId: String, colors: ExtractedColors) {
        self.init(
            objectId: objectId,
            bgRed: colors.background.red,
            bgGreen: colors.background.green,
            bgBlue: colors.background.blue,
            bgAlpha: 1,
            primaryRed: colors.primary.red,
            primaryGreen: colors.primary.green,
            primaryBlue: colors.primary.blue,
            primaryAlpha: 1,
            secondaryRed: colors.secondary.red,
            secondaryGreen: colors.secondary.green,
            secondaryBlue: colors.secondary.blue,
            secondaryAlpha: 1,
            detailRed: colors.detail.red,
            detailGreen: colors.detail.green,
            detailBlue: colors.detail.blue,
            detailAlpha: 1
        )
    }
}
