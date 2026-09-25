//
//  UIApplication+MainWindow.swift
//  iBurn
//
//  Created by Claude Code on 9/24/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import UIKit

/// Scene-aware window lookups.
///
/// iBurn adopted the UIScene lifecycle for the iOS 27 SDK (apps built against it that skip
/// scenes crash at launch). The window no longer lives on the app delegate: `SceneDelegate`
/// creates it. Everything that used to reach for `BRCAppDelegate.shared.window`,
/// `UIApplication.shared.keyWindow`, or `connectedScenes.first?.windows.first` goes through
/// here instead, so there is one definition of "the app's window".
///
/// `windows.first` is deliberately avoided: a scene can own more than one window (Siren's
/// update alert and other overlays put up their own), and the first one is not necessarily
/// the window the app's UI lives in.
extension UIApplication {

    /// The app's main window scene: the foreground-active one if there is one, otherwise the
    /// most recently foregrounded. iBurn declares a single scene
    /// (`UIApplicationSupportsMultipleScenes` = NO), so in practice this is that scene.
    @objc var mainWindowScene: UIWindowScene? {
        let windowScenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        return windowScenes.min { Self.rank($0.activationState) < Self.rank($1.activationState) }
    }

    /// The window the app's root view controller (onboarding or the tab controller) lives in.
    ///
    /// Prefers the window `SceneDelegate` installed; falls back to the scene's key window.
    /// `nil` before the first scene connects (e.g. during `didFinishLaunching`).
    @objc var mainWindow: UIWindow? {
        guard let scene = mainWindowScene else { return nil }
        if let window = (scene.delegate as? SceneDelegate)?.window {
            return window
        }
        return scene.keyWindow ?? scene.windows.first { !$0.isHidden }
    }

    /// Whatever is actually on top: walks the presentation chain from the main window's root,
    /// so callers presenting an alert don't silently fail when a sheet is already up.
    @objc var frontmostViewController: UIViewController? {
        var controller = mainWindow?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }

    /// Presents `viewController` over whatever is frontmost in the main window.
    ///
    /// App-level callers (location authorization, the playa region unlock, notification
    /// taps) can fire before the scene has connected; in that case the presentation waits for
    /// the first scene to become active instead of being dropped.
    @objc(brc_presentOnFrontmostViewController:)
    func presentOnFrontmostViewController(_ viewController: UIViewController) {
        if let presenter = frontmostViewController, presenter.view.window != nil {
            presenter.present(viewController, animated: true)
            return
        }
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: UIScene.didActivateNotification) {
                UIApplication.shared.frontmostViewController?.present(viewController, animated: true)
                break
            }
        }
    }

    private static func rank(_ state: UIScene.ActivationState) -> Int {
        switch state {
        case .foregroundActive: return 0
        case .foregroundInactive: return 1
        case .background: return 2
        case .unattached: return 3
        @unknown default: return 4
        }
    }
}
