//
//  DataUpdateDependencies.swift
//  iBurn
//
//  Created by Claude Code on 9/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaAPI
import PlayaDB

// MARK: - Network

/// Minimal fetch surface so tests can serve `update.json` and the per-type files
/// without a network (or a URLProtocol stub).
protocol DataFetching {
    func fetchData(from url: URL) async throws -> Data
}

/// `URLSession`-backed fetcher. File URLs are read directly, which keeps the
/// "point the app at a local folder" debugging trick working.
struct URLSessionDataFetcher: DataFetching {
    let session: URLSession
    let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 60) {
        self.session = session
        self.timeout = timeout
    }

    func fetchData(from url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        let request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout
        )
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DataUpdateError.httpError(statusCode: http.statusCode, url: url)
        }
        return data
    }
}

// MARK: - Preferences

/// The user-facing knobs the update check consults, behind a protocol so tests
/// don't touch `UserDefaults.standard`.
protocol DataUpdatePreferencing: AnyObject {
    /// Mirrors `UserDefaults.areDownloadsDisabled` (always true once the event is over).
    var areDownloadsDisabled: Bool { get }
    /// Timestamp of the last `update.json` fetch, used for the 24h throttle.
    var lastUpdateCheck: Date? { get set }
}

final class UserDefaultsDataUpdatePreferences: DataUpdatePreferencing {
    var areDownloadsDisabled: Bool { UserDefaults.areDownloadsDisabled }

    var lastUpdateCheck: Date? {
        get { UserDefaults.lastUpdateCheck }
        set { UserDefaults.lastUpdateCheck = newValue }
    }
}

// MARK: - Bundled data

/// The dataset shipped inside the app binary — the floor that OTA data is
/// compared against, and what "Reset to Bundled Data" restores.
protocol BundledDataProviding {
    /// JSON for one data type, or nil when this build ships none (e.g. no `mv.json`).
    func data(for type: DataObjectType) -> Data?
    /// The bundled `update.json`, or nil when absent.
    func updateInfoData() -> Data?
}

struct BundledDataProvider: BundledDataProviding {
    let bundle: Bundle

    init(bundle: Bundle = .brc_dataBundle) {
        self.bundle = bundle
    }

    func data(for type: DataObjectType) -> Data? {
        switch type {
        case .art: return try? BundleDataLoader.loadArt(from: bundle)
        case .camp: return try? BundleDataLoader.loadCamps(from: bundle)
        case .event: return try? BundleDataLoader.loadEvents(from: bundle)
        case .mutantVehicle: return try? BundleDataLoader.loadMutantVehicles(from: bundle)
        }
    }

    func updateInfoData() -> Data? {
        try? BundleDataLoader.loadUpdateInfo(from: bundle)
    }
}

// MARK: - OTA cache

/// One downloaded file's provenance: the name it had on the server and the
/// `updated` stamp `update.json` gave it.
struct OTACacheEntry: Codable, Equatable {
    let file: String
    let updated: Date
}

/// Persists downloaded JSON between launches.
///
/// Two jobs: resuming a partially-downloaded update (a type whose cached stamp
/// already matches the server isn't downloaded again), and making sure a re-import
/// uses the freshest data we have rather than falling back to the bundle.
protocol OTADataCaching: AnyObject {
    /// What's currently on disk, keyed by `DataObjectType.rawValue`.
    var entries: [String: OTACacheEntry] { get }
    func data(for type: DataObjectType) -> Data?
    func store(_ data: Data, for type: DataObjectType, entry: OTACacheEntry) throws
    /// Delete every downloaded file and forget the manifest.
    func clear() throws
}

extension OTADataCaching {
    func entry(for type: DataObjectType) -> OTACacheEntry? {
        entries[type.rawValue]
    }
}

/// File-backed cache at `<Application Support>/PlayaDB/ota/<year>/`.
///
/// Application Support (not Caches) because the OS may evict Caches, and losing a
/// downloaded update would silently roll the app back to bundled data. Excluded
/// from iCloud backup — it's re-downloadable.
final class OTADataFileCache: OTADataCaching {
    private let directory: URL
    private let fileManager: FileManager
    private let manifestName = "manifest.json"
    private var cachedEntries: [String: OTACacheEntry]?

    /// - Parameters:
    ///   - year: namespaces the cache so a new year's data never mixes with the old.
    ///   - containerURL: parent directory; defaults to Application Support.
    init(year: String, containerURL: URL? = nil, fileManager: FileManager = .default) {
        let base = containerURL
            ?? (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.directory = base
            .appendingPathComponent("PlayaDB", isDirectory: true)
            .appendingPathComponent("ota", isDirectory: true)
            .appendingPathComponent(year, isDirectory: true)
        self.fileManager = fileManager
    }

    /// Direct-directory initializer for tests.
    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    var entries: [String: OTACacheEntry] {
        if let cachedEntries { return cachedEntries }
        let loaded = loadManifest()
        cachedEntries = loaded
        return loaded
    }

    func data(for type: DataObjectType) -> Data? {
        try? Data(contentsOf: fileURL(for: type))
    }

    func store(_ data: Data, for type: DataObjectType, entry: OTACacheEntry) throws {
        try createDirectoryIfNeeded()
        try data.write(to: fileURL(for: type), options: .atomic)
        // Manifest is written after the payload so a crash in between leaves an
        // unreferenced file rather than a manifest promising data we don't have.
        var updated = entries
        updated[type.rawValue] = entry
        try writeManifest(updated)
        cachedEntries = updated
    }

    func clear() throws {
        cachedEntries = [:]
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    // MARK: - Private

    /// Plain ISO-8601 coders: the manifest is keyed by `DataObjectType.rawValue`,
    /// and PlayaAPI's snake-case key strategy would mangle `mutantVehicle`.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func fileURL(for type: DataObjectType) -> URL {
        directory.appendingPathComponent("\(type.rawValue).json")
    }

    private var manifestURL: URL {
        directory.appendingPathComponent(manifestName)
    }

    private func createDirectoryIfNeeded() throws {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private func loadManifest() -> [String: OTACacheEntry] {
        guard let data = try? Data(contentsOf: manifestURL) else { return [:] }
        guard let decoded = try? Self.decoder.decode([String: OTACacheEntry].self, from: data) else {
            return [:]
        }
        // A manifest entry whose payload vanished is worse than no entry at all —
        // it would make the service skip a needed download.
        return decoded.filter { key, _ in
            guard let type = DataObjectType(rawValue: key) else { return false }
            return fileManager.fileExists(atPath: fileURL(for: type).path)
        }
    }

    private func writeManifest(_ entries: [String: OTACacheEntry]) throws {
        let data = try Self.encoder.encode(entries)
        try data.write(to: manifestURL, options: .atomic)
    }
}
