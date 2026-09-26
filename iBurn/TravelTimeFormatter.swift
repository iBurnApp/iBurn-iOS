//
//  TravelTimeFormatter.swift
//  iBurn
//
//  Swift port of the old `TTTLocationFormatter+iBurn` category (FormatterKit), which only
//  used FormatterKit as a namespace. The output string is unchanged: "🚶🏽 6m   🚴🏽 2m".
//

import CoreLocation
import Foundation
import UIKit

/// Turns a distance on the playa into how long it takes to get there on foot and by bike.
enum TravelTimeFormatter {

    /// Seconds per meter for walking.
    static let walkingSecondsPerMeter = 1.4
    /// Seconds per meter for biking. Copenhagen commuters average about 15.5 km/h (9.6 mph).
    static let bikingSecondsPerMeter = 0.432258065
    /// Every estimate gets 120 seconds of faffing time added.
    static let faffSeconds: TimeInterval = 120

    /// Under this many seconds a trip is easy (green).
    static let easyThreshold: TimeInterval = 20 * 60
    /// At or over this many seconds a trip is hard (red). In between is orange.
    static let hardThreshold: TimeInterval = 35 * 60

    enum Effort: Equatable {
        case easy
        case moderate
        case hard

        var color: UIColor {
            switch self {
            case .easy: return .brc_green
            case .moderate: return .brc_orange
            case .hard: return .brc_red
            }
        }
    }

    /// Estimated walking time in seconds, faff included.
    static func walkSeconds(forDistance distance: CLLocationDistance) -> TimeInterval {
        walkingSecondsPerMeter * distance + faffSeconds
    }

    /// Estimated biking time in seconds, faff included.
    static func bikeSeconds(forDistance distance: CLLocationDistance) -> TimeInterval {
        bikingSecondsPerMeter * distance + faffSeconds
    }

    /// Green under 20 minutes, orange under 35, red after that.
    static func effort(forTimeInterval interval: TimeInterval) -> Effort {
        if interval < easyThreshold {
            return .easy
        } else if interval < hardThreshold {
            return .moderate
        } else {
            return .hard
        }
    }

    /// The plain estimate, e.g. "🚶🏽 6m   🚴🏽 2m", or nil when a time can't be formatted.
    static func string(forDistance distance: CLLocationDistance) -> String? {
        parts(forDistance: distance)?.string
    }

    /// The estimate with each time colored by `effort(forTimeInterval:)`.
    static func attributedString(forDistance distance: CLLocationDistance) -> NSAttributedString? {
        guard let parts = parts(forDistance: distance) else { return nil }
        let result = NSMutableAttributedString(string: parts.string)
        result.addAttribute(.foregroundColor,
                            value: effort(forTimeInterval: parts.walkSeconds).color,
                            range: parts.walkRange)
        result.addAttribute(.foregroundColor,
                            value: effort(forTimeInterval: parts.bikeSeconds).color,
                            range: parts.bikeRange)
        return result
    }

    // MARK: - Private

    private struct Parts {
        let string: String
        let walkSeconds: TimeInterval
        let bikeSeconds: TimeInterval
        let walkRange: NSRange
        let bikeRange: NSRange
    }

    private static let walkPrefix = "🚶🏽 "
    private static let separator = "   🚴🏽 "

    private static func parts(forDistance distance: CLLocationDistance) -> Parts? {
        let walk = walkSeconds(forDistance: distance)
        let bike = bikeSeconds(forDistance: distance)
        guard let walkText = DateFormatters.stringForTimeInterval(walk),
              let bikeText = DateFormatters.stringForTimeInterval(bike) else {
            return nil
        }
        let string = walkPrefix + walkText + separator + bikeText
        // Ranges are built from the pieces rather than searched for, so a bike time that is
        // a substring of the walk time ("1m" inside "11m") still colors the right text.
        let walkLocation = (walkPrefix as NSString).length
        let walkLength = (walkText as NSString).length
        let bikeLocation = walkLocation + walkLength + (separator as NSString).length
        let bikeLength = (bikeText as NSString).length
        return Parts(
            string: string,
            walkSeconds: walk,
            bikeSeconds: bike,
            walkRange: NSRange(location: walkLocation, length: walkLength),
            bikeRange: NSRange(location: bikeLocation, length: bikeLength)
        )
    }
}
