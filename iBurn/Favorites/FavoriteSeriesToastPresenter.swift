//
//  FavoriteSeriesToastPresenter.swift
//  iBurn
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import UIKit
import PlayaDB

/// Watches for "the user just favorited one showing of a recurring event" and offers to
/// favorite the rest.
///
/// ## Why a notification, not a call site
///
/// Hearts live in a dozen places — the browse lists, Detail, Nearby, the map's visible-pins
/// sheet, Recently Viewed, Visits, global search, the AI screen. They already funnel through
/// `PlayaDB.toggleFavorite`, which posts `.playaDBFavoriteDidChange` for exactly this kind of
/// "someone did something just now" reaction (the tab bar's favorite-button glow is the other
/// listener). Subscribing here covers every one of them without threading a callback through
/// each screen, and it can't drift out of sync with the ones that get added later.
///
/// `setFavorite` deliberately does *not* post, which is what stops the toast's own
/// "favorite them all" write from re-raising the toast.
///
/// ## Why one overlay in the app's window
///
/// The screens that raise it are a mix of UIKit view controllers, hosted SwiftUI, and
/// sheets. One card added to the app's window sits above all of them, so the toast is
/// written once instead of being installed on each screen — and it survives navigation
/// pushes and tab switches, which a per-screen overlay would not.
///
/// The window comes from `BRCAppDelegate.shared.window` rather than a `connectedScenes`
/// lookup: iBurn predates scenes (no `UIApplicationSceneManifest`; the app delegate makes
/// its own window), so walking the implicit `UIWindowScene` is not guaranteed to hand back
/// the window that is actually on screen.
@MainActor
final class FavoriteSeriesToastPresenter {

    /// The offer currently on screen, if any.
    private(set) var toast: FavoriteSeriesToast?

    /// How long an unanswered offer stays up.
    static let displayDuration: TimeInterval = 5

    private let playaDB: PlayaDB
    private let favoriteSync: FavoriteSyncService
    private var toastView: FavoriteSeriesToastView?
    private var dismissTask: Task<Void, Never>?
    private var resolveTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    init(playaDB: PlayaDB, favoriteSync: FavoriteSyncService) {
        self.playaDB = playaDB
        self.favoriteSync = favoriteSync
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Begins listening. Safe to call once, from app startup.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .playaDBFavoriteDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handle(notification)
            }
        }
    }

    // MARK: - Reacting to a favorite

    private func handle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let uid = userInfo[PlayaDBFavoriteChange.uidKey] as? String,
              let objectType = userInfo[PlayaDBFavoriteChange.objectTypeKey] as? String,
              let isFavorite = PlayaDBFavoriteChange.isFavorite(from: notification) else { return }

        guard let eventUID = FavoriteSeriesToastEligibility.candidateEventUID(
            objectType: objectType, uid: uid, isFavorite: isFavorite
        ) else { return }

        resolveTask?.cancel()
        resolveTask = Task { [weak self] in
            guard let self else { return }
            let occurrences = (try? await self.playaDB.fetchOccurrences(forEventUID: eventUID)) ?? []
            guard !Task.isCancelled else { return }
            guard let candidate = FavoriteSeriesToastEligibility.toast(
                eventUID: eventUID,
                favoritedIdentity: uid,
                eventName: occurrences.first?.name ?? "this event",
                occurrenceCount: occurrences.count
            ) else { return }
            self.present(candidate)
        }
    }

    // MARK: - Actions

    /// Favorites every remaining occurrence of the series and reconciles the calendar.
    func performSeriesFavorite() {
        guard let toast else { return }
        dismiss()
        let playaDB = self.playaDB
        let favoriteSync = self.favoriteSync
        Task {
            do {
                // One write covers every occurrence, so the list refreshes once rather
                // than flickering N times through the observation.
                _ = try await playaDB.setFavorite(true, forEventSeries: toast.eventUID)
            } catch {
                print("FavoriteSeriesToast: failed to favorite series \(toast.eventUID): \(error)")
                return
            }
            // Bare uid: the whole series changed, so every Yap occurrence mirrors and the
            // event's calendar entries are reconciled in one pass.
            await favoriteSync.mirrorFavorite(type: .event, uid: toast.eventUID, isFavorite: true)
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        toast = nil
        guard let view = toastView else { return }
        toastView = nil
        UIView.animate(withDuration: Self.animationDuration, animations: {
            view.alpha = 0
            if !UIAccessibility.isReduceMotionEnabled {
                view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height + 24)
            }
        }, completion: { _ in
            view.removeFromSuperview()
        })
    }

    // MARK: - Presentation

    /// Reduce Motion trades the slide for a plain cross-fade.
    private static let animationDuration: TimeInterval = 0.28

    private func present(_ candidate: FavoriteSeriesToast) {
        guard let root = Self.frontmostViewController() else { return }
        let window = BRCAppDelegate.shared.window

        // Replace rather than stack: a second offer while one is up means the user has
        // moved on to another event.
        toastView?.removeFromSuperview()
        toastView = nil

        let view = FavoriteSeriesToastView(
            toast: candidate,
            onAction: { [weak self] in self?.performSeriesFavorite() },
            onDismiss: { [weak self] in self?.dismiss() }
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 12),
            view.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -12),
            view.bottomAnchor.constraint(
                equalTo: window.bottomAnchor,
                constant: -Self.bottomClearance(over: root)
            ),
        ])
        window.layoutIfNeeded()

        view.alpha = 0
        if !UIAccessibility.isReduceMotionEnabled {
            view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height + 24)
        }
        UIView.animate(withDuration: Self.animationDuration,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0,
                       options: [.allowUserInteraction]) {
            view.alpha = 1
            view.transform = .identity
        }

        toast = candidate
        toastView = view

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.displayDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    // MARK: - Placement

    /// How far above the window's bottom edge the toast floats to stay clear of the chrome
    /// underneath.
    ///
    /// Measured from the tab bar's actual position rather than assumed: on iOS 26 the tab
    /// bar is a floating capsule inset from the bottom edge, so neither its height nor the
    /// safe-area inset alone describes where its top edge is. Falls back to a
    /// home-indicator-sized gap when there is no tab bar (a presented search screen or
    /// sheet), and to `tabBarFallback` when there is one that can't be found to measure.
    private static func bottomClearance(over root: UIViewController) -> CGFloat {
        let minimum = root.view.safeAreaInsets.bottom + 12
        if let tabBar = findTabBar(in: root.view), !tabBar.bounds.isEmpty {
            let barFrame = tabBar.convert(tabBar.bounds, to: root.view)
            return max(minimum, root.view.bounds.maxY - barFrame.minY + 12)
        }
        let isPresented = root.presentingViewController != nil
        return isPresented ? minimum : max(minimum, Self.tabBarFallback)
    }

    /// Clearance for the iOS 26 floating tab bar: its height plus the gap it floats above
    /// the bottom edge. Only used when the bar cannot be found to measure directly.
    private static let tabBarFallback: CGFloat = 96

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar, !tabBar.isHidden, tabBar.alpha > 0 { return tabBar }
        for subview in view.subviews {
            if let found = findTabBar(in: subview) { return found }
        }
        return nil
    }

    /// The view controller whose window the toast goes into, and whose chrome it clears:
    /// whatever is actually frontmost.
    ///
    /// Walks the presentation chain rather than stopping at the window's root, because
    /// several of the screens that raise a toast — global search, the map's visible-pins
    /// sheet, the filter sheets — are *presented* over the tab controller and have no tab
    /// bar of their own to clear.
    private static func frontmostViewController() -> UIViewController? {
        // `BRCAppDelegate.shared.window`, not a scene lookup: this app predates scenes and
        // makes its own window, so the implicit `UIWindowScene` UIKit synthesizes for it
        // does not necessarily list that window. Walking `connectedScenes` can hand back a
        // different window entirely — whose hierarchy accepts subviews, lays them out, and
        // reports them to accessibility while nothing ever appears on screen.
        let window = BRCAppDelegate.shared.window
        var controller = window.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
