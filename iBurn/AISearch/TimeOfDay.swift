//
//  TimeOfDay.swift
//  iBurn
//
//  Time-of-day windows for the AI "Right Now" guide. Pure Swift (no FoundationModels)
//  so it stays unit-testable on any simulator.
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// Whether discovery leans on the user's favorites, deliberate randomness, or a mix.
enum DiscoveryLean: Sendable, Equatable {
    case personalized
    case surprise
    case balanced
}

/// A near-term time horizon for "what's good right now / what to do next."
/// `.now` is the immediacy default; named periods anchor to the current festival day.
enum TimeOfDay: String, CaseIterable, Identifiable, Sendable {
    case now
    case sunrise
    case morning
    case midday
    case afternoon
    case evening
    case night
    case lateNight

    var id: String { rawValue }

    /// Short label for the picker.
    var label: String {
        switch self {
        case .now: return "Now"
        case .sunrise: return "Sunrise"
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        case .lateNight: return "Late Night"
        }
    }

    /// SF Symbol for the picker.
    var icon: String {
        switch self {
        case .now: return "clock"
        case .sunrise: return "sunrise"
        case .morning: return "sun.max"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.haze"
        case .evening: return "sunset"
        case .night: return "moon.stars"
        case .lateNight: return "moon.zzz"
        }
    }

    /// Hour offsets from the start of the festival day, in BRC local time.
    /// `nil` means "relative to the actual current time" (`.now`).
    /// `lateNight` extends past 24 to spill into the next day's early morning.
    var hourRange: (start: Double, end: Double)? {
        switch self {
        case .now: return nil
        case .sunrise: return (5.5, 7.5)
        case .morning: return (7.5, 11)
        case .midday: return (11, 14)
        case .afternoon: return (14, 17)
        case .evening: return (17, 20.5) // includes sunset (~19:30)
        case .night: return (20.5, 24)
        case .lateNight: return (24, 28) // 00:00–04:00 of the next day
        }
    }

    /// Resolve this horizon to a concrete `(start, end)` event window on the given festival
    /// `day`, in BRC local time, clamped to the festival's date range so off-season/off-playa
    /// queries stay sane. `.now` returns the next two hours when `day` is the current day,
    /// otherwise the whole selected day.
    func dateWindow(on day: Date, now: Date = Date.present) -> (start: Date, end: Date) {
        let low = YearSettings.eventStart
        let high = YearSettings.eventEnd
        func clamp(_ date: Date) -> Date { min(max(date, low), high) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .burningManTimeZone
        let dayStart = calendar.startOfDay(for: day)

        guard let range = hourRange else {
            // .now → the next two hours if we're looking at today, else the whole selected day.
            if calendar.isDate(day, inSameDayAs: now) {
                return (clamp(now), clamp(now.addingTimeInterval(2 * 3600)))
            }
            return (clamp(dayStart), clamp(dayStart.addingTimeInterval(24 * 3600)))
        }
        let start = dayStart.addingTimeInterval(range.start * 3600)
        let end = dayStart.addingTimeInterval(range.end * 3600)
        return (clamp(start), clamp(end))
    }

    /// Convenience anchored to the festival day containing `now`.
    func dateWindow(now: Date = Date.present) -> (start: Date, end: Date) {
        dateWindow(on: now, now: now)
    }

    /// Whether the window contains the current moment (so "happening now" is meaningful).
    func containsNow(_ now: Date = Date.present) -> Bool {
        let window = dateWindow(now: now)
        return now >= window.start && now <= window.end
    }
}
