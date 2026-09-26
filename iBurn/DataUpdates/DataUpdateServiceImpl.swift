//
//  DataUpdateServiceImpl.swift
//  iBurn
//
//  Created by Claude Code on 9/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import PlayaAPI
import PlayaDB

/// PlayaDB-native replacement for `BRCDataImporter`'s over-the-air update path.
///
/// Shape of an update check:
/// 1. Fetch `update.json` from the update server.
/// 2. Ask PlayaDB which of the types it mentions are newer than what's imported
///    (`outdatedDataTypes(comparedTo:)` — the same comparison the bundled-seed
///    path uses via `needsImport`).
/// 3. Download those files, resolving each `file` value against the folder holding
///    `update.json` (absolute URLs are used as-is), and persist each one under
///    Application Support as it lands. A file whose cached stamp already matches
///    the server isn't downloaded again, so an interrupted update resumes.
/// 4. Import the freshest copy of *every* type — cached download when it's at least
///    as new as the bundle, bundled JSON otherwise. `PlayaDB.importFromData` is a
///    full replace, so it has to be handed a complete set or untouched types would
///    be wiped.
/// 5. Prefetch thumbnail colors for anything new and post
///    `.BRCDataUpdateDidImport`. Lists and the map refresh themselves through GRDB
///    observations.
///
/// Map tiles are deliberately absent: the legacy tiles branch in
/// `BRCDataImporter.loadDataFromLocalURL:` returned immediately ("No longer using
/// static map tiles"), nothing observed `BRCDataImporterMapTilesUpdatedNotification`,
/// and MapLibre now reads the bundled style. There is no tiles behavior to port.
@MainActor
final class DataUpdateServiceImpl: DataUpdateService {
    private let playaDB: PlayaDB
    private let updatesURL: URL?
    private let fetcher: DataFetching
    private let cache: OTADataCaching
    private let bundledData: BundledDataProviding
    private var preferences: DataUpdatePreferencing
    private let throttleInterval: TimeInterval
    private let now: () -> Date
    private let notificationCenter: NotificationCenter
    private let onDidImport: ((PlayaDB) async -> Void)?

    private var isRunning = false

    /// - Parameters:
    ///   - updatesURL: the `update.json` URL. Nil means no server is configured, and
    ///     every check throws `DataUpdateError.missingUpdateURL`.
    ///   - throttleInterval: minimum gap between non-forced checks (default 24h,
    ///     matching the legacy importer).
    ///   - now: clock, injectable for tests and the Mock Date scheme.
    ///   - onDidImport: post-import side effect. Defaults to thumbnail color
    ///     prefetching; tests pass a no-op.
    init(
        playaDB: PlayaDB,
        updatesURL: URL?,
        fetcher: DataFetching,
        cache: OTADataCaching,
        bundledData: BundledDataProviding,
        preferences: DataUpdatePreferencing,
        throttleInterval: TimeInterval = 24 * 60 * 60,
        now: @escaping () -> Date = { Date.present },
        notificationCenter: NotificationCenter = .default,
        onDidImport: ((PlayaDB) async -> Void)? = { db in
            await ColorPrefetcher.prefetchMissingColors(playaDB: db)
        }
    ) {
        self.playaDB = playaDB
        self.updatesURL = updatesURL
        self.fetcher = fetcher
        self.cache = cache
        self.bundledData = bundledData
        self.preferences = preferences
        self.throttleInterval = throttleInterval
        self.now = now
        self.notificationCenter = notificationCenter
        self.onDidImport = onDidImport
    }

    var lastUpdateCheck: Date? { preferences.lastUpdateCheck }

    // MARK: - DataUpdateService

    @discardableResult
    func checkForUpdates(force: Bool) async throws -> DataUpdateOutcome {
        guard !isRunning else {
            DDLogInfo("DataUpdateService: check already running, skipping")
            return .alreadyRunning
        }
        if !force {
            guard !preferences.areDownloadsDisabled else { return .skippedDisabled }
            if let last = preferences.lastUpdateCheck,
               now().timeIntervalSince(last) < throttleInterval {
                return .skippedThrottled
            }
        }
        guard let updatesURL else { throw DataUpdateError.missingUpdateURL }

        isRunning = true
        defer { isRunning = false }

        // Stamped before the fetch, like the legacy importer: a server that's down
        // shouldn't be retried on every single launch.
        preferences.lastUpdateCheck = now()

        let remoteData = try await fetcher.fetchData(from: updatesURL)
        let remoteInfo = try APIParserFactory.create().parseUpdateInfo(from: remoteData)

        let outdated = try await playaDB.outdatedDataTypes(comparedTo: remoteData)
        guard !outdated.isEmpty else {
            DDLogInfo("DataUpdateService: PlayaDB is up to date with the server")
            return .upToDate
        }

        let folderURL = updatesURL.deletingLastPathComponent()
        var downloaded: [DataObjectType] = []
        var firstError: Error?

        for type in outdated {
            guard let fileInfo = remoteInfo.fileInfo(for: type) else { continue }
            // Resume: this type was already downloaded at this exact stamp but never
            // made it into the database (interrupted launch, failed import).
            if let cached = cache.entry(for: type),
               cached.updated == fileInfo.updated,
               cache.data(for: type) != nil {
                DDLogInfo("DataUpdateService: reusing cached \(type.rawValue) download")
                downloaded.append(type)
                continue
            }
            do {
                let fileURL = Self.resolveFileURL(fileInfo.file, relativeTo: folderURL)
                let data = try await fetcher.fetchData(from: fileURL)
                try cache.store(
                    data,
                    for: type,
                    entry: OTACacheEntry(file: fileInfo.file, updated: fileInfo.updated)
                )
                downloaded.append(type)
            } catch {
                DDLogError("DataUpdateService: failed to download \(type.rawValue): \(error)")
                firstError = firstError ?? error
            }
        }

        guard !downloaded.isEmpty else {
            throw DataUpdateError.downloadFailed(underlying: firstError ?? DataUpdateError.missingUpdateURL)
        }

        try await importFreshestAvailableData()
        return .updated(downloaded)
    }

    func resetToBundledData() async throws {
        try cache.clear()
        // Forget the throttle so the next launch (or button tap) re-checks the
        // server instead of sitting on bundled data for up to a day.
        preferences.lastUpdateCheck = nil
        try await importFreshestAvailableData()
    }

    // MARK: - Import

    /// Hands `PlayaDB.importFromData` the newest copy of every data type we have.
    ///
    /// The import is a full replace, so each type must be supplied even when only
    /// one of them changed — otherwise unchanged types would vanish from the
    /// database. `updateData` is synthesized from the chosen sources, which is what
    /// makes the next `outdatedDataTypes` comparison (and the bundled-seed
    /// `needsImport` check) see the right per-type timestamps.
    private func importFreshestAvailableData() async throws {
        let bundleInfo = bundledData.updateInfoData()
            .flatMap { try? APIParserFactory.create().parseUpdateInfo(from: $0) }

        var sources: [DataObjectType: ResolvedSource] = [:]
        for type in DataObjectType.allCases {
            if let source = resolveSource(for: type, bundleInfo: bundleInfo) {
                sources[type] = source
            }
        }

        guard let art = sources[.art], let camp = sources[.camp], let event = sources[.event] else {
            throw DataUpdateError.downloadFailed(
                underlying: BundleDataLoader.LoadError.invalidData("missing art, camp, or event data")
            )
        }
        let mv = sources[.mutantVehicle]

        let mergedUpdateInfo = APIUpdateInfo(
            art: art.info,
            camps: camp.info,
            events: event.info,
            mv: mv?.info
        )
        // Encoded, not optional: without it importFromData would stamp every type
        // with "now", and the next comparison against the server would think the
        // database is already newer than anything the server could offer.
        let updateData = try PlayaAPI.createEncoder().encode(mergedUpdateInfo)

        try await playaDB.importFromData(
            artData: art.data,
            campData: camp.data,
            eventData: event.data,
            mvData: mv?.data,
            updateData: updateData
        )

        if let onDidImport {
            let db = playaDB
            Task.detached(priority: .utility) {
                await onDidImport(db)
            }
        }
        notificationCenter.post(name: .BRCDataUpdateDidImport, object: nil)
    }

    private struct ResolvedSource {
        let data: Data
        let info: FileUpdateInfo
    }

    /// Cached download when it is at least as new as the bundled copy, bundled JSON
    /// otherwise. A type present in neither returns nil.
    private func resolveSource(
        for type: DataObjectType,
        bundleInfo: APIUpdateInfo?
    ) -> ResolvedSource? {
        let bundleFileInfo = bundleInfo?.fileInfo(for: type)
        let bundleData = bundledData.data(for: type)

        if let cached = cache.entry(for: type), let cachedData = cache.data(for: type) {
            let bundleIsNewer = (bundleFileInfo?.updated).map { $0 > cached.updated } ?? false
            if !bundleIsNewer || bundleData == nil {
                return ResolvedSource(
                    data: cachedData,
                    info: FileUpdateInfo(file: cached.file, updated: cached.updated)
                )
            }
        }

        guard let bundleData else { return nil }
        // A build with no update.json stamp for this type falls back to "now", which
        // is what importFromData does when handed no update data at all.
        let info = bundleFileInfo ?? FileUpdateInfo(file: "\(type.rawValue).json", updated: now())
        return ResolvedSource(data: bundleData, info: info)
    }

    // MARK: - URL resolution

    /// `update.json` file entries are normally bare names (`art.json`) resolved
    /// against the folder holding `update.json`, but the server is allowed to hand
    /// back a fully-qualified URL instead — the legacy importer keyed off the string
    /// containing "https". Matching any scheme is a superset of that behavior.
    static func resolveFileURL(_ file: String, relativeTo folderURL: URL) -> URL {
        if let absolute = URL(string: file), absolute.scheme != nil {
            return absolute
        }
        return folderURL.appendingPathComponent(file)
    }
}
