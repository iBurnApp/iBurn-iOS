//
//  DisplayableObject.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// Protocol for objects that can be displayed in list views
/// Minimal set of properties needed by ObjectRowView for rendering list rows.
/// Avoids naming conflicts with legacy DataObject types.
protocol DisplayableObject {
    /// Display name for this object
    var name: String { get }

    /// Description of this object
    var description: String? { get }

    /// Unique identifier
    var uid: String { get }

    /// Object ID used for thumbnail lookup (defaults to uid)
    var thumbnailObjectID: String { get }
}

extension DisplayableObject {
    var thumbnailObjectID: String { uid }
}

// Extend PlayaDB types to conform to DisplayableObject
import PlayaDB

extension ArtObject: DisplayableObject {}
extension CampObject: DisplayableObject {}
extension EventObject: DisplayableObject {}
extension MutantVehicleObject: DisplayableObject {}

extension EventObjectOccurrence: DisplayableObject {
    var thumbnailObjectID: String {
        hostedByCamp ?? locatedAtArt ?? uid
    }
}

// MARK: - Event Time Formatting

extension EventObjectOccurrence {
    /// Dynamic time description for display in list rows.
    /// Shows context-aware status: "Starts 5 min (2h)", "2:00pm (30 min left)",
    /// "Mon 9:00am (2h 45m)", or "Mon (All Day)".
    func timeDescription(now: Date) -> String {
        if allDay {
            return "\(dayAbbrev(startDate)) (All Day)"
        }
        if isStartingSoon(now) {
            let durationStr = DateFormatters.stringForTimeInterval(duration) ?? "0m"
            let startInterval = timeIntervalUntilStart(now)
            let startStr = DateFormatters.stringForTimeInterval(startInterval) ?? "now!"
            if startStr.isEmpty || startInterval <= 0 {
                return "Starts now! (\(durationStr))"
            }
            return "Starts \(startStr) (\(durationStr))"
        }
        if isCurrentlyHappening(now) {
            let endInterval = timeIntervalUntilEnd(now)
            let endStr = DateFormatters.stringForTimeInterval(endInterval) ?? "0m"
            return "\(timeString(startDate)) (\(endStr) left)"
        }
        return defaultTimeText
    }

    /// Static time description without live status (e.g. "Mon 9:00am (2h 45m)").
    var defaultTimeText: String {
        if allDay { return "\(dayAbbrev(startDate)) (All Day)" }
        let durationStr = DateFormatters.stringForTimeInterval(duration) ?? "0m"
        let timePart = "\(timeString(startDate)) (\(durationStr))".lowercased()
        return "\(dayAbbrev(startDate)) \(timePart)"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        formatter.timeZone = TimeZone.burningManTimeZone
        return formatter.string(from: date)
    }

    private func dayAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.timeZone = TimeZone.burningManTimeZone
        return formatter.string(from: date)
    }
}
