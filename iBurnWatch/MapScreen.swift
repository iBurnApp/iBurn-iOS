//
//  MapScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import PlayaGeo
import SwiftUI

/// Offline BRC map: Digital Crown zooms, drag pans, compass button toggles
/// north-up vs heading-up. Follows the user until they pan away; recenter
/// button snaps back.
struct MapScreen: View {
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService

    @State private var camera = MapCamera(center: .zero, metersPerPoint: 25)
    /// Crown zoom level; metersPerPoint = 50 / 2^(level/2).
    @State private var zoomLevel: Double = 1
    @State private var headingUp = false
    @State private var followUser = true
    @State private var dragStartCenter: CGPoint?

    var body: some View {
        PlayaMapView(
            data: mapData,
            camera: displayCamera,
            user: userState,
            markers: markers
        )
        .ignoresSafeArea()
        .focusable(true)
        .digitalCrownRotation(
            $zoomLevel,
            from: 0,
            through: 12,
            by: 0.1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: zoomLevel) { _, newValue in
            camera.metersPerPoint = 50 / pow(2, newValue / 2)
        }
        .gesture(dragGesture)
        .overlay(alignment: .bottomTrailing) {
            controls
        }
        .overlay(alignment: .top) {
            if headingUp && location.needsCalibration {
                Text("Wave your wrist in a figure-8 to calibrate the compass")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .padding(6)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 4)
            }
        }
        .onAppear {
            location.start()
        }
        .navigationTitle("Map")
    }

    // MARK: - Camera composition

    private var displayCamera: MapCamera {
        var cam = camera
        if headingUp, let heading = location.headingDegrees {
            cam.headingDegrees = heading
        }
        if followUser, let point = userPoint {
            cam.center = point
        }
        return cam
    }

    private var userPoint: CGPoint? {
        guard let location = location.location else { return nil }
        return mapData.projection.point(
            for: GeoCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        )
    }

    private var userState: PlayaMapView.UserState? {
        guard let point = userPoint else { return nil }
        return PlayaMapView.UserState(point: point, headingDegrees: location.headingDegrees)
    }

    private var markers: [MapMarker] {
        mapData.pois
            .filter { $0.ref == "center" || $0.ref == "centerCamp" }
            .map { poi in
                MapMarker(
                    id: poi.ref ?? poi.name,
                    point: poi.point,
                    label: camera.metersPerPoint < 20 ? poi.name : nil,
                    color: .orange
                )
            }
    }

    // MARK: - Gestures & controls

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartCenter == nil {
                    dragStartCenter = displayCamera.center
                    followUser = false
                }
                var cam = displayCamera
                cam.center = dragStartCenter ?? cam.center
                camera.center = cam.centerAfterPan(translation: value.translation)
            }
            .onEnded { _ in
                dragStartCenter = nil
            }
    }

    private var controls: some View {
        VStack(spacing: 6) {
            Button {
                headingUp.toggle()
            } label: {
                Image(systemName: headingUp ? "location.north.line.fill" : "safari")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(7)
            .background(.black.opacity(0.55), in: Circle())
            .foregroundStyle(headingUp ? .orange : .white)
            .accessibilityLabel(headingUp ? "Switch to north up" : "Switch to compass mode")

            Button {
                followUser = true
                if userPoint == nil {
                    camera.center = .zero
                }
            } label: {
                Image(systemName: followUser ? "location.fill" : "location")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(7)
            .background(.black.opacity(0.55), in: Circle())
            .foregroundStyle(followUser ? .blue : .white)
            .accessibilityLabel("Recenter on my location")
        }
        .padding(.trailing, 2)
    }
}

#Preview("City overview") {
    MapScreen(mapData: PreviewMapData.data, location: LocationService())
}

enum PreviewMapData {
    static let data: PlayaMapData = {
        guard let data = try? PlayaMapData.load(from: .main) else {
            // Previews outside the watch target have no bundled geo files;
            // an empty map still renders the background.
            return PlayaMapData(
                projection: PlayaProjection(origin: GeoCoordinate(latitude: 40.7864, longitude: -119.2065)),
                streets: [],
                fence: [],
                plazas: [],
                toilets: [],
                pois: []
            )
        }
        return data
    }()
}
