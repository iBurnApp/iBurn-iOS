//
//  AudioTourViewModelTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the SwiftUI/PlayaDB Audio Tour view model: the union membership rule
//  (database `audio_tour_url` OR a local `MediaFiles/<uid>.m4a`), track-list
//  building (local file preferred over the remote URL, display ordering), the
//  bundled intro track, and the empty state the 2026 payload produces today.
//

import CoreLocation
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

// MARK: - Stubs

/// No-op stand-in for the legacy YapDatabase mirror so tests never touch Yap.
private final class StubFavoriteSyncService: FavoriteSyncService {
    func mirrorFavorite(type: FavoriteSyncObjectType, uid: String, isFavorite: Bool) async {}
    func mirrorVisitStatus(type: FavoriteSyncObjectType, uid: String, visitStatus: Int) async {}
    func mirrorNotes(type: FavoriteSyncObjectType, uid: String, notes: String) async {}
}

/// Stubs the filesystem half of the membership rule.
private final class StubAudioTourAssetProvider: AudioTourAssetProviding {
    private let uids: Set<String>
    static let directory = "/stub/MediaFiles"

    init(uids: Set<String> = []) {
        self.uids = uids
    }

    func localAudioUIDs() -> Set<String> { uids }

    func localAudioURL(uid: String) -> URL? {
        guard uids.contains(uid) else { return nil }
        return URL(fileURLWithPath: "\(Self.directory)/\(uid).m4a")
    }

    func localArtworkURL(uid: String) -> URL? { nil }
}

/// Records what got queued and lets a test drive the play/pause state.
private final class StubAudioPlayer: AudioPlayerProtocol {
    private(set) var queuedTracks: [[BRCAudioTourTrack]] = []
    var playingUID: String?
    var loadedUID: String?

    func playAudioTour(_ tracks: [BRCAudioTourTrack]) {
        queuedTracks.append(tracks)
        playingUID = tracks.first?.uid
        loadedUID = playingUID
    }

    func isPlaying(id: String) -> Bool { playingUID == id }

    func hasItem(id: String) -> Bool { loadedUID == id }
}

// MARK: - Tests

@MainActor
final class AudioTourViewModelTests: XCTestCase {

    private var playaDB: PlayaDB?
    private var audioPlayer: StubAudioPlayer?

    override func setUp() async throws {
        try await super.setUp()
        audioPlayer = StubAudioPlayer()
    }

    override func tearDown() async throws {
        playaDB = nil
        audioPlayer = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeDatabase(artJSON: Data) async throws -> PlayaDB {
        let db = try PlayaDBImpl(dbPath: ":memory:")
        try await db.importFromData(
            artData: artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON
        )
        playaDB = db
        return db
    }

    private func makeViewModel(
        localAudioUIDs: Set<String> = [],
        location: CLLocation? = nil
    ) throws -> AudioTourViewModel {
        let db = try XCTUnwrap(playaDB)
        let player = try XCTUnwrap(audioPlayer)
        return AudioTourViewModel(
            artProvider: ArtDataProvider(playaDB: db, favoriteSync: StubFavoriteSyncService()),
            locationProvider: MockLocationProvider(mockLocation: location),
            assetProvider: StubAudioTourAssetProvider(uids: localAudioUIDs),
            audioPlayer: player
        )
    }

    /// The view model is observation-driven, so tests wait for the first emission
    /// (which clears `isLoading`) rather than calling a refresh entry point.
    private func waitUntilLoaded(
        _ viewModel: AudioTourViewModel,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.isLoading && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(viewModel.isLoading, "Timed out waiting for the art observation to emit")
    }

    // MARK: - Membership

    func testDatabaseFlaggedArtAppears() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel()
        try await waitUntilLoaded(viewModel)

        XCTAssertEqual(viewModel.items.map(\.id), [Self.remoteAudioArtUID])
        let item = try XCTUnwrap(viewModel.items.first)
        XCTAssertEqual(item.audioURL.absoluteString, Self.remoteAudioURLString)
    }

    func testLocalFileOnlyArtAppears() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        // `silentArtUID` has no audio_tour_url in the database — only a local file.
        let viewModel = try makeViewModel(localAudioUIDs: [Self.silentArtUID])
        try await waitUntilLoaded(viewModel)

        XCTAssertEqual(
            Set(viewModel.items.map(\.id)),
            [Self.remoteAudioArtUID, Self.silentArtUID],
            "Local-file art must join the database-flagged art"
        )

        let localItem = try XCTUnwrap(viewModel.items.first { $0.id == Self.silentArtUID })
        XCTAssertEqual(localItem.audioURL.path, "\(StubAudioTourAssetProvider.directory)/\(Self.silentArtUID).m4a")
    }

    func testUnionDeDupesArtWithBothSources() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        // The same uid is flagged in the database *and* has a local recording.
        let viewModel = try makeViewModel(localAudioUIDs: [Self.remoteAudioArtUID])
        try await waitUntilLoaded(viewModel)

        XCTAssertEqual(viewModel.items.map(\.id), [Self.remoteAudioArtUID], "Must appear exactly once")

        let item = try XCTUnwrap(viewModel.items.first)
        XCTAssertTrue(item.audioURL.isFileURL, "The local recording must win over the remote URL")
    }

    func testArtWithoutAudioIsExcluded() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel(localAudioUIDs: [Self.silentArtUID])
        try await waitUntilLoaded(viewModel)

        XCTAssertFalse(viewModel.items.contains { $0.id == Self.otherSilentArtUID })
    }

    func testEmptyWhenNeitherSourceHasAudio() async throws {
        // The shape of the 2026 payload: no audio_tour_url anywhere, no .m4a files.
        _ = try await makeDatabase(artJSON: Self.silentArtJSON)

        let viewModel = try makeViewModel()
        try await waitUntilLoaded(viewModel)

        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertNil(viewModel.introTrack)
    }

    // MARK: - Track list

    func testTracksAreBuiltInDisplayOrderWithLocalPreference() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel(localAudioUIDs: [Self.silentArtUID])
        try await waitUntilLoaded(viewModel)

        // No location: alphabetical. "Aardvark Ascending" (local) before "Echoes of the Playa" (remote).
        XCTAssertEqual(viewModel.items.map(\.art.name), ["Aardvark Ascending", "Echoes of the Playa"])

        let tracks = viewModel.tracks
        XCTAssertEqual(tracks.map(\.uid), [Self.silentArtUID, Self.remoteAudioArtUID])
        XCTAssertEqual(tracks.map(\.title), ["Aardvark Ascending", "Echoes of the Playa"])
        XCTAssertTrue(tracks[0].audioURL.isFileURL)
        XCTAssertEqual(tracks[1].audioURL.absoluteString, Self.remoteAudioURLString)
        XCTAssertEqual(tracks[1].artist, "Audio Collective")
    }

    func testTracksAreSortedNearestFirstWithLocation() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        // Sitting on top of "Echoes of the Playa", which is alphabetically second.
        let here = CLLocation(latitude: 40.79179890754886, longitude: -119.1976993927176)
        let viewModel = try makeViewModel(localAudioUIDs: [Self.silentArtUID], location: here)
        try await waitUntilLoaded(viewModel)

        XCTAssertEqual(viewModel.tracks.map(\.uid), [Self.remoteAudioArtUID, Self.silentArtUID])
    }

    func testPlayAllQueuesEveryTrackInOrder() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel(localAudioUIDs: [Self.silentArtUID])
        try await waitUntilLoaded(viewModel)

        viewModel.playAll()

        let player = try XCTUnwrap(audioPlayer)
        let queued = try XCTUnwrap(player.queuedTracks.first)
        XCTAssertEqual(queued.map(\.uid), [Self.silentArtUID, Self.remoteAudioArtUID])
        XCTAssertEqual(viewModel.playAllTitle, "Pause", "Playing the tour flips the toolbar title")
    }

    func testPlayAllDoesNothingWhenThereIsNoAudio() async throws {
        _ = try await makeDatabase(artJSON: Self.silentArtJSON)

        let viewModel = try makeViewModel()
        try await waitUntilLoaded(viewModel)

        viewModel.playAll()

        let player = try XCTUnwrap(audioPlayer)
        XCTAssertTrue(player.queuedTracks.isEmpty)
        XCTAssertEqual(viewModel.playAllTitle, "Play All")
    }

    // MARK: - Intro track

    func testIntroTrackRequiresLocalIntroFile() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let withoutIntro = try makeViewModel()
        XCTAssertNil(withoutIntro.introTrack)

        let withIntro = try makeViewModel(localAudioUIDs: ["intro"])
        let intro = try XCTUnwrap(withIntro.introTrack)
        XCTAssertEqual(intro.uid, "intro", "Must match legacy BRCArtObject.introObject's uid")
        XCTAssertTrue(intro.audioURL.isFileURL)
        XCTAssertEqual(withIntro.introTitle, "Play Audio Tour Introduction")
    }

    func testIntroIsNotListedAsATourItem() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel(localAudioUIDs: ["intro"])
        try await waitUntilLoaded(viewModel)

        XCTAssertFalse(viewModel.items.contains { $0.id == "intro" })
        XCTAssertFalse(viewModel.tracks.contains { $0.uid == "intro" })
    }

    func testPlayIntroQueuesOnlyTheIntro() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel(localAudioUIDs: ["intro"])
        try await waitUntilLoaded(viewModel)

        viewModel.playIntro()

        let player = try XCTUnwrap(audioPlayer)
        let queued = try XCTUnwrap(player.queuedTracks.first)
        XCTAssertEqual(queued.map(\.uid), ["intro"])
        XCTAssertEqual(viewModel.introTitle, "Pause Introduction")
        XCTAssertEqual(viewModel.playAllTitle, "Play All", "The intro is not part of the tour queue")
    }

    // MARK: - Playback state

    func testPausedTrackShowsResumeTitles() async throws {
        _ = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel(localAudioUIDs: ["intro"])
        try await waitUntilLoaded(viewModel)

        let player = try XCTUnwrap(audioPlayer)

        // Loaded but not playing == paused.
        player.loadedUID = Self.remoteAudioArtUID
        player.playingUID = nil
        viewModel.refreshPlaybackState()
        XCTAssertEqual(viewModel.playAllTitle, "Resume")
        XCTAssertEqual(viewModel.introTitle, "Play Audio Tour Introduction")

        player.loadedUID = "intro"
        viewModel.refreshPlaybackState()
        XCTAssertEqual(viewModel.playAllTitle, "Play All")
        XCTAssertEqual(viewModel.introTitle, "Resume Introduction")
    }

    // MARK: - Favorites

    func testToggleFavoriteWritesThroughToPlayaDB() async throws {
        let db = try await makeDatabase(artJSON: Self.artJSON)

        let viewModel = try makeViewModel()
        try await waitUntilLoaded(viewModel)

        let item = try XCTUnwrap(viewModel.items.first)
        XCTAssertFalse(item.isFavorite)

        await viewModel.toggleFavorite(item)

        let fetched = try await db.fetchArt(uid: Self.remoteAudioArtUID)
        let art = try XCTUnwrap(fetched)
        let isFavorite = try await db.isFavorite(art)
        XCTAssertTrue(isFavorite)
    }

    // MARK: - Fixtures

    private static let remoteAudioArtUID = "a2IVI000000yWeZ2AU"
    private static let silentArtUID = "a2IVI000000yWeZ2AV"
    private static let otherSilentArtUID = "a2IVI000000yWeZ2AW"
    private static let remoteAudioURLString =
        "https://iburn-data.iburnapp.com/2025/audio_tour/a2IVI000000yWeZ2AU.mp3"

    /// One art piece with a remote `audio_tour_url` and two without the field at all.
    private static let artJSON = """
    [{"uid":"a2IVI000000yWeZ2AU","name":"Echoes of the Playa","year":2026,"description":"An art piece with a recorded audio tour.","artist":"Audio Collective","location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[],"guided_tours":false,"self_guided_tour_map":false,"audio_tour_url":"\(remoteAudioURLString)"},
     {"uid":"a2IVI000000yWeZ2AV","name":"Aardvark Ascending","year":2026,"description":"A kinetic sculpture.","artist":"Sam Jones","location":{"hour":3,"minute":0,"distance":4000,"category":"Open Playa","gps_latitude":40.78,"gps_longitude":-119.21},"location_string":"3:00 4000'","images":[],"guided_tours":false,"self_guided_tour_map":false},
     {"uid":"a2IVI000000yWeZ2AW","name":"Silent Monolith","year":2026,"description":"An art piece without any audio.","artist":"Quiet Collective","location":null,"location_string":null,"images":[],"guided_tours":false,"self_guided_tour_map":false}]
    """.data(using: .utf8) ?? Data()

    /// The 2026 shape: no record carries `audio_tour_url`.
    private static let silentArtJSON = """
    [{"uid":"a2IVI000000yWeZ2AW","name":"Silent Monolith","year":2026,"description":"An art piece without any audio.","artist":"Quiet Collective","location":null,"location_string":null,"images":[],"guided_tours":false,"self_guided_tour_map":false}]
    """.data(using: .utf8) ?? Data()

    private static let campJSON = """
    [{"uid":"a1XVI000008zSaf2AE","name":"Camp ASL Support Services HUB","year":2026,"url":null,"contact_email":null,"hometown":"All over","description":"American sign language support services.","landmark":null,"location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":null},"location_string":"Esplanade & 6:30","images":[]}]
    """.data(using: .utf8) ?? Data()

    private static let eventJSON = """
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"All levels welcome","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2026,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000008zSaf2AE","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2026-08-31T12:00:00-07:00","end_time":"2026-08-31T13:30:00-07:00"}]}]
    """.data(using: .utf8) ?? Data()
}
