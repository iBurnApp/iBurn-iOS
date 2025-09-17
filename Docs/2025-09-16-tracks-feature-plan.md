# High-Level Plan
- **Problem Statement:** Add an always-on tracks feature that records user location history in the background and renders each day's path in a distinct color on the main MapLibre map.
- **Solution Overview:** Create a standalone `TracksService` Swift package powered by GRDB to manage background recording, storage, and querying of breadcrumb samples grouped by day. Integrate the service with app lifecycle events and expose retrieval APIs for UI. Extend the main map to subscribe to daily track updates, render multicolor polylines via MapLibre style layers, and provide user controls for privacy and retention.
- **Key Changes:** New Swift package with GRDB migrations, location manager wrapper, data access facade, background task coordination, map overlay renderer, settings hooks, and tests for storage/query logic and rendering pipeline.

## Technical Details

### Swift Package: TracksService
- Package structure under `Packages/TracksService` with a core target (`TracksService`) plus a test target.
- Public entry point: `TracksService` singleton/factory responsible for configuration, lifecycle management, and dependency injection (e.g., `DatabaseProvider`, `LocationAuthorizationHandler`).
- Submodules: `Persistence` (GRDB models/migrations), `Recording` (CLLocationManager delegate & background integration), `Querying` (daily segments, statistics), `Publishing` (Combine/NotificationCenter events).
- Provide protocols for mocking (`TracksDatabase`, `TracksRecorder`, `TracksProvider`) to make the package reusable/testing-friendly.

### GRDB Schema & Persistence
- Database stored in `Application Support/Tracks/Tracks.sqlite` managed by `DatabasePool` for concurrent reads/writes.
- Tables:
  - `track_samples`: `id INTEGER PRIMARY KEY`, `day TEXT NOT NULL`, `timestamp DATETIME NOT NULL`, `latitude DOUBLE NOT NULL`, `longitude DOUBLE NOT NULL`, optional metrics (`horizontalAccuracy`, `speed`, `course`, `activityType`, `isManual`).
  - `track_days`: aggregated metadata per day (`day TEXT PRIMARY KEY`, `sampleCount`, `firstTimestamp`, `lastTimestamp`, `distanceMeters`, `syncState`).
- Indices on `(day, timestamp)` and `timestamp` to speed filtering and pruning.
- Migration strategy versioned in GRDB migrator; include migration tests and lightweight data migration path from existing `LocationHistory.sqlite` if present.

### Recording Workflow
- `TracksRecorder` configures `CLLocationManager` with background mode: `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`, `activityType = .fitness`, `desiredAccuracy = kCLLocationAccuracyBest`, and `distanceFilter` tuned for battery (e.g., 10-25 meters).
- Handles authorization flow (request `always` with fallback to `whenInUse` + reminder) and monitors `UIApplication` lifecycle (foreground/background) to restart updates as needed.
- Filters incoming locations (accuracy threshold, BM geofence) then persists asynchronously on a background queue via GRDB. Batches writes and updates daily aggregates within a transaction.
- Exposes manual triggers for flush/pause/resume, plus retention policy cleanup job (e.g., keep last 14 days by default, configurable).

### Data Access & Notifications
- Provide query APIs: `tracksService.fetchDays(range:)`, `fetchSamples(for day:)`, `observeLiveDay(day:)`, `latestSample`, `totalDistance(for:)`.
- Output Combine publishers / NotificationCenter broadcasts for new samples per day to drive UI updates.
- Include convenience grouping to split by local calendar day, respecting festival timezone (America/Los_Angeles).

### Background Execution Strategy
- Register `BGProcessingTask` (or region monitoring fallback) to relaunch recorder if terminated and to perform cleanup/aggregation tasks.
- Ensure Info.plist updates (`UIBackgroundModes` for `location`, `BGTaskSchedulerPermittedIdentifiers`).
- Document manual testing steps for background scenarios (simulator vs. device, TestFlight).

### Settings & Privacy Integration
- Reuse `UserDefaults.isLocationHistoryDisabled` as primary toggle; add new preferences for retention duration and day-color mapping if needed.
- Provide onboarding copy & settings UI (map screen settings button or global preferences) to explain recording, local-only storage, and deletion controls.
- Hook toggles to start/stop recorder immediately and surface status indicator (e.g., map overlay legend, toast when paused).

### Main Map Integration (MapLibre)
- Create `TracksOverlayController` in app target that depends on `TracksService` and `MapLayerManager`.
- On style load, register an `MLNShapeSource` per day or a data-driven source with `day` attribute. Add dedicated line layers inserted above user-track layer but below POIs.
- Generate `MLNPolylineFeature`s from daily sample arrays; assign `lineColor` using categorical data-driven styling (e.g., palette cycling through evening/day colors). Maintain consistent colors by hashing the day string.
- Listen to service publishers to refresh the relevant day's source incrementally without rebuilding full map overlays.
- Provide legend UI (e.g., pill overlay) describing day-to-color mapping and allow toggling individual days.

### Testing & Tooling
- Unit tests in package for migrations, sample inserts, day grouping, pruning, and color assignment.
- UI tests (optional) verifying map overlay updates using mocked `TracksService` in simulator.
- Diagnostics command (maybe debug menu) to export GPX/GeoJSON using service queries for manual validation.

### Public Protocols & Interfaces

```swift
public protocol TracksServiceProtocol: AnyObject {
    var configuration: TracksConfiguration { get }
    func startRecording()
    func stopRecording()
    func setRecordingEnabled(_ isEnabled: Bool)
    func refreshAuthorizationStatus()
    func purgeSamples(olderThan date: Date) async throws
    func purgeAllSamples() async throws
    func exportGeoJSON(for day: TrackDay.ID) async throws -> Data
    func fetchDays(range: DateInterval?) async throws -> [TrackDay]
    func fetchSamples(for day: TrackDay.ID) async throws -> [TrackSample]
    func observeDaySummaries() -> AnyPublisher<[TrackDay], Never>
    func observeSamples(for day: TrackDay.ID) -> AnyPublisher<[TrackSample], Never>
}
```

- `TracksConfiguration`: Immutable value describing retention window, geofence rectangle/circle, minimum accuracy, maximum sample rate, color palette seed, and background task identifiers.
- `TrackDay`: Lightweight struct containing `id` (calendar day string), `date`, `sampleCount`, `distanceMeters`, `firstTimestamp`, `lastTimestamp`, `colorToken`, `isRecording`.
- `TrackSample`: Codable record with CoreLocation mirror (latitude/longitude, timestamp, accuracy metadata, optional altitude/speed/course).
- `TracksServiceFactoryProtocol` exposes `makeService(environment:) -> TracksServiceProtocol` so the app can inject dependencies during app launch/testing.

```swift
public protocol TracksDatabase: AnyObject {
    func performWrite<T>(_ block: (Database) throws -> T) throws -> T
    func performRead<T>(_ block: (Database) throws -> T) throws -> T
    func asyncWrite(_ block: @escaping (Database) throws -> Void)
    func observeValueChanges(_ observer: AnyTracksDatabaseObserver)
}

public protocol TracksRecorder: AnyObject {
    var delegate: TracksRecorderDelegate? { get set }
    func start(with configuration: RecorderConfiguration)
    func stop()
    func pause()
    func resume()
    func refreshAuthorization()
}

public protocol TracksRecorderDelegate: AnyObject {
    func recorder(_ recorder: TracksRecorder, didProduce locations: [CLLocation])
    func recorder(_ recorder: TracksRecorder, didFailWith error: Error)
    func recorderNeedsAuthorizationPrompt(_ recorder: TracksRecorder)
}

public protocol TracksQueryProviding {
    func latestDayID() async throws -> TrackDay.ID?
    func fetchSummary(for day: TrackDay.ID) async throws -> TrackDay
    func fetchPolyline(for day: TrackDay.ID) async throws -> TrackPolyline
    func fetchLegendEntries(limit: Int?) async throws -> [TrackLegendEntry]
}

public struct TrackPolyline: Sendable {
    public let day: TrackDay.ID
    public let coordinates: [CLLocationCoordinate2D]
    public let color: UIColor
    public let lastUpdated: Date
}

public struct TrackLegendEntry: Sendable {
    public let day: TrackDay.ID
    public let color: UIColor
    public let sampleCount: Int
    public let distanceMeters: Double
}
```

Provide default concrete implementations within the package and expose lightweight mocks (`TracksServiceMock`, `TracksRecorderMock`, `TracksDatabaseInMemory`) for tests and host app previews.

### Implementation Details by Module

- **Configuration & Environment**
  - `TracksEnvironment` struct bundles dependencies: `logHandler`, `dateProvider`, `calendar`, `timeZone`, `backgroundTaskScheduler`, `userDefaults`, `notificationCenter`, `locationAuthorizationPrompter`.
  - `TracksConfiguration` default uses Burning Man region polygon from `BRCLocations`, festival timezone `America/Los_Angeles`, retention `14` days, color palette derived from `HCL` hues.
  - Provide builder that can load overrides from `UserSettings` during runtime.

- **Persistence**
  - Use `DatabasePool` configured with `JournalMode.wal`, `foreignKeys = true`, `busyMode = .timeout(2)`, `defaultMaxReaderCount = 5`.
  - Schema migrations via `DatabaseMigrator`, versioned: `v1_initial_samples`, `v2_add_metadata`, `v3_track_days`, `v4_create_indices`, `v5_drop_legacy_breadcrumbs_table`.
  - `TrackSampleRecord` implements `PersistableRecord`, `FetchableRecord`, `MutablePersistableRecord`. Column definitions align with `TrackSample` codable struct.
  - Aggregation maintained by database triggers (`AFTER INSERT ON track_samples`) to update `track_days`, plus background task to recompute totals in case of manual deletions.
  - Provide incremental distance calculation using haversine formula in Swift and persist `distanceMeters` delta per sample.
  - Retention job deletes rows older than `configuration.retention`, cascades to `track_days` via trigger.

- **Recording**
  - `CoreLocationTracksRecorder` leverages `CLLocationManager`, toggles `allowsBackgroundLocationUpdates` and `showsBackgroundLocationIndicator` when enabled. When user disables from settings, stop updates and `CLLocationManager.stopMonitoringSignificantLocationChanges` to conserve battery.
  - Implements `didChangeAuthorization`, `didFailWithError`, `didFinishDeferredUpdates`. Use `allowDeferredLocationUpdates(untilTraveled:timeout:)` for longer battery life once user is stationary.
  - Batching: accumulate up to `configuration.batchSize` (default 20) or flush every 60 seconds; dispatch to persistence using `DatabasePool.asyncWrite`.
  - Filtering: discard samples with `horizontalAccuracy` > `configuration.maxHorizontalAccuracy` (e.g., 75 m), coordinates outside `BRCLocations.burningManRegion`, or stale timestamps > 2 minutes old.

- **Aggregation & Publishing**
  - `TracksAggregationController` listens for `DatabaseRegionObservation` from GRDB to stream updates to Combine `PassthroughSubject`.
  - Provide `TracksPublisherAdapter` that converts raw DB change sets into value objects on a dedicated dispatch queue, coalescing frequent updates (e.g., throttle to every 2 seconds) before pushing to UI.
  - Emit `TrackOverlaySnapshot` containing `day` id, polyline coords, bounding box, `lastSampleDate`, `isCurrentDay` for overlay controller to diff.

- **API Surface for Host App**
  - Expose `TracksServiceBootstrapper.bootstrap(application:)` to be called in `BRCAppDelegate.application(_:didFinishLaunchingWithOptions:)`, hooking into `UIApplication.didBecomeActiveNotification` / `willResignActive` to resume/pause as appropriate.
  - Provide bridging method `TracksServiceProtocol.registerForBackgroundTasks()` returning identifier strings; AppDelegate registers them with `BGTaskScheduler`.
  - Provide `TracksServiceProtocol.handleBackgroundTask(identifier:completion:)` to execute when the OS launches tasks.

- **Swift Package Layout**
  - `Sources/TracksService/Configuration/TracksConfiguration.swift`
  - `Sources/TracksService/Environment/TracksEnvironment.swift`
  - `Sources/TracksService/Persistence/DatabasePoolProvider.swift`
  - `Sources/TracksService/Persistence/Records/TrackSampleRecord.swift`
  - `Sources/TracksService/Persistence/Records/TrackDayRecord.swift`
  - `Sources/TracksService/Recording/CoreLocationTracksRecorder.swift`
  - `Sources/TracksService/Service/TracksService.swift`
  - `Sources/TracksService/Publishing/TracksPublisher.swift`
  - `Sources/TracksService/Querying/TracksQueryController.swift`
  - `Sources/TracksService/Mocks` for internal testing convenience.
  - Tests mirror modules with fixture builders (`TrackSampleFixtures`), migration harness, and concurrency tests using `XCTestExpectation`.

### Map Overlay Implementation Details
- `TracksOverlayController` instantiated by `MainMapViewController` once map style is available; retains `TracksServiceProtocol` reference.
- Maintains `MLNSources` dictionary keyed by `TrackDay.ID`. Current day updates in place; past day sources replaced only when aggregates change.
- Use a single `MLNShapeSource` named `tracks-day-source` with `MLNPolylineFeature` features per day and per segment (if there are gaps > 10 minutes, start a new feature to avoid straight lines across playa).
- Line layer configuration:
  - Identifier: `tracks-day-layer`
  - Styling: `lineColor` expression referencing feature attribute `dayColor`, fallback to palette array; `lineWidth` expression 2.5 when zoom >= 15, else 1.25.
  - `lineOpacity` 0.6 default, ramp to 0.35 when day toggled off (but still present for legend).
- Add optional `MLNCircleStyleLayer` for showing most recent sample with pulsing animation (attach to current day only).
- Legend UI: simple `UIStackView` anchored above sidebar buttons or integrated into `SidebarButtonsView`. Provides per-day toggle, long-press to rename day (if we later support). Colors derived from `TracksColorPalette` using deterministic hash (e.g., convert day string to `UInt32`, map to color wheel).
- Provide adapter to translate `TrackPolyline` into `MLNPolyline`. Offload coordinate smoothing (Douglas-Peucker) to `TracksOverlayController` before adding to map to avoid clutter.

### Authorization & Settings Flow
- Extend `Preferences` module with `TracksPreferences` wrapper storing: `isEnabled`, `retentionDays`, `showsLegend`, `colorSeed`, `allowsCellularExport`.
- Update `TracksViewController` (legacy) to either wrap new service or be replaced by `TracksHistoryViewController` that leverages same query APIs for list/table view of days.
- On first launch, show modal explaining tracking; provide quick access to `Settings > Privacy > Location` if user denies `always` permission, using `UIApplication.openSettingsURLString`.
- Record analytics event (if permitted) when user toggles tracking so we can monitor adoption (respecting offline mode: stored locally and only sent when authorized).

### Migration Strategy
- Existing `LocationHistory.sqlite` contains `breadcrumb` table. Implement migration command inside `TracksService` that detects file, reads rows via temporary GRDB `DatabaseQueue`, groups by day, and inserts into new schema.
- After successful migration, archive legacy file by moving to `LocationHistory.sqlite.bak`. Provide user prompt (in advanced settings) to retry migration or delete legacy data if corruption detected.
- Provide unit test with fixture DB replicating old schema to ensure migration path continues to succeed.
- If migration fails, fall back to creating new database and surface non-blocking alert to user offering manual import instructions.

### Background Execution & Battery Considerations
- Register `BGProcessingTaskRequest` with identifier `org.iburn.tracks.processing` scheduled every 30 minutes while recording is enabled. Task flushes deferred updates, recomputes aggregates, performs retention cleanup, and ensures recorder is active.
- Use `BGAppRefreshTaskRequest` `org.iburn.tracks.refresh` for lightweight restarts after OS suspends app.
- When app transitions to background, call `CLLocationManager.allowDeferredLocationUpdates(untilTraveled: 200, timeout: 120)`; on foreground restore to immediate updates.
- Monitor `ProcessInfo.isLowPowerModeEnabled`; if true, reduce sampling rate (increase `distanceFilter`, reduce desired accuracy) while still maintaining path continuity.
- Provide heuristics to pause recording if device leaves playa geofence for > 5 km radius to conserve power.

### Testing & Validation Plan
- **Unit**: Validate migrations using `DatabaseMigrator.eraseDatabaseOnSchemaChange` in tests. Verify sample insertion yields expected `track_days` aggregates and distances. Test retention logic with synthetic data sets.
- **Integration**: Use `CLLocationManager` chaff via `TestLocationGenerator` to simulate user walking path; confirm service batches and publishes updates appropriately.
- **UI**: Snapshot tests for legend view with multiple days, map overlay integration tests using MapLibre test harness (if available) or verifying `TracksOverlayController` writes expected sources.
- **Performance**: Stress test with 10k samples per day, ensure database queries under 50 ms and map overlays render within 16 ms on iPhone 12 class hardware.
- **Manual QA**: Document steps for on-device background run (drive around for 30 minutes, kill app, relaunch) verifying track continuity; check retention by adjusting setting to 1 day and ensuring older data removed overnight.

### Open Questions & Research Notes
- Does iOS 18 require explicit `NSLocationAlwaysUsageDescription` copy updates? Need to confirm message tone aligns with privacy copy guidelines.
- Confirm MapLibre supports categorical color expressions sourced from feature attributes without additional runtime styling—if not, fallback to generating separate line layers per day.
- Determine if we should store altitude/course; evaluate based on sensor noise vs. value for user.
- Evaluate using `CLBeaconRegion` or geofencing to auto-pause when outside Burning Man region—respects battery but may delay resume if OS throttles geofence events.
- Assess whether to integrate HealthKit motion activity for heuristic to skip stationary noise (requires additional entitlements).

### Implementation Timeline (Rough)
1. Scaffold Swift package, configuration, protocols, and baseline migrations.
2. Implement persistence layer with unit tests and migration suite.
3. Build CoreLocation recorder, integrate batching and filtering, add mocks.
4. Wire service facade with Combine publishers and background task hooks.
5. Migrate legacy data and create utilities/diagnostic exporters.
6. Integrate into iBurn app (AppDelegate + UserDefaults + Settings UI).
7. Build MapLibre overlay controller, legend UI, and update `MainMapViewController`.
8. Perform on-device validation, finalize copy, and ship behind feature flag if needed.

## Context Preservation

### Conversation Transcript
```
User: let's make a plan for a "tracks" feature that records your location in the background and shows each day as a separate color on the main map screen. 1. we want to use GRDB. 2. we want to make this a standalone swift package service for the underlying recording and data storage. 3. display of the tracks will happen via our existing MapLibre MLNMapView
Assistant: Gathered repository context, reviewed existing Tracks code (LocationStorage, Breadcrumb, TracksViewController) to inform new design. Planned architecture for GRDB-backed Swift package, background recording, and MapLibre integration with multiday color styling.
```

### Existing Implementation References
- `iBurn/Tracks/LocationStorage.swift`: legacy GRDB-backed location recorder tied to app target, lacks day segmentation and multicolor map rendering.
- `iBurn/Tracks/TracksViewController.swift`: standalone screen rendering breadcrumbs as red polyline with annotations; serves as migration reference for data model & UI expectations.

```swift
// iBurn/Tracks/LocationStorage.swift (excerpt)
@objc public func start() {
    guard !UserDefaults.isLocationHistoryDisabled else { return }
    locationManager.startUpdatingLocation()
}

public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let newCrumbs: [Breadcrumb] = locations.compactMap {
        guard BRCLocations.burningManRegion.contains($0.coordinate) else { return nil }
        return Breadcrumb.from($0)
    }
    dbQueue.asyncWrite({ (db) in
        for var crumb in newCrumbs {
            try crumb.insert(db)
        }
    }) { (db, result) in
        switch result {
        case .success:
            print("Saved breadcrumbs: \(newCrumbs)")
        case .failure(let error):
            print("Error saving breadcrumb: \(error)")
        }
    }
}
```

```swift
// iBurn/Tracks/TracksViewController.swift (excerpt)
let coordinates = crumbs.map { $0.coordinate }
let polyLine = MLNPolyline(coordinates: coordinates, count: UInt(coordinates.count))
annotations.append(polyLine)
mapView.addAnnotation(polyLine)
...
func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
    return .red
}
```

## Cross-References
- Review recent map-layer work: `Docs/2025-08-23-camp-layer-implementation.md` for style layer patterns.
- Check prior visit-tracking planning: `Docs/2025-08-16-visit-tracking-feature.md` for background/location considerations.

## Expected Outcomes
- GRDB-powered `TracksService` package manages background recording, retention, and querying of location samples grouped by day.
- iBurn app integrates service lifecycle (AppDelegate/MainMap) with user preferences and background task scheduling.
- Main map renders colored polylines per day using MapLibre, updates live as new samples arrive, and provides legend/toggle UI.
- Users can pause/resume recording and purge history; data stays on-device unless exported.
