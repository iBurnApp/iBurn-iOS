//
//  PlayaMapView.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/3/26.
//

import SwiftUI

/// Marker rendered on top of the base map (target POI, favorites, etc.).
public struct MapMarker: Identifiable, Sendable {
    public let id: String
    public let point: CGPoint
    public let label: String?
    public let color: Color

    public init(id: String, point: CGPoint, label: String? = nil, color: Color = .red) {
        self.id = id
        self.point = point
        self.label = label
        self.color = color
    }
}

/// Offline vector map of Black Rock City drawn with SwiftUI Canvas.
/// Pure rendering: pan/zoom/rotation live in `camera`, owned by the caller.
public struct PlayaMapView: View {
    public struct UserState {
        public let point: CGPoint
        /// Compass heading in degrees (0 = north) — draws the direction cone.
        public let headingDegrees: Double?

        public init(point: CGPoint, headingDegrees: Double?) {
            self.point = point
            self.headingDegrees = headingDegrees
        }
    }

    let data: PlayaMapData
    let camera: MapCamera
    let user: UserState?
    let markers: [MapMarker]

    @Environment(\.colorScheme) private var colorScheme

    public init(
        data: PlayaMapData,
        camera: MapCamera,
        user: UserState? = nil,
        markers: [MapMarker] = []
    ) {
        self.data = data
        self.camera = camera
        self.user = user
        self.markers = markers
    }

    public var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let transform = camera.transform(viewport: size)
            let style = MapStyle(colorScheme: colorScheme)

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(style.background))

            // Plazas
            for ring in data.plazas {
                var path = polyline(ring, transform: transform)
                path.closeSubpath()
                context.fill(path, with: .color(style.plazaFill))
            }

            // Streets — width in true meters, clamped so far-out zooms stay legible.
            for street in data.streets {
                let lineWidth = max(1, street.widthMeters / camera.metersPerPoint)
                for line in street.paths {
                    context.stroke(
                        polyline(line, transform: transform),
                        with: .color(style.street),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }

            // Trash fence
            for line in data.fence {
                context.stroke(
                    polyline(line, transform: transform),
                    with: .color(style.fence),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            }

            // Toilets appear once zoomed in enough to be useful.
            if camera.metersPerPoint < 12 {
                for point in data.toilets {
                    let p = point.applying(transform)
                    let r: CGFloat = 2.5
                    context.fill(
                        Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                        with: .color(style.toilet)
                    )
                }
            }

            for marker in markers {
                draw(marker: marker, context: &context, transform: transform, style: style)
            }

            if let user {
                draw(user: user, context: &context, transform: transform, style: style)
            }
        }
    }

    private func polyline(_ points: [CGPoint], transform: CGAffineTransform) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first.applying(transform))
        for point in points.dropFirst() {
            path.addLine(to: point.applying(transform))
        }
        return path
    }

    private func draw(marker: MapMarker, context: inout GraphicsContext, transform: CGAffineTransform, style: MapStyle) {
        let p = marker.point.applying(transform)
        let r: CGFloat = 5
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
            with: .color(marker.color)
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
            with: .color(.white),
            lineWidth: 1.5
        )
        if let label = marker.label {
            context.draw(
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(style.label),
                at: CGPoint(x: p.x, y: p.y - r - 8)
            )
        }
    }

    private func draw(user: UserState, context: inout GraphicsContext, transform: CGAffineTransform, style: MapStyle) {
        let p = user.point.applying(transform)

        // Heading cone (under the dot). Screen angle accounts for map rotation.
        if let heading = user.headingDegrees {
            let screenAngle = (heading - camera.headingDegrees - 90) * .pi / 180
            let spread = 25 * Double.pi / 180
            let length: CGFloat = 22
            var cone = Path()
            cone.move(to: p)
            cone.addArc(
                center: p,
                radius: length,
                startAngle: .radians(screenAngle - spread),
                endAngle: .radians(screenAngle + spread),
                clockwise: false
            )
            cone.closeSubpath()
            context.fill(cone, with: .linearGradient(
                Gradient(colors: [style.userDot.opacity(0.5), style.userDot.opacity(0)]),
                startPoint: p,
                endPoint: CGPoint(x: p.x + cos(screenAngle) * length, y: p.y + sin(screenAngle) * length)
            ))
        }

        let r: CGFloat = 6
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
            with: .color(style.userDot)
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
            with: .color(.white),
            lineWidth: 2
        )
    }
}

private struct MapStyle {
    let background: Color
    let street: Color
    let fence: Color
    let plazaFill: Color
    let toilet: Color
    let userDot: Color
    let label: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(red: 0.09, green: 0.08, blue: 0.07)
            street = Color(red: 0.35, green: 0.32, blue: 0.28)
            fence = Color(red: 0.45, green: 0.35, blue: 0.25)
            plazaFill = Color(red: 0.20, green: 0.17, blue: 0.13)
            toilet = Color(red: 0.30, green: 0.55, blue: 0.85)
            userDot = Color(red: 0.25, green: 0.55, blue: 1.0)
            label = .white
        } else {
            background = Color(red: 0.96, green: 0.93, blue: 0.86)
            street = Color(red: 0.75, green: 0.70, blue: 0.60)
            fence = Color(red: 0.65, green: 0.50, blue: 0.35)
            plazaFill = Color(red: 0.88, green: 0.83, blue: 0.72)
            toilet = Color(red: 0.20, green: 0.45, blue: 0.80)
            userDot = Color(red: 0.10, green: 0.45, blue: 0.95)
            label = .black
        }
    }
}
