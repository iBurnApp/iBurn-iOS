//
//  MapUserTrackingBarButtonItem.swift
//  iBurn
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Replaces `BRCUserTrackingBarButtonItem`, a vendored Route-Me/MapLibre button from
//  2013. That one rendered a PNG mask into a bitmap with a hardcoded +2pt vertical
//  offset and animated its own 4pt-radius tinted background — which on iOS 26 draws a
//  second, squarish backplate inside the system's glass capsule and leaves the arrow
//  visibly off-center. Using a plain image `UIBarButtonItem` with SF Symbols instead
//  hands sizing, tinting, and the Liquid Glass capsule back to UIKit.
//

import UIKit
import CoreLocation
import MapLibre

/// Cycles the map's user-tracking mode (off → follow → follow-with-heading) and
/// mirrors the current mode in its icon, matching Apple Maps' semantics.
final class MapUserTrackingBarButtonItem: UIBarButtonItem {

    private weak var mapView: MLNMapView?
    private var isObserving = false

    /// MapLibre mutates `userLocation.location` in place, so this has to be string-based
    /// KVO — a Swift key path with optional chaining has no `_kvcKeyPathString`.
    private static let observedKeyPaths = ["userTrackingMode", "userLocation.location"]
    private static var observationContext = 0

    /// Shown in place of the icon while tracking is requested but no fix has arrived
    /// yet — the playa's cold starts can take a while, so the wait needs to be visible.
    private lazy var activityView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        return view
    }()

    private var isAwaitingFix = false

    init(mapView: MLNMapView) {
        self.mapView = mapView
        super.init()
        self.target = self
        self.action = #selector(cycleTrackingMode)
        self.accessibilityLabel = NSLocalizedString("Tracking Mode", comment: "accessibility label for the map locate button")

        for keyPath in Self.observedKeyPaths {
            mapView.addObserver(self, forKeyPath: keyPath, options: [.new], context: &Self.observationContext)
        }
        isObserving = true
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        guard isObserving, let mapView else { return }
        for keyPath in Self.observedKeyPaths {
            mapView.removeObserver(self, forKeyPath: keyPath, context: &Self.observationContext)
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard context == &Self.observationContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if Thread.isMainThread {
            updateAppearance()
        } else {
            DispatchQueue.main.async { [weak self] in self?.updateAppearance() }
        }
    }

    // MARK: - Actions

    @objc private func cycleTrackingMode() {
        guard let mapView else { return }
        switch mapView.userTrackingMode {
        case .none:
            mapView.userTrackingMode = .follow
        case .follow:
            mapView.userTrackingMode = CLLocationManager.headingAvailable() ? .followWithHeading : .none
        default:
            mapView.userTrackingMode = .none
        }
        updateAppearance()
    }

    // MARK: - Appearance

    private func updateAppearance() {
        guard let mapView else { return }
        let mode = mapView.userTrackingMode

        // Tracking was asked for but there's no fix yet: show the spinner rather than an
        // icon that would imply we already know where the user is.
        let hasFix: Bool
        if let location = mapView.userLocation?.location {
            hasFix = location.coordinate.latitude != 0 || location.coordinate.longitude != 0
        } else {
            hasFix = false
        }
        let shouldAwaitFix = mode != .none && !hasFix

        if shouldAwaitFix != isAwaitingFix {
            isAwaitingFix = shouldAwaitFix
            if shouldAwaitFix {
                activityView.startAnimating()
                customView = activityView
            } else {
                activityView.stopAnimating()
                // Clearing customView restores the item's own image rendering, which is
                // what picks up the system glass background on iOS 26.
                customView = nil
            }
        }

        guard !isAwaitingFix else { return }
        image = UIImage(systemName: Self.symbolName(for: mode))
    }

    private static func symbolName(for mode: MLNUserTrackingMode) -> String {
        switch mode {
        case .none: return "location"
        case .follow: return "location.fill"
        case .followWithHeading: return "location.north.line.fill"
        case .followWithCourse: return "location.north.fill"
        @unknown default: return "location"
        }
    }
}
