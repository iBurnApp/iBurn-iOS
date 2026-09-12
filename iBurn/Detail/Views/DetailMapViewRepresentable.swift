//
//  DetailMapViewRepresentable.swift
//  iBurn
//
//  Created by Claude Code on 7/13/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import MapLibre
import CoreLocation

/// SwiftUI wrapper for MLNMapView to display embedded map previews in DetailView
struct DetailMapViewRepresentable: UIViewRepresentable {
    private let annotationProvider: () -> MLNAnnotation?
    let onTap: () -> Void

    init(
        annotation: MLNAnnotation,
        onTap: @escaping () -> Void
    ) {
        self.annotationProvider = { annotation }
        self.onTap = onTap
    }

    /// Matches the rounding the rest of the detail screen's inset content uses, so the
    /// preview reads as a card rather than as a hole cut in the page.
    static let cornerRadius: CGFloat = 14

    /// Breathing room around the two framed points so neither the pin nor the blue dot
    /// lands under the rounded corners. Same inset the legacy UIKit detail screen used.
    static let framingPadding = UIEdgeInsets(top: 45, left: 45, bottom: 45, right: 45)

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView.brcMapView()
        mapView.isUserInteractionEnabled = false

        // Rounded here rather than at the two call sites: `.mapView` and `.mapAnnotation`
        // are the same preview and must not drift apart. `masksToBounds` clips MapLibre's
        // own render layer along with everything else.
        mapView.layer.cornerRadius = Self.cornerRadius
        mapView.layer.cornerCurve = .continuous
        mapView.layer.masksToBounds = true

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        mapView.addGestureRecognizer(tapGesture)

        // Builds the adapter and claims the delegate. Must happen after the map view is
        // fully configured, and exactly once — see `Coordinator.attach(to:)`.
        context.coordinator.attach(to: mapView)

        return mapView
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        context.coordinator.update(annotation: annotationProvider())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    /// The single `MLNMapViewDelegate` for the preview map.
    ///
    /// `MapViewAdapter` also wants to be the map's delegate (it sets itself in `init`), but
    /// it only implements the annotation-rendering half of the protocol. When it held the
    /// delegate directly, the framing callbacks this coordinator needs
    /// (`mapViewDidFinishLoadingMap`, `didUpdate userLocation`) were never delivered and the
    /// preview sat at the default whole-city camera forever. So the coordinator takes the
    /// delegate back after building the adapter and forwards the adapter's methods to it.
    class Coordinator: NSObject, MLNMapViewDelegate {
        let onTap: () -> Void

        /// Built once per map view and reused. `MapViewAdapter` holds its map view strongly;
        /// the map view's `delegate` is weak, so nothing here retains the coordinator.
        private(set) var mapViewAdapter: MapViewAdapter?
        private weak var mapView: MLNMapView?

        /// The annotation currently framed/displayed, after the data source's embargo filter.
        private var framingAnnotation: MLNAnnotation?
        private var state = DetailMapFramingState()

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap() {
            onTap()
        }

        // MARK: Setup

        func attach(to mapView: MLNMapView) {
            guard mapViewAdapter == nil else { return }
            self.mapView = mapView
            // `MapViewAdapter.init` installs itself as the delegate; take it back so the
            // framing callbacks below actually arrive, and forward what the adapter needs.
            let adapter = MapViewAdapter(mapView: mapView)
            mapView.delegate = self
            mapViewAdapter = adapter
        }

        // MARK: Annotation updates

        func update(annotation: MLNAnnotation?) {
            guard let mapView, let adapter = mapViewAdapter else { return }

            let dataSource = annotation.map { StaticAnnotationDataSource(annotation: $0) }
            // Read back through the data source so an embargoed pin is treated as "no
            // location" here too, rather than being framed and then never drawn.
            let incoming = dataSource?.allAnnotations().first

            if !DetailMapFramingState.isEquivalent(incoming, framingAnnotation) {
                framingAnnotation = incoming
                state.hasFramed = false
                state.framedWithUserLocation = false
                adapter.dataSource = dataSource
                adapter.reloadAnnotations()
            }

            frameIfNeeded(mapView)
        }

        // MARK: Framing

        private func frameIfNeeded(_ mapView: MLNMapView) {
            state.hasNonZeroBounds = !mapView.bounds.isEmpty
            state.hasAnnotation = framingAnnotation != nil
            guard DetailMapFramingState.shouldFrame(state) else { return }
            frame(mapView, animated: false)
        }

        private func frame(_ mapView: MLNMapView, animated: Bool) {
            state.hasFramed = true
            state.framedWithUserLocation = DetailMapFramingState.framesAroundUser(mapView.userLocation?.location)
            if let framingAnnotation {
                mapView.brc_showDestination(framingAnnotation,
                                            animated: animated,
                                            padding: DetailMapViewRepresentable.framingPadding)
            } else {
                // No usable coordinate (event with no location, embargoed pin): show the
                // city rather than leaving whatever camera the map happened to have.
                mapView.brc_moveToBlackRockCityCenter(animated: animated)
            }
        }

        // MARK: - MLNMapViewDelegate (framing)

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            state.isMapReady = true
            frameIfNeeded(mapView)
        }

        func mapViewDidFinishRenderingFrame(_ mapView: MLNMapView, fullyRendered: Bool) {
            // Safety net for the ordering SwiftUI actually produces: `updateUIView` can run
            // before the view has a size, and `mapViewDidFinishLoadingMap` can fire while the
            // frame is still zero. A rendered frame means both a size and a live style.
            // Guarded by `hasFramed`, so this is a cheap no-op on every subsequent frame.
            guard !state.hasFramed else { return }
            state.isMapReady = true
            frameIfNeeded(mapView)
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            // The first fix usually lands after the initial framing, which then framed the
            // destination against the Man instead of the user. Re-frame exactly once, when a
            // fix that is actually on playa arrives; never again, so this can't fight itself.
            guard DetailMapFramingState.shouldReframeForUserLocation(
                state,
                userLocationFramesAroundUser: DetailMapFramingState.framesAroundUser(userLocation?.location)
            ) else { return }
            frame(mapView, animated: true)
        }

        // MARK: - MLNMapViewDelegate (forwarded to MapViewAdapter)

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            mapViewAdapter?.mapView(mapView, didFinishLoading: style)
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let mapViewAdapter else { return nil }
            return mapViewAdapter.mapView(mapView, viewFor: annotation)
        }

        func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
            mapViewAdapter?.mapView(mapView, annotationCanShowCallout: annotation) ?? false
        }

        func mapView(_ mapView: MLNMapView, didDeselect annotation: MLNAnnotation) {
            mapViewAdapter?.mapView(mapView, didDeselect: annotation)
        }

        func mapView(_ mapView: MLNMapView, leftCalloutAccessoryViewFor annotation: MLNAnnotation) -> UIView? {
            guard let mapViewAdapter else { return nil }
            return mapViewAdapter.mapView(mapView, leftCalloutAccessoryViewFor: annotation)
        }

        func mapView(_ mapView: MLNMapView, rightCalloutAccessoryViewFor annotation: MLNAnnotation) -> UIView? {
            guard let mapViewAdapter else { return nil }
            return mapViewAdapter.mapView(mapView, rightCalloutAccessoryViewFor: annotation)
        }

        func mapView(_ mapView: MLNMapView, annotation: MLNAnnotation, calloutAccessoryControlTapped control: UIControl) {
            mapViewAdapter?.mapView(mapView, annotation: annotation, calloutAccessoryControlTapped: control)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            mapViewAdapter?.mapView(mapView, regionDidChangeAnimated: animated)
        }
    }
}

// MARK: - Framing decision

/// Everything the detail preview needs to decide whether to move its camera, kept free of
/// UIKit/MapLibre so the rules can be tested directly.
struct DetailMapFramingState: Equatable {
    /// The map view has been laid out. A zero-sized map projects NaN, so framing it is both
    /// meaningless and unsafe.
    var hasNonZeroBounds = false
    /// The style has loaded or at least one frame has rendered.
    var isMapReady = false
    /// There is a pin to frame. False means "center on the city" instead.
    var hasAnnotation = false
    /// The camera has already been placed for the current annotation.
    var hasFramed = false
    /// That placement included a real on-playa fix, so a later fix adds nothing.
    var framedWithUserLocation = false

    /// The initial placement: once, as soon as the map can be framed at all.
    static func shouldFrame(_ state: DetailMapFramingState) -> Bool {
        state.hasNonZeroBounds && state.isMapReady && !state.hasFramed
    }

    /// The one re-frame allowed after the fact: the first on-playa fix to arrive after a
    /// placement that had to fall back to the Man. Requires a pin — with nothing to frame
    /// against, the user's dot alone wouldn't improve the picture.
    static func shouldReframeForUserLocation(
        _ state: DetailMapFramingState,
        userLocationFramesAroundUser: Bool
    ) -> Bool {
        state.hasFramed
            && state.hasAnnotation
            && !state.framedWithUserLocation
            && userLocationFramesAroundUser
    }

    /// Whether `location` is the point `brc_showDestination` will actually frame against, as
    /// opposed to the Man standing in for a missing or far-away fix.
    /// Mirrors `BRCLocations.mapFramingCoordinate(forUserLocation:)`.
    static func framesAroundUser(_ location: CLLocation?) -> Bool {
        let framing = BRCLocations.mapFramingCoordinate(forUserLocation: location)
        let center = BRCLocations.blackRockCityCenter
        return framing.latitude != center.latitude || framing.longitude != center.longitude
    }

    /// Whether a freshly built annotation represents the same pin as the one on the map.
    /// Callers may mint a fresh annotation on every SwiftUI update, so identity alone would
    /// reload and re-animate the map on every pass.
    static func isEquivalent(_ lhs: MLNAnnotation?, _ rhs: MLNAnnotation?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            if lhs === rhs { return true }
            return lhs.coordinate.latitude == rhs.coordinate.latitude
                && lhs.coordinate.longitude == rhs.coordinate.longitude
                && (lhs.title ?? nil) == (rhs.title ?? nil)
        default:
            return false
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct DetailMapViewRepresentable_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Map Preview")
                .font(.headline)

            Text("Map component requires real data objects")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(height: 200)
                .border(Color.gray, width: 1)

            Text("Tap the map to navigate")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
#endif
