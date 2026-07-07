//
//  DetailScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import PlayaDB
import PlayaGeo
import SwiftUI

struct DetailScreen: View {
    let object: any DataObject
    let playaDB: PlayaDB
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService
    var onFavoriteChange: () -> Void = {}

    @State private var isFavorite = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(object.objectType.emoji)
                    Text(object.name)
                        .font(.headline)
                }

                Button {
                    Task {
                        do {
                            try await playaDB.setFavorite(!isFavorite, for: object)
                            isFavorite.toggle()
                            onFavoriteChange()
                        } catch {
                            print("Favorite toggle failed: \(error)")
                        }
                    }
                } label: {
                    Label(
                        isFavorite ? "Remove Favorite" : "Add Favorite",
                        systemImage: isFavorite ? "heart.fill" : "heart"
                    )
                }
                .tint(isFavorite ? .red : nil)

                if object.hasLocation {
                    NavigationLink {
                        NavigationScreen(
                            target: object,
                            mapData: mapData,
                            location: location
                        )
                    } label: {
                        Label("Navigate", systemImage: "location.north.circle.fill")
                    }
                    .tint(.orange)
                } else {
                    Text("Location hidden until gates open")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let description = object.description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(object.objectType.displayName)
        .task {
            isFavorite = (try? await playaDB.isFavorite(object)) ?? false
        }
    }
}

/// Compass navigation to a single POI: map fit to you + the target, heading-up
/// when the compass is available, with live distance/bearing readout.
struct NavigationScreen: View {
    let target: any DataObject
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService

    var body: some View {
        GeometryReader { geometry in
            let targetPoint = targetWorldPoint
            let userPoint = userWorldPoint

            ZStack(alignment: .bottom) {
                PlayaMapView(
                    data: mapData,
                    camera: camera(viewport: geometry.size, user: userPoint, target: targetPoint),
                    user: userPoint.map {
                        PlayaMapView.UserState(point: $0, headingDegrees: location.headingDegrees)
                    },
                    markers: targetPoint.map {
                        [MapMarker(id: target.uid, point: $0, label: target.name, color: .red)]
                    } ?? []
                )
                .ignoresSafeArea()

                if let readout {
                    Text(readout)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.65), in: Capsule())
                }
            }
            .overlay(alignment: .top) {
                if location.needsCalibration {
                    Text("Wave your wrist in a figure-8 to calibrate")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .padding(4)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onAppear { location.start() }
        .navigationTitle("Navigate")
    }

    private var targetWorldPoint: CGPoint? {
        guard let targetLocation = target.location else { return nil }
        return mapData.projection.point(
            for: GeoCoordinate(
                latitude: targetLocation.coordinate.latitude,
                longitude: targetLocation.coordinate.longitude
            )
        )
    }

    private var userWorldPoint: CGPoint? {
        guard let userLocation = location.location else { return nil }
        return mapData.pointOnPlaya(
            for: GeoCoordinate(
                latitude: userLocation.coordinate.latitude,
                longitude: userLocation.coordinate.longitude
            )
        )
    }

    private func camera(viewport: CGSize, user: CGPoint?, target: CGPoint?) -> MapCamera {
        var points = [CGPoint]()
        if let user { points.append(user) }
        if let target { points.append(target) }
        if points.isEmpty { points = mapData.cityBounds }
        var cam = MapCamera.fitting(points: points, viewport: viewport, paddingFraction: 0.22, minMetersPerPoint: 1)
        if let heading = location.headingDegrees {
            cam.headingDegrees = heading
        }
        return cam
    }

    private var readout: String? {
        guard let user = userWorldPoint, let target = targetWorldPoint else { return nil }
        let dx = Double(target.x - user.x)
        let dy = Double(target.y - user.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        // World +y is south, so north = -dy.
        var bearing = atan2(dx, -dy) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return "\(formatDistance(distance)) · \(Int(bearing.rounded()))°"
    }
}
