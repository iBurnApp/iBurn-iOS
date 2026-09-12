import Foundation

/// The clock every time-relative query in PlayaDB reads ("not expired", "happening now",
/// "starting within"). Defaults to the wall clock; the app points it at its mockable
/// `Date.present` so the Mock Date scheme moves the Events tab and map along with it.
public enum PlayaDBClock {
    public static var now: @Sendable () -> Date = { Date() }
}
