import Foundation
import GRDB

/// Handle for cancelling database observations.
public final class PlayaDBObservationToken {
    private let cancellable: DatabaseCancellable

    init(_ cancellable: DatabaseCancellable) {
        self.cancellable = cancellable
    }

    /// Stop receiving observation updates.
    public func cancel() {
        cancellable.cancel()
    }
}
