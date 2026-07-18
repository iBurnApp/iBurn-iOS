//
//  StreetLabelLayout.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/12/26.
//

import CoreGraphics
import Foundation

/// Where to draw one street-name label, in screen space.
public struct StreetLabelPlacement: Equatable, Sendable {
    public let point: CGPoint
    /// Radians; already normalized to (-π/2, π/2] so text reads upright.
    public let angle: Double

    public init(point: CGPoint, angle: Double) {
        self.point = point
        self.angle = angle
    }
}

public enum StreetLabelLayout {
    /// Places labels along a screen-space polyline: one every `interval` points
    /// of path length, starting at interval/2, keeping only placements whose
    /// point lies inside `bounds` (caller pre-insets for margin). Angle is the
    /// local segment tangent, normalized upright.
    public static func placements(
        along screenPoints: [CGPoint],
        interval: CGFloat,
        bounds: CGRect
    ) -> [StreetLabelPlacement] {
        guard screenPoints.count >= 2, interval > 0 else { return [] }

        var placements: [StreetLabelPlacement] = []
        var traveled: CGFloat = 0
        var nextTarget = interval / 2

        for (start, end) in zip(screenPoints, screenPoints.dropFirst()) {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let segmentLength = hypot(dx, dy)
            guard segmentLength > 0 else { continue }

            while traveled + segmentLength >= nextTarget {
                let t = (nextTarget - traveled) / segmentLength
                let point = CGPoint(x: start.x + dx * t, y: start.y + dy * t)

                // Segment tangent, folded into (-π/2, π/2] so text reads upright.
                var angle = atan2(Double(dy), Double(dx))
                while angle > .pi / 2 { angle -= .pi }
                while angle <= -.pi / 2 { angle += .pi }

                if bounds.contains(point) {
                    placements.append(StreetLabelPlacement(point: point, angle: angle))
                }
                nextTarget += interval
            }
            traveled += segmentLength
        }
        return placements
    }
}
