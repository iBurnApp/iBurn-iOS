//
//  MapBackdropStore.swift
//  iBurn
//
//  Created by Claude Code on 8/7/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Keeps the last frame the map drew before it went off screen.
//
//  `UITabBarController` unloads the selected tab's view when another tab takes over, so
//  the search tab genuinely has nothing behind it — a transparent search screen shows the
//  window, not the map. Rather than stand up a second `MLNMapView` just to fill that gap,
//  the map hands over a still of itself on the way out and search paints that underneath.
//
//  The still is only ever a backdrop, never something you interact with, so a frozen frame
//  is honest: the map isn't live while you're typing either way.
//

import UIKit

@MainActor
final class MapBackdropStore {
    static let shared = MapBackdropStore()

    private(set) var image: UIImage?

    private init() {}

    /// Captures `view` as it currently appears. Called from the map's `viewWillDisappear`,
    /// while it's still in the window — an off-window view renders blank.
    func capture(_ view: UIView) {
        guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else { return }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        // `afterScreenUpdates: false` reuses the frame already on screen instead of forcing
        // a fresh render pass, which is both cheaper and safe to call mid-transition.
        image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
    }
}
