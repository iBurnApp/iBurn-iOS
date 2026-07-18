import XCTest
@testable import iBurn

/// Tests for the Max Duration slider's tap-to-set mapping
/// (`EventFilterSheet.sliderValue(forTapX:trackWidth:)`).
///
/// The mapping mirrors the native Slider's geometry: a 13.5pt thumb inset on each
/// side, linear across the remaining track, snapped to the nearest of the 13
/// discrete positions (1h...12h caps + "Any").
final class EventFilterSheetSliderTests: XCTestCase {

    /// Typical slider width inside a Form row on a modern iPhone.
    private let width: CGFloat = 300

    func testTapAtLeadingEdgeClampsToMinimum() {
        XCTAssertEqual(EventFilterSheet.sliderValue(forTapX: 0, trackWidth: width), 1)
    }

    func testTapBeforeLeadingEdgeClampsToMinimum() {
        XCTAssertEqual(EventFilterSheet.sliderValue(forTapX: -50, trackWidth: width), 1)
    }

    func testTapAtTrailingEdgeClampsToAnyPosition() {
        XCTAssertEqual(EventFilterSheet.sliderValue(forTapX: width, trackWidth: width), 13)
    }

    func testTapPastTrailingEdgeClampsToAnyPosition() {
        XCTAssertEqual(EventFilterSheet.sliderValue(forTapX: width + 50, trackWidth: width), 13)
    }

    func testTapAtCenterSnapsToMiddlePosition() {
        // 13 positions -> center of the span is position 7 (7h).
        XCTAssertEqual(EventFilterSheet.sliderValue(forTapX: width / 2, trackWidth: width), 7)
    }

    func testEveryPositionReachableAtItsTrackCenter() {
        let inset = EventFilterSheet.sliderThumbInset
        let usable = width - 2 * inset
        for position in 1...13 {
            let fraction = CGFloat(position - 1) / 12
            let x = inset + fraction * usable
            XCTAssertEqual(
                EventFilterSheet.sliderValue(forTapX: x, trackWidth: width),
                Double(position),
                "tap at the exact track fraction for position \(position) should select it"
            )
        }
    }

    func testDegenerateWidthFallsBackToMinimum() {
        XCTAssertEqual(EventFilterSheet.sliderValue(forTapX: 10, trackWidth: 0), 1)
        XCTAssertEqual(EventFilterSheet.sliderValue(forTapX: 10, trackWidth: 20), 1)
    }
}
