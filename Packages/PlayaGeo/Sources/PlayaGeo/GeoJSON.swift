//
//  GeoJSON.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/3/26.
//

import Foundation

/// A WGS84 coordinate. PlayaGeo carries its own type so the package stays
/// dependency-free; app targets convert from CLLocationCoordinate2D.
public struct GeoCoordinate: Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum GeoGeometry: Sendable {
    case point(GeoCoordinate)
    case lineString([GeoCoordinate])
    case multiLineString([[GeoCoordinate]])
    /// Rings; first ring is the outer boundary.
    case polygon([[GeoCoordinate]])
    case multiPolygon([[[GeoCoordinate]]])
}

public struct GeoFeature: Sendable {
    public let stringProperties: [String: String]
    public let numberProperties: [String: Double]
    public let geometry: GeoGeometry

    public func string(_ key: String) -> String? { stringProperties[key] }
    public func number(_ key: String) -> Double? { numberProperties[key] }
}

public enum GeoJSONError: Error {
    case notAFeatureCollection
    case malformedGeometry
}

public enum GeoJSON {
    /// Decodes a GeoJSON FeatureCollection. Features with unsupported or null
    /// geometry are skipped rather than failing the whole file.
    public static func decodeFeatureCollection(_ data: Data) throws -> [GeoFeature] {
        let root = try JSONSerialization.jsonObject(with: data)
        guard let dict = root as? [String: Any],
              dict["type"] as? String == "FeatureCollection",
              let features = dict["features"] as? [[String: Any]] else {
            throw GeoJSONError.notAFeatureCollection
        }
        return features.compactMap(feature(from:))
    }

    private static func feature(from dict: [String: Any]) -> GeoFeature? {
        guard let geometryDict = dict["geometry"] as? [String: Any],
              let geometry = geometry(from: geometryDict) else {
            return nil
        }
        var strings: [String: String] = [:]
        var numbers: [String: Double] = [:]
        for (key, value) in dict["properties"] as? [String: Any] ?? [:] {
            switch value {
            case let s as String: strings[key] = s
            case let n as NSNumber: numbers[key] = n.doubleValue
            default: break
            }
        }
        return GeoFeature(stringProperties: strings, numberProperties: numbers, geometry: geometry)
    }

    private static func geometry(from dict: [String: Any]) -> GeoGeometry? {
        guard let type = dict["type"] as? String,
              let coords = dict["coordinates"] else {
            return nil
        }
        switch type {
        case "Point":
            return position(coords).map(GeoGeometry.point)
        case "LineString":
            return line(coords).map(GeoGeometry.lineString)
        case "MultiLineString":
            return lines(coords).map(GeoGeometry.multiLineString)
        case "Polygon":
            return lines(coords).map(GeoGeometry.polygon)
        case "MultiPolygon":
            guard let array = coords as? [Any] else { return nil }
            let polygons = array.compactMap(lines(_:))
            guard polygons.count == array.count else { return nil }
            return .multiPolygon(polygons)
        default:
            return nil
        }
    }

    /// GeoJSON positions are [longitude, latitude].
    private static func position(_ value: Any) -> GeoCoordinate? {
        guard let pair = value as? [Any], pair.count >= 2,
              let lon = (pair[0] as? NSNumber)?.doubleValue,
              let lat = (pair[1] as? NSNumber)?.doubleValue else {
            return nil
        }
        return GeoCoordinate(latitude: lat, longitude: lon)
    }

    private static func line(_ value: Any) -> [GeoCoordinate]? {
        guard let array = value as? [Any] else { return nil }
        let coords = array.compactMap(position(_:))
        return coords.count == array.count ? coords : nil
    }

    private static func lines(_ value: Any) -> [[GeoCoordinate]]? {
        guard let array = value as? [Any] else { return nil }
        let result = array.compactMap(line(_:))
        return result.count == array.count ? result : nil
    }
}
