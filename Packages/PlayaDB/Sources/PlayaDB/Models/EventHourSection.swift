import Foundation

/// A group of event-occurrence rows sharing the same hour-of-day,
/// shaped at the data layer so the UI consumes already-grouped sections.
public struct EventHourSection {
    /// 0...23 — stable identifier for `ScrollViewReader`.
    public let hour: Int

    public let rows: [ListRow<EventObjectOccurrence>]

    public init(hour: Int, rows: [ListRow<EventObjectOccurrence>]) {
        self.hour = hour
        self.rows = rows
    }
}
