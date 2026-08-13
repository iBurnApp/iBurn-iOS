//
//  LocationEmbargo.swift
//  PlayaDB
//
//  Created by Claude Code on 8/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// Which unlock date an object's placement rides on.
///
/// The BMorg API terms embargo placement data in two tiers: theme camp
/// locations become publishable at 12:01 am on the Sunday of the week before
/// the event, art locations only when the gates open.
public enum EmbargoTier: String, Sendable, Equatable, CaseIterable {
    /// Theme camps, and events hosted by one.
    case camp
    /// Art installations, and events located at one.
    case art
    /// Never embargoed (mutant vehicles, user-placed pins, free-text locations).
    case unrestricted
}

/// The two unlock instants for a given playa year.
public struct EmbargoSchedule: Sendable, Equatable {

    /// When theme camp placement may be shown.
    public let campLocationUnlock: Date

    /// When art placement may be shown — gate opening (`EventStart`).
    public let artLocationUnlock: Date

    /// - Parameter campLocationUnlock: `nil` (a year whose settings predate the
    ///   tier split) falls back to `artLocationUnlock`, i.e. the stricter,
    ///   fully-embargoed-until-gates behaviour.
    public init(campLocationUnlock: Date?, artLocationUnlock: Date) {
        self.artLocationUnlock = artLocationUnlock
        self.campLocationUnlock = campLocationUnlock ?? artLocationUnlock
    }

    /// Plist keys, matching `iBurn/YearSettings.plist`.
    private enum Keys {
        static let eventStart = "EventStart"
        static let campLocationUnlock = "CampLocationUnlock"
    }

    /// Reads the schedule out of a `YearSettings`-shaped plist in `bundle`.
    ///
    /// Returns `nil` when the resource is missing or unreadable; callers are
    /// expected to fail closed (treat everything as embargoed) rather than
    /// guess, since a wrong guess publishes data under embargo.
    public static func load(plistNamed name: String = "YearSettings", in bundle: Bundle) -> EmbargoSchedule? {
        guard let url = bundle.url(forResource: name, withExtension: "plist") else { return nil }
        return load(contentsOf: url)
    }

    public static func load(contentsOf url: URL) -> EmbargoSchedule? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let settings = plist as? [String: Any],
              let eventStart = settings[Keys.eventStart] as? Date
        else { return nil }
        return EmbargoSchedule(
            campLocationUnlock: settings[Keys.campLocationUnlock] as? Date,
            artLocationUnlock: eventStart
        )
    }
}

/// Pure, date-driven answer to "may this object's coordinates be shown?".
///
/// Mirrors the iOS app's `BRCEmbargo` semantics without any of its dependencies
/// (no `UserDefaults`, no `NSDate.present`, no Obj-C), so the watch app — which
/// cannot see the iOS target — can gate the same way. `now` and
/// `passcodeUnlocked` are parameters rather than ambient state, which is what
/// makes the whole thing testable in one line.
public struct LocationEmbargo: Sendable, Equatable {

    public let schedule: EmbargoSchedule

    public init(schedule: EmbargoSchedule) {
        self.schedule = schedule
    }

    /// The unlock instant for a tier. Camps can never outlast art: a
    /// misconfigured year with `CampLocationUnlock` after `EventStart` still
    /// unlocks camps at the gates.
    public func unlockDate(for tier: EmbargoTier) -> Date? {
        switch tier {
        case .unrestricted: return nil
        case .art: return schedule.artLocationUnlock
        case .camp: return min(schedule.campLocationUnlock, schedule.artLocationUnlock)
        }
    }

    public func canShowLocations(tier: EmbargoTier, now: Date, passcodeUnlocked: Bool) -> Bool {
        guard let unlock = unlockDate(for: tier) else { return true }
        if passcodeUnlocked { return true }
        return now >= unlock
    }

    public func canShowCampLocations(now: Date, passcodeUnlocked: Bool) -> Bool {
        canShowLocations(tier: .camp, now: now, passcodeUnlocked: passcodeUnlocked)
    }

    public func canShowArtLocations(now: Date, passcodeUnlocked: Bool) -> Bool {
        canShowLocations(tier: .art, now: now, passcodeUnlocked: passcodeUnlocked)
    }

    public func canShowLocation(for object: any DataObject, now: Date, passcodeUnlocked: Bool) -> Bool {
        canShowLocations(tier: object.embargoTier, now: now, passcodeUnlocked: passcodeUnlocked)
    }
}

public extension DataObject {

    /// The tier this object's coordinates belong to.
    ///
    /// An event at an art installation would leak the art's position, so it
    /// stays on the art tier; every other event rides the camp tier, matching
    /// `BRCEmbargo.canShowLocationForObject:`.
    var embargoTier: EmbargoTier {
        switch objectType {
        case .art:
            return .art
        case .camp:
            return .camp
        case .mutantVehicle:
            return .unrestricted
        case .event:
            if let event = self as? EventObject {
                return event.locatedAtArt == nil ? .camp : .art
            }
            if let occurrence = self as? EventObjectOccurrence {
                return occurrence.locatedAtArt == nil ? .camp : .art
            }
            // An event shape we don't recognise could be hosted anywhere;
            // fail closed on the later of the two tiers.
            return .art
        }
    }
}
