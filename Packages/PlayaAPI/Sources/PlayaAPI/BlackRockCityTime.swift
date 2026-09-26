import Foundation

// MARK: - Black Rock City time

// The festival runs on US Pacific time, and every festival date the apps show — event times,
// day headers, the day picker, "today" — is in that zone. Anything that buckets, compares or
// constructs festival dates (a day, a start-of-day, an hour-of-day band) must use these, not
// `Calendar.current` / `TimeZone.current`: people arrive with phones (and watches) still set
// to wherever they flew in from, and a 9 PM Thursday event is a *Friday* event in Tokyo.
//
// Defined here, in the lowest package both apps and PlayaDB already link, so there is one
// definition. Keep device-local calendars for genuinely device-local things only (e.g. the
// user's own "last viewed" timestamps).

public extension TimeZone {
    /// Black Rock City time: `America/Los_Angeles` (PDT during the event).
    ///
    /// An identifier rather than `TimeZone(abbreviation: "PDT")`: on Darwin the abbreviation
    /// happens to resolve to `America/Los_Angeles`, but that's a lookup table, not a contract.
    /// The fixed −7h fallback is the offset the festival always falls in, and is unreachable
    /// on Apple platforms, which always ship the tz database.
    static let burningMan: TimeZone = TimeZone(identifier: "America/Los_Angeles")
        ?? TimeZone(secondsFromGMT: -7 * 60 * 60)
        ?? .gmt
}

public extension Calendar {
    /// Gregorian calendar in Black Rock City time (`TimeZone.burningMan`). Use it for any
    /// day, start-of-day or hour-of-day bucketing of festival dates, so buckets agree with
    /// the times the UI shows whatever zone the device is set to.
    static let burningMan: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .burningMan
        return calendar
    }()
}
