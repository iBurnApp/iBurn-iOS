import CoreGraphics
import XCTest
@testable import PlayaColors

final class ImageColorExtractorTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a test image from a row-major grid of 8-bit RGB triples.
    private func makeImage(width: Int, height: Int, pixel: (Int, Int) -> (UInt8, UInt8, UInt8)) throws -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b) = pixel(x, y)
                let offset = (y * width + x) * 4
                bytes[offset] = b
                bytes[offset + 1] = g
                bytes[offset + 2] = r
                bytes[offset + 3] = 255
            }
        }

        let context = try XCTUnwrap(CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ))
        return try XCTUnwrap(context.makeImage())
    }

    private func makeSolidImage(width: Int = 64, height: Int = 64, r: UInt8, g: UInt8, b: UInt8) throws -> CGImage {
        try makeImage(width: width, height: height) { _, _ in (r, g, b) }
    }

    private func assertClose(
        _ color: PlayaRGB,
        red: Double,
        green: Double,
        blue: Double,
        accuracy: Double = 0.02,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.red, red, accuracy: accuracy, "red", file: file, line: line)
        XCTAssertEqual(color.green, green, accuracy: accuracy, "green", file: file, line: line)
        XCTAssertEqual(color.blue, blue, accuracy: accuracy, "blue", file: file, line: line)
    }

    // MARK: - Background selection

    func testSolidColorBecomesBackground() throws {
        let image = try makeSolidImage(r: 200, g: 30, b: 40)
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))
        assertClose(colors.background, red: 200 / 255, green: 30 / 255, blue: 40 / 255)
    }

    func testDominantColorWinsOverMinorityColor() throws {
        // Left three quarters teal, right quarter orange.
        let image = try makeImage(width: 80, height: 80) { x, _ in
            x < 60 ? (0, 128, 128) : (255, 140, 0)
        }
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))
        assertClose(colors.background, red: 0, green: 128 / 255, blue: 128 / 255, accuracy: 0.05)
    }

    func testNearWhiteBackgroundIsSkippedForAComparablyCommonColor() throws {
        // 55% white, 45% blue: white is most frequent but blue clears the 0.3 ratio,
        // so the blue should be promoted to background.
        let image = try makeImage(width: 100, height: 100) { x, _ in
            x < 55 ? (255, 255, 255) : (20, 40, 200)
        }
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))
        assertClose(colors.background, red: 20 / 255, green: 40 / 255, blue: 200 / 255, accuracy: 0.06)
    }

    func testNearWhiteBackgroundIsKeptWhenNothingElseIsCommon() throws {
        // 97% white, 3% blue — below the 0.3 ratio, so white stays.
        let image = try makeImage(width: 100, height: 100) { x, _ in
            x < 97 ? (255, 255, 255) : (20, 40, 200)
        }
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))
        assertClose(colors.background, red: 1, green: 1, blue: 1, accuracy: 0.05)
    }

    // MARK: - Foreground fallbacks

    func testForegroundsFallBackToWhiteOnDarkBackground() throws {
        let image = try makeSolidImage(r: 10, g: 10, b: 12)
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))

        XCTAssertTrue(colors.background.red < 0.1)
        for color in [colors.primary, colors.secondary, colors.detail] {
            assertClose(color, red: 1, green: 1, blue: 1)
        }
    }

    func testForegroundsFallBackToBlackOnLightBackground() throws {
        let image = try makeSolidImage(r: 245, g: 245, b: 245)
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))

        XCTAssertTrue(colors.background.red > 0.9)
        for color in [colors.primary, colors.secondary, colors.detail] {
            assertClose(color, red: 0, green: 0, blue: 0)
        }
    }

    func testForegroundContrastsWithBackground() throws {
        // Dark navy field with a bright yellow band.
        let image = try makeImage(width: 100, height: 100) { _, y in
            y < 75 ? (10, 20, 60) : (250, 230, 40)
        }
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))

        let backgroundLuminance = 0.2126 * colors.background.red
            + 0.7152 * colors.background.green
            + 0.0722 * colors.background.blue
        let primaryLuminance = 0.2126 * colors.primary.red
            + 0.7152 * colors.primary.green
            + 0.0722 * colors.primary.blue
        XCTAssertGreaterThan(abs(primaryLuminance - backgroundLuminance), 0.3)
    }

    // MARK: - Determinism and scaling

    func testRepeatedExtractionIsStable() throws {
        let image = try makeImage(width: 120, height: 90) { x, y in
            // A handful of colours in equal proportion, which is exactly the tie
            // case that made the NSCountedSet version non-reproducible.
            switch (x / 30 + y / 30) % 4 {
            case 0: return (200, 40, 40)
            case 1: return (40, 200, 40)
            case 2: return (40, 40, 200)
            default: return (200, 200, 40)
            }
        }

        let first = try XCTUnwrap(ImageColorExtractor.extract(from: image))
        for _ in 0..<10 {
            XCTAssertEqual(try XCTUnwrap(ImageColorExtractor.extract(from: image)), first)
        }
    }

    func testQualityDoesNotChangeASolidColorResult() throws {
        let image = try makeSolidImage(width: 400, height: 300, r: 120, g: 60, b: 180)

        for quality in [ColorQuality.lowest, .low, .high, .highest] {
            let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image, quality: quality))
            assertClose(colors.background, red: 120 / 255, green: 60 / 255, blue: 180 / 255)
        }
    }

    func testNonSquareImageKeepsAspectRatioWhenDownscaled() throws {
        // A wide image whose left half is red: after the aspect-preserving resize the
        // proportions must hold, so red stays the dominant colour.
        let image = try makeImage(width: 1000, height: 200) { x, _ in
            x < 700 ? (220, 30, 30) : (30, 30, 220)
        }
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image, quality: .high))
        assertClose(colors.background, red: 220 / 255, green: 30 / 255, blue: 30 / 255, accuracy: 0.06)
    }

    // MARK: - Packing

    func testRGBComponentsRoundTripThroughPacking() throws {
        let image = try makeSolidImage(r: 1, g: 254, b: 128)
        let colors = try XCTUnwrap(ImageColorExtractor.extract(from: image))
        assertClose(colors.background, red: 1 / 255, green: 254 / 255, blue: 128 / 255, accuracy: 0.01)
    }
}
