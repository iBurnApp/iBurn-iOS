//
//  PlayaMapData.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/3/26.
//

import CoreGraphics
import Foundation

/// City geometry projected into world space (meters around The Man),
/// ready for rendering.
public struct PlayaMapData: Sendable {
    public struct Street: Sendable {
        public enum Kind: Sendable {
            /// Concentric arc street (Esplanade, A–L).
            case arc
            /// Radial time street (2:00–10:00).
            case radial
            case other
        }

        public let name: String?
        public let kind: Kind
        /// Nominal street width in meters (the source data uses feet-derived
        /// values; already converted).
        public let widthMeters: Double
        public let paths: [[CGPoint]]
    }

    public struct POI: Sendable {
        public let name: String
        public let ref: String?
        public let point: CGPoint
    }

    public let projection: PlayaProjection
    public let streets: [Street]
    public let fence: [[CGPoint]]
    /// Plaza/district outer rings.
    public let plazas: [[CGPoint]]
    public let toilets: [CGPoint]
    public let pois: [POI]

    public init(
        projection: PlayaProjection,
        streets: [Street],
        fence: [[CGPoint]],
        plazas: [[CGPoint]],
        toilets: [CGPoint],
        pois: [POI]
    ) {
        self.projection = projection
        self.streets = streets
        self.fence = fence
        self.plazas = plazas
        self.toilets = toilets
        self.pois = pois
    }
}

public enum PlayaMapDataError: Error {
    case missingResource(String)
    case missingCenterPOI
}

public extension PlayaMapData {
    /// Loads the map from GeoJSON resources in a bundle:
    /// `points.geojson` (required — supplies the projection origin via
    /// `ref == "center"`, i.e. The Man), plus optional `streets.geojson`,
    /// `fence.geojson`, `polygons.geojson`, `toilets.geojson`.
    static func load(from bundle: Bundle) throws -> PlayaMapData {
        func features(_ name: String) throws -> [GeoFeature] {
            guard let url = bundle.url(forResource: name, withExtension: "geojson") else {
                return []
            }
            return try GeoJSON.decodeFeatureCollection(try Data(contentsOf: url))
        }

        guard let pointsURL = bundle.url(forResource: "points", withExtension: "geojson") else {
            throw PlayaMapDataError.missingResource("points.geojson")
        }
        let pointFeatures = try GeoJSON.decodeFeatureCollection(try Data(contentsOf: pointsURL))

        guard let center = pointFeatures.first(where: { $0.string("ref") == "center" }),
              case .point(let manCoordinate) = center.geometry else {
            throw PlayaMapDataError.missingCenterPOI
        }
        let projection = PlayaProjection(origin: manCoordinate)

        func project(_ line: [GeoCoordinate]) -> [CGPoint] {
            line.map(projection.point(for:))
        }

        func projectedLines(_ geometry: GeoGeometry) -> [[CGPoint]] {
            switch geometry {
            case .lineString(let line): return [project(line)]
            case .multiLineString(let lines): return lines.map(project)
            case .polygon(let rings): return rings.first.map { [project($0)] } ?? []
            case .multiPolygon(let polygons): return polygons.compactMap { $0.first.map(project) }
            case .point: return []
            }
        }

        let streets: [Street] = try features("streets").map { feature in
            let kind: Street.Kind
            switch feature.string("type") {
            case "arc": kind = .arc
            case "radial": kind = .radial
            default: kind = .other
            }
            return Street(
                name: feature.string("name"),
                kind: kind,
                widthMeters: feature.number("width").map { $0 * 0.3048 } ?? 12,
                paths: projectedLines(feature.geometry)
            )
        }

        let fence = try features("fence").flatMap { projectedLines($0.geometry) }
        let plazas = try features("polygons").flatMap { projectedLines($0.geometry) }

        let toilets: [CGPoint] = try features("toilets").compactMap { feature in
            switch feature.geometry {
            case .point(let coordinate):
                return projection.point(for: coordinate)
            case .polygon(let rings):
                guard let ring = rings.first, !ring.isEmpty else { return nil }
                let points = ring.map(projection.point(for:))
                let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
                return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
            default:
                return nil
            }
        }

        let pois: [POI] = pointFeatures.compactMap { feature in
            guard case .point(let coordinate) = feature.geometry,
                  let name = feature.string("name") else { return nil }
            return POI(name: name, ref: feature.string("ref"), point: projection.point(for: coordinate))
        }

        return PlayaMapData(
            projection: projection,
            streets: streets,
            fence: fence,
            plazas: plazas,
            toilets: toilets,
            pois: pois
        )
    }

    /// All fence points — a convenient bounding set for fit-to-city cameras.
    var cityBounds: [CGPoint] {
        fence.flatMap { $0 }
    }

    /// Projects a coordinate into world space, or nil when it is farther than
    /// `maxDistanceMeters` from the projection origin (The Man). Following or
    /// camera-fitting a far-off fix — e.g. a dev running the app at home —
    /// would fling the camera hundreds of km from the city and render a blank
    /// map, so treat such fixes as "not at the event". The default radius
    /// covers the fence, deep playa, and the airport with margin.
    func pointOnPlaya(for coordinate: GeoCoordinate, maxDistanceMeters: CGFloat = 10_000) -> CGPoint? {
        let point = projection.point(for: coordinate)
        guard hypot(point.x, point.y) < maxDistanceMeters else { return nil }
        return point
    }
}
