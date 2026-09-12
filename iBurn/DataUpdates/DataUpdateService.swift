//
//  DataUpdateService.swift
//  iBurn
//
//  Created by Claude Code on 9/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaAPI
import PlayaDB

/// What a single over-the-air update check did.
enum DataUpdateOutcome: Equatable {
    /// Another check was already running; this call did nothing.
    case alreadyRunning
    /// Automatic updates are switched off (or the event is over). Only possible
    /// for a non-forced check.
    case skippedDisabled
    /// Checked recently enough that we didn't hit the network again.
    case skippedThrottled
    /// The server's data is not newer than what PlayaDB already holds.
    case upToDate
    /// These types were refreshed from the server and imported into PlayaDB.
    case updated([DataObjectType])
}

enum DataUpdateError: LocalizedError {
    /// `kBRCUpdatesURLString` is empty or unparseable (e.g. a fresh clone with a
    /// stub `BRCSecrets.m`).
    case missingUpdateURL
    /// Every changed file failed to download.
    case downloadFailed(underlying: Error)
    case httpError(statusCode: Int, url: URL)

    var errorDescription: String? {
        switch self {
        case .missingUpdateURL:
            return "No update server URL is configured."
        case .downloadFailed(let underlying):
            return "Download failed: \(underlying.localizedDescription)"
        case .httpError(let statusCode, let url):
            return "Server returned \(statusCode) for \(url.lastPathComponent)"
        }
    }
}

extension Notification.Name {
    /// Posted on the main queue after an OTA update has been imported into PlayaDB.
    /// Most UI updates itself through GRDB observations; this exists for the few
    /// places that need an explicit nudge (and for tests).
    static let BRCDataUpdateDidImport = Notification.Name("BRCDataUpdateDidImportNotification")
}

/// Downloads `update.json` and the per-type JSON files it references, and imports
/// the freshest available data into PlayaDB.
///
/// Replaces the YapDatabase-era `BRCDataImporter` OTA path. Downloaded JSON is
/// persisted under Application Support so an interrupted update resumes, and so a
/// re-import never falls back to the (older) bundled data when fresher data is
/// already on disk.
@MainActor
protocol DataUpdateService: AnyObject {
    /// Check the update server and import anything newer than what PlayaDB holds.
    ///
    /// - Parameter force: bypasses both the once-per-day throttle and the
    ///   "automatic updates" preference. The Settings screen's "Check for Updates"
    ///   button passes `true`; launch and background refresh pass `false`.
    @discardableResult
    func checkForUpdates(force: Bool) async throws -> DataUpdateOutcome

    /// Throw away every downloaded update and re-import the data bundled with the
    /// app binary.
    func resetToBundledData() async throws

    /// When the update server was last contacted, for display in Settings.
    var lastUpdateCheck: Date? { get }
}

/// Builds the shipping `DataUpdateService`.
enum DataUpdateServiceFactory {
    /// - Parameters:
    ///   - playaDB: the app's single database instance.
    ///   - updatesURLString: the `update.json` URL. Defaults to the secret baked
    ///     into `BRCSecrets.m`; an empty string yields a service that reports
    ///     `DataUpdateError.missingUpdateURL`.
    @MainActor
    static func makeService(
        playaDB: PlayaDB,
        updatesURLString: String = kBRCUpdatesURLString
    ) -> DataUpdateService {
        let updatesURL = updatesURLString.isEmpty ? nil : URL(string: updatesURLString)
        return DataUpdateServiceImpl(
            playaDB: playaDB,
            updatesURL: updatesURL,
            fetcher: URLSessionDataFetcher(),
            cache: OTADataFileCache(year: YearSettings.playaYear),
            bundledData: BundledDataProvider(),
            preferences: UserDefaultsDataUpdatePreferences()
        )
    }
}
