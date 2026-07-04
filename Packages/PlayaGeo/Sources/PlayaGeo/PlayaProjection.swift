//
//  PlayaProjection.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/3/26.
//

import CoreGraphics
import Foundation

/// Equirectangular projection centered on a reference coordinate (The Man).
/// World space is in meters: +x east, +y SOUTH (screen-down), so north renders
/// up with an identity rotation. Accurate to well under a meter at Black Rock
/// City scale (~4 km across).
public struct PlayaProjection: Equatable, Sendable {
    public let origin: GeoCoordinate

    private let metersPerDegreeLatitude: Double
    private let metersPerDegreeLongitude: Double

    public init(origin: GeoCoordinate) {
        self.origin = origin
        let latRadians = origin.latitude * .pi / 180
        // WGS84 local scale factors.
        metersPerDegreeLatitude = 111_132.92 - 559.82 * cos(2 * latRadians) + 1.175 * cos(4 * latRadians)
        metersPerDegreeLongitude = 111_412.84 * cos(latRadians) - 93.5 * cos(3 * latRadians)
    }

    public func point(for coordinate: GeoCoordinate) -> CGPoint {
        CGPoint(
            x: (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude,
            y: -(coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
        )
    }

    public func coordinate(for point: CGPoint) -> GeoCoordinate {
        GeoCoordinate(
            latitude: origin.latitude - Double(point.y) / metersPerDegreeLatitude,
            longitude: origin.longitude + Double(point.x) / metersPerDegreeLongitude
        )
    }
}
