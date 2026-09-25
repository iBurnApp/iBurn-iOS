# Live Tracks: design spike (2027 feature)

Status: **design spike, research and writing only.** No code has been changed. Every code block below is
a throwaway sketch. Where this doc isn't sure about an API, it says so; nothing here was compiled.

---

## 1. High-Level Plan

### Problem / motivation

At the burn, Chris records his daily adventures by hand in **GaiaGPS**: he starts a track each morning and
exports it later. iBurn already knows where you are and already has the playa basemap, so it should do
this itself:

- **Record where you go** (opt-in), including while the phone is in your pocket.
- **Draw it on the main map** as a line. Each day gets its own color. Today's line fades with age, so
  older points are more transparent. Past days are drawn much fainter so they don't clutter the map.
- **Export to GPX**, one day or all days.
- **Build it generically**, so the same code runs as a small standalone app that Chris can test at home in
  the Bay Area. The iBurn map is clamped to Black Rock City (`minimumZoomLevel = 12`, BRC-only
  MBTiles), so a Bay Area track can't be seen in iBurn at all.

### Recommendations (TL;DR)

| Area | Recommendation |
|---|---|
| Package | New local SwiftPM package **`Packages/TrackKit`** (playa-agnostic): GRDB storage, recorder, fix filtering, day bucketing, Douglas–Peucker simplification, a renderer-agnostic style model, GPX writer. Plus a small **`TrackKitUI`** product with SwiftUI status, permission-CTA and controls views that both apps embed. |
| iBurn integration | A thin layer: `TrackLayerController` (MapLibre sources and layers, re-added on every style load), a "Live Tracks" section in `MapFilterView`, a record/pause button in `SidebarButtonsView`, and a factory in `DependencyContainer`. **Replaces** the 2019 `LocationStorage` / `TracksViewController` prior art (§3.1). |
| Location API | **`CLLocationUpdate.liveUpdates(.fitness)` + `CLBackgroundActivitySession`** (iOS 17+), with **`CLServiceSession`** (iOS 18+) for authorization and diagnostics. The recorder downsamples in software according to a **Low / Balanced / High** fidelity setting. `CLLocationManager` is the fallback for iOS 16 and the "Low" preset. Needs `UIBackgroundModes += location`. |
| Authorization | **When In Use is enough** to record in the background once recording starts in the foreground (blue location pill). **Always** is an optional upgrade ("survives the app being closed or rebooted") and shows as a warning-level CTA, not a blocker. |
| Storage | A separate `Tracks.sqlite` file in Application Support, not inside PlayaDB, because PlayaDB is replaced from a seed each year and has a different lifecycle. Tables `track_point` and `track_session`. Store raw filtered fixes; **simplify on read**. Bucket days on read with a **configurable day boundary** (iBurn defaults to 06:00, the standalone app to 00:00). A week at Balanced is about 5 MB. |
| Rendering | **Time-sliced segments with data-driven `lineOpacity`/`lineColor`** in two `MLNShapeSource`s (`tracks-past`, `tracks-today`). Today's fade is an `interpolate` over a per-feature `t` property. It is refreshed by **re-setting only the layer's opacity expression** each minute, so there is no GeoJSON re-upload. `line-gradient` was considered and rejected (it works by distance, not time, and one gradient applies per layer; §6.2). |
| UI | Filter sheet: a "Live Tracks" section with staged display options (these follow the sheet's Done/Cancel model) and a pushed **"Recording & Data"** page whose controls apply immediately: enable, pause, fidelity, day boundary, retention, export, wipe. Permission problems appear as a status row with a CTA. Pause and resume also sit in a map sidebar button. |
| GPX | GPX 1.1 with one `<trk>` per day and one `<trkseg>` per session. A streaming writer runs over a GRDB cursor. Speed and course go in the Garmin `TrackPointExtension`. Sharing uses `ShareLink`/`UIActivityViewController`. |
| Standalone app | A **"TrackKit Demo"** SwiftUI app using **MapKit** (`Map` + `MapPolyline`), so it needs no tile setup, rendering the same `TrackStyleModel`. It lives in `Packages/TrackKit/Demo/TrackKitDemo.xcodeproj` and is sideloaded from Xcode. |
| Watch | Out of scope. Later phase: show-only (phone sends today's simplified line). Recording on the watch would need a workout session, which is a battery non-starter. |

### Phases (details and sizing in §10)

- **P1**: TrackKit package, storage, filter, foreground recording, and a plain line on the iBurn map. Legacy breadcrumb import.
- **P2**: Background recording, authorization and diagnostics, status CTA, relaunch handling.
- **P3**: Day colors, today fade, filter-sheet display options, sidebar pause button.
- **P4**: GPX export, wipe, retention.
- **P5**: Standalone demo app for Bay Area testing. (It can move earlier: it is the fastest way to test P2 on a real device.)
- **Later**: watch display, Live Activity, timed pause, and "record only on playa" geofence auto-start.

---

## 2. Codebase research (current state, with citations)

### 2.1 Location plumbing today

- **App-wide manager**: `BRCAppDelegate.m:103-108` creates `[CLLocationManager brc_locationManager]` and
  calls `startLocationUpdatesIfAuthorized` (`BRCAppDelegate.m:294-299`, starts only for
  WhenInUse/Always).
- `CLLocationManager+iBurn.m:14-20`: `desiredAccuracy = Best`, `activityType = CLActivityTypeFitness`,
  `distanceFilter = 10`.
- The delegate `locationManagerDidChangeAuthorization` (`BRCAppDelegate.m:303-313`) restarts updates or
  shows a "Location Services Unavailable" alert. `didUpdateLocations` (`BRCAppDelegate.m:315-321`) only
  latches the Burning Man region for the embargo (`enteredBurningManRegion`, `:265-288`). The comment at
  `:320` says "Breadcrumb tracking is handled by LocationStorage (GRDB-backed)".
- Permission request: `requestLocationPermission` (`BRCAppDelegate.m:343-346`) calls
  `requestWhenInUseAuthorization` only. Onboarding goes through `BRCPermissions.promptForLocation`
  (`iBurn/BRCPermissions.swift:16-27`, PermissionScope, `LocationWhileInUsePermission`) from
  `BRCOnboardingViewController.swift:21-22`.
- **`CoreLocationProvider`** (`iBurn/ListView/LocationProvider.swift:34-66`) wraps the app delegate's
  manager and **polls `locationManager.location` every 5 s** into an `AsyncStream`. It's fine for Nearby
  but wrong for track recording (it samples and loses fixes). `MockLocationProvider` at `:70-89`.
  Created in `DependencyContainer.swift:126-128`.
- **Watch**: `iBurnWatch/LocationService.swift:12-57` has its own `CLLocationManager`, WhenInUse, and
  foreground only.
- **Info.plist** (`iBurn/iBurn-Info.plist`):
  - `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationAlwaysUsageDescription` and
    `NSLocationWhenInUseUsageDescription` (`:61-66`) are all the same string: "iBurn only uses your
    location **within the app itself**…". This string becomes **false** once we record in the background
    and must be rewritten.
  - `NSMotionUsageDescription` = "iBurn does not use motion tracking." (`:69-70`). Keep it that way;
    this design doesn't need CoreMotion.
  - `UIBackgroundModes` (`:75-80`): `audio`, `fetch`, `remote-notification`, `processing`. **No
    `location`.**
- **Entitlements** (`iBurn/iBurn.entitlements`): `aps-environment` and associated domains only. Background
  location needs no entitlement, only the background mode.
- **Deployment targets**: iOS **16.6** at project level (`iBurn.xcodeproj/project.pbxproj:863,916`), and
  watchOS 26.0 (`:810,1022`). Packages declare `.iOS(.v16)`, `.macOS(.v13)`, `.watchOS(.v10)` (for
  example `Packages/PlayaDB/Package.swift:8-12`). `liveUpdates` and `CLBackgroundActivitySession` need
  iOS 17 and `CLServiceSession` needs iOS 18, so §4.5 recommends raising the minimum for 2027.

### 2.2 Prior art: there is already a "Tracks" feature (2019)

This matters: Live Tracks **replaces** it rather than starting from scratch.

- `iBurn/Tracks/LocationStorage.swift`: a singleton with its **own `CLLocationManager`** (`:46-48`) and its
  own GRDB `DatabaseQueue` at `Application Support/LocationHistory.sqlite` (`:29-31`), table
  `breadcrumb(id, latitude, longitude, timestamp)` (`:65-79`, migration `"createBreadcrumbs2"`). It
  **only records inside `BRCLocations.burningManRegion`** (`:85`, a 5-mile circle,
  `iBurn/BRCLocations.swift:18-23`). It is foreground only, since there is no background mode.
- It is started at launch by `[LocationStorage setup:nil]` (`BRCAppDelegate.m:144`) and gated by
  `UserDefaults.isLocationHistoryDisabled` (`iBurn/UserDefaults+iBurn.swift:19-26`), mirrored by
  `Preferences.Location.historyDisabled` (`iBurn/Preferences/Preferences.swift:59-63`, **default
  `false`**). So **it records by default today**, silently, whenever the app is open on playa.
- `iBurn/Tracks/TracksViewController.swift` is reached from More → "Location History"
  (`MoreViewController.swift:234,326,374-377`). It draws one red `MLNPolyline` annotation at 0.25 alpha
  plus a pin per breadcrumb (`:111-133`, `:156-170`). An action sheet offers Pause/Resume and a
  destructive "Clear History" confirmation (`:65-95`), which is a good precedent for the wipe UX.
- `Breadcrumb.swift` is a Codable GRDB record. `BRCBreadcrumbPoint.h/.m` is dead Mantle-era code.

### 2.3 Main map and MapLibre

- MapLibre pinned **exactVersion `6.18.0-patch0`** (`iBurn.xcodeproj/project.pbxproj:1153-1160`,
  `iBurn.xcworkspace/xcshareddata/swiftpm/Package.resolved:113-118`).
- I checked the shipped headers in DerivedData:
  - `MLNLineStyleLayer.lineGradient` exists. It accepts "interpolation and step functions applied to the
    `$lineProgress` variable" and **"does not support applying interpolation or step functions to feature
    attributes"**.
  - `lineOpacity` supports "interpolation and step functions applied to the `$zoomLevel` variable and/or
    **feature attributes**".
  - `MLNShapeSourceOptionLineDistanceMetrics` is the `lineMetrics` option.
  - `MLNShapeSourceOptionSimplificationTolerance` and `lineSortKey` exist.
- `MainMapViewController` (`iBurn/MainMapViewController.swift:19`) subclasses `BaseMapViewController`,
  which owns `mapViewAdapter` and `lazy var mapLayerManager` (`BaseMapViewController.swift:16-20`) and
  hooks `mapViewAdapter.onStyleLoaded` → `mapLayerManager.updateAllLayers()` (`:64-67`).
  `MapViewAdapter.mapView(_:didFinishLoading:)` calls `onStyleLoaded` (`MapViewAdapter.swift:161-163`).
- **Every style layer today comes from the style JSON.** There is no runtime `MLNShapeSource` or
  `MLNStyleLayer` insertion anywhere in the app (grep finds none). `MapLayerManager.swift:102-141` only
  toggles `isVisible` on the JSON's layers. Live Tracks would be the first runtime-added source.
- **The style reloads on light/dark changes** (`MLNMapView+iBurn.swift:41-49` → `brc_setDefaults` sets
  `styleURL`). That throws away any runtime sources and layers, so they must be re-added in
  `onStyleLoaded` every time.
- 2026 style layer order (`Submodules/iBurn-Data/data/2026/Map/Map.bundle/styles/iburn-{light,dark}.json`):
  `background` (#E8E0D8 light / #232323 dark), `dmz`, `dmz-name`, `toilets-outline` (#00AFD4), `fence`,
  `outline` (street fill, #C3B8AB / #574e26), `gate-road`, `airport-road`, `camp-boundaries`
  (#8B7BA6 / #9B8DB0), `camp-labels-big`, `streets` (label symbols), `airport-road-label`,
  `toilet-icon`, `points`, `man`.
- POI pins are **UIView annotations** (`MapViewAdapter.swift:204-240`), which always draw above all GL
  layers. So z-ordering only matters relative to the style's own layers.
- `BaseMapViewController` already reacts to Low Power Mode (`:70`, `:107-129`, the idle timer).
- Sidebar: `SidebarButtonsView` (`iBurn/SidebarButtonsView.swift:18-66`), a column of pin, bike and home
  buttons laid out at `MainMapViewController.swift:367-380`.

### 2.4 Map filter UI and settings

- `MapFilterView.swift`: `MapFilterViewModel` (`:22-141`) with `@Published` mirrors of `UserSettings`.
  It **stages** edits: Cancel discards, Done calls `saveSettings()` (`:238-250`), and a swipe-dismiss also
  saves (`:290-303`). Presented from `MainMapViewController.filterButtonPressed` (`:398-416`), whose
  `onFilterChanged` re-resolves the data source, layers and pins.
- `UserSettings.showActiveEventsOnMap` (`iBurn/UserSettings.swift:259-271`) shows the "nil → default
  true" `UserDefaults` pattern. The newer `Preferences`/`PreferenceService` (`iBurn/Preferences/*`)
  holds keyed, typed prefs with a factory (`PreferenceServiceFactory.shared`). Use that for new settings.

### 2.5 Persistence and packages

- `Packages/`: `PlayaAPI`, `PlayaColors`, `PlayaDB`, `PlayaGeo`, `PlayaSeed`, each its own
  `Package.swift` (no root package). They are wired into the app as `XCLocalSwiftPackageReference`
  (`project.pbxproj:1124-1140`). GRDB is `7.11.1` (`Package.resolved:70-74`,
  `Packages/PlayaDB/Package.swift:20`).
- PlayaDB uses a `DatabasePool` (WAL) on disk and a `DatabaseQueue` in memory for tests, with numbered
  migrations `v3…v7` (`PlayaDBImpl.swift:11-32`, `:302-368`). Its models are `Codable` +
  `FetchableRecord` + `MutablePersistableRecord` with a `Columns` enum (for example
  `Models/UserMapPin.swift:9-33`). TrackKit's records follow the same style.
- PlayaDB is **restored from a bundled seed** on fresh installs (`SeedRestore.swift`,
  `DependencyContainer.swift:115-117`) and is conceptually per-year. That's a lifecycle mismatch with
  multi-year personal tracks, hence a separate database file.

### 2.6 DI conventions

- CLAUDE.md: `protocol FooService` + `FooServiceImpl` + a factory that returns the protocol.
  Examples: `DataUpdateServiceFactory.makeService` and `EventCalendarServiceFactory.makeService`
  (`DependencyContainer.swift:48-51`, `:84-86`), and `EmbargoUnlockSchedulerFactory`.
- `DependencyContainer` is `@MainActor` with `lazy` services (`DependencyContainer.swift:16-91`).

### 2.7 Share and export patterns

- `UIActivityViewController` in `MoreViewController.swift:468`, `ShareQRCodeView.swift:184`,
  `Detail/Services/DetailActionCoordinator.swift:163,217`. There are no file exports yet, so GPX
  would be the first file-URL share.

### 2.8 Embargo

- Tiers live in `iBurn/EmbargoService.swift` over `PlayaDB/LocationEmbargo.swift`, with dates in
  `YearSettings` (`iBurn/YearSettings.swift:13-47`). The embargo hides **BMorg placement data** (camp and
  art locations). See §5.6 for why tracks don't interact with it.

### 2.9 Simulator location tooling

- `iBurnWatch/BlackRockCity.gpx` (a single `<wpt>` at the Man) is referenced by the **watch** scheme's
  `LocationScenarioReference` (`iBurnWatch.xcscheme:61-64`). The iBurn schemes use "current location".
- drive-app sets locations with `xcrun simctl location <UDID> set 40.7864,-119.2065`
  (`.claude/skills/drive-app/SKILL.md:37-38`).

---

## 3. Architecture

### 3.1 Replace, don't coexist

Retire `LocationStorage`, `Breadcrumb`, `TracksViewController`, `BRCBreadcrumbPoint.*` and the
`[LocationStorage setup:nil]` launch call. The More → "Location History" row becomes an entry point into
the new "Recording & Data" screen (or a day list, §7.6).

**Legacy data**: on first launch of the new build, if `LocationHistory.sqlite` exists, import its
breadcrumbs into TrackKit as a `legacy` source session (they have only lat, lon and time), then delete
the old file. That data was recorded by default without much consent, so the import is a good moment to
show it and offer the wipe (open question Q3).

### 3.2 Package: `Packages/TrackKit`

It's playa-agnostic: it never imports PlayaDB, PlayaGeo, `BRCLocations` or `YearSettings`.

```
Packages/TrackKit/
  Package.swift                 // products: TrackKit, TrackKitUI; dep: GRDB 7.11.1
  Sources/TrackKit/
    Model/        TrackPoint.swift, TrackSession.swift, TrackDay.swift, Fidelity.swift
    Storage/      TrackStore.swift (protocol), TrackStoreImpl.swift (GRDB), TrackMigrations.swift
    Recording/    LocationSource.swift (protocol), LiveUpdatesLocationSource.swift,
                  ManagerLocationSource.swift, TrackRecorder.swift (protocol + Impl),
                  FixFilter.swift, RecorderState.swift
    Authorization/ TrackAuthorization.swift (status + problems → CTA model)
    Geometry/     Simplifier.swift (Douglas–Peucker), LocalProjection.swift, DayBucketer.swift
    Styling/      TrackStyleModel.swift (renderer-agnostic segments), DayPalette.swift
    Export/       GPXWriter.swift, GPXReader.swift (for replay/tests)
    Replay/       GPXReplayLocationSource.swift, ScriptedLocationSource.swift
    TrackKitFactory.swift
  Sources/TrackKitUI/           // SwiftUI; no MapLibre, no MapKit
    TrackStatusRow.swift, TrackProblemCTA.swift, RecordingControls.swift,
    TrackSettingsForm.swift, WipeConfirmation.swift, GPXShareButton.swift
  Tests/TrackKitTests/          // runs with `swift test --package-path Packages/TrackKit`
  Demo/TrackKitDemo.xcodeproj   // standalone MapKit app (P5)
```

Platforms: `.iOS(.v17)`, `.macOS(.v14)` (tests run on the Mac host), `.watchOS(.v10)` (compiles, not
used yet). An app target at 16.6 **cannot link** a package that requires iOS 17, so either raise the
iBurn target (recommended) or declare `.iOS(.v16)` and `@available`-gate the recorder (see §4.5).

**MapLibre stays out of the package.** The pin is an exact version, and pulling MapLibre into a package
means two sources of truth. The package emits a `TrackStyleModel`. iBurn turns it into
`MLNShapeSource` features, and the demo turns it into MapKit `MapPolyline`s.

### 3.3 Core protocols (sketch)

```swift
// Location input: fakeable, replayable.
public protocol LocationSource: Sendable {
    /// Starts delivering fixes. Finishes when stopped. Also reports diagnostics (auth, stationary, …).
    func updates(config: RecordingConfig) -> AsyncStream<LocationEvent>
}
public enum LocationEvent: Sendable {
    case fix(CLLocation)
    case stationary(Bool)
    case diagnostic(TrackProblemSet)   // insufficient auth, reduced accuracy, services off, …
}

public protocol TrackStore: Sendable {
    func append(_ points: [TrackPoint], session: TrackSession.ID) async throws
    func beginSession(source: TrackSession.Source, at: Date) async throws -> TrackSession
    func endSession(_ id: TrackSession.ID, at: Date) async throws
    func days(boundary: DayBoundary, in tz: TimeZone) async throws -> [TrackDay]
    func points(in interval: DateInterval) async throws -> [TrackPoint]
    func pointCursor(in interval: DateInterval?, _ body: (TrackPoint) throws -> Void) throws   // GPX streaming
    func observeLatest() -> AsyncStream<TrackPoint>        // GRDB ValueObservation
    func deleteAll() async throws
    func deleteOlderThan(_ date: Date) async throws
}

@MainActor public protocol TrackRecorder: AnyObject {
    var state: RecorderState { get }                         // @Observable in the Impl
    var problems: TrackProblemSet { get }
    func setEnabled(_ enabled: Bool)                        // opt-in master switch
    func pause()
    func resume()
    func setFidelity(_ f: Fidelity)
    /// MUST be called from application(_:didFinishLaunchingWithOptions:), before it returns,
    /// so a background relaunch re-arms the session (§4.4).
    func restoreOnLaunch()
}

public enum RecorderState: Equatable { case off, needsPermission, recording(since: Date), paused(since: Date), degraded(TrackProblemSet) }

public enum TrackKitFactory {
    public static func makeStore(url: URL) throws -> TrackStore
    public static func makeRecorder(store: TrackStore, source: LocationSource? = nil,
                                    settings: TrackSettingsStore, now: @escaping @Sendable () -> Date = Date.init) -> TrackRecorder
}
```

`TrackSettingsStore` is a small protocol over UserDefaults (enabled, paused, fidelity, day boundary,
retention, display options). iBurn backs it with its `PreferenceService`, and the demo uses a plain
UserDefaults impl.

**Clock**: TrackKit takes `now` injected. iBurn must pass the **real clock** (`Date.init`), not
`Date.present`: GPS timestamps are real, so under the "iBurn (Mock Date)" scheme, "today" would
otherwise be empty.

### 3.4 iBurn integration layer (in `iBurn/Tracks/`)

- `TrackLayerController`: owns the two sources and three layers, builds MapLibre features from
  `TrackStyleModel`, and is re-applied in `onStyleLoaded`. It is created by `MainMapViewController`,
  or folded into `MapLayerManager.updateAllLayers()`.
- `LiveTracksFilterSection` (SwiftUI) embeds TrackKitUI views into `MapFilterView`.
- `DependencyContainer`: `lazy var trackRecorder: TrackRecorder` and `trackStore` via `TrackKitFactory`.
  Because of the launch-order requirement (§4.4), the recorder is actually constructed from
  `BRCAppDelegate` `didFinishLaunching`, **before** the heavy `DependencyContainer` work, and then handed
  to the container.
- `BRCTrackSettings: TrackSettingsStore` is backed by new `Preferences.Tracks.*` keys.
- The existing app-wide `CLLocationManager` and `CoreLocationProvider` are left alone. Nearby keeps
  polling. The recorder has its own source.

### 3.5 Standalone demo app

- `Packages/TrackKit/Demo/TrackKitDemo.xcodeproj` is a SwiftUI app with a local package reference to
  `..` (TrackKit). Bundle id `com.iburnapp.TrackKitDemo`, the same team, and
  `UIBackgroundModes: location`.
- One screen: a MapKit `Map` rendering the `TrackStyleModel` segments as `MapPolyline` with
  `.stroke(color.opacity(o), lineWidth:)`, `UserAnnotation()`, and a bottom sheet containing
  `TrackSettingsForm` (the same TrackKitUI views iBurn embeds), plus a "Replay GPX…" debug action.
- Why MapKit instead of MapLibre: at home you want a real street basemap with zero tile plumbing, and
  it keeps MapLibre out of the package. The cost is that the fade and colors are validated in MapKit,
  not MapLibre. The style *model* is shared, but the iBurn MapLibre rendering still needs its own
  on-device check.
- Kept out of `iBurn.xcworkspace` schemes, so iBurn CI doesn't build it. Optionally add a CI job later.
- Installed from Xcode to Chris's own phone. TestFlight isn't needed.

---

## 4. Location recording strategy (battery)

### 4.1 API comparison

| API | Min iOS | Background? | Battery | Playa suitability |
|---|---|---|---|---|
| `CLLocationManager.startUpdatingLocation` + `allowsBackgroundLocationUpdates` | 2 / 9 | Yes, with the `location` background mode | GPS always on unless `pausesLocationUpdatesAutomatically`, and **after an auto-pause the app is not resumed** until foregrounded (a classic pitfall), which needs region or significant-change hacks | Works, but you hand-roll stationary handling |
| `desiredAccuracy`, `distanceFilter`, `activityType` | – | – | `distanceFilter` doesn't save much GPS power by itself. It only reduces callbacks. `kCLLocationAccuracyHundredMeters` allows GPS duty-cycling | The only fine-grained knobs available; useful for "Low" |
| **`CLLocationUpdate.liveUpdates(_:)`** (`LiveConfiguration`: `.default`, `.fitness`, `.otherNavigation`, `.automotiveNavigation`, `.airborne`) | 17 | Yes, with `CLBackgroundActivitySession` or Always | **Automatic stationary detection**: it stops delivering and powers down, then resumes on movement, with the resume handled by the system. `isStationary` (17) and `stationary` (18) flags | **Best fit**: camp-sitting hours cost almost nothing, and biking resumes automatically |
| **`CLBackgroundActivitySession`** | 17 | Keeps a When-In-Use app eligible for background updates. Blue indicator | – | Lets us skip requiring Always |
| **`CLServiceSession(authorization: .whenInUse/.always, fullAccuracyPurposeKey:)`** + `diagnostics` | 18 | Declares need. The system prompts when the app is foregrounded | – | Gives the problem list for the CTA "for free" (§5.3) |
| Significant-change (`startMonitoringSignificantLocationChanges`) | 4 | Relaunches the app | Very low | **Poor on playa**: it's cell/Wi-Fi-driven, roughly 500 m, and there is little cell service. It is only useful as a relaunch safety net |
| Visits (`startMonitoringVisits`) | 8 | Relaunches | Very low | Coarse, arrival/departure only. Could annotate "stops" later, but not for lines |
| `CLMonitor` (region conditions) | 17 | Relaunches | Low | Useful for "auto-start when I arrive at BRC" (later) |

Unsure on the iOS 27 SDK: this doc was written against my knowledge of iOS 17 and 18 Core Location
(the `liveUpdates` configurations, `CLBackgroundActivitySession`, `CLServiceSession` and its
`Diagnostic` fields). I have **not** verified whether iOS 26 or 27 deprecate or rename any of these, or
add new background-location affordances. **Action for P2**: read the iOS 27 SDK `CoreLocation` headers
and release notes before implementing, and re-check the exact `CLUpdate` / `CLServiceSession.Diagnostic`
property names used in §5.3.

### 4.2 Recommendation

1. **Primary (iOS 17+)**: `LiveUpdatesLocationSource` uses
   `CLLocationUpdate.liveUpdates(.fitness)` (walking and biking, with no road snapping). The Low preset
   uses `.default`. It holds a `CLBackgroundActivitySession` while recording, and on iOS 18 a
   `CLServiceSession(authorization: .whenInUse)`, upgraded to `.always` when the user opts into the
   upgrade.
2. **Software downsampling** in `FixFilter` according to fidelity. `liveUpdates` doesn't expose
   `distanceFilter` or `desiredAccuracy`, so the preset controls what we **store** and how often we
   wake up the writer, while the stationary detection controls GPS power.
3. **Fallback (iOS 16, or if liveUpdates misbehaves)**: `ManagerLocationSource`, using
   `CLLocationManager` with `allowsBackgroundLocationUpdates = true`,
   `showsBackgroundLocationIndicator = true`, `activityType = .fitness`,
   `pausesLocationUpdatesAutomatically = false` (we do our own stationary handling via
   `distanceFilter`), with `desiredAccuracy` and `distanceFilter` per preset. Both conform to
   `LocationSource`, so the recorder doesn't care which one it has.

### 4.3 Fidelity presets (user-selectable, worth having)

Battery and density figures are **estimates to measure in P5**, not facts.

| Preset | Source config | Stored when… | Typical density (bike ~4.5 m/s, 10 mph) | Use |
|---|---|---|---|---|
| **Low** ("All-day, battery saver") | `liveUpdates(.default)`, or manager at `HundredMeters` / `distanceFilter 50` | moved ≥ 50 m **or** 5 min heartbeat; accuracy ≤ 100 m | ~1 point / 11 s | Multi-day with no battery pack |
| **Balanced** (default) | `liveUpdates(.fitness)` | moved ≥ 15 m or 60 s; accuracy ≤ 50 m | ~1 point / 3 s; walking ~1 / 11 s | Normal burn day |
| **High** ("GaiaGPS-like") | `liveUpdates(.fitness)`, or manager at `Best` / `distanceFilter 5` | moved ≥ 5 m or 30 s; accuracy ≤ 30 m | ~1 point / s | Short trips, art-car tours, when on a battery pack |

- **Low Power Mode**: automatically drop one preset while LPM is on (High → Balanced → Low), show it in
  the status row ("Low Power Mode: recording at Low"), and restore it when LPM ends
  (`NSProcessInfoPowerStateDidChange`, as `BaseMapViewController.swift:70` already observes).
- On-playa behavior:
  - GPS works with no cell service. Satellite-only first fixes can take longer, but the phone keeps
    ephemeris for hours.
  - Long camp-sitting stretches are the main battery win: liveUpdates goes stationary and the GPS
    powers down. The recorder writes one "stationary" heartbeat and nothing else.
  - Bikes at 10 mph are well within every preset.
  - Art cars at 5 mph are fine.
  - Flights out of the airport (Burner Express Air) are about 50+ m/s. The implied-speed filter
    (§4.6) allows up to about 90 m/s, so those legs are kept. That's a feature: they show up as a
    straight line.
- **24h+ constraint**: expect roughly **2–5 %/h** of battery with GPS actively moving, and near zero when
  stationary. A typical burn day (about 6 h moving) should cost about 15–30 % at Balanced. It's fine
  with a pack, and borderline without one if combined with heavy map use. The fidelity picker and
  the LPM downgrade exist for this reason. **Validate** with the demo app over a real Bay Area day in P5.

### 4.4 Lifecycle and relaunch

- Recording begins only from a foreground user action (enable or resume). That's what
  `CLBackgroundActivitySession` requires.
- **Backgrounded**: updates continue, with the blue pill for When-In-Use. Writes go to GRDB in batches
  (flush every 20 points, every 30 s, or on `didEnterBackground`/`willTerminate`). A crash loses at
  most about 30 s.
- **Terminated by the system** while a background activity session or an Always liveUpdates stream was
  active: per WWDC23 ("Discover streamlined location updates"), the app is relaunched in the
  background and must **re-create the session and restart the `liveUpdates` loop immediately in
  `didFinishLaunching`**. Verify this on iOS 27. Hence `TrackRecorder.restoreOnLaunch()` is called from
  `BRCAppDelegate` `application:didFinishLaunchingWithOptions:`.
- **Risk: heavy launch path.** A background relaunch runs the full `didFinishLaunching`, and
  `DependencyContainer.init` kicks off seed restore, JSON seeding and **image downloads**
  (`DependencyContainer.swift:115-140`). Guard the non-essential work with
  `applicationState == .background` (or defer it until `didBecomeActive`) when relaunched for location.
  This needs an audit in P2.
- **Force-quit by the user**: recording stops (When-In-Use), and I believe Always + liveUpdates also
  isn't relaunched after a user force-quit. Verify. On next launch, if recording was enabled and not
  paused, auto-resume and show a one-line note: "Recording stopped while iBurn was closed (9:14–11:02)."
  The gap shows as a segment break.
- **Optional safety net (Always only)**: also start significant-change monitoring and/or a `CLMonitor`
  circular condition around the last point. Either can relaunch us, which lets us re-arm liveUpdates.
  It's cheap but weak on playa. Decide in P2 after testing.
- **iOS nags**: with Always, iOS periodically asks the user "iBurn has used your location in the
  background N times…". That's expected, and the copy (§5.4) should prepare the user for it.

### 4.5 Deployment target

- The iBurn app is at 16.6. For a 2027 feature, when iOS 27 ships, **raise it to iOS 17** at
  minimum: liveUpdates, `CLBackgroundActivitySession` and `CLMonitor` all need 17.
- **Better: raise it to 18**, which gets `CLServiceSession` diagnostics and removes the manager fallback
  from the hot path. The watch is already at watchOS 26.
- Open question Q1. If the target stays at 16.6, TrackKit declares `.iOS(.v16)` and the recorder
  `@available`-gates, with `ManagerLocationSource` as the 16.x path.

### 4.6 Fix filtering (`FixFilter`, pure, unit-tested)

Each rule drops the fix when:

1. `horizontalAccuracy < 0` (invalid) or `> preset.maxAccuracy`.
2. `abs(location.timestamp.timeIntervalSince(now)) > 30 s` (a cached or stale fix delivered late).
3. `timestamp <= lastKept.timestamp` (out of order or duplicate).
4. Implied speed from the last kept fix is `> 90 m/s` **and** the new accuracy is worse than 20 m.
   That's a jump or teleport. Planes pass with good accuracy.
5. Distance to the last kept fix is `< max(preset.minDistance, horizontalAccuracy)` **and** less than
   `preset.heartbeat` has elapsed (jitter while standing still).

**Segment breaks** (a new `TrackSession` or segment, drawn as a line break, `<trkseg>` in GPX) happen on:
pause/resume, app relaunch, or a gap of more than 10 min **and** more than 200 m. The last case stops a
dead phone from drawing a straight line across the city.

---

## 5. Permissions and privacy

### 5.1 Authorization flow

1. **Opt-in** from the filter sheet or the "Recording & Data" page: toggle "Record my tracks" → an
   explainer sheet (copy in §5.4) → "Start recording".
2. If `notDetermined`, request When In Use. Onboarding already does this, so most users are already
   there.
3. Start the recorder: a `CLBackgroundActivitySession` plus liveUpdates. This works in the background
   with When-In-Use.
4. **After the first successful background session** (for example the next foreground), the status row
   offers "Keep recording even if iBurn is closed → Allow Always". That calls
   `requestAlwaysAuthorization()` (iOS shows the upgrade prompt once) or, on 18+, creates
   `CLServiceSession(authorization: .always)`. If it's declined, fall back to Settings.
5. **Precise location off** (`accuracyAuthorization == .reducedAccuracy`): call
   `requestTemporaryFullAccuracyAuthorization(withPurposeKey: "LiveTracks")` (needs
   `NSLocationTemporaryUsageDescriptionDictionary`), or on 18+ `CLServiceSession(…,
   fullAccuracyPurposeKey:)`. The persistent fix is Settings. Reduced accuracy (~5 km fuzz) makes tracks
   useless, so it's shown as a blocker.

### 5.2 Info.plist changes (implementation, not this spike)

- `UIBackgroundModes`: add **`location`**. It is app-wide, but it only takes effect for managers or
  sessions that opt in. The app delegate's manager keeps `allowsBackgroundLocationUpdates = NO` by
  default and is still suspended in the background.
- Rewrite the three `NSLocation*UsageDescription` strings (`iBurn-Info.plist:61-66`). The current
  "only within the app itself" becomes untrue. Proposed:
  - WhenInUse: "iBurn uses your location to show where you are on the map and what's near you. If you
    turn on Live Tracks, it also records where you go. That data stays on your iPhone."
  - Always / AlwaysAndWhenInUse: "With Live Tracks turned on, Always lets iBurn keep recording your
    route even after iBurn is closed or your iPhone restarts. Your tracks stay on your iPhone unless
    you export them."
- Add `NSLocationTemporaryUsageDescriptionDictionary` → `LiveTracks`: "Precise location is needed to
  draw an accurate track of where you've been."
- Leave `NSMotionUsageDescription` as is.
- Optional (iOS 18): `NSLocationRequireExplicitServiceSession` makes all location use go through
  explicit sessions. **Don't** set it. It would affect the existing Nearby/map managers.

### 5.3 Problem detection → CTA model (`TrackProblemSet`, an OptionSet, pure)

| Problem | Detect | Severity | CTA |
|---|---|---|---|
| Location Services off globally | `CLLocationManager.locationServicesEnabled()` false / diagnostic `authorizationDeniedGlobally` | Blocker | Text: "Turn on Location Services in Settings → Privacy & Security." (No public deep link to that pane.) |
| Denied / restricted | `authorizationStatus` / `authorizationDenied`, `authorizationRestricted` | Blocker | "Open Settings" → `UIApplication.openSettingsURLString` |
| Not yet asked | `.notDetermined` | Blocker | "Allow Location" → request |
| Reduced accuracy | `accuracyAuthorization == .reducedAccuracy` / `fullAccuracyDenied` | Blocker | "Turn on Precise" → temporary full accuracy, else Settings |
| When-In-Use only | status `authorizedWhenInUse` / `alwaysAuthorizationDenied` / `insufficientlyInUse` | Warning | "Allow Always (recommended)" → request, else Settings |
| Background App Refresh off | `UIApplication.shared.backgroundRefreshStatus != .available` | Warning* | "Open Settings" |
| Low Power Mode | `ProcessInfo.isLowPowerModeEnabled` | Info | "Recording at Low while Low Power Mode is on." (No public deep link, and `App-prefs:` URLs are private and get rejected.) |
| Paused by user | recorder state | Info | "Resume" |

\*Unsure: continuous location updates started in the foreground do not, as far as I know, depend on
Background App Refresh. BAR does gate **relaunches** (significant-change and region), and users
conflate the two. Keep it as a warning worded "may stop recording after iBurn is closed", and verify in
P2.

The diagnostic names above come from `CLServiceSession.Diagnostic` (iOS 18). Verify them against the
iOS 27 SDK. On iOS 17, derive the same set from `CLLocationManager` properties.

### 5.4 Opt-in UX copy (explainer sheet)

> **Live Tracks**
> Draw where you've been on the map, one color per day, like a travel journal of your burn.
>
> - **Stays on your iPhone.** Nothing is uploaded. You can export a GPX file or delete everything at any
>   time.
> - **Uses battery.** Recording in the background uses GPS. It's about as costly as a hiking app. Pick
>   "Battery Saver" if you don't carry a battery pack.
> - **You'll see a blue location indicator** while iBurn records in the background.
>
> [Start Recording]   [Not Now]

### 5.5 "Recording" indicators

- **System**: the blue pill or Dynamic Island location indicator (When-In-Use + background session).
  With Always, set `showsBackgroundLocationIndicator = true` on the manager path. For liveUpdates, the
  background activity session shows it. Being transparent here is good for trust and for App Review.
- **In-app**: a sidebar button with a red dot while recording and a pause glyph while paused (§7.3),
  plus the status row in the filter sheet.
- **Later**: a Live Activity ("Recording · 3.2 mi today · since 9:14"). It's the GaiaGPS-like lock
  screen affordance.

### 5.6 Data retention, backup and embargo

- **Retention setting**: Keep until I delete them (default) / 30 days / 90 days / 1 year. Prune at
  launch and on `didBecomeActive`. The default is "keep" because the whole point is a memory log of the
  burn.
- **Wipe**: a destructive two-step confirmation (§7.4). It deletes all rows, runs `VACUUM`, and removes
  exported temp GPX files.
- **File protection**: the database must be writable **while the phone is locked in a pocket**, so use
  `.completeUntilFirstUserAuthentication` (the iOS default). **Not** `.complete`, or background writes
  fail. Keep the database in the app's own container, **not** an App Group container: holding SQLite
  locks in a shared container while suspended is the classic `0xdead10cc` termination.
- **Backup**: open question Q4. The default proposal is to include it in device backups (it's
  personal memory and backups are encrypted), with an optional "Exclude from backups" toggle that sets
  `isExcludedFromBackup`.
- **Embargo**: showing your *own* track reveals nothing BMorg-embargoed:
  - The embargo covers placement data: camp and art coordinates and camp polygons.
  - The basemap streets are already shown pre-embargo.
  - A track only shows where *you* physically were.
  - TrackKit never touches `BRCEmbargo`/`EmbargoService`, and tracks are not gated.
  - Exported GPX contains only your own points.
  - One subtle point: don't *label* track points with the nearest camp name (the old
    `TracksViewController` reverse-geocoded to street addresses only, which is fine). If "stops" ever get
    named with camp names, that feature must go through `BRCEmbargo.canShowLocation(for:)`.
- **"Record only near Black Rock City"** (iBurn-only option, open question Q5): reuse
  `BRCLocations.burningManRegion` as a filter (the old `LocationStorage.swift:85` behavior). Later, a
  `CLMonitor` condition could auto-start recording on arrival. The demo app has no such filter.

### 5.7 App Store review

- Guideline 2.5.4: background location must serve a clear user-facing feature. Live Tracks is exactly
  that. Expect review to ask for a **demo video** showing opt-in, background recording and the
  indicator. Prepare it at submission, and note it in the review notes: "Live Tracks is opt-in from the
  Map filter. Records a GPS track in the background while enabled. Data never leaves the device."
- 5.1.1 / 5.1.2: purpose strings must be accurate (hence the rewrite). No tracking or analytics on
  location data. Keep Crashlytics breadcrumbs free of coordinates.
- Historically, Apple suggested a "continued use of GPS in the background can decrease battery life"
  disclaimer in the app description. It's cheap to add to the App Store description.
- Adding `location` to background modes on an app that previously lacked it has, in past review
  cycles, triggered extra questions. Budget a rejection round-trip before the event (see Risks).

---

## 6. Storage schema and geometry

### 6.1 Database

A separate file: `Application Support/Tracks/Tracks.sqlite`. GRDB `DatabasePool` (WAL), with
`DatabaseQueue(":memory:")` for tests, the same pattern as `PlayaDBImpl.swift:11-32`. It's separate from
PlayaDB because PlayaDB is seed-restored and yearly, while tracks are multi-year personal data. It is
also separate from the old `LocationHistory.sqlite`, which is imported and then removed.

```swift
migrator.registerMigration("v1-tracks") { db in
    try db.create(table: "track_session") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("started_at", .double).notNull()        // unix seconds (UTC)
        t.column("ended_at", .double)                     // null while open
        t.column("source", .text).notNull()               // "live" | "legacy" | "replay" | "import"
        t.column("fidelity", .text).notNull()
    }
    try db.create(table: "track_point") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("session_id", .integer).notNull()
            .references("track_session", onDelete: .cascade)
        t.column("t", .double).notNull()                  // CLLocation.timestamp, unix seconds UTC
        t.column("lat", .double).notNull()
        t.column("lon", .double).notNull()
        t.column("h_acc", .double).notNull()              // meters
        t.column("alt", .double)                          // null if verticalAccuracy < 0
        t.column("v_acc", .double)
        t.column("speed", .double)                        // null if < 0
        t.column("course", .double)                       // null if < 0
        t.column("flags", .integer).notNull().defaults(to: 0)  // bit0: segment start, bit1: stationary heartbeat
    }
    try db.create(index: "track_point_on_t", on: "track_point", columns: ["t"])
    try db.create(index: "track_point_on_session_t", on: "track_point", columns: ["session_id", "t"])
}
```

- Timestamps are stored as `Double` (unix seconds) rather than GRDB's default `Date` text, for compact
  and fast range queries. `TrackPoint` maps them itself.
- No `day` column: days are derived at read time (§6.2), so changing the day boundary or timezone
  re-buckets everything without a migration.

### 6.2 Day bucketing (`DayBucketer`, pure)

```swift
public struct DayBoundary: Codable, Equatable { public var hour: Int; public var minute: Int }  // iBurn default 06:00, demo 00:00

/// The "day" a timestamp belongs to: the calendar date of (t − boundary) in `timeZone`.
public func dayKey(for t: Date, boundary: DayBoundary, calendar: Calendar /* .timeZone set */) -> DateComponents {
    let shifted = t.addingTimeInterval(-TimeInterval(boundary.hour * 3600 + boundary.minute * 60))
    return calendar.dateComponents([.year, .month, .day], from: shifted)
}
public func interval(for day: DateComponents, boundary: DayBoundary, calendar: Calendar) -> DateInterval
// start = calendar.date(from: day) + boundary; end = next day's start (DST-safe via calendar.date(byAdding:.day))
```

- **Timezone**: use `TimeZone.current` at read time. At the burn it's Pacific, like the Bay Area. If a
  user later views a burn track from another timezone, bucketing shifts. That's acceptable. The
  alternative (a `tz` column per session) is cheap and can be added if needed (Q6). GPX always uses UTC
  `Z` times, so it's unaffected.
- **Why a 06:00 default at the burn**: a night out that ends at 4 am belongs to "Tuesday night", not
  Wednesday. The setting lets you pick 00:00–08:00.
- The day list is `SELECT min(t), max(t) FROM track_point`, then the days in between are enumerated in
  Swift, with a per-day `EXISTS` / count query (indexed by `t`).

### 6.3 Simplification: store raw, simplify on read

- Raw filtered fixes are small (§6.4). Lossy writes can't be undone, and GPX export should be full
  fidelity.
- **On read (rendering)**: iterative, stack-based (no recursion) Douglas–Peucker in a local
  equirectangular projection (`x = Δlon·cos(lat0)·R`, `y = Δlat·R`, which is accurate to well under 1 m
  at city scale). Tolerance is about 2 m for today and about 4 m for past days. Visvalingam gives
  slightly nicer shapes, but DP is simpler, O(n log n) typical, and fine here.
- **Past days are immutable**, so cache their simplified geometry (in memory keyed by day,
  boundary and tolerance, optionally persisted). Only today is re-simplified, incrementally: only the
  last open slice (§6.5) is re-simplified.
- MapLibre's GeoJSON-VT also simplifies per tile (`MLNShapeSourceOptionSimplificationTolerance`,
  default 0.375). Ours is a pre-pass that bounds upload size.

### 6.4 Size estimates

A row is about 90–110 bytes including SQLite overhead and two indexes. Assuming about 6 h moving per day
at the burn:

| Preset | Points/day | Week (8 days) | DB size | GPX size (week, ~130 B/pt) |
|---|---|---|---|---|
| Low | ~2,000 | ~16k | ~2 MB | ~2 MB |
| Balanced | ~6,000–8,000 | ~60k | ~6 MB | ~8 MB |
| High | ~20,000 | ~160k | ~16 MB | ~21 MB |

Trivial on disk. Rendering cost is what matters, hence the simplification and the today/past split.

### 6.5 Style model (renderer-agnostic, in TrackKit)

```swift
public struct TrackStyleModel: Sendable {
    public struct Segment: Sendable {
        public var coordinates: [CLLocationCoordinate2D]
        public var dayKey: String          // "2027-08-31"
        public var dayIndex: Int           // palette index, stable per date
        public var isToday: Bool
        public var tStart: Double          // unix seconds of first point (drives today's fade)
        public var tEnd: Double
    }
    public var today: [Segment]            // time-sliced: ≤ 15-min slices, split at segment breaks
    public var past: [Segment]             // one per session-segment per day (no slicing needed)
}
```

`TrackStyleBuilder.build(store:, visibleDays:, boundary:, now:)` produces it. Consecutive slices
share their boundary point so the line is continuous.

---

## 7. Rendering (MapLibre, iBurn)

### 7.1 Sources and layers

- `tracks-past`: `MLNShapeSource` with all past-day segments as `MLNPolylineFeature`s with attributes
  `day` (palette index). It is rebuilt only when the day rolls over, the visible-day setting changes,
  data is wiped or imported, or the style reloads.
- `tracks-today`: an `MLNShapeSource` of today's slices with attributes `day`, `t` (slice midpoint).
  Its `shape` is re-set on new points, **throttled to at most every 10 s while the map is visible, and
  never while backgrounded**. `TrackStore.observeLatest()` drives it. On foreground it gets one catch-up
  rebuild.
- Layers, all `MLNLineStyleLayer`, inserted **above `camp-boundaries` and below `camp-labels-big`** with
  `style.insertLayer(_:below: style.layer(withIdentifier: "camp-labels-big"))`, falling back to
  `below: "streets"` and then to `addLayer`. That keeps camp and street names readable on top of the
  tracks. Pins (UIView annotations) and the user puck are always above.
  1. `tracks-past-line`: `lineColor = match(day → palette)`, `lineOpacity = pastOpacity` (setting,
     default **0.25**), `lineWidth = interpolate(zoom, 12: 1.5, 18: 3.5)`.
  2. `tracks-today-casing` (optional, P3 polish): width +2, color = map background, opacity = the same
     fade expression × 0.6. It lifts the line off busy street fills.
  3. `tracks-today-line`: `lineColor = match(day)`, `lineWidth = interpolate(zoom, 12: 2.5, 18: 6)`,
     `lineOpacity` = fade (§7.2), `lineCap = butt`, `lineJoin = round`.
- **Re-add on every style load**: in `onStyleLoaded` (`BaseMapViewController.swift:64-67`) call
  `trackLayerController.install(on: style)`. It's idempotent: if the source exists, it re-sets the
  shape. Light/dark reloads the style (`MLNMapView+iBurn.swift:41-49`) and passes the dark palette.
- Visibility: `layer.isVisible = settings.showTracks && !days.isEmpty`, applied from
  `MapLayerManager.updateAllLayers()` next to `updateCampLayerVisibility()`.

### 7.2 Today's fade: two options

**Option A: `line-gradient` + `lineMetrics`** (one feature per today segment, one gradient per layer).

- ✅ Smooth per-pixel fade with no slice seams.
- ❌ `$lineProgress` is **fraction of distance**, not time. If you sit at camp for 5 h and then bike for
  20 min, the fade follows the bike ride's length, not the clock. It can be worked around by
  generating gradient stops from a time→distance map on every update.
- ❌ One gradient per layer, and it **can't use feature attributes** (confirmed in the 6.18
  `MLNLineStyleLayer.h` docs). So all of today's segments share one gradient, and a multi-segment day
  would need one source and layer per segment.
- ❌ Requires re-uploading the source on every tick for the fade to move.
- ❓ **Alpha in gradients**: the style spec's colors are RGBA and GL JS honors alpha in `line-gradient`.
  I *expect* native 6.18 to as well (the gradient is an RGBA texture), but I didn't verify it. It needs
  a 30-minute prototype, and there are reports of premultiplied-alpha banding at low alpha.
- ❌ The gradient texture has limited resolution (~256 px), which bands on long lines.

**Option B: time-sliced segments with data-driven `lineOpacity`** ✅ **Recommended**

- Today is split into ≤ 15-min slices (and at segment breaks). Each feature carries `t`.
- `lineOpacity = interpolate(linear, get("t"), dayStart, minTodayOpacity(0.35), now, 1.0)`. The fade
  lives entirely in the **layer expression**. Updating "now" each minute is a cheap property set: **no
  GeoJSON re-upload** just to advance the fade.
- Per-feature colors work in the same layer (`match(get("day"))`), so past days and today use one
  code path.
- It's time-true: sitting still for hours produces no slices, and the fade tracks the clock.
- ❌ Seams: adjacent semi-transparent slices overlap at shared vertices, so a faint darker dot appears at
  each join. Mitigations: `lineCap = butt` and 15-min slices (so only a few dozen joins per day). The
  opacity step between neighboring slices is under 2%, so joins are barely visible. Self-crossings
  also darken, since there's no layer-level compositing in GL. That's acceptable and arguably
  informative ("I went here twice").

Sketch:

```swift
func fadeExpression(dayStart: Date, now: Date, minOpacity: Double) -> NSExpression {
    NSExpression(mglJSONObject: ["interpolate", ["linear"], ["get", "t"],
        dayStart.timeIntervalSince1970, minOpacity,
        max(now.timeIntervalSince1970, dayStart.timeIntervalSince1970 + 1), 1.0])   // stops must increase
}
// once a minute while visible:
todayLayer.lineOpacity = fadeExpression(dayStart: today.start, now: Date(), minOpacity: 0.35)
```

(The name of the JSON-to-NSExpression initializer on MapLibre iOS is `NSExpression(mglJSONObject:)`.
Verify it against the 6.18 headers. Alternatively use the `NSExpression(format: "mgl_interpolate:…")`
form.)

Option A stays a possible P3 polish for *today only* if Option B's seams look bad on device.

### 7.3 Day palette (`DayPalette` in TrackKit, with light and dark variants)

- The color is assigned by `dayIndex = daysSince(referenceDate) mod 7`, where the reference date is the
  first recorded day. Colors are stable per date, so the legend, day list, GPX names and map always
  agree.
- The palette must avoid the basemap and style colors: tans (#E8E0D8, #D9CCBE, #C3B8AB / dark #574e26),
  camp-boundary purple (#8B7BA6 / #9B8DB0), toilet cyan (#00AFD4), and label greys and cream.

| # | Light basemap | Dark basemap |
|---|---|---|
| 0 | #D62839 red | #FF5C6C |
| 1 | #1D6FD1 blue | #5AA9FF |
| 2 | #1E9E4A green | #52D67A |
| 3 | #E36A00 orange | #FFA23A |
| 4 | #C2187A magenta | #FF5DB8 |
| 5 | #00897B teal | #3FD6C4 |
| 6 | #8A5A00 umber | #F2D14B yellow |

- These are proposals. **Validate on device in bright sun** (in P5/P3 with screenshots) and against
  deuteranopia. Color isn't the only signal: the day list and legend name the days, and a tap on a line
  could show "Tue Aug 31" later.
- PlayaColors (`Packages/PlayaColors`) extracts colors from images, which doesn't fit here. The
  palette stays in TrackKit so the demo shares it. The iBurn theme (`Appearance.currentColors`) could
  override slot 0 ("today") if a branded look is wanted (Q7).

### 7.4 Performance guardrails

- Today at High: about 20k raw points → about 2–4k after DP → about 60 slice features. Past days: 7
  features of about 2k points each. This is well within GeoJSON-VT's comfort zone.
- Build the style model off the main actor (actor or `Task.detached`) and hop to main only for
  `source.shape = …`.
- Nothing touches MapLibre in the background (MapLibre tears down GL state and throws
  `MLNUnderlyingMapUnavailableException`, see the `MLNMapView+iBurn.swift:36-39` comment).

---

## 8. UI

### 8.1 Map filter sheet: new "Live Tracks" section

`MapFilterView` stages edits (Done/Cancel, and swipe saves). **Display options follow that model.
Recording controls must not**, because Cancel can't un-record or un-wipe. So:

```
Map Filter
├─ Show on Map … (existing)
├─ Nearby Card … (existing)
├─ ── Live Tracks ─────────────────────────────  (new section, below "Show on Map")
│   [Status row]  ● Recording · 3.2 mi today · Balanced         ← live, not staged
│   [CTA row, only if problems]  ⚠ Allow "Always" so recording survives closing iBurn  [Fix]
│   Toggle  Show Tracks on Map                         (staged)
│   Picker  Days: Today · Today + Yesterday · Last 3 Days · All Days   (staged)
│   Slider  Past Days Opacity   ○────●──── 25%          (staged, only if Days ≠ Today)
│   NavigationLink  Recording, Export & Data  ›        (pushes 8.2; immediate)
│   footer: "Tracks stay on this iPhone."
├─ Camp Display … (existing)
└─ …
```

If the feature has never been enabled, the section collapses to one row: "Record Your Tracks…" ›,
which opens the explainer (§5.4).

### 8.2 "Recording, Export & Data" (pushed; every control applies immediately)

```
Recording
  Toggle  Record My Tracks                 (master opt-in; first enable → explainer)
  Button  Pause Recording / Resume Recording
  Picker  Fidelity: Battery Saver · Balanced · High Detail
          footer: estimated battery impact per preset; "Low Power Mode lowers this automatically."
  Picker  New day starts at: 12 AM … 6 AM … 8 AM   (iBurn default 6 AM)
  Toggle  Only record near Black Rock City   (iBurn only, Q5)

Permissions  (only rows that apply; each with its CTA, see §5.3)
  ✓ Location: Always      /  ⚠ While Using → [Allow Always]
  ✓ Precise Location      /  ⛔ Approximate → [Turn On]
  ⚠ Background App Refresh off → [Open Settings]
  ℹ Low Power Mode on

Export
  Button  Export All Days (GPX)               → share sheet
  Row     Export a Day…  › (list of days with distance and duration → share)

Data
  Picker  Keep Tracks: Until I Delete Them · 30 Days · 90 Days · 1 Year
  Toggle  Include in iPhone Backups (Q4)
  Button (destructive)  Delete All Tracks…
```

This is all TrackKitUI (`TrackSettingsForm`) except the "near Black Rock City" row, which iBurn
injects through a `@ViewBuilder extraRecordingRows` slot. The same form appears in the demo app. The
More → "Location History" row pushes this page too.

### 8.3 Map quick control (sidebar)

- Add a 4th circular button to `SidebarButtonsView`, shown only when the feature is enabled:
  - Recording: `record.circle` with a pulsing red fill (the pulse respects Reduce Motion).
  - Paused: `pause.circle`.
  - Degraded: `exclamationmark.triangle`, amber.
- **Tap** toggles pause/resume, with a haptic and a toast ("Tracks paused" / "Recording").
- **Long-press** opens a `UIMenu` with Pause/Resume, "Show Today Only" / "Show All Days", and "Tracks
  Settings…" (opens §8.2).
- Degraded tap opens §8.2 scrolled to Permissions.
- `SidebarButtonsView.columnHeight` (`MainMapViewController.swift:378`) must grow. Check that the column
  doesn't collide with the FAB or bottom accessory on small phones. Alternatively put it in the
  navigation bar's left items next to Filter (`MainMapViewController.swift:390-396`).
- VoiceOver labels: "Live Tracks, recording. Double-tap to pause."

**Pause semantics**: pause stops the location stream (it saves battery) and closes the session. Resume
opens a new session. P1–P4 offer indefinite pause only. "Pause for 1 hour" is later work: it can't
auto-resume in the background once the stream is stopped, so it would need a local notification
("Tap to resume recording").

### 8.4 Destructive wipe

Copy the existing `TracksViewController.swift:74-89` pattern, in SwiftUI:
`.confirmationDialog("Delete all tracks?", role: .destructive)` → message "This permanently deletes
N days of tracks (X points) from this iPhone. Export a GPX first if you want to keep them." with the
buttons **Export First…**, **Delete All Tracks** (destructive) and Cancel. For stronger protection,
the destructive button is disabled for 1 s. Deleting removes the rows, runs VACUUM, rebuilds the map
sources, and **does not** turn recording off (the dialog footer says so).

### 8.5 GPX share

A SwiftUI `ShareLink(item: GPXFile(days:), preview: …)` where `GPXFile: Transferable` has a
`FileRepresentation(exportedContentType: .gpx)` that writes lazily to `FileManager.temporaryDirectory`.
Declare the `UTType` `com.topografix.gpx` via an exported or imported type declaration, or use
`UTType(filenameExtension: "gpx")`. From UIKit contexts (the sidebar menu), use
`UIActivityViewController(activityItems: [fileURL])` like `DetailActionCoordinator.swift:163`. Filename:
`iBurn-Tracks-2027-08-31.gpx` or `iBurn-Tracks-2027-08-29_to_2027-09-06.gpx`. Delete temp files on
completion.

---

## 9. GPX export

### 9.1 Structure (GPX 1.1)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="iBurn Live Tracks"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v2"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata><name>iBurn Tracks</name><time>2027-09-07T18:00:00Z</time></metadata>
  <trk>
    <name>Tue, Aug 31, 2027</name>           <!-- one trk per bucketed day -->
    <type>burn-day</type>
    <trkseg>                                  <!-- one per session / segment break -->
      <trkpt lat="40.7864210" lon="-119.2065330">
        <ele>1191.4</ele>
        <time>2027-08-31T16:02:11Z</time>
        <extensions><gpxtpx:TrackPointExtension>
          <gpxtpx:speed>4.52</gpxtpx:speed><gpxtpx:course>187.0</gpxtpx:course>
        </gpxtpx:TrackPointExtension></extensions>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
```

- Times are UTC ISO 8601 with a `Z` suffix. Coordinates use 7 decimals (about 1 cm).
- `ele` is written only if `v_acc ≥ 0`. `extensions` are written only if speed or course is present.
- There's no GPX field for horizontal accuracy (`hdop` is not the same thing), so it's omitted.
  Optionally write it to a private `ib:` extension.
- GaiaGPS, Strava, Google Earth and Garmin all import this.

### 9.2 Streaming writer

```swift
public struct GPXWriter {
    public init(output: OutputStream, creator: String)
    public mutating func begin(metadataName: String, time: Date) throws
    public mutating func beginTrack(name: String, type: String?) throws
    public mutating func beginSegment() throws
    public mutating func point(_ p: TrackPoint) throws       // buffered; flush every 64 KB
    public mutating func endSegment() throws
    public mutating func endTrack() throws
    public mutating func finish() throws
}
```

- It iterates `TrackStore.pointCursor(in:)` (a GRDB `Row.fetchCursor` inside `dbPool.read`), so 160k
  points never sit in memory. Day and segment boundaries are detected while streaming (the
  `session_id` changes, or a `flags` segment-start bit, or the day key changes).
- Numbers are formatted with locale-independent code (`String(format: "%.7f")` uses the POSIX locale,
  or hand-rolled), **never `NumberFormatter` with the current locale**, which would write German
  decimal commas.
- `ISO8601DateFormatter` is created once. XML-escape `&<>"'` in names.

### 9.3 Tests (GPXWriterTests)

- A golden file: 2 days × 2 segments → byte-exact expected XML.
- Round trip: write → `GPXReader` (XMLParser) → the same points within 1e-7°. Days map to `trk` and
  segments to `trkseg`.
- Escaping: a track name with `&` or `<`.
- Locale: run under `de_DE`, where decimals must still be `.`.
- Optional fields: no ele or speed → no elements.
- Empty export: a valid document with zero `trk`.
- Streaming: 200k synthetic points under N MB peak (a loose `measure`), and it completes.
- Day boundary: points at 05:59 and 06:01 local with a 06:00 boundary land in different `trk`s.

---

## 10. Testability

### 10.1 Seams

- `LocationSource` (protocol): `ScriptedLocationSource` (an array of `LocationEvent`s with virtual
  time), `GPXReplayLocationSource(url:, speedMultiplier:)` (it reads `<trkpt time>`, re-times the
  points to "now", and yields them at `Δt / multiplier`), plus the two real sources.
- `TrackStore` has an in-memory GRDB implementation for tests.
- `TrackSettingsStore` has an in-memory fake.
- `now: () -> Date` is injected everywhere (bucketing, fade, retention, the filter's staleness check).
- `AuthorizationProvider` (protocol) wraps status, accuracy, BAR and LPM so `TrackProblemSet`
  derivation is pure and testable.
- `TrackRecorderImpl` is `@MainActor` and `@Observable`. Tests drive it with the scripted source and
  assert on state and store contents.

### 10.2 Unit tests to write (`Packages/TrackKit/Tests/TrackKitTests`)

| Suite | Cases |
|---|---|
| `FixFilterTests` | rejects negative or over-threshold accuracy; stale timestamps; out-of-order; teleport with bad accuracy; keeps a plane leg with good accuracy; stationary jitter suppressed; heartbeat after N seconds; per-preset thresholds |
| `SegmentBreakTests` | pause/resume → new session; gap > 10 min and > 200 m → break; gap > 10 min but < 20 m → no break |
| `DayBucketerTests` | 06:00 boundary; midnight boundary; DST spring-forward and fall-back days (intervals of 23 h and 25 h); a timezone change; the day list over sparse data |
| `SimplifierTests` | straight line → 2 points; tolerance respected (max deviation ≤ tol); 100k points without stack overflow; closed loop; duplicate points |
| `TrackStoreTests` | migrations; append and fetch by interval; cascade delete; `deleteAll`; retention prune; the cursor streams in order; legacy `breadcrumb` import |
| `TrackStyleBuilderTests` | slices ≤ 15 min; slices share boundary points; segment breaks split slices; past vs today assignment around the boundary; palette index stable per date; visible-day setting |
| `TrackProblemSetTests` | each auth, accuracy, BAR and LPM combination → the expected problems and severity ordering |
| `TrackRecorderTests` | enable → recording; pause stops the source; resume starts a new session; LPM downgrades fidelity; restoreOnLaunch re-arms only if enabled and not paused; batching flushes on background notification |
| `GPXWriterTests` | §9.3 |

In the iBurn target (`iBurnTests`): `TrackLayerController` builds the expected features and attributes
from a model (pure mapping, no GL), `fadeExpression` stop ordering, and the settings bridge. Use
`XCTUnwrap` rather than force unwraps (per user feedback memory).

### 10.3 Simulator and drive-app

- **Fixture**: add `iBurn/Tracks/Fixtures/PlayaBikeLoop.gpx`, a timed `<wpt>` sequence (Xcode GPX
  location scenarios interpolate between `<wpt>`s using their `<time>`) looping Center Camp → 9:00 →
  the Man → the Temple → 3:00 at about 4.5 m/s. Optionally add a scheme `LocationScenarioReference` in a
  test-only scheme (the watch scheme already does this: `iBurnWatch.xcscheme:61-64`).
- **simctl** (no Xcode attached):
  `xcrun simctl location <UDID> start --speed=4.5 40.7866,-119.2166 40.7790,-119.2120 40.7832,-119.2079`.
  Or use the built-in scenarios (`xcrun simctl location <UDID> run …`, the "City Bicycle Ride" style
  presets, which are useful off-playa). Check the `simctl location` help on the current Xcode for exact
  flags.
- **Background test in Simulator**: start recording, go to the Home screen, let the route run, return,
  and assert the line grew and the row count rose (`sqlite3 "$APP_DATA/Library/Application
  Support/Tracks/Tracks.sqlite" "select count(*) from track_point"`, following drive-app's database
  verification steps, with the sandbox disabled for simctl and sqlite).
- **In-app debug replay**: a Feature Flags entry (`iBurn/Preferences/FeatureFlagsView.swift`) for
  "Replay GPX into Live Tracks at 20×", using `GPXReplayLocationSource`. It exercises the full pipeline
  without moving the simulator location, and the demo app has the same thing.
- **drive-app `flows.md`**: the implementation PR must add a "Live Tracks" flow (enable → explainer →
  permission → record → pause → export → wipe), per CLAUDE.md's flows rule. It isn't added in this
  spike.
- **Real-device validation** (P5, demo app): a full Bay Area day per fidelity preset. Record the battery
  % per hour moving and stationary, point counts, and gaps after the app is backgrounded or killed. This
  is the evidence for the battery figures in §4.3.

---

## 11. Phased implementation plan

| Phase | Scope | Rough size |
|---|---|---|
| **P1: package, storage, foreground** | `Packages/TrackKit` scaffold; schema and migrations; `FixFilter`; `DayBucketer`; `Simplifier`; `TrackStoreImpl`; `LiveUpdatesLocationSource` (foreground only); `TrackRecorderImpl` (enable, pause, resume); legacy `LocationHistory.sqlite` import; remove `LocationStorage` launch call; a basic `TrackLayerController` (a single color and opacity) installed in `onStyleLoaded`; unit tests | 4–5 days |
| **P2: background and permissions** | `UIBackgroundModes: location`; `CLBackgroundActivitySession`; `CLServiceSession` + diagnostics (iOS 18) or manager-derived problems; `TrackProblemSet` + `TrackStatusRow` / `TrackProblemCTA`; Always upgrade and temporary full accuracy; `restoreOnLaunch` in `BRCAppDelegate`; background relaunch launch-path audit (`DependencyContainer` downloads); Info.plist copy rewrite; LPM downgrade; deployment-target decision | 4–5 days, plus device testing |
| **P3: styling and filter UI** | `DayPalette`; time slices plus the fade expression; past vs today layers and z-order; per-minute fade tick; light and dark; filter-sheet section; "Recording, Export & Data" page (TrackKitUI `TrackSettingsForm`); sidebar record/pause button + menu; explainer sheet | 4 days |
| **P4: GPX, wipe, retention** | `GPXWriter`/`GPXReader` + tests; `ShareLink`/UIActivity export (all days, a single day, a day list); wipe dialog; retention prune; backup toggle; More → Location History reroute | 2–3 days |
| **P5: standalone demo** | `TrackKitDemo.xcodeproj` (MapKit rendering of `TrackStyleModel`, the same TrackKitUI form, GPX replay); Bay Area battery and fidelity study; tune presets and palette | 2 days, plus a week of real use |
| **Later** | Watch: show today's simplified line on `PlayaMapView` (`Packages/PlayaGeo/Sources/PlayaGeo/PlayaMapView.swift`) via the existing WatchConnectivity sync; no watch recording. Live Activity. Timed pause with a notification. `CLMonitor` auto-start at BRC. Tap a line → day and time callout. "Stops" from Visits. Import GPX (for example old GaiaGPS burns) | – |

Total is about 3–3.5 weeks of focused work, plus real-world validation. **Suggested order tweak**: build
the P5 demo shell right after P2. It's the cheapest way to live with background recording at home
for a couple of weeks before touching iBurn's UI.

---

## 12. Context Preservation

### 12.1 Decisions and rationale

- **Separate DB file, not PlayaDB**: PlayaDB is seed-restored and yearly (`SeedRestore.swift`,
  `DependencyContainer.swift:115-117`). Tracks are personal, multi-year data, and they're also reused
  by the demo app, which has no PlayaDB.
- **GRDB, not plist or Mantle**: per the user's standing preference (the memory note "Prefer GRDB/Codable
  over Mantle"). Yap and Mantle are gone.
- **Store raw, simplify on read**: data is small, export needs full fidelity, and lossy writes are
  irreversible.
- **Option B rendering over `line-gradient`**: the headers confirm `lineGradient` can't use feature
  attributes and is distance-based. Data-driven `lineOpacity` over feature attributes is confirmed
  supported in 6.18.
- **When-In-Use first, Always optional**: `CLBackgroundActivitySession` makes WIU sufficient for the
  core use case (start recording in the morning, pocket the phone). Requiring Always up front hurts
  opt-in and review.
- **MapKit in the demo**: it gives a home basemap without tile plumbing and keeps MapLibre's exact pin
  out of the package.
- **Recording controls are immediate, display options staged**: `MapFilterView`'s Done/Cancel model
  (`:238-250`) can't meaningfully cancel recording or a wipe.
- **Real clock, not `Date.present`**: GPS timestamps are real, and a mock date would hide today's track.

### 12.2 Things verified vs. not verified

- Verified in the repo:
  - every file:line citation above;
  - the MapLibre 6.18.0-patch0 header semantics for `lineGradient`, `lineOpacity`,
    `MLNShapeSourceOptionLineDistanceMetrics` and `lineSortKey`;
  - the 2026 style layer ids and colors;
  - the deployment targets.
- **Not verified**:
  - iOS 27 SDK Core Location changes;
  - exact `CLServiceSession.Diagnostic` and `CLUpdate` property names;
  - relaunch semantics after termination and force-quit with liveUpdates;
  - whether Background App Refresh affects continuous updates;
  - alpha support in native `line-gradient`;
  - the `NSExpression(mglJSONObject:)` spelling;
  - the battery percentages;
  - the exact `simctl location` flags on the current Xcode.

### 12.3 Risks

1. **App Review** pushback on the new background location mode. Mitigate with a demo video, accurate
   purpose strings and opt-in only. Submit a build with the feature well before the event (by early July
   2027).
2. **Battery**, which can be worse than estimated on older phones or in heat. Mitigate with presets,
   the LPM downgrade, stationary detection and P5 measurement.
3. **Background relaunch** running the full heavy launch path (seed restore, downloads). This needs the
   P2 audit.
4. **iOS killing the app** despite the session, especially under memory pressure with MapLibre
   resident. Mitigate with batch flushes, segment-break UX, and the optional Always + significant-change
   safety net.
5. **MapLibre** seams in Option B, and the first runtime-added source in the app (style reload
   handling). Mitigate with the idempotent `install(on:)` and a device check in light and dark.
6. **Privacy perception**: the legacy default-on breadcrumb recorder is replaced with explicit opt-in.
   Handle the migration messaging carefully (Q3).
7. **Deployment target**: staying at 16.6 doubles the recorder code paths.

### 12.4 Open questions for Chris

- **Q1**: Raise the iBurn deployment target to iOS 17, or ideally 18, for the 2027 release?
- **Q2**: Package name `TrackKit`, OK? (Alternatives: `Breadcrumbs`, `PlayaTracks`. The latter isn't
  playa-agnostic.)
- **Q3**: Legacy breadcrumbs (recorded by default since 2019, foreground only, BRC-only): import them
  into Live Tracks and show them, import them silently, or delete them? And should users who had the
  old recorder on be pre-opted in? (Recommendation: import, don't pre-opt-in, and show a one-time "We
  found your 2026 location history" card.)
- **Q4**: Include tracks in iCloud and device backups by default?
- **Q5**: iBurn-only "Only record near Black Rock City" option: default on or off?
- **Q6**: Is timezone-at-read-time acceptable, or store a `tz` per session?
- **Q7**: Should today use a fixed brand or hero color, with only past days rotating through the
  palette?
- **Q8**: Sidebar button vs. navigation-bar item for pause/resume. Is the sidebar column tall enough on
  small phones?
- **Q9**: Is a Live Activity for recording worth pulling into P3 for GaiaGPS parity?
- **Q10**: Should the demo app ever ship (App Store or TestFlight), or stay sideload-only?

---

## 13. Cross-References

- Prior art: `iBurn/Tracks/LocationStorage.swift`, `iBurn/Tracks/Breadcrumb.swift`,
  `iBurn/Tracks/TracksViewController.swift`, `iBurn/MoreViewController.swift:374-377`.
- Location: `iBurn/BRCAppDelegate.m:103-108,144,294-346`, `iBurn/CLLocationManager+iBurn.m:14-20`,
  `iBurn/ListView/LocationProvider.swift`, `iBurn/BRCPermissions.swift`, `iBurn/BRCLocations.swift:18-23`,
  `iBurn/iBurn-Info.plist:61-80`, `iBurn/iBurn.entitlements`.
- Map: `iBurn/MainMapViewController.swift`, `iBurn/BaseMapViewController.swift:16-129`,
  `iBurn/MapViewAdapter.swift:33,161-163`, `iBurn/MapLayerManager.swift`, `iBurn/MLNMapView+iBurn.swift`,
  `iBurn/SidebarButtonsView.swift`, the 2026 styles in `Submodules/iBurn-Data/data/2026/Map/Map.bundle/styles/`.
- Filter and settings: `iBurn/MapFilterView.swift`, `iBurn/UserSettings.swift:259-271`,
  `iBurn/Preferences/Preferences.swift:59-63`, `iBurn/UserDefaults+iBurn.swift:19-26`.
- DI: `iBurn/DependencyContainer.swift`. Packages: `Packages/PlayaDB/Package.swift`,
  `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`.
- Watch: `iBurnWatch/LocationService.swift`, `iBurnWatch/BlackRockCity.gpx`,
  `Packages/PlayaGeo/Sources/PlayaGeo/PlayaMapView.swift`.
- Related docs: `Docs/2026-09-12-yap-removal-and-playa-bug-fixes.md` (Yap and Mantle removal;
  post-event backlog), `Docs/2026-08-28-maplibre-voiceover-crash-and-boundary-passcode.md` (MapLibre
  pin context), `Docs/2026-08-16-camp-boundary-embargo-tier.md` and
  `Docs/2026-08-22-camp-tier-date-only-unlock.md` (embargo tiers),
  `Docs/2026-07-12-watch-browse-and-visit-status.md` (watch sync).
- Skill: `.claude/skills/drive-app/SKILL.md`, `.claude/skills/drive-app/references/flows.md` (add a
  Live Tracks flow at implementation time).

---

## 14. Expected Outcomes (when implemented)

- A user can opt in from the Map filter, see an honest explainer, grant When-In-Use (and optionally
  Always), and pocket the phone. The track keeps recording in the background with the system
  indicator showing.
- The main map shows today's route in the day's color, fading from about 35% opacity at the start of the
  day to 100% at "now". Earlier days show at about 25% in their own colors. Day selection, fading and
  light/dark all survive style reloads.
- Permission problems (denied, approximate, When-In-Use only, BAR off, LPM) show as specific status
  rows with a one-tap fix where iOS allows it.
- Pause/resume is one tap on the map. Wipe is behind a destructive confirmation that offers export first.
- GPX export of one day or all days opens in GaiaGPS and Strava, with a `trk` per day and a `trkseg`
  per session.
- `swift test --package-path Packages/TrackKit` covers filtering, bucketing, simplification,
  storage, styling, problem derivation, the recorder and GPX.
- The TrackKit Demo app records and displays tracks in the Bay Area on a MapKit basemap using the same
  package and settings UI, and produces the battery data that tunes the presets.
