//
//  MapCamera.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/3/26.
//

import CoreGraphics
import Foundation

/// Camera over projected world space (meters, +x east, +y south).
public struct MapCamera: Equatable, Sendable {
    /// World point (meters) at the viewport center.
    public var center: CGPoint
    /// Zoom: world meters represented by one screen point.
    public var metersPerPoint: Double
    /// Map rotation in degrees. 0 = north-up. Set to the user's compass heading
    /// for heading-up mode (the direction they face points to the top of screen).
    public var headingDegrees: Double

    public init(center: CGPoint = .zero, metersPerPoint: Double = 8, headingDegrees: Double = 0) {
        self.center = center
        self.metersPerPoint = metersPerPoint
        self.headingDegrees = headingDegrees
    }

    /// World → screen transform for the given viewport size.
    public func transform(viewport: CGSize) -> CGAffineTransform {
        CGAffineTransform.identity
            .translatedBy(x: viewport.width / 2, y: viewport.height / 2)
            .rotated(by: -headingDegrees * .pi / 180)
            .scaledBy(x: 1 / metersPerPoint, y: 1 / metersPerPoint)
            .translatedBy(x: -center.x, y: -center.y)
    }

    /// Converts a screen-space pan translation into a new camera center, taking
    /// rotation into account (dragging always moves the map under the finger).
    public func centerAfterPan(translation: CGSize) -> CGPoint {
        let angle = headingDegrees * .pi / 180
        let dx = Double(-translation.width) * metersPerPoint
        let dy = Double(-translation.height) * metersPerPoint
        return CGPoint(
            x: center.x + dx * cos(angle) - dy * sin(angle),
            y: center.y + dx * sin(angle) + dy * cos(angle)
        )
    }

    /// Camera fitting the given world-space bounding box into the viewport,
    /// north-up, with padding on every edge.
    public static func fitting(
        points: [CGPoint],
        viewport: CGSize,
        paddingFraction: CGFloat = 0.15,
        minMetersPerPoint: Double = 0.5
    ) -> MapCamera {
        guard let first = points.first else { return MapCamera() }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let usableWidth = viewport.width * (1 - 2 * paddingFraction)
        let usableHeight = viewport.height * (1 - 2 * paddingFraction)
        let scaleX = usableWidth > 0 ? Double((maxX - minX) / usableWidth) : 0
        let scaleY = usableHeight > 0 ? Double((maxY - minY) / usableHeight) : 0
        return MapCamera(
            center: CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
            metersPerPoint: max(scaleX, scaleY, minMetersPerPoint),
            headingDegrees: 0
        )
    }
}
