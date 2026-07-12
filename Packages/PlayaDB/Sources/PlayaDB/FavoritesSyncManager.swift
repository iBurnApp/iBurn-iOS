#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// Symmetric phone <-> watch favorites sync over WatchConnectivity.
///
/// Both the iOS app and the watch app create one of these around their local
/// `PlayaDB` and call `start()`. Each side observes its own favorite state and
/// publishes the full snapshot via `updateApplicationContext` (best-effort,
/// latest-wins transport); incoming snapshots are merged through
/// `PlayaDB.applyFavoriteSync`, whose last-writer-wins semantics skip
/// same-state items without writing, so applying a peer's snapshot never
/// re-fires the local observation and cannot cause a push loop.
public final class FavoritesSyncManager: NSObject, @unchecked Sendable {

    /// Application-context key carrying the JSON-encoded `[FavoriteSyncItem]`.
    private static let contextKey = "favoritesV1"

    private let playaDB: PlayaDB

    /// Invoked (on an arbitrary background queue) with the items that were
    /// actually applied locally after receiving a peer snapshot.
    private let onApplied: (([FavoriteSyncItem]) -> Void)?

    /// Protects `latestSnapshot`, `observationToken`, and `started`: the
    /// observation callback and WCSession delegate callbacks arrive on
    /// different queues.
    private let lock = NSLock()
    private var latestSnapshot: [FavoriteSyncItem]?
    private var observationToken: PlayaDBObservationToken?
    private var started = false

    public init(playaDB: PlayaDB, onApplied: (([FavoriteSyncItem]) -> Void)? = nil) {
        self.playaDB = playaDB
        self.onApplied = onApplied
        super.init()
    }

    /// Activates the WCSession and begins observing local favorite changes.
    /// No-op when WatchConnectivity is unsupported (e.g. iPad) or if already
    /// started.
    public func start() {
        guard WCSession.isSupported() else { return }
        lock.lock()
        let alreadyStarted = started
        started = true
        lock.unlock()
        guard !alreadyStarted else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        // Hold the token for the lifetime of the manager or the observation dies.
        let token = playaDB.observeFavoriteSyncState(
            onChange: { [weak self] items in
                guard let self else { return }
                self.lock.lock()
                self.latestSnapshot = items
                self.lock.unlock()
                self.pushLatestSnapshot()
            },
            onError: { error in
                print("FavoritesSyncManager: favorite observation failed: \(error)")
            }
        )
        lock.lock()
        observationToken = token
        lock.unlock()
    }

    // MARK: - Private

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// Publishes the most recent local snapshot to the peer, if the session is
    /// active. Failures are logged and dropped: application-context updates are
    /// best-effort, and the next favorite change (or the next activation)
    /// pushes again.
    private func pushLatestSnapshot() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        lock.lock()
        let snapshot = latestSnapshot
        lock.unlock()
        guard let snapshot else { return }
        do {
            let data = try Self.makeEncoder().encode(snapshot)
            try session.updateApplicationContext([Self.contextKey: data])
        } catch {
            print("FavoritesSyncManager: failed to push favorites (\(error)); will retry on next change")
        }
    }

    /// Decodes and merges a peer snapshot. Malformed payloads are logged and
    /// ignored — never crash on peer data.
    private func applyReceivedContext(_ applicationContext: [String: Any]) {
        guard let data = applicationContext[Self.contextKey] as? Data else { return }
        let items: [FavoriteSyncItem]
        do {
            items = try Self.makeDecoder().decode([FavoriteSyncItem].self, from: data)
        } catch {
            print("FavoritesSyncManager: ignoring malformed favorites payload: \(error)")
            return
        }
        guard !items.isEmpty else { return }
        let playaDB = self.playaDB
        let onApplied = self.onApplied
        Task {
            do {
                let applied = try await playaDB.applyFavoriteSync(items)
                if !applied.isEmpty {
                    onApplied?(applied)
                }
            } catch {
                print("FavoritesSyncManager: failed to apply peer favorites: \(error)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension FavoritesSyncManager: WCSessionDelegate {

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("FavoritesSyncManager: session activation failed: \(error)")
        }
        guard activationState == .activated else { return }
        // Fresh install: pull whatever the peer last published, then publish
        // our own state so the peer converges too.
        applyReceivedContext(session.receivedApplicationContext)
        pushLatestSnapshot()
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyReceivedContext(applicationContext)
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        // Transitional state while the user switches watches; nothing to do.
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to a different paired watch; re-activate for it.
        session.activate()
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        // Pushes fail with "Watch app is not installed" until the watch app
        // exists; when it appears (or the user pairs a new watch), publish the
        // current state so the watch converges without waiting for the next
        // favorite change.
        pushLatestSnapshot()
    }
    #else
    public func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        // Same as sessionWatchStateDidChange, from the watch's perspective.
        pushLatestSnapshot()
    }
    #endif
}
#endif
