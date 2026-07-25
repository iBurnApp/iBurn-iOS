#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// Symmetric phone <-> watch sync over WatchConnectivity.
///
/// Both the iOS app and the watch app create one of these around their local
/// `PlayaDB` and call `start()`. Each side observes its own state and publishes
/// full snapshots via `updateApplicationContext` (best-effort, latest-wins
/// transport); incoming snapshots are merged through `PlayaDB.applyFavoriteSync`
/// and `PlayaDB.applyUserMapPinSync`, whose last-writer-wins semantics skip
/// no-op items without writing, so applying a peer's snapshot never re-fires the
/// local observation and cannot cause a push loop.
///
/// Two payloads (favorites/visit status, and user map pins) share **one**
/// manager on purpose: `updateApplicationContext` replaces the entire
/// dictionary, so two independent publishers would silently clobber each other.
public final class PeerSyncManager: NSObject, @unchecked Sendable {

    /// Application-context key carrying the JSON-encoded `[FavoriteSyncItem]`.
    private static let favoritesKey = "favoritesV1"

    /// Application-context key carrying the JSON-encoded `[UserMapPin]`.
    private static let pinsKey = "userMapPinsV1"

    private let playaDB: PlayaDB

    /// Invoked (on an arbitrary background queue) with the favorite/visit items
    /// that were actually applied locally after receiving a peer snapshot.
    private let onFavoritesApplied: (([FavoriteSyncItem]) -> Void)?

    /// Invoked (on an arbitrary background queue) with the pins that were
    /// actually applied locally after receiving a peer snapshot.
    private let onPinsApplied: (([UserMapPin]) -> Void)?

    /// Protects the cached snapshots, observation tokens, and `started`: the
    /// observation callbacks and WCSession delegate callbacks arrive on
    /// different queues.
    private let lock = NSLock()
    private var latestFavorites: [FavoriteSyncItem]?
    private var latestPins: [UserMapPin]?
    private var observationTokens: [PlayaDBObservationToken] = []
    private var started = false

    public init(
        playaDB: PlayaDB,
        onFavoritesApplied: (([FavoriteSyncItem]) -> Void)? = nil,
        onPinsApplied: (([UserMapPin]) -> Void)? = nil
    ) {
        self.playaDB = playaDB
        self.onFavoritesApplied = onFavoritesApplied
        self.onPinsApplied = onPinsApplied
        super.init()
    }

    /// Activates the WCSession and begins observing local state. No-op when
    /// WatchConnectivity is unsupported (e.g. iPad) or if already started.
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

        // Hold the tokens for the lifetime of the manager or the observations die.
        let favoritesToken = playaDB.observeFavoriteSyncState(
            onChange: { [weak self] items in
                guard let self else { return }
                self.lock.lock()
                self.latestFavorites = items
                self.lock.unlock()
                self.pushLatestSnapshot()
            },
            onError: { error in
                print("PeerSyncManager: favorite observation failed: \(error)")
            }
        )
        let pinsToken = playaDB.observeUserMapPinSyncState(
            onChange: { [weak self] pins in
                guard let self else { return }
                self.lock.lock()
                self.latestPins = pins
                self.lock.unlock()
                self.pushLatestSnapshot()
            },
            onError: { error in
                print("PeerSyncManager: pin observation failed: \(error)")
            }
        )
        lock.lock()
        observationTokens = [favoritesToken, pinsToken]
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

    /// Publishes the most recent local snapshots to the peer, if the session is
    /// active. Both keys go out together because the application context is
    /// replaced wholesale — pushing one key alone would drop the other. Failures
    /// are logged and dropped: context updates are best-effort, and the next
    /// local change (or the next activation) pushes again.
    private func pushLatestSnapshot() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        lock.lock()
        let favorites = latestFavorites
        let pins = latestPins
        lock.unlock()

        do {
            var context: [String: Any] = [:]
            if let favorites {
                context[Self.favoritesKey] = try Self.makeEncoder().encode(favorites)
            }
            if let pins {
                context[Self.pinsKey] = try Self.makeEncoder().encode(pins)
            }
            guard !context.isEmpty else { return }
            try session.updateApplicationContext(context)
        } catch {
            print("PeerSyncManager: failed to push state (\(error)); will retry on next change")
        }
    }

    /// Decodes and merges a peer snapshot. Malformed payloads are logged and
    /// ignored — never crash on peer data, and never let one bad key stop the
    /// other from applying.
    private func applyReceivedContext(_ applicationContext: [String: Any]) {
        let favorites: [FavoriteSyncItem] = decode(applicationContext[Self.favoritesKey], label: "favorites")
        let pins: [UserMapPin] = decode(applicationContext[Self.pinsKey], label: "pins")
        guard !favorites.isEmpty || !pins.isEmpty else { return }

        let playaDB = self.playaDB
        let onFavoritesApplied = self.onFavoritesApplied
        let onPinsApplied = self.onPinsApplied
        Task {
            if !favorites.isEmpty {
                do {
                    let applied = try await playaDB.applyFavoriteSync(favorites)
                    if !applied.isEmpty {
                        onFavoritesApplied?(applied)
                    }
                } catch {
                    print("PeerSyncManager: failed to apply peer favorites: \(error)")
                }
            }
            if !pins.isEmpty {
                do {
                    let applied = try await playaDB.applyUserMapPinSync(pins)
                    if !applied.isEmpty {
                        onPinsApplied?(applied)
                    }
                } catch {
                    print("PeerSyncManager: failed to apply peer pins: \(error)")
                }
            }
        }
    }

    private func decode<T: Decodable>(_ value: Any?, label: String) -> [T] {
        guard let data = value as? Data else { return [] }
        do {
            return try Self.makeDecoder().decode([T].self, from: data)
        } catch {
            print("PeerSyncManager: ignoring malformed \(label) payload: \(error)")
            return []
        }
    }
}

// MARK: - WCSessionDelegate

extension PeerSyncManager: WCSessionDelegate {

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("PeerSyncManager: session activation failed: \(error)")
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
        // local change.
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
