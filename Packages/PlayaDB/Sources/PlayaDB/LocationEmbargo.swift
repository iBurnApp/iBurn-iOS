//
//  LocationEmbargo.swift
//  PlayaDB
//
//  Created by Claude Code on 8/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
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

/// The circle around the Man that counts as "you are at Burning Man".
///
/// Mirrors the iOS app's `BRCLocations.burningManRegion` — same centre (the
/// year's `ManCenterLatitude`/`ManCenterLongitude`) and same radius — without
/// depending on the iOS target, so the watch can answer the same question.
/// Coordinates are stored as plain `Double`s rather than a
/// `CLLocationCoordinate2D` so the type stays `Equatable`/`Sendable`.
public struct EmbargoRegion: Sendable, Equatable {

    /// `BRCLocations`' radius, kept bit-identical to the phone's expression.
    public static let defaultRadius = CLLocationDistance(5 * 8046.72)

    public let centerLatitude: CLLocationDegrees
    public let centerLongitude: CLLocationDegrees
    public let radius: CLLocationDistance

    public init(
        centerLatitude: CLLocationDegrees,
        centerLongitude: CLLocationDegrees,
        radius: CLLocationDistance = EmbargoRegion.defaultRadius
    ) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.radius = radius
    }

    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }

    /// Inclusive at the rim, matching `CLCircularRegion.contains`. An invalid
    /// coordinate (including the `(0, 0)` a stale fix can carry) is outside.
    public func contains(_ location: CLLocation) -> Bool {
        let coordinate = location.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate),
              !(coordinate.latitude == 0 && coordinate.longitude == 0)
        else { return false }
        let center = CLLocation(latitude: centerLatitude, longitude: centerLongitude)
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: center) <= radius
    }

    /// Plist keys, matching `iBurn/YearSettings.plist`.
    private enum Keys {
        static let manCenterLatitude = "ManCenterLatitude"
        static let manCenterLongitude = "ManCenterLongitude"
    }

    /// Reads the Man's coordinate out of a `YearSettings`-shaped plist.
    ///
    /// `nil` when the resource is missing or lacks the keys; callers fail closed
    /// (no auto-unlock) rather than guess at a centre.
    public static func load(plistNamed name: String = "YearSettings", in bundle: Bundle) -> EmbargoRegion? {
        guard let url = bundle.url(forResource: name, withExtension: "plist") else { return nil }
        return load(contentsOf: url)
    }

    public static func load(contentsOf url: URL) -> EmbargoRegion? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let settings = plist as? [String: Any],
              let latitude = settings[Keys.manCenterLatitude] as? CLLocationDegrees,
              let longitude = settings[Keys.manCenterLongitude] as? CLLocationDegrees
        else { return nil }
        return EmbargoRegion(centerLatitude: latitude, centerLongitude: longitude)
    }
}

/// Pure answer to "may this object's coordinates be shown?".
///
/// The rule is deliberately stricter than a calendar check. A date alone is not
/// evidence: the device clock is user-settable, so "unlock when `now >=`
/// EventStart" is defeated by dragging Settings ▸ Date & Time forward. Being
/// physically inside the Burning Man region is not spoofable that way, so both
/// have to hold:
///
/// ```
/// passcodeUnlocked || (inRegion && now >= unlockDate(tier))
/// ```
///
/// The consequence is accepted, not accidental: someone at home stays locked
/// past the unlock dates unless their phone pushes a passcode unlock.
///
/// Nothing here reads ambient state — `now`, `passcodeUnlocked` and `inRegion`
/// are all parameters — which is what makes the whole thing testable in one
/// line, and what lets the iOS app adopt the same seam later.
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

    /// - Parameters:
    ///   - now: The device clock. Never sufficient on its own.
    ///   - passcodeUnlocked: The BMorg passcode was entered (on this device or,
    ///     for the watch, on the paired phone). The one bypass.
    ///   - inRegion: This device is, or has been, inside the Burning Man region
    ///     — i.e. the user is actually at the event.
    public func canShowLocations(
        tier: EmbargoTier,
        now: Date,
        passcodeUnlocked: Bool,
        inRegion: Bool
    ) -> Bool {
        guard let unlock = unlockDate(for: tier) else { return true }
        if passcodeUnlocked { return true }
        return inRegion && now >= unlock
    }

    public func canShowCampLocations(now: Date, passcodeUnlocked: Bool, inRegion: Bool) -> Bool {
        canShowLocations(tier: .camp, now: now, passcodeUnlocked: passcodeUnlocked, inRegion: inRegion)
    }

    public func canShowArtLocations(now: Date, passcodeUnlocked: Bool, inRegion: Bool) -> Bool {
        canShowLocations(tier: .art, now: now, passcodeUnlocked: passcodeUnlocked, inRegion: inRegion)
    }

    public func canShowLocation(
        for object: any DataObject,
        now: Date,
        passcodeUnlocked: Bool,
        inRegion: Bool
    ) -> Bool {
        canShowLocations(
            tier: object.embargoTier,
            now: now,
            passcodeUnlocked: passcodeUnlocked,
            inRegion: inRegion
        )
    }

    /// Does this fix put the device at Burning Man?
    ///
    /// The `inRegion` half of the rule, as a pure function so the callers only
    /// have to decide *when* to persist the answer. Fails closed on a missing
    /// fix or a missing region — an unknown position is not the playa.
    ///
    /// Persisting a `true` is safe in a way that persisting a date check is not:
    /// no clock change can manufacture a past visit to Black Rock City.
    public static func isInRegion(location: CLLocation?, region: EmbargoRegion?) -> Bool {
        guard let location, let region else { return false }
        return region.contains(location)
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
