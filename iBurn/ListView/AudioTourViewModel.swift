//
//  AudioTourViewModel.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import Foundation
import PlayaDB

// MARK: - Local audio assets

/// Resolves locally available audio-tour recordings (`MediaFiles/<uid>.m4a`).
///
/// The audio tour's membership rule is a union of two independent sources — the
/// database (`ArtObject.audioTourUrl`) and the filesystem — and only the second
/// half needs real files, so it is protocolized to keep the view model testable.
protocol AudioTourAssetProviding {
    /// Every uid that has a local `.m4a` recording, resolved with a single
    /// directory listing per media location (not one `stat` per art object).
    func localAudioUIDs() -> Set<String>

    /// Local file URL for a uid's recording, or nil when it isn't on disk.
    func localAudioURL(uid: String) -> URL?

    /// Local artwork for the lock-screen "now playing" info, if cached.
    func localArtworkURL(uid: String) -> URL?
}

/// Default implementation over the legacy media cache layout: downloaded media in
/// `Documents/MediaFiles/`, bundled media in the year's `MediaFiles.bundle`.
///
/// The uid listing is cached for the lifetime of the instance (one per screen
/// visit). `BRCMediaDownloader`'s download path is dead code today, so media only
/// ever arrives with the app bundle and cannot change mid-screen.
final class BundledAudioTourAssetProvider: AudioTourAssetProviding {
    /// uid of the synthesized "intro" track — matches the legacy
    /// `BRCArtObject.introObject`, whose audio is `MediaFiles/intro.m4a`.
    static let introUID = "intro"

    private var cachedUIDs: Set<String>?

    func localAudioUIDs() -> Set<String> {
        if let cachedUIDs { return cachedUIDs }
        // `localMediaURL` copies the bundled media into Documents on first use;
        // probing one filename makes sure that copy has happened before listing.
        _ = BRCMediaDownloader.localMediaURL("\(Self.introUID).m4a")

        var uids = Self.audioUIDs(inDirectoryAt: Self.documentsMediaDirectory)
        uids.formUnion(Self.audioUIDs(inDirectoryAt: Bundle.bundledMedia?.resourceURL))
        cachedUIDs = uids
        return uids
    }

    func localAudioURL(uid: String) -> URL? {
        BRCMediaDownloader.localMediaURL("\(uid).m4a")
    }

    func localArtworkURL(uid: String) -> URL? {
        BRCMediaDownloader.localMediaURL("\(uid).jpg")
    }

    // MARK: Private

    /// `Documents/MediaFiles`, derived from the public per-file accessor so the
    /// path stays in one place.
    private static var documentsMediaDirectory: URL {
        BRCMediaDownloader.localCacheURL("probe.m4a").deletingLastPathComponent()
    }

    private static func audioUIDs(inDirectoryAt url: URL?) -> Set<String> {
        guard let url,
              let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            return []
        }
        var uids = Set<String>()
        for name in contents where (name as NSString).pathExtension.lowercased() == "m4a" {
            uids.insert((name as NSString).deletingPathExtension)
        }
        return uids
    }
}

// MARK: - Item

/// One playable row of the audio tour.
struct AudioTourItem: Identifiable {
    let row: ListRow<ArtObject>
    /// Resolved playback URL: a local recording when one exists, else the remote
    /// `audio_tour_url` from the database.
    let audioURL: URL
    let artworkURL: URL?

    var id: String { row.object.uid }
    var art: ArtObject { row.object }
    var isFavorite: Bool { row.isFavorite }

    var track: BRCAudioTourTrack {
        BRCAudioTourTrack(
            uid: art.uid,
            title: art.name,
            artist: art.artist,
            audioURL: audioURL,
            artworkURL: artworkURL
        )
    }
}

// MARK: - Playback state

/// Playback state of a button's track(s), used to pick its title.
enum AudioTourPlaybackState {
    /// Nothing from this button is loaded in the player.
    case idle
    /// Loaded and playing.
    case playing
    /// Loaded but paused.
    case paused
}

// MARK: - View Model

/// View model for the SwiftUI/PlayaDB Audio Tour (More → Audio Tour).
///
/// **Membership** matches the legacy Yap screen's semantics (`art.audioURL != nil`,
/// which resolved a local file first and fell back to a remote URL): art belongs on
/// the tour when the database says it has an `audio_tour_url` **or** a local
/// `MediaFiles/<uid>.m4a` exists.
///
/// **Union strategy** — the local half can't be expressed in SQL, so:
/// - No local recordings (the 2026 payload today ships zero `.m4a` and zero
///   `audio_tour_url`): observe with `ArtFilter(hasAudioTour: true)` so the
///   database does the filtering.
/// - Local recordings present: observe unfiltered and apply the union predicate in
///   memory against the single directory listing taken at startup.
///
/// Either way this is **one** observation and **one** directory listing, and both
/// halves stay reactive (favorites/metadata changes re-emit through `observeArt`).
@MainActor
final class AudioTourViewModel: ObservableObject {
    // MARK: - Published

    /// Tour items in database order; `items` applies the display sort.
    @Published private(set) var loadedItems: [AudioTourItem] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var tourPlaybackState: AudioTourPlaybackState = .idle
    @Published private(set) var introPlaybackState: AudioTourPlaybackState = .idle

    /// The bundled introduction track, present only when `MediaFiles/intro.m4a`
    /// ships with the app. Mirrors legacy `BRCArtObject.introObject` (same uid, so
    /// both stacks agree on what the player currently has loaded).
    let introTrack: BRCAudioTourTrack?

    /// SoundCloud set the legacy screen linked to.
    static let soundCloudURL: URL? = URL(string: "https://m.soundcloud.com/burningman/sets")

    // MARK: - Dependencies

    private let artProvider: ArtDataProvider
    private let locationProvider: LocationProvider
    private let assetProvider: AudioTourAssetProviding
    private let audioPlayer: any AudioPlayerProtocol

    // MARK: - State

    private let localAudioUIDs: Set<String>
    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var playbackObserver: NSObjectProtocol?

    // MARK: - Init

    init(
        artProvider: ArtDataProvider,
        locationProvider: LocationProvider,
        assetProvider: AudioTourAssetProviding = BundledAudioTourAssetProvider(),
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance
    ) {
        self.artProvider = artProvider
        self.locationProvider = locationProvider
        self.assetProvider = assetProvider
        self.audioPlayer = audioPlayer
        self.currentLocation = locationProvider.currentLocation

        // One directory listing for the whole screen.
        let localUIDs = assetProvider.localAudioUIDs()
        self.localAudioUIDs = localUIDs

        let introUID = BundledAudioTourAssetProvider.introUID
        if localUIDs.contains(introUID), let introURL = assetProvider.localAudioURL(uid: introUID) {
            self.introTrack = BRCAudioTourTrack(
                uid: introUID,
                title: "Audio Tour Introduction",
                artist: "Burning Man",
                audioURL: introURL,
                artworkURL: nil
            )
        } else {
            self.introTrack = nil
        }

        startObserving()
        startLocationUpdates()
        observePlayerChanges()
        refreshPlaybackState()
    }

    deinit {
        observationTask?.cancel()
        locationTask?.cancel()
        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
        }
    }

    // MARK: - Display

    /// Nearest-first when a user location is available, alphabetical otherwise —
    /// same convention as the other PlayaDB list screens.
    var items: [AudioTourItem] {
        guard let location = currentLocation else {
            return loadedItems.sorted {
                $0.art.name.localizedCaseInsensitiveCompare($1.art.name) == .orderedAscending
            }
        }
        return loadedItems.sorted { a, b in
            let distanceA = a.art.location.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
            let distanceB = b.art.location.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
            if distanceA == distanceB {
                return a.art.name.localizedCaseInsensitiveCompare(b.art.name) == .orderedAscending
            }
            return distanceA < distanceB
        }
    }

    var isEmpty: Bool { loadedItems.isEmpty }

    /// Every listed track, in display order — what "Play All" queues up.
    var tracks: [BRCAudioTourTrack] { items.map(\.track) }

    var playAllTitle: String {
        switch tourPlaybackState {
        case .playing: "Pause"
        case .paused: "Resume"
        case .idle: "Play All"
        }
    }

    var introTitle: String {
        switch introPlaybackState {
        case .playing: "Pause Introduction"
        case .paused: "Resume Introduction"
        case .idle: "Play Audio Tour Introduction"
        }
    }

    func distanceAttributedString(for item: AudioTourItem) -> AttributedString? {
        artProvider.distanceAttributedString(from: currentLocation, to: item.art)
    }

    // MARK: - Playback

    /// Queues the whole tour. Re-pressing with the same queue toggles play/pause
    /// inside `BRCAudioPlayer`, which is what makes the title cycle
    /// Play All → Pause → Resume exactly like the legacy screen.
    func playAll() {
        let tracks = self.tracks
        guard !tracks.isEmpty else { return }
        audioPlayer.playAudioTour(tracks)
        refreshPlaybackState()
    }

    /// Plays (or toggles) the bundled introduction track.
    func playIntro() {
        guard let introTrack else { return }
        audioPlayer.playAudioTour([introTrack])
        refreshPlaybackState()
    }

    func refreshPlaybackState() {
        tourPlaybackState = playbackState(forTrackUIDs: loadedItems.map(\.id))
        introPlaybackState = introTrack.map { playbackState(forTrackUIDs: [$0.uid]) } ?? .idle
    }

    private func playbackState(forTrackUIDs uids: [String]) -> AudioTourPlaybackState {
        if uids.contains(where: { audioPlayer.isPlaying(id: $0) }) { return .playing }
        if uids.contains(where: { audioPlayer.hasItem(id: $0) }) { return .paused }
        return .idle
    }

    private func observePlayerChanges() {
        playbackObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPlaybackState()
            }
        }
    }

    // MARK: - Favorites

    /// Toggles through `ArtDataProvider` so the legacy YapDatabase mirror
    /// (`FavoriteSyncService`) stays in agreement. The observation re-emits with
    /// fresh metadata, so no optimistic local mutation is needed.
    func toggleFavorite(_ item: AudioTourItem) async {
        do {
            try await artProvider.toggleFavorite(item.art)
        } catch {
            print("Error toggling favorite for \(item.art.name): \(error)")
        }
    }

    // MARK: - Observation

    private func startObserving() {
        observationTask?.cancel()
        // SQL does the filtering when no local recordings exist; otherwise every
        // art row has to be considered because the local half isn't in the database.
        let filter: ArtFilter = localAudioUIDs.isEmpty ? ArtFilter(hasAudioTour: true) : .all
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await rows in self.artProvider.observeObjects(filter: filter) {
                if Task.isCancelled { return }
                self.apply(rows: rows)
            }
        }
    }

    private func apply(rows: [ListRow<ArtObject>]) {
        var seen = Set<String>()
        loadedItems = rows.compactMap { row in
            guard let audioURL = audioURL(for: row.object),
                  seen.insert(row.object.uid).inserted else { return nil }
            return AudioTourItem(
                row: row,
                audioURL: audioURL,
                artworkURL: assetProvider.localArtworkURL(uid: row.object.uid)
            )
        }
        isLoading = false
        refreshPlaybackState()
    }

    /// Local recordings win over the remote URL — they play offline on the playa.
    /// Returns nil for art that has neither, which is what excludes it from the tour.
    private func audioURL(for art: ArtObject) -> URL? {
        if localAudioUIDs.contains(art.uid),
           let localURL = assetProvider.localAudioURL(uid: art.uid) {
            return localURL
        }
        guard art.hasAudioTour else { return nil }
        return art.audioTourUrl
    }

    // MARK: - Location

    private func startLocationUpdates() {
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self else { return }
            for await location in self.locationProvider.locationStream {
                self.currentLocation = location
            }
        }
    }
}
