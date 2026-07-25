//
//  MapScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import PlayaDB
import PlayaGeo
import SwiftUI

/// How the camera tracks the user, MapKit-style.
private enum TrackingMode {
    case free          // user panned away; camera stays put
    case follow        // center follows user, north-up
    case followHeading // center follows user, map rotates to compass heading
}

/// Offline BRC map: Digital Crown zooms, double tap zooms in one level,
/// drag pans. The bottom toolbar carries a MapKit-style tracking button that
/// cycles free → follow (north-up, centered on the user) → follow-heading (map
/// rotates to the compass) → free, plus a drop-pin button; panning drops back to
/// free without moving the camera.
struct MapScreen: View {
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService
    @ObservedObject var pinStore: PinStore

    @State private var camera = MapCamera(center: .zero, metersPerPoint: 25)
    /// Crown zoom level; metersPerPoint = 50 / 2^(level/2).
    @State private var zoomLevel: Double = 1
    @State private var trackingMode: TrackingMode = .follow
    @State private var dragStartCenter: CGPoint?
    @State private var showingDropPin = false

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
        // +2 crown units = one map zoom level (halves metersPerPoint).
        .onTapGesture(count: 2) {
            zoomLevel = min(zoomLevel + 2, 12)
        }
        .gesture(dragGesture)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                trackingButton
                dropPinButton
            }
        }
        .sheet(isPresented: $showingDropPin) {
            DropPinSheet(
                coordinate: location.location?.coordinate,
                pinStore: pinStore
            ) { _ in
                showingDropPin = false
            }
        }
        .overlay(alignment: .top) {
            if trackingMode == .followHeading && location.needsCalibration {
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
        if trackingMode == .followHeading, let heading = location.headingDegrees {
            cam.headingDegrees = heading
        }
        if trackingMode != .free, let point = userPoint {
            cam.center = point
        }
        return cam
    }

    private var userPoint: CGPoint? {
        guard let location = location.location else { return nil }
        return mapData.pointOnPlaya(
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
        let landmarks = mapData.pois
            .filter { $0.ref == "center" || $0.ref == "centerCamp" }
            .map { poi in
                MapMarker(
                    id: poi.ref ?? poi.name,
                    point: poi.point,
                    label: camera.metersPerPoint < 20 ? poi.name : nil,
                    color: .orange
                )
            }
        let pins = pinStore.pins.map { pin in
            MapMarker(
                id: pin.id,
                point: mapData.projection.point(
                    for: GeoCoordinate(latitude: pin.latitude, longitude: pin.longitude)
                ),
                label: camera.metersPerPoint < 20 ? pin.displayTitle : nil,
                color: pin.type.tint,
                symbolName: pin.type.symbolName
            )
        }
        // Pins last so they draw over the landmarks.
        return landmarks + pins
    }

    // MARK: - Gestures & controls

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartCenter == nil {
                    dragStartCenter = displayCamera.center
                    // Bake the compass rotation so the map doesn't snap under the finger.
                    if trackingMode == .followHeading {
                        camera.headingDegrees = location.headingDegrees ?? camera.headingDegrees
                    }
                    trackingMode = .free
                }
                var cam = displayCamera
                cam.center = dragStartCenter ?? cam.center
                camera.center = cam.centerAfterPan(translation: value.translation)
            }
            .onEnded { _ in
                dragStartCenter = nil
            }
    }

    /// MapKit's cycle: free → follow → follow-heading → free.
    private var trackingButton: some View {
        Button {
            switch trackingMode {
            case .free:
                trackingMode = .follow
                camera.headingDegrees = 0
                if userPoint == nil {
                    camera.center = .zero
                }
            case .follow:
                trackingMode = .followHeading
            case .followHeading:
                trackingMode = .free
                // Keep the map where the user is looking; only stop tracking.
                camera.center = displayCamera.center
                camera.headingDegrees = displayCamera.headingDegrees
            }
        } label: {
            Image(systemName: trackingIcon)
                .foregroundStyle(trackingTint)
        }
        .accessibilityLabel(trackingAccessibilityLabel)
    }

    private var dropPinButton: some View {
        Button {
            showingDropPin = true
        } label: {
            Image(systemName: "mappin.and.ellipse")
        }
        .accessibilityLabel("Drop a pin here")
    }

    private var trackingIcon: String {
        switch trackingMode {
        case .free: return "location"
        case .follow: return "location.fill"
        case .followHeading: return "location.north.line.fill"
        }
    }

    private var trackingTint: Color {
        switch trackingMode {
        case .free: return .primary
        case .follow: return .blue
        case .followHeading: return .orange
        }
    }

    private var trackingAccessibilityLabel: String {
        switch trackingMode {
        case .free: return "Follow my location"
        case .follow: return "Switch to compass mode"
        case .followHeading: return "Stop following my location"
        }
    }
}

#Preview("City overview") {
    MapScreen(
        mapData: PreviewMapData.data,
        location: LocationService(),
        pinStore: PinStore(previewPins: PreviewPins.pins)
    )
}

/// Zoomed to the 6:00 blocks — exercises the street-name label pass.
#Preview("Street detail") {
    PlayaMapView(
        data: PreviewMapData.data,
        camera: MapCamera(center: CGPoint(x: 0, y: 900), metersPerPoint: 3)
    )
    .ignoresSafeArea()
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
