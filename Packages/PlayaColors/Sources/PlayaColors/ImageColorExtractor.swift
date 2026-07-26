import CoreGraphics
import Foundation

/// Extracts a background + three contrasting foreground colours from an image.
///
/// This is a CoreGraphics-only port of jathu/UIImageColors 2.2.0, which iBurn used
/// via CocoaPods until the seed tool needed the same numbers on macOS. The scoring
/// rules (luminance, contrast, distinctness, minimum saturation) are reproduced
/// exactly so cached colours stay comparable across app versions.
///
/// Two deliberate differences from the pod:
///
/// 1. **Fixed 1x resize.** UIImageColors resized through `UIGraphicsBeginImageContextWithOptions(_:_:0)`,
///    which uses the *device* scale — so a 3x phone histogrammed 9x as many
///    (interpolated) pixels as a 1x one and could land on a different colour. Here
///    the downscale target is always in pixels, so every platform agrees.
/// 2. **Deterministic tie-breaking.** Equally-frequent colours are ordered by their
///    packed RGB value instead of by `NSCountedSet` enumeration order, so repeated
///    runs over the same image return the same result.
public enum ImageColorExtractor {

    /// Extracts colours from `image`, or returns nil if it can't be rasterized.
    ///
    /// - Parameters:
    ///   - image: Source image. Any colour space is fine; it is drawn into sRGB.
    ///   - quality: Downscale target for the longest edge (default `.high`, 250px).
    public static func extract(from image: CGImage, quality: ColorQuality = .high) -> ExtractedColors? {
        guard let bitmap = Bitmap(image: image, quality: quality) else { return nil }

        // Colours are packed into a single Int (r * 1_000_000 + g * 1_000 + b) so the
        // histogram is a plain dictionary rather than an NSCountedSet of boxed doubles.
        var histogram: [Int: Int] = [:]
        histogram.reserveCapacity(bitmap.width * bitmap.height)

        for y in 0..<bitmap.height {
            let rowStart = y * bitmap.bytesPerRow
            for x in 0..<bitmap.width {
                let pixel = rowStart + x * 4
                // Skip mostly-transparent pixels; they say nothing about the artwork.
                guard bitmap.bytes[pixel + 3] >= 127 else { continue }
                let blue = Int(bitmap.bytes[pixel])
                let green = Int(bitmap.bytes[pixel + 1])
                let red = Int(bitmap.bytes[pixel + 2])
                histogram[pack(red: red, green: green, blue: blue), default: 0] += 1
            }
        }

        // Colours occupying less than 1% of the image height are treated as noise.
        let threshold = Int(CGFloat(bitmap.height) * 0.01)

        let background = proposedBackground(histogram: histogram, threshold: threshold)
        let foregrounds = proposedForegrounds(histogram: histogram, background: background)

        return ExtractedColors(
            background: unpack(background),
            primary: unpack(foregrounds.0),
            secondary: unpack(foregrounds.1),
            detail: unpack(foregrounds.2)
        )
    }

    // MARK: - Background

    /// The most common colour in the image, skipping near-black/near-white unless
    /// nothing else comes close in frequency.
    private static func proposedBackground(histogram: [Int: Int], threshold: Int) -> Int {
        let sorted = sortedByFrequency(
            histogram.compactMap { $0.value > threshold ? Candidate(color: $0.key, count: $0.value) : nil }
        )
        guard var proposed = sorted.first else { return 0 }

        if isBlackOrWhite(proposed.color) {
            for candidate in sorted.dropFirst() {
                // Stop as soon as the runner-up is too rare to be representative.
                guard Double(candidate.count) / Double(proposed.count) > 0.3 else { break }
                if !isBlackOrWhite(candidate.color) {
                    proposed = candidate
                    break
                }
            }
        }
        return proposed.color
    }

    // MARK: - Foregrounds

    /// Primary, secondary and detail colours: the most common colours that contrast
    /// with the background and stay visually distinct from each other.
    private static func proposedForegrounds(histogram: [Int: Int], background: Int) -> (Int, Int, Int) {
        let wantDarkText = !isDark(background)

        // Saturate washed-out colours so pale text still reads. Matching UIImageColors,
        // the primary ranking is the frequency of the *saturated* colour in the original
        // histogram: colours already saturated enough are returned unchanged and keep
        // their real counts, while boosted ones almost never occur verbatim and land at
        // zero. Those zeroes are broken by how common the colour was *before* boosting,
        // which is the signal the pod threw away (it left them to NSCountedSet
        // enumeration order, so its 2nd/3rd picks were effectively arbitrary).
        var candidates: [Candidate] = []
        candidates.reserveCapacity(histogram.count)
        for (color, count) in histogram {
            let saturated = withMinimumSaturation(color, minSaturation: 0.15)
            guard isDark(saturated) == wantDarkText else { continue }
            candidates.append(Candidate(color: saturated, count: histogram[saturated] ?? 0, sourceCount: count))
        }

        var primary = -1
        var secondary = -1
        var detail = -1

        for candidate in sortedByFrequency(candidates) {
            let color = candidate.color
            if primary == -1 {
                if isContrasting(color, against: background) {
                    primary = color
                }
            } else if secondary == -1 {
                guard isContrasting(color, against: background), isDistinct(primary, color) else { continue }
                secondary = color
            } else if detail == -1 {
                guard isContrasting(color, against: background),
                      isDistinct(secondary, color),
                      isDistinct(primary, color) else { continue }
                detail = color
                break
            }
        }

        // Anything still unfilled falls back to plain white or black.
        let fallback = isDark(background) ? 255_255_255 : 0
        return (
            primary == -1 ? fallback : primary,
            secondary == -1 ? fallback : secondary,
            detail == -1 ? fallback : detail
        )
    }

    /// A colour under consideration, with the two frequencies used to rank it.
    private struct Candidate {
        /// The colour as proposed (possibly saturation-boosted).
        let color: Int
        /// How often `color` itself appears in the image.
        let count: Int
        /// How often the colour this was derived from appears. Equals `count` when no
        /// boosting happened; used to order candidates whose boosted form is absent.
        let sourceCount: Int

        init(color: Int, count: Int, sourceCount: Int? = nil) {
            self.color = color
            self.count = count
            self.sourceCount = sourceCount ?? count
        }
    }

    /// Ranks candidates most-frequent-first. Ties fall through to source frequency,
    /// then to saturation, then to the packed value — a total order, so the same image
    /// always yields the same colours.
    ///
    /// The saturation step matters because exact count ties do happen (~1% of iBurn's
    /// thumbnails), and without it a muddy near-grey can beat a vivid colour purely on
    /// having a lower RGB value, which makes for a poor theme.
    private static func sortedByFrequency(_ entries: [Candidate]) -> [Candidate] {
        entries.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.sourceCount != rhs.sourceCount { return lhs.sourceCount > rhs.sourceCount }
            let lhsSaturation = saturation(lhs.color), rhsSaturation = saturation(rhs.color)
            if lhsSaturation != rhsSaturation { return lhsSaturation > rhsSaturation }
            return lhs.color < rhs.color
        }
    }

    /// HSV saturation in `0...1`.
    private static func saturation(_ color: Int) -> Double {
        let (r, g, b) = components(color)
        let value = max(r, max(g, b))
        guard value > 0 else { return 0 }
        return (value - min(r, min(g, b))) / value
    }

    // MARK: - Packed colour maths

    private static func pack(red: Int, green: Int, blue: Int) -> Int {
        red * 1_000_000 + green * 1_000 + blue
    }

    private static func components(_ color: Int) -> (r: Double, g: Double, b: Double) {
        (
            Double(color / 1_000_000),
            Double((color / 1_000) % 1_000),
            Double(color % 1_000)
        )
    }

    private static func unpack(_ color: Int) -> PlayaRGB {
        let (r, g, b) = components(color)
        return PlayaRGB(red: r / 255, green: g / 255, blue: b / 255)
    }

    private static func isDark(_ color: Int) -> Bool {
        let (r, g, b) = components(color)
        return (r * 0.2126) + (g * 0.7152) + (b * 0.0722) < 127.5
    }

    private static func isBlackOrWhite(_ color: Int) -> Bool {
        let (r, g, b) = components(color)
        return (r > 232 && g > 232 && b > 232) || (r < 23 && g < 23 && b < 23)
    }

    /// True when two colours differ enough to be worth showing side by side. The
    /// second clause exempts pairs where both colours are near-greyscale.
    private static func isDistinct(_ color: Int, _ other: Int) -> Bool {
        let (r, g, b) = components(color)
        let (or, og, ob) = components(other)

        return (abs(r - or) > 63.75 || abs(g - og) > 63.75 || abs(b - ob) > 63.75)
            && !(abs(r - g) < 7.65 && abs(r - b) < 7.65 && abs(or - og) < 7.65 && abs(or - ob) < 7.65)
    }

    /// Relative-luminance ratio test, with the same 12.75 floor and 1.6 ratio the
    /// pod used (a looser bar than WCAG, tuned for large thumbnail text).
    private static func isContrasting(_ color: Int, against background: Int) -> Bool {
        let (br, bg, bb) = components(background)
        let (fr, fg, fb) = components(color)
        let backgroundLuminance = (0.2126 * br) + (0.7152 * bg) + (0.0722 * bb) + 12.75
        let foregroundLuminance = (0.2126 * fr) + (0.7152 * fg) + (0.0722 * fb) + 12.75
        return backgroundLuminance > foregroundLuminance
            ? 1.6 < backgroundLuminance / foregroundLuminance
            : 1.6 < foregroundLuminance / backgroundLuminance
    }

    /// Raises a colour's HSV saturation to at least `minSaturation`, leaving hue and
    /// value alone. Colours already saturated enough are returned untouched.
    private static func withMinimumSaturation(_ color: Int, minSaturation: Double) -> Int {
        let (r255, g255, b255) = components(color)
        let r = r255 / 255, g = g255 / 255, b = b255 / 255

        let maxComponent = max(r, max(g, b))
        var chroma = maxComponent - min(r, min(g, b))

        let value = maxComponent
        let saturation = value == 0 ? 0 : chroma / value
        guard saturation < minSaturation else { return color }

        var hue: Double
        if chroma == 0 {
            hue = 0
        } else if r == maxComponent {
            hue = ((g - b) / chroma).truncatingRemainder(dividingBy: 6)
        } else if g == maxComponent {
            hue = 2 + ((b - r) / chroma)
        } else {
            hue = 4 + ((r - g) / chroma)
        }
        if hue < 0 { hue += 6 }

        chroma = value * minSaturation
        let x = chroma * (1 - abs(hue.truncatingRemainder(dividingBy: 2) - 1))
        let (red, green, blue): (Double, Double, Double)

        switch hue {
        case 0...1: (red, green, blue) = (chroma, x, 0)
        case 1...2: (red, green, blue) = (x, chroma, 0)
        case 2...3: (red, green, blue) = (0, chroma, x)
        case 3...4: (red, green, blue) = (0, x, chroma)
        case 4...5: (red, green, blue) = (x, 0, chroma)
        case 5..<6: (red, green, blue) = (chroma, 0, x)
        default: (red, green, blue) = (0, 0, 0)
        }

        let m = value - chroma
        return pack(
            red: Int(((red + m) * 255).rounded(.down)),
            green: Int(((green + m) * 255).rounded(.down)),
            blue: Int(((blue + m) * 255).rounded(.down))
        )
    }
}

// MARK: - Rasterization

private extension ImageColorExtractor {
    /// A downscaled BGRA copy of the source image with a known, unpadded stride.
    struct Bitmap {
        let bytes: [UInt8]
        let width: Int
        let height: Int
        var bytesPerRow: Int { width * 4 }

        init?(image: CGImage, quality: ColorQuality) {
            let size = Self.targetSize(for: image, quality: quality)
            self.width = size.width
            self.height = size.height

            var buffer = [UInt8](repeating: 0, count: size.width * size.height * 4)
            let drew: Bool = buffer.withUnsafeMutableBytes { raw -> Bool in
                // premultipliedFirst + byteOrder32Little lays pixels out as B, G, R, A —
                // the same order UIKit's bitmap contexts use.
                guard let context = CGContext(
                    data: raw.baseAddress,
                    width: size.width,
                    height: size.height,
                    bitsPerComponent: 8,
                    bytesPerRow: size.width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                ) else { return false }

                context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                return true
            }
            guard drew else { return nil }
            self.bytes = buffer
        }

        /// Scales the longest edge down to `quality`, preserving aspect ratio.
        private static func targetSize(for image: CGImage, quality: ColorQuality) -> (width: Int, height: Int) {
            let sourceWidth = CGFloat(image.width)
            let sourceHeight = CGFloat(image.height)
            guard quality != .highest, sourceWidth > 0, sourceHeight > 0 else {
                return (max(image.width, 1), max(image.height, 1))
            }

            let target = quality.rawValue
            let scaled: CGSize
            if sourceWidth < sourceHeight {
                scaled = CGSize(width: target / (sourceHeight / sourceWidth), height: target)
            } else {
                scaled = CGSize(width: target, height: target / (sourceWidth / sourceHeight))
            }
            return (max(Int(scaled.width.rounded()), 1), max(Int(scaled.height.rounded()), 1))
        }
    }
}
