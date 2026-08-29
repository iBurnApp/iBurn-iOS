//
//  EmbargoUnlockScheduler.swift
//  iBurn
//
//  Created by Claude Code on 8/22/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaDB
import UIKit

/// Which tiers were visible the last time anybody looked.
///
/// Only the locked → unlocked direction matters: nothing in the app re-locks
/// (the region latch and the passcode never clear, and the dates only move
/// forward), and a spurious "did clear" is a wasted reload of every live
/// surface, so the transition is spelled out rather than a plain `!=`.
struct EmbargoUnlockState: Equatable {

    let canShowCampLocations: Bool
    let canShowArtLocations: Bool

    /// Everything embargoed — the state a fresh install boots into.
    static let locked = EmbargoUnlockState(canShowCampLocations: false, canShowArtLocations: false)

    /// Did any tier become visible going from `previous` to `self`?
    func didUnlock(comparedTo previous: EmbargoUnlockState) -> Bool {
        (canShowCampLocations && !previous.canShowCampLocations)
            || (canShowArtLocations && !previous.canShowArtLocations)
    }
}

/// A one-shot timer, as a seam. `Timer` is the production implementation;
/// tests hand the scheduler a fake so nothing has to sleep.
protocol EmbargoUnlockTimer: AnyObject {
    func invalidate()
}

extension Timer: EmbargoUnlockTimer {}

/// Re-evaluates the embargo when the clock — not the user — is what changed.
///
/// `.BRCEmbargoDidClear` used to fire from exactly two places, both of them
/// events: passcode entry and entering the Burning Man region. That was enough
/// while every tier needed a GPS fix, but the camp tier became **date-only** on
/// 2026-08-22, so an app that is merely running (or suspended, which iOS will
/// happily do for days) across `YearSettings.campLocationUnlock` keeps drawing
/// "Location Restricted" until it is killed and relaunched. Everything that
/// listens for the notification — `PlayaDBAnnotationDataSource`,
/// `UserMapViewAdapter`, `BaseMapViewController`, the Nearby view models, the
/// list hosting controllers, the watch bridge in `DependencyContainer` — is
/// stuck with it.
///
/// So: hold the last verdict, re-evaluate whenever the clock could plausibly
/// have crossed an unlock instant, and post only on a real locked → unlocked
/// transition.
protocol EmbargoUnlockScheduling: AnyObject {

    /// Records the current verdict as the baseline (posting nothing — at launch
    /// every surface is about to read the live state anyway) and starts
    /// watching for the transitions.
    func start()

    /// Re-evaluates now. Posts `.BRCEmbargoDidClear` iff a tier just unlocked.
    /// - Returns: whether it posted.
    @discardableResult
    func refresh() -> Bool

    /// Drops the timer and the notification observers.
    func stop()
}

/// The shipping `EmbargoUnlockScheduling`.
///
/// Three triggers, deliberately overlapping — a missed unlock is a user-visible
/// bug and a redundant check is free:
///
/// 1. **`start()`**, from `DependencyContainer`, i.e. app launch.
/// 2. **`UIApplication.didBecomeActive`** and
///    **`significantTimeChange`** (the latter fires on day rollover, timezone
///    changes and clock edits) — this is what covers the suspended-across-
///    midnight case, which is the common one.
/// 3. **A one-shot timer** at the next unlock instant, so an app left in the
///    foreground across midnight updates without being touched.
///
/// Every input is injectable, and `now` comes from the same `Date.present` the
/// verdict itself uses, so the mock-date scheme ("iBurn (Mock Date)") moves the
/// scheduler's clock too.
///
/// Not thread-safe by design: `start()`, the notification observers (registered
/// on `.main`) and the timer all run on the main thread, which is also where
/// `.BRCEmbargoDidClear` has to be posted.
final class EmbargoUnlockSchedulerImpl: EmbargoUnlockScheduling {

    /// Don't arm a timer further out than this. A device whose clock is years
    /// behind would otherwise hold a `Timer` with an absurd fire date; a
    /// foreground/time-change trigger will pick the unlock up when it is
    /// actually near. Comfortably longer than a year, so the real dates always
    /// schedule.
    static let maximumScheduledInterval: TimeInterval = 400 * 24 * 60 * 60

    /// Fire a beat *after* the unlock instant: `canShowLocations` wants
    /// `now >= unlock`, and a timer that fires a few microseconds early would
    /// evaluate to still-locked and then have nothing left to re-arm on.
    private static let fireDelay: TimeInterval = 1

    private let now: () -> Date
    private let stateProvider: (Date) -> EmbargoUnlockState
    private let unlockDates: () -> [Date]
    private let post: () -> Void
    private let makeTimer: (TimeInterval, @escaping () -> Void) -> EmbargoUnlockTimer
    private let notificationCenter: NotificationCenter

    private var lastState: EmbargoUnlockState = .locked
    private var timer: EmbargoUnlockTimer?
    private var observers: [NSObjectProtocol] = []

    /// - Parameters:
    ///   - now: the clock. `Date.present`, so the mock-date scheme applies.
    ///   - stateProvider: the verdict for a given instant. Defaults to the live
    ///     rule (`EmbargoService`), passcode latch and region latch included.
    ///   - unlockDates: instants worth waking up for.
    ///   - post: how a transition is announced. Defaults to
    ///     `BRCEmbargoNotifier.postDidClear()`.
    ///   - makeTimer: the one-shot timer factory.
    ///   - notificationCenter: where the lifecycle notifications come from.
    init(
        now: @escaping () -> Date = { Date.present },
        stateProvider: @escaping (Date) -> EmbargoUnlockState = EmbargoUnlockSchedulerImpl.liveState(at:),
        unlockDates: @escaping () -> [Date] = {
            [YearSettings.campLocationUnlock, YearSettings.eventStart]
        },
        post: @escaping () -> Void = { BRCEmbargoNotifier.postDidClear() },
        makeTimer: @escaping (TimeInterval, @escaping () -> Void) -> EmbargoUnlockTimer
            = EmbargoUnlockSchedulerImpl.makeRunLoopTimer,
        notificationCenter: NotificationCenter = .default
    ) {
        self.now = now
        self.stateProvider = stateProvider
        self.unlockDates = unlockDates
        self.post = post
        self.makeTimer = makeTimer
        self.notificationCenter = notificationCenter
    }

    deinit {
        timer?.invalidate()
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    /// The live rule, with the app's own inputs — the default `stateProvider`.
    static func liveState(at now: Date) -> EmbargoUnlockState {
        let passcodeUnlocked = EmbargoService.passcodeUnlocked
        let inRegion = EmbargoService.hasSeenBurningManRegion
        return EmbargoUnlockState(
            canShowCampLocations: EmbargoService.canShowLocations(
                tier: .camp, now: now, passcodeUnlocked: passcodeUnlocked, inRegion: inRegion),
            canShowArtLocations: EmbargoService.canShowLocations(
                tier: .art, now: now, passcodeUnlocked: passcodeUnlocked, inRegion: inRegion)
        )
    }

    /// The default `makeTimer`: a non-repeating `Timer` on the main run loop,
    /// tolerant because a few seconds' slop past midnight is invisible and the
    /// coalescing is worth it.
    static func makeRunLoopTimer(
        interval: TimeInterval,
        fire: @escaping () -> Void
    ) -> EmbargoUnlockTimer {
        let timer = Timer(timeInterval: interval, repeats: false) { _ in fire() }
        timer.tolerance = min(max(interval * 0.05, 1), 60)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    // MARK: - EmbargoUnlockScheduling

    func start() {
        // Launch: whatever is visible now is the baseline. Posting here would
        // only make every surface reload the state it is about to read anyway.
        lastState = stateProvider(now())
        observeLifecycle()
        scheduleNextEvaluation()
    }

    @discardableResult
    func refresh() -> Bool {
        let state = stateProvider(now())
        let didUnlock = state.didUnlock(comparedTo: lastState)
        lastState = state
        if didUnlock {
            post()
        }
        return didUnlock
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    // MARK: - Triggers

    private func observeLifecycle() {
        guard observers.isEmpty else { return }
        let names: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.significantTimeChangeNotification
        ]
        observers = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.evaluateAndReschedule()
            }
        }
    }

    /// Foreground / time change / timer fire: same handling. Rescheduling after
    /// every one keeps a single armed timer, and re-arms for the *second* tier
    /// once the first one's instant has passed.
    private func evaluateAndReschedule() {
        refresh()
        scheduleNextEvaluation()
    }

    /// Arms one timer for the soonest unlock instant still in the future.
    /// Nothing pending (or something absurdly far off) means no timer at all —
    /// the foreground triggers remain.
    private func scheduleNextEvaluation() {
        timer?.invalidate()
        timer = nil

        let current = now()
        guard let next = unlockDates()
            .filter({ $0 > current })
            .min()
        else { return }

        let interval = next.timeIntervalSince(current) + Self.fireDelay
        guard interval.isFinite,
              interval > 0,
              interval <= Self.maximumScheduledInterval
        else { return }

        timer = makeTimer(interval) { [weak self] in
            self?.evaluateAndReschedule()
        }
    }
}

/// Builds the app's `EmbargoUnlockScheduling`, hiding the implementation from
/// its one caller (`DependencyContainer`).
enum EmbargoUnlockSchedulerFactory {
    static func makeScheduler() -> EmbargoUnlockScheduling {
        EmbargoUnlockSchedulerImpl()
    }
}
