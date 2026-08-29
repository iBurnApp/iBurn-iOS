//
//  EmbargoUnlockSchedulerTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/22/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import UIKit
import XCTest
@testable import iBurn
import PlayaDB

/// `EmbargoUnlockScheduler`: the clock, rather than the user, crossing a tier's
/// unlock instant.
///
/// Before this existed `.BRCEmbargoDidClear` only fired on passcode entry and on
/// entering the Burning Man region, which was sufficient while every tier needed
/// a GPS fix. The camp tier went date-only on 2026-08-22, so an app suspended
/// across `campLocationUnlock` kept every camp address hidden until it was
/// killed and relaunched.
///
/// Nothing here sleeps: `now` is a variable the test moves, and the timer is a
/// fake whose fire block the test calls by hand.
final class EmbargoUnlockSchedulerTests: XCTestCase {

    // MARK: - Test doubles

    /// A `Timer` stand-in that never runs; the test fires it.
    private final class FakeTimer: EmbargoUnlockTimer {
        var invalidated = false
        let fire: () -> Void
        init(fire: @escaping () -> Void) { self.fire = fire }
        func invalidate() { invalidated = true }
    }

    private final class TimerFactory {
        private(set) var scheduledIntervals: [TimeInterval] = []
        private(set) var timers: [FakeTimer] = []
        var latest: FakeTimer? { timers.last }

        func make(interval: TimeInterval, fire: @escaping () -> Void) -> EmbargoUnlockTimer {
            scheduledIntervals.append(interval)
            let timer = FakeTimer(fire: fire)
            timers.append(timer)
            return timer
        }
    }

    // MARK: - Fixture

    private let campUnlock = Date(timeIntervalSince1970: 1_000_000)
    private let artUnlock = Date(timeIntervalSince1970: 2_000_000)

    private var now = Date(timeIntervalSince1970: 0)
    private var posts = 0
    private var timerFactory = TimerFactory()
    /// A notification center of our own, so lifecycle notifications posted by
    /// the host app (or another test) can't reach the scheduler under test.
    private var center = NotificationCenter()

    override func setUpWithError() throws {
        try super.setUpWithError()
        now = Date(timeIntervalSince1970: 0)
        posts = 0
        timerFactory = TimerFactory()
        center = NotificationCenter()
    }

    /// A scheduler whose verdict is the pure tier rule against the test's clock:
    /// camp on its date alone, art needing the region too.
    private func makeScheduler(
        passcodeUnlocked: Bool = false,
        inRegion: Bool = false,
        unlockDates: [Date]? = nil
    ) -> EmbargoUnlockSchedulerImpl {
        let camp = campUnlock
        let art = artUnlock
        return EmbargoUnlockSchedulerImpl(
            now: { [weak self] in self?.now ?? Date(timeIntervalSince1970: 0) },
            stateProvider: { instant in
                EmbargoUnlockState(
                    canShowCampLocations: passcodeUnlocked || instant >= camp,
                    canShowArtLocations: passcodeUnlocked || (inRegion && instant >= art)
                )
            },
            unlockDates: { unlockDates ?? [camp, art] },
            post: { [weak self] in self?.posts += 1 },
            makeTimer: { [weak self] interval, fire in
                guard let self else { return FakeTimer(fire: fire) }
                return self.timerFactory.make(interval: interval, fire: fire)
            },
            notificationCenter: center
        )
    }

    // MARK: - Transitions

    /// The bug this whole type exists for: the camp date arriving while the app
    /// is alive.
    func testCampDateArrivingPostsOnce() throws {
        let scheduler = makeScheduler()
        scheduler.start()
        XCTAssertEqual(posts, 0, "launch records a baseline, it doesn't announce one")

        now = campUnlock.addingTimeInterval(1)
        XCTAssertTrue(scheduler.refresh())
        XCTAssertEqual(posts, 1)
        scheduler.stop()
    }

    /// Foregrounding the app over and over must not make every map data source
    /// and list controller reload.
    func testRepeatedRefreshesWithoutAChangeStaySilent() throws {
        let scheduler = makeScheduler()
        scheduler.start()

        now = campUnlock.addingTimeInterval(1)
        XCTAssertTrue(scheduler.refresh())
        for _ in 0..<5 {
            XCTAssertFalse(scheduler.refresh())
        }
        XCTAssertEqual(posts, 1)
        scheduler.stop()
    }

    /// Starting after a tier is already open is not an unlock — that state is
    /// the baseline, and every surface reads it live on first render anyway.
    func testStartingPastAnUnlockPostsNothing() throws {
        now = campUnlock.addingTimeInterval(1)
        let scheduler = makeScheduler()
        scheduler.start()
        XCTAssertFalse(scheduler.refresh())
        XCTAssertEqual(posts, 0)
        scheduler.stop()
    }

    /// Both tiers, in order: camp on its date, art only once the region latch is
    /// there too. Each opening posts exactly once.
    func testEachTierPostsAsItOpens() throws {
        let scheduler = makeScheduler(inRegion: true)
        scheduler.start()

        now = campUnlock.addingTimeInterval(1)
        XCTAssertTrue(scheduler.refresh())
        XCTAssertEqual(posts, 1)

        now = artUnlock.addingTimeInterval(-1)
        XCTAssertFalse(scheduler.refresh())

        now = artUnlock
        XCTAssertTrue(scheduler.refresh())
        XCTAssertEqual(posts, 2)
        scheduler.stop()
    }

    /// A clock dragged backwards re-locks the verdict, but that is not an
    /// unlock: nothing is posted, and moving forward again posts once.
    func testClockMovingBackwardsPostsNothingAndRearms() throws {
        let scheduler = makeScheduler()
        scheduler.start()

        now = campUnlock.addingTimeInterval(60)
        XCTAssertTrue(scheduler.refresh())
        XCTAssertEqual(posts, 1)

        now = campUnlock.addingTimeInterval(-60)
        XCTAssertFalse(scheduler.refresh(), "re-locking is not an unlock")
        XCTAssertEqual(posts, 1)

        now = campUnlock.addingTimeInterval(60)
        XCTAssertTrue(scheduler.refresh())
        XCTAssertEqual(posts, 2)
        scheduler.stop()
    }

    /// The passcode path already posts for itself, but the scheduler must agree
    /// with it rather than announcing the same unlock a second time on the next
    /// foreground.
    func testPasscodeStateIsAlreadyUnlockedAtStart() throws {
        let scheduler = makeScheduler(passcodeUnlocked: true)
        scheduler.start()
        now = artUnlock.addingTimeInterval(1)
        XCTAssertFalse(scheduler.refresh())
        XCTAssertEqual(posts, 0)
        scheduler.stop()
    }

    // MARK: - The state type

    func testUnlockStateOnlyCountsTheLockedToUnlockedDirection() {
        let locked = EmbargoUnlockState.locked
        let camp = EmbargoUnlockState(canShowCampLocations: true, canShowArtLocations: false)
        let both = EmbargoUnlockState(canShowCampLocations: true, canShowArtLocations: true)

        XCTAssertTrue(camp.didUnlock(comparedTo: locked))
        XCTAssertTrue(both.didUnlock(comparedTo: camp))
        XCTAssertFalse(camp.didUnlock(comparedTo: camp))
        XCTAssertFalse(locked.didUnlock(comparedTo: both), "re-locking never posts")
        XCTAssertFalse(camp.didUnlock(comparedTo: both))
    }

    // MARK: - Scheduling

    /// One timer, armed for the next instant only, a beat past it so the
    /// `now >= unlock` comparison is satisfied when it fires.
    func testStartArmsTheNextUnlockInstant() throws {
        let scheduler = makeScheduler()
        scheduler.start()

        XCTAssertEqual(timerFactory.scheduledIntervals.count, 1)
        let interval = try XCTUnwrap(timerFactory.scheduledIntervals.first)
        XCTAssertEqual(interval, campUnlock.timeIntervalSince(now) + 1, accuracy: 0.001)
        scheduler.stop()
    }

    /// Firing the camp timer posts and re-arms for the art instant — the old
    /// timer being invalidated, so only one is ever live.
    func testFiringTheTimerPostsAndRearmsForTheNextTier() throws {
        let scheduler = makeScheduler(inRegion: true)
        scheduler.start()
        let campTimer = try XCTUnwrap(timerFactory.latest)

        now = campUnlock.addingTimeInterval(1)
        campTimer.fire()
        XCTAssertEqual(posts, 1)
        XCTAssertTrue(campTimer.invalidated)

        XCTAssertEqual(timerFactory.scheduledIntervals.count, 2)
        let next = try XCTUnwrap(timerFactory.scheduledIntervals.last)
        XCTAssertEqual(next, artUnlock.timeIntervalSince(now) + 1, accuracy: 0.001)
        scheduler.stop()
    }

    /// Past every unlock there is nothing left to wake up for.
    func testNoTimerWhenEveryUnlockHasPassed() throws {
        now = artUnlock.addingTimeInterval(1)
        let scheduler = makeScheduler()
        scheduler.start()
        XCTAssertTrue(timerFactory.scheduledIntervals.isEmpty)
        scheduler.stop()
    }

    /// A device whose clock is years behind must not hold a `Timer` with an
    /// absurd fire date; the foreground triggers will catch the unlock later.
    func testAbsurdlyDistantUnlockIsNotArmed() throws {
        let farFuture = now.addingTimeInterval(EmbargoUnlockSchedulerImpl.maximumScheduledInterval * 2)
        let scheduler = makeScheduler(unlockDates: [farFuture])
        scheduler.start()
        XCTAssertTrue(timerFactory.scheduledIntervals.isEmpty)
        scheduler.stop()
    }

    func testStopInvalidatesTheArmedTimer() throws {
        let scheduler = makeScheduler()
        scheduler.start()
        let timer = try XCTUnwrap(timerFactory.latest)
        scheduler.stop()
        XCTAssertTrue(timer.invalidated)
    }

    // MARK: - Lifecycle notifications

    /// The case that actually bites: iOS suspends the app before midnight and
    /// resumes it after, so no timer ever fires.
    func testBecomingActiveAcrossTheUnlockPosts() throws {
        let scheduler = makeScheduler()
        scheduler.start()

        now = campUnlock.addingTimeInterval(3600)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(posts, 1)

        // A second foreground with nothing new must stay quiet.
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(posts, 1)
        scheduler.stop()
    }

    /// `significantTimeChange` is the notification iOS actually sends at
    /// midnight, and on any clock or timezone edit.
    func testSignificantTimeChangePosts() throws {
        let scheduler = makeScheduler()
        scheduler.start()

        now = campUnlock
        center.post(name: UIApplication.significantTimeChangeNotification, object: nil)
        XCTAssertEqual(posts, 1)
        scheduler.stop()
    }

    /// Waking re-arms the timer for whatever is still pending, and leaves only
    /// one armed.
    func testBecomingActiveReschedulesTheTimer() throws {
        let scheduler = makeScheduler(inRegion: true)
        scheduler.start()
        let first = try XCTUnwrap(timerFactory.latest)

        now = campUnlock.addingTimeInterval(1)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertTrue(first.invalidated)
        XCTAssertEqual(timerFactory.scheduledIntervals.count, 2)
        let next = try XCTUnwrap(timerFactory.scheduledIntervals.last)
        XCTAssertEqual(next, artUnlock.timeIntervalSince(now) + 1, accuracy: 0.001)
        scheduler.stop()
    }

    func testStopEndsTheLifecycleObservation() throws {
        let scheduler = makeScheduler()
        scheduler.start()
        scheduler.stop()

        now = campUnlock.addingTimeInterval(1)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(posts, 0)
    }

    // MARK: - The live wiring

    /// The default `stateProvider` is the same rule `BRCEmbargo` answers with,
    /// so the scheduler can never disagree with what the screens are showing.
    func testLiveStateMatchesTheEmbargoService() throws {
        let originalPasscode = UserDefaults.enteredEmbargoPasscode
        let originalRegion = UserDefaults.enteredBurningManRegion
        UserDefaults.enteredEmbargoPasscode = false
        UserDefaults.enteredBurningManRegion = false
        BRCLocations.hasEnteredBurningManRegion = false
        defer {
            UserDefaults.enteredEmbargoPasscode = originalPasscode
            UserDefaults.enteredBurningManRegion = originalRegion
            BRCLocations.hasEnteredBurningManRegion = false
        }

        let insideCampWindow = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-25T12:00:00Z"))
        let beforeAnyTier = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-10T12:00:00Z"))

        let early = EmbargoUnlockSchedulerImpl.liveState(at: beforeAnyTier)
        XCTAssertFalse(early.canShowCampLocations)
        XCTAssertFalse(early.canShowArtLocations)

        let campOpen = EmbargoUnlockSchedulerImpl.liveState(at: insideCampWindow)
        XCTAssertTrue(campOpen.canShowCampLocations)
        XCTAssertFalse(campOpen.canShowArtLocations, "art still needs the region")
        XCTAssertTrue(campOpen.didUnlock(comparedTo: early))
    }
}
