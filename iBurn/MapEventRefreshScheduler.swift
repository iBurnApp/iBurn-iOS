//
//  MapEventRefreshScheduler.swift
//  iBurn
//
//  Keeps the map's event pins honest about the clock.
//

import Foundation
import PlayaDB
import UIKit

/// When the map's event pins next go stale.
///
/// Both annotation paths are clock-dependent and neither is clock-driven: the region path
/// (`UserMapViewAdapter.refreshRegionAnnotations`) only reran on a pan, and the observation
/// path only re-derives on a database write or a reload. So a 2pm event kept its pin — green
/// dot and all — until the user happened to touch the map. This is the seam that decides when
/// to look again.
///
/// Pure: occurrences and a clock in, one `Date` out, no timers and no map. The rule is the
/// soonest *interesting* instant — an occurrence's start, its end, or either of the two
/// "soon" thresholds that change a pin's status colour — or the next minute boundary if none
/// of those is closer, clamped into `[floor, ceiling]` so a burst of edges can't spin the
/// timer and an empty map still checks in.
enum MapEventRefreshBoundary {

    /// Never re-evaluate more often than this, however many edges are crowded together.
    static let floorInterval: TimeInterval = 15

    /// Always re-evaluate at least this often, even with nothing scheduled: the pins' time
    /// text and status dots are relative to now, and "now" moves on its own.
    static let ceilingInterval: TimeInterval = 60

    /// The next instant worth redrawing at.
    static func nextFireDate(
        occurrences: [EventObjectOccurrence],
        now: Date,
        floor: TimeInterval = floorInterval,
        ceiling: TimeInterval = ceilingInterval
    ) -> Date {
        var candidates: [Date] = [nextMinuteBoundary(after: now)]
        for occurrence in occurrences {
            candidates.append(occurrence.startDate)
            candidates.append(occurrence.endDate)
            // The two instants where a pin changes colour without anything else happening.
            candidates.append(occurrence.startDate.addingTimeInterval(-EventPinStatus.startingSoonThreshold))
            candidates.append(occurrence.endDate.addingTimeInterval(-EventPinStatus.endingSoonThreshold))
        }
        let soonest = candidates.filter { $0 > now }.min() ?? now.addingTimeInterval(ceiling)
        let interval = soonest.timeIntervalSince(now)
        return now.addingTimeInterval(min(max(interval, floor), ceiling))
    }

    /// The top of the next wall-clock minute, which is when every "8:00 AM - 10:00 AM" and
    /// every status dot can change even with no occurrence edge nearby.
    static func nextMinuteBoundary(after now: Date) -> Date {
        let seconds = now.timeIntervalSinceReferenceDate
        let next = (seconds / 60).rounded(.down) * 60 + 60
        return Date(timeIntervalSinceReferenceDate: next)
    }
}

/// Arms one timer at a time for the instant `MapEventRefreshBoundary` picks, and re-arms
/// after every fire — the same shape as `EmbargoUnlockScheduler`, for the same reason: a
/// repeating tick either wastes work or misses the edge that mattered.
///
/// Also refreshes when the app comes back from the background or the system clock jumps,
/// because a timer that slept through both would leave the map showing whatever was true
/// when the phone went in the pocket.
final class MapEventRefreshScheduler {

    private let notificationCenter: NotificationCenter
    private let now: () -> Date
    private let onRefresh: () -> Void

    /// The occurrences currently on the map, asked for fresh at each re-arm so the schedule
    /// follows what is actually drawn.
    var occurrencesProvider: () -> [EventObjectOccurrence] = { [] }

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    /// - Parameter onRefresh: redraw the map's event pins. Called on the main queue. The
    ///   caller owns this scheduler, so this closure must not capture it strongly.
    init(notificationCenter: NotificationCenter = .default,
         now: @escaping () -> Date = { .present },
         onRefresh: @escaping () -> Void) {
        self.notificationCenter = notificationCenter
        self.now = now
        self.onRefresh = onRefresh
    }

    deinit {
        timer?.invalidate()
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    /// Starts refreshing. Safe to call again; the map's appearance callbacks do.
    func start() {
        observeLifecycle()
        scheduleNext()
    }

    /// Stops the timer and the notifications. The map calls this when it goes away — nothing
    /// should be redrawing pins for a screen nobody is looking at.
    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    /// Re-arms against the current occurrence set without refreshing first. Called after a
    /// refresh lands with a new set of pins.
    func reschedule() {
        scheduleNext()
    }

    // MARK: - Private

    private func observeLifecycle() {
        guard observers.isEmpty else { return }
        let names: [Notification.Name] = [
            UIApplication.willEnterForegroundNotification,
            UIApplication.didBecomeActiveNotification,
            UIApplication.significantTimeChangeNotification
        ]
        observers = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.fire()
            }
        }
    }

    private func fire() {
        onRefresh()
        scheduleNext()
    }

    private func scheduleNext() {
        timer?.invalidate()
        timer = nil

        let current = now()
        let next = MapEventRefreshBoundary.nextFireDate(
            occurrences: occurrencesProvider(),
            now: current
        )
        let interval = next.timeIntervalSince(current)
        guard interval.isFinite, interval > 0 else { return }

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.fire()
        }
        // Generous by timer standards but still well inside the 15s floor: nothing here is
        // worth waking the device precisely for.
        timer.tolerance = min(interval * 0.1, 5)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
