//
//  ImageColorExtraction.swift
//  iBurn
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import UIKit
import PlayaColors

/// UIKit adapter over `PlayaColors`, which replaced the UIImageColors CocoaPod.
///
/// The same extractor runs in the `playa-seed` command-line tool that bakes
/// `thumbnail_colors` into the shipped database, so a colour computed on device is
/// identical to the one baked at build time. See `Packages/PlayaColors`.
extension UIImage {
    /// Extracts background/primary/secondary/detail colours from this image.
    /// Returns nil for images with no backing bitmap (e.g. CIImage-only).
    func brc_extractColors(quality: ColorQuality = .high) -> BRCImageColors? {
        guard let cgImage else { return nil }
        return ImageColorExtractor.extract(from: cgImage, quality: quality)?.brc_ImageColors
    }
}

extension PlayaRGB {
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension ExtractedColors {
    var brc_ImageColors: BRCImageColors {
        BRCImageColors(
            backgroundColor: background.uiColor,
            primaryColor: primary.uiColor,
            secondaryColor: secondary.uiColor,
            detailColor: detail.uiColor
        )
    }
}
