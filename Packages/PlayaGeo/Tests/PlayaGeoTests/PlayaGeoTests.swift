//
//  PlayaGeoTests.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/3/26.
//

import XCTest
@testable import PlayaGeo

final class GeoJSONTests: XCTestCase {
    private func loadFixture() throws -> [GeoFeature] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/mini", withExtension: "geojson"))
        return try GeoJSON.decodeFeatureCollection(try Data(contentsOf: url))
    }

    func testDecodesFeaturesAndSkipsNullGeometry() throws {
        let features = try loadFixture()
        // 5 features in the file, one has null geometry and is skipped.
        XCTAssertEqual(features.count, 4)
    }

    func testPointFeatureProperties() throws {
        let features = try loadFixture()
        let center = try XCTUnwrap(features.first(where: { $0.string("ref") == "center" }))
        guard case .point(let coordinate) = center.geometry else {
            return XCTFail("expected point geometry")
        }
        XCTAssertEqual(coordinate.latitude, 40.7864, accuracy: 1e-9)
        XCTAssertEqual(coordinate.longitude, -119.2065, accuracy: 1e-9)
        XCTAssertEqual(center.string("name"), "The Man")
    }

    func testLineStringAndNumberProperty() throws {
        let features = try loadFixture()
        let esplanade = try XCTUnwrap(features.first(where: { $0.string("name") == "Esplanade" }))
        XCTAssertEqual(esplanade.number("width"), 40)
        guard case .lineString(let line) = esplanade.geometry else {
            return XCTFail("expected lineString")
        }
        XCTAssertEqual(line.count, 3)
    }

    func testMultiLineStringAndPolygon() throws {
        let features = try loadFixture()
        let split = try XCTUnwrap(features.first(where: { $0.string("name") == "Split" }))
        guard case .multiLineString(let lines) = split.geometry else {
            return XCTFail("expected multiLineString")
        }
        XCTAssertEqual(lines.map(\.count), [2, 2])

        let plaza = try XCTUnwrap(features.first(where: { $0.string("name") == "Plaza" }))
        guard case .polygon(let rings) = plaza.geometry else {
            return XCTFail("expected polygon")
        }
        XCTAssertEqual(rings.first?.count, 4)
    }

    func testRejectsNonFeatureCollection() {
        let data = Data(#"{"type": "Feature"}"#.utf8)
        XCTAssertThrowsError(try GeoJSON.decodeFeatureCollection(data))
    }
}

final class PlayaProjectionTests: XCTestCase {
    private let man = GeoCoordinate(latitude: 40.7864, longitude: -119.2065)

    func testOriginProjectsToZero() {
        let projection = PlayaProjection(origin: man)
        let p = projection.point(for: man)
        XCTAssertEqual(p.x, 0, accuracy: 1e-9)
        XCTAssertEqual(p.y, 0, accuracy: 1e-9)
    }

    func testNorthIsNegativeYEastIsPositiveX() {
        let projection = PlayaProjection(origin: man)
        let north = projection.point(for: GeoCoordinate(latitude: man.latitude + 0.01, longitude: man.longitude))
        XCTAssertLessThan(north.y, -1000)
        XCTAssertEqual(north.x, 0, accuracy: 1e-9)

        let east = projection.point(for: GeoCoordinate(latitude: man.latitude, longitude: man.longitude + 0.01))
        XCTAssertGreaterThan(east.x, 500)
        XCTAssertEqual(east.y, 0, accuracy: 1e-9)
    }

    func testKnownDistanceScale() {
        let projection = PlayaProjection(origin: man)
        // 0.01° latitude ≈ 1,110 m anywhere on Earth.
        let north = projection.point(for: GeoCoordinate(latitude: man.latitude + 0.01, longitude: man.longitude))
        XCTAssertEqual(Double(-north.y), 1109, accuracy: 5)
        // 0.01° longitude at ~40.79°N ≈ 843 m.
        let east = projection.point(for: GeoCoordinate(latitude: man.latitude, longitude: man.longitude + 0.01))
        XCTAssertEqual(Double(east.x), 843, accuracy: 5)
    }

    func testRoundTrip() {
        let projection = PlayaProjection(origin: man)
        let original = GeoCoordinate(latitude: 40.7789, longitude: -119.2134)
        let restored = projection.coordinate(for: projection.point(for: original))
        XCTAssertEqual(restored.latitude, original.latitude, accuracy: 1e-9)
        XCTAssertEqual(restored.longitude, original.longitude, accuracy: 1e-9)
    }
}

final class MapCameraTests: XCTestCase {
    private let viewport = CGSize(width: 200, height: 200)

    func testCenterMapsToViewportCenter() {
        let camera = MapCamera(center: CGPoint(x: 500, y: -300), metersPerPoint: 4, headingDegrees: 45)
        let screen = camera.center.applying(camera.transform(viewport: viewport))
        XCTAssertEqual(screen.x, 100, accuracy: 1e-6)
        XCTAssertEqual(screen.y, 100, accuracy: 1e-6)
    }

    func testNorthUpNorthPointsToTopOfScreen() {
        let camera = MapCamera(center: .zero, metersPerPoint: 1, headingDegrees: 0)
        // 10 m north of center = world (0, -10).
        let screen = CGPoint(x: 0, y: -10).applying(camera.transform(viewport: viewport))
        XCTAssertEqual(screen.x, 100, accuracy: 1e-6)
        XCTAssertEqual(screen.y, 90, accuracy: 1e-6)
    }

    func testHeadingUpRotatesFacingDirectionToTop() {
        // Facing east (heading 90): a point east of center should render above center.
        let camera = MapCamera(center: .zero, metersPerPoint: 1, headingDegrees: 90)
        let screen = CGPoint(x: 10, y: 0).applying(camera.transform(viewport: viewport))
        XCTAssertEqual(screen.x, 100, accuracy: 1e-6)
        XCTAssertEqual(screen.y, 90, accuracy: 1e-6)
    }

    func testZoomScalesDistances() {
        let camera = MapCamera(center: .zero, metersPerPoint: 5, headingDegrees: 0)
        let screen = CGPoint(x: 50, y: 0).applying(camera.transform(viewport: viewport))
        XCTAssertEqual(screen.x, 110, accuracy: 1e-6)
    }

    func testPanNorthUpMovesCenterOppositeToDrag() {
        let camera = MapCamera(center: .zero, metersPerPoint: 2, headingDegrees: 0)
        // Dragging right by 10 pts moves the world left: center shifts -20 m in x.
        let newCenter = camera.centerAfterPan(translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(newCenter.x, -20, accuracy: 1e-6)
        XCTAssertEqual(newCenter.y, 0, accuracy: 1e-6)
    }

    func testPanRespectsRotation() {
        // Heading-up facing east: east is at the top of the screen, so the bottom
        // of the viewport shows what lies west. Dragging up reveals more of the
        // bottom — the center must move west (-x).
        let camera = MapCamera(center: .zero, metersPerPoint: 1, headingDegrees: 90)
        let newCenter = camera.centerAfterPan(translation: CGSize(width: 0, height: -10))
        XCTAssertEqual(newCenter.x, -10, accuracy: 1e-6)
        XCTAssertEqual(newCenter.y, 0, accuracy: 1e-6)
    }

    func testFittingContainsAllPoints() {
        let points = [CGPoint(x: -1000, y: -800), CGPoint(x: 1000, y: 800)]
        let camera = MapCamera.fitting(points: points, viewport: viewport)
        XCTAssertEqual(camera.center.x, 0, accuracy: 1e-6)
        XCTAssertEqual(camera.center.y, 0, accuracy: 1e-6)

        let transform = camera.transform(viewport: viewport)
        for point in points {
            let screen = point.applying(transform)
            XCTAssertTrue((0...200).contains(screen.x), "x \(screen.x) out of viewport")
            XCTAssertTrue((0...200).contains(screen.y), "y \(screen.y) out of viewport")
        }
    }

    func testFittingEmptyPointsFallsBackToDefault() {
        let camera = MapCamera.fitting(points: [], viewport: viewport)
        XCTAssertEqual(camera.center, .zero)
    }
}

final class PlayaMapDataTests: XCTestCase {
    func testLoadFromRealCityData() throws {
        // Uses the real 2026 geo files when present (repo checkout); skips otherwise.
        let geoDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PlayaGeoTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // PlayaGeo
            .deletingLastPathComponent() // Packages
            .appendingPathComponent("Submodules/iBurn-Data/data/2026/geo")
        guard FileManager.default.fileExists(atPath: geoDir.appendingPathComponent("points.geojson").path),
              let bundle = Bundle(url: geoDir) ?? Bundle(path: geoDir.path) else {
            throw XCTSkip("2026 geo data not available")
        }

        let data = try PlayaMapData.load(from: bundle)
        XCTAssertEqual(data.projection.origin.latitude, 40.78, accuracy: 0.05)
        XCTAssertGreaterThan(data.streets.count, 30)
        XCTAssertFalse(data.fence.isEmpty)
        XCTAssertGreaterThan(data.toilets.count, 20)
        XCTAssertGreaterThan(data.pois.count, 5)
        // The whole city fits within ~6 km of The Man.
        for point in data.cityBounds {
            XCTAssertLessThan(abs(point.x), 6000)
            XCTAssertLessThan(abs(point.y), 6000)
        }
    }

    func testPointOnPlayaClampsFarOffFixes() {
        let man = GeoCoordinate(latitude: 40.783242, longitude: -119.207871)
        let mapData = PlayaMapData(
            projection: PlayaProjection(origin: man),
            streets: [], fence: [], plazas: [], toilets: [], pois: []
        )

        // At The Man → world origin.
        let atMan = mapData.pointOnPlaya(for: man)
        XCTAssertNotNil(atMan)
        XCTAssertEqual(atMan.map { hypot($0.x, $0.y) } ?? -1, 0, accuracy: 0.001)

        // ~3 km out (deep playa / fence) still counts as on-playa.
        let deepPlaya = GeoCoordinate(latitude: 40.810, longitude: -119.208)
        XCTAssertNotNil(mapData.pointOnPlaya(for: deepPlaya))

        // San Francisco → nil; a follow-camera there would render a blank map.
        let sanFrancisco = GeoCoordinate(latitude: 37.7749, longitude: -122.4194)
        XCTAssertNil(mapData.pointOnPlaya(for: sanFrancisco))
    }
}
