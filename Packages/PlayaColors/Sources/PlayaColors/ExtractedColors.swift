import CoreGraphics
import Foundation

/// A single opaque colour, expressed as sRGB components in `0...1`.
///
/// Deliberately platform-free so the same value can be produced by the macOS seed
/// tool and consumed by UIKit on iOS/watchOS.
public struct PlayaRGB: Equatable, Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Builds a colour from 8-bit components.
    public init(red8: Int, green8: Int, blue8: Int) {
        self.init(
            red: Double(red8) / 255,
            green: Double(green8) / 255,
            blue: Double(blue8) / 255
        )
    }

    public var cgColor: CGColor {
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [CGFloat(red), CGFloat(green), CGFloat(blue), 1]
        )!
    }
}

/// The four semantic colours pulled out of a thumbnail: a background plus three
/// foreground colours guaranteed to contrast against it.
public struct ExtractedColors: Equatable, Hashable, Sendable, Codable {
    public var background: PlayaRGB
    public var primary: PlayaRGB
    public var secondary: PlayaRGB
    public var detail: PlayaRGB

    public init(background: PlayaRGB, primary: PlayaRGB, secondary: PlayaRGB, detail: PlayaRGB) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.detail = detail
    }
}

/// How far the image is scaled down before its histogram is built. Smaller is
/// faster and blurs away noise; `.highest` skips the resize entirely.
public enum ColorQuality: CGFloat, Sendable {
    case lowest = 50
    case low = 100
    case high = 250
    case highest = 0
}
