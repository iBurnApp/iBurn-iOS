//
//  AreaPickerView.swift
//  iBurn
//
//  Lets the user pan/zoom the BRC map and capture the visible area as an
//  MKCoordinateRegion for scoping AI "Right Now" discovery.
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import MapKit
import MapLibre

/// Holds a weak reference to the live map view so the SwiftUI button can read its
/// current viewport when the user taps "Use this area."
final class AreaMapProxy {
    weak var mapView: MLNMapView?

    var currentRegion: MKCoordinateRegion? {
        guard let mapView else { return nil }
        let bounds = mapView.visibleCoordinateBounds
        return coordinateRegion(
            swLat: bounds.sw.latitude, swLon: bounds.sw.longitude,
            neLat: bounds.ne.latitude, neLon: bounds.ne.longitude
        )
    }
}

/// Convert SW/NE corner coordinates (e.g. a map's visible bounds) to an MKCoordinateRegion.
/// Free function so it can be unit-tested without a live map view.
func coordinateRegion(swLat: Double, swLon: Double, neLat: Double, neLon: Double) -> MKCoordinateRegion {
    MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: (swLat + neLat) / 2, longitude: (swLon + neLon) / 2),
        span: MKCoordinateSpan(latitudeDelta: abs(neLat - swLat), longitudeDelta: abs(neLon - swLon))
    )
}

struct AreaPickerView: View {
    let onUseArea: (MKCoordinateRegion) -> Void
    let onCancel: () -> Void

    @State private var proxy = AreaMapProxy()

    var body: some View {
        NavigationStack {
            ZStack {
                AreaPickerMapRepresentable(proxy: proxy)
                    .ignoresSafeArea(edges: .bottom)

                // Center reticle marks the focus of the selected area.
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Text("Pan & zoom to the area you want")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.ultraThinMaterial))
                    Button {
                        if let region = proxy.currentRegion {
                            onUseArea(region)
                        }
                    } label: {
                        Label("Use this area", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Pick an area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}

struct AreaPickerMapRepresentable: UIViewRepresentable {
    let proxy: AreaMapProxy

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView.brcMapView()
        mapView.showsUserLocation = true
        // Frame the whole city to start; the user zooms into their area of interest.
        mapView.brc_zoomToFullTileSource(animated: false)
        proxy.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        proxy.mapView = mapView
    }
}
