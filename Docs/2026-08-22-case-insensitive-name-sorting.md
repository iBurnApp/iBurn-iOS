# 2026-08-22 — Case-insensitive name sorting for browse lists

## High-Level Plan

**Problem.** The Art, Camps, and Mutant Vehicles lists sorted case-sensitively: every
capitalized name came first, then every lowercase one ("Zebra" before "apple"). Users
reading an alphabetical list see this as two interleaved alphabets.

**Root cause.** `orderedByName()` emitted `ORDER BY name ASC`, which SQLite resolves with
the default BINARY collation — a UTF-8 code-point comparison, where `A`–`Z` (0x41–0x5A)
all precede `a`–`z` (0x61–0x7A). `PlayaDBImpl.artRequest` / `campRequest` /
`mutantVehicleRequest` all end in `orderedByName()` and feed the SwiftUI lists with no
further sorting.

**Fix.** Collate with GRDB's built-in `localizedStandardCompare` — the Finder-style
comparison: case- and diacritic-insensitive, and numeric-aware so "Camp 2" precedes
"Camp 10". This matches `GlobalSearchViewModel.sortedByName`
(`iBurn/ListView/GlobalSearchViewModel.swift:383-391`), so browse lists and search
results now agree. A secondary `uid ASC` keeps equal-comparing names stably ordered.

## Technical Details

### `Packages/PlayaDB/Sources/PlayaDB/QueryExtensions/QueryInterfaceRequest+DataObject.swift`

```swift
public func orderedByName() -> Self {
    order(
        Self.columns.name.collating(.localizedStandardCompare).asc,
        Self.columns.uid.asc
    )
}
```

Collation availability was verified against the vendored GRDB: `DatabaseCollation`
declares `localizedStandardCompare`
(`GRDB/Core/Support/StandardLibrary/StandardLibrary.swift:926`) and `Database.setUp`
registers it on **every** connection GRDB opens (`GRDB/Core/Database.swift:597`). That
matters because the shipped DB is restored from the pre-baked `PlayaDB-<year>.zip` seed —
collations are per-connection, not stored in the file, so a seeded DB sorts correctly too.

Trade-off: the `name` indexes are BINARY-collated and cannot serve this ORDER BY, so
SQLite sorts in memory. Result sets are a few thousand rows; nothing in `QueryPlanTests`
asserted an index for this ORDER BY (its only index assertions are on
`event_occurrences`), and the full suite still passes.

### `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`

The unfiltered `fetchArt()`, `fetchCamps()`, and `fetchMutantVehicles()` were returning
`X.fetchAll(db)` in arbitrary rowid order. They now route through `orderedByName()` so the
whole API is consistently ordered. (Their only app caller is `iBurnWatch/BrowseScreen.swift`,
which already re-sorts in memory at `iBurnWatch/ObjectListScreen.swift:97` — that stays,
harmlessly redundant.)

### Consistency fixes in the app target

- `iBurn/BRCDataSorter.swift:91-92` — `camps.sort { $0.title < $1.title }` →
  `localizedStandardCompare($1.title) == .orderedAscending` (same for `art`).
- `iBurn/UserMapViewAdapter.swift:78` — user-pin annotation titles, same change.

### Skipped: `iBurn/BRCDatabaseManager.m`

`+sorting` (line ~609/615) still uses `[data1.title compare:data2.title]`. It is the shared
sort block for several Yap views registered with hardcoded version tags (`@"7"` at line
630, `@"2"` at line 299, `@"7"` at line 480). Changing a Yap view's sort block requires
bumping every one of those tags to force a re-sort, which triggers a full view rebuild on
upgrade. Given Yap's default surfaces are already retired (only bridges/boot-import remain
on Yap), the churn is not worth it. Left as-is deliberately.

## Tests

New `Packages/PlayaDB/Tests/PlayaDBTests/NameOrderingTests.swift` inserts
`["cherry", "Zebra", "apple", "Banana"]` — an order whose BINARY sort
(`Banana, Zebra, apple, cherry`) differs from the expected `apple, Banana, cherry, Zebra` —
and asserts the expected order for:

- `fetchArt()`, `fetchCamps()`, `fetchMutantVehicles()`
- `fetchArt(filter:)`, `fetchCamps(filter:)`, `fetchMutantVehicles(filter:)` (what the
  SwiftUI lists actually observe)
- numeric awareness: `["Camp 10", "Camp 2", "camp 1"]` → `camp 1, Camp 2, Camp 10`
- the `uid` tiebreaker for identical names

## Expected Outcomes

- `swift test --package-path Packages/PlayaDB` → 345 passed, 0 failed.
- `xcodebuild -scheme iBurn` → success; `xcodebuild -scheme iBurnWatch` → success.
- Art / Camps / Mutant Vehicles browse lists read as a single alphabet, matching search.

---

## CALayerInvalidGeometry crash when placing a user map pin (2026.0 build 109)

### Crash trace (summary)

```
Fatal Exception: CALayerInvalidGeometry
CA::Layer::set_position(CA::Vec2<double> const&, bool)
-[UIView setCenter:]                      (MapLibre annotation view placement)
MapViewAdapter.addAnnotations(_:)          MapViewAdapter.swift:138
UserMapViewAdapter.editMapPoint(_:)        UserMapViewAdapter.swift:243
MainMapViewController.addUserMapPoint(type:)  MainMapViewController.swift:490
closure placePinAction in setupUserGuide() MainMapViewController.swift:465
```

A NaN coordinate reached MapLibre, which projects an annotation coordinate straight into
a `CALayer.position`.

### Root cause

`addUserMapPoint` places the pin at
`BRCLocations.userMapPointCoordinate(forUserLocation:viewportCenter:)`, whose off-playa
fallback is `MLNMapView.centerCoordinate`. `centerCoordinate` unprojects the center of the
map's bounds, and a map whose bounds are still degenerate (zero-sized / mid-transition at
the moment the FAB is tapped) answers NaN. Nothing downstream rejected it:

* `BRCLocations.userMapPointCoordinate` validated only the GPS branch.
* `BRCMapPoint.coordinate` guarded with `_latitude == 0 || _longitude == 0` — NaN passes,
  because every comparison against NaN is false.
* `MapViewAdapter.addAnnotations` handed everything to `mapView.addAnnotations`.

### Fix — defense in depth

`iBurn/BRCLocations.swift`: new shared predicate plus a validated fallback.

```swift
@objc static func isUsable(_ coordinate: CLLocationCoordinate2D) -> Bool {
    coordinate.latitude.isFinite
        && coordinate.longitude.isFinite
        && CLLocationCoordinate2DIsValid(coordinate)
}
// …userMapPointCoordinate off-playa branch:
return isUsable(viewportCenter) ? viewportCenter : blackRockCityCenter
```

`iBurn/MainMapViewController.swift` (`addUserMapPoint`): refuses to build the pin at all.

```swift
guard BRCLocations.isUsable(coordinate) else {
    DDLogWarn("Refusing to place a user map point at an invalid coordinate: \(coordinate)")
    return
}
```

`iBurn/MapViewAdapter.swift` (`addAnnotations`): unusable coordinates are filtered *before*
`registry.add`, so the registry never claims a key for a pin the map isn't drawing (which
would otherwise lock the good copy of that pin out forever). The overlap-offset loop —
which divides by `cos(latitude)` — also skips non-finite `originalCoordinate`s.

`iBurn/BRCMapPoint.m` (`coordinate` getter): keeps the existing "either component is 0 means
unset" semantics and adds an `isfinite` + `CLLocationCoordinate2DIsValid` check, so the
model itself can never publish a NaN.

### Tests

`iBurnTests/InvalidCoordinateGuardTests.swift` (new, 11 tests): `isUsable`; NaN viewport →
Man, NaN viewport still loses to an on-playa fix, usable viewport unchanged; `BRCMapPoint`
built from NaN → invalid coordinate and nil `location()`; adapter drops the invalid
annotation, keeps a valid sibling, leaves `registry.count` consistent, and still accepts a
later good copy of a rejected pin.

```
xcodebuild -scheme iBurn …                       → success, 0 errors
xcodebuild test -scheme iBurnTests \
  -only-testing:…/InvalidCoordinateGuardTests …  → 42 passed (1.239s)
```

---

# Crash: "A transaction has been left opened at the end of a database access" (GRDB bump 7.6.1 → 7.11.1)

## High-Level Plan

**Problem.** Production crash in build 2026.0 (110), crashed thread `GRDB.DatabasePool.reader.6`:

```
0 libswiftCore _assertionFailure
1 $defer #1 in closure #1 in closure #1 in SerializedDatabase.execute<A>(_:) (Utils.swift:41)
2 closure #1 in closure #1 in SerializedDatabase.execute<A>(_:) (SerializedDatabase.swift:265)
4 DispatchQueueActor.execute<A>(_:) (DispatchQueueActor.swift:19)
5 closure #1 in SerializedDatabase.execute<A>(_:) (SerializedDatabase.swift:257)
```

The fatal message is `preconditionNoUnsafeTransactionLeft` — "A transaction has been left
opened at the end of a database access". The app has no manual transactions; the culprit is
Task cancellation of async GRDB accesses (search type-ahead, list reloads, nearby
recomputes cancel in-flight Tasks constantly).

**Root cause: two GRDB bugs, both fixed upstream after the 7.6.1 we shipped.**

**Fix.** Bump GRDB 7.6.1 → 7.11.1 everywhere it is pinned. No app-level workaround needed.

## Mechanism (GRDB 7.6.1 source)

`SerializedDatabase.execute(_:) async` (SerializedDatabase.swift:252-270) — the frame in the
crash log:

```swift
return try await withTaskCancellationHandler {
    try await actor.execute {
        defer {
            cancelMutex.store(nil)
            db.uncancel()
            preconditionNoUnsafeTransactionLeft(db)   // ← fatalError if isInsideTransaction
        }
        cancelMutex.store(db.cancel)
        try Task.checkCancellation()
        return try block(db)
    }
} onCancel: {
    cancelMutex.withLock { $0?() }                    // → Database.cancel() → sqlite3_interrupt
}
```

`Database.cancel` (Database.swift:1231-1253) sets `suspension.isCancelled` and calls
`sqlite3_interrupt(sqliteConnection)`.

`DatabasePool.read(_:) async` in 7.6.1 (DatabasePool.swift:354-372):

```swift
try await reader.execute { db in
   defer {
       // Ignore commit error, but make sure we leave the transaction
       try? db.commit()
       assert(!db.isInsideTransaction)     // compiled out in Release
   }
   try db.beginTransaction(.deferred)
   try db.clearSchemaCacheIfNeeded()
   return try value(db)
}
```

So: if `commit()` throws, the deferred transaction stays open, the `assert` is stripped in a
Release build, and the outer `preconditionNoUnsafeTransactionLeft` fires — exactly the crash
stack. Two independent ways for that COMMIT (or a ROLLBACK) to throw after a cancellation:

1. **No ROLLBACK fallback (fixed in 7.7.0).** `try? db.commit()` is the only attempt. GRDB's
   own cancellation check does exempt COMMIT on read-only connections —
   `checkForSuspensionViolation` (Database.swift:1332): `if statement.transactionEffect ==
   .commitTransaction && isReadOnly { return }`, added by #1797 for 7.6.1 — but that does not
   stop SQLite itself: `onCancel` runs concurrently with the reader queue, so
   `sqlite3_interrupt` can land while the COMMIT statement is being prepared/stepped and
   return `SQLITE_INTERRUPT`. 7.7.0 replaced the defer with commit-else-rollback
   (upstream commit `4cfa692dd`, "Fix race condition regarding Task cancellation", shipped in
   7.7.0 as "Fix another race condition regarding Task cancellation, completing #1797"):

   ```swift
   do { try db.commit() } catch { try? db.rollback() }
   ```

2. **Sticky interrupted state from FTS5 (fixed in 7.9.0, PR #1839 / issue #1838).** FTS5
   leaks prepared statements (<https://sqlite.org/forum/forumpost/137c7662b3>), which keeps
   the connection interrupted *after* the interrupted statement ends — so even the
   COMMIT/ROLLBACK that is supposed to close the transaction fails with `SQLITE_INTERRUPT`.
   The app is a heavy FTS5 user (search runs `MATCH` at SQL, imports write the `*_fts`
   tables through triggers). 7.9.0's fix wraps `rollback()` and `endReadOnly()` in
   `ignoringInterruption`, which resets every prepared statement on the connection and
   retries:

   ```swift
   func ignoringInterruption<T>(_ value: () throws -> T) rethrows -> T {
       do { return try value() }
       catch is CancellationError, DatabaseError.SQLITE_INTERRUPT, DatabaseError.SQLITE_ABORT {
           resetAllPreparedStatements()   // sqlite3_next_stmt + sqlite3_reset loop
           return try value()
       }
   }
   ```

## Upstream status

| Version | Relevant change |
|---|---|
| 7.6.1 (shipped in build 110) | #1797 first cancellation race fix — not enough |
| 7.7.0 | "Fix another race condition regarding Task cancellation, completing #1797" — adds the ROLLBACK fallback in `DatabasePool.read` |
| 7.9.0 | #1839 (issue #1838) "Fix cancellation of async tasks that use the FTS5 full-text engine" — transaction may not roll back on cancellation; read-only mode may not be left; FTS5 sticky-interrupt workaround. **Raises requirements to Swift 6.1+ / Xcode 16.3+** (we are on Xcode 26 — fine) |
| 7.11.1 (June 18, 2026) | current release; what we now pin |

Issue #1838 reports the identical message: `GRDB/SerializedDatabase.swift:261: Fatal error: A
transaction has been left opened at the end of a database access`.

## Changes

* `Packages/PlayaDB/Package.swift` — `.upToNextMajor(from: "7.6.1")` → `"7.11.1"`
* `Packages/PlayaDB/Package.resolved` — 7.6.1 / `8ba1bc9a` → 7.11.1 / `b83108d1`
* `iBurn.xcodeproj/project.pbxproj` — `XCRemoteSwiftPackageReference "GRDB.swift"`
  `minimumVersion` 7.6.1 → 7.11.1
* `iBurn.xcworkspace/xcshareddata/swiftpm/Package.resolved` and
  `iBurn.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — repinned to 7.11.1
* `Packages/PlayaSeed/Package.resolved` already resolved 7.11.1 (it pins GRDB transitively
  through the PlayaDB path dependency); PlayaAPI/PlayaColors/PlayaGeo do not depend on GRDB.
* `Packages/PlayaDB/Tests/PlayaDBTests/TaskCancellationTransactionTests.swift` (new)

No app-level mitigation was added. A `Task {}`-based "shielded read" wrapper around
`dbQueue.read` was considered and rejected: unstructured `Task {}` does not inherit
cancellation, so it would make every read uninterruptible (wasted work on every abandoned
search keystroke) while only papering over a library bug that is fixed upstream.
`Configuration.allowsUnsafeTransactions` was also rejected outright — it merely silences the
precondition, and a pool reader returned to the pool *still inside* a deferred read
transaction would hold a stale snapshot and keep WAL frames alive for every later borrower of
that connection.

## Reproduction

`Packages/PlayaDB/Tests/PlayaDBTests/TaskCancellationTransactionTests.swift` opens a real
on-disk `PlayaDBImpl` (so a `DatabasePool`, not the in-memory `DatabaseQueue`) and cancels
async accesses:

* `testCancellingWriteThatTouchedFTS5DoesNotLeaveTransactionOpen` — the write first UPDATEs
  `art_objects` (whose triggers write `art_objects_fts`, leaking the FTS5 statements), signals
  from inside the transaction, then burns time in a recursive CTE; the test cancels the Task at
  that signal. **On GRDB 7.6.1 this reproduced the production fatalError deterministically on
  the first iteration:**

  ```
  GRDB/SerializedDatabase.swift:261: Fatal error: A transaction has been left opened at the end of a database access
  error: Process '…/xctest …' exited with unexpected signal code 5
  ```

  On 7.11.1 it passes.
* `testCancellingReadsLeavesPoolUsable` — 200 cancelled reader Tasks at a deterministic
  spread of delays through an FTS5 `MATCH` + slow scan. This did **not** reproduce the crash on
  7.6.1 on its own (the reader-side COMMIT race is far narrower than the FTS5 write case, and
  host macOS SQLite may not leak on FTS5 reads), but it is fast and deterministic, so it stays
  as a smoke test of the cancelled-read path.

A regression here does not fail the test — it kills the test process with a fatalError.

## Verification

```
swift test --package-path Packages/PlayaDB                     → 349 passed, 0 failed
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn …        → success, 0 errors, 0 warnings
xcodebuild -workspace iBurn.xcworkspace -scheme iBurnWatch …   → success, 0 errors, 0 warnings
```

---

# API data refresh (Aug 22)

Routine BMorg API refresh of the 2026 bundles, plus a placement regression fix.

## Commands

```bash
cd Submodules/iBurn-Data/scripts/BlackRockCityPlanner
node src/cli/fetch_and_geocode.js -y 2026 -l ../../data/2026/layouts/layout.json \
  -o ../../data/2026/APIData/APIData.bundle      # BMORG_API_KEY from the environment

cd ../..                                          # Submodules/iBurn-Data
node scripts/apply_placement.js --year 2026       # restores footprint-centroid camp pins

cd ../..                                          # repo root
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
```

## Count deltas (Aug 19 `7295d21` → Aug 22 `85101b8`)

| | Aug 19 | Aug 22 |
|---|---|---|
| art | 332 | 331 |
| art at GPS 0,0 (known upstream test rows) | 20 | 20 |
| camps | 1185 | 1184 |
| camps with GPS | 1178 | 1177 |
| events (records) | 2884 | 2876 |
| event occurrences | 5791 | 5778 |
| mutant vehicles | 492 | 493 |
| `camp_outlines`/`camp_labels` features | 1178 | 1175 |

Every feed has unique uids (art 331/331, camps 1184/1184, events 2876/2876, mv 493/493);
no null-island camps; no `MOCK_LOCATIONS` sentinel.

## Placement regression fixed

The Aug 19 refresh ran `fetch_and_geocode.js` **without** the mandatory follow-up
`apply_placement.js`, so all camp pins had been sitting on the address geocoder's
street-intersection points rather than their footprint centroids (verified: 0 of 1176
camps in the Aug 19 snapshot matched their own `camp_labels.geojson` geometry).
Re-applying placement here restores that: 1175 camps from polygon centroid, 2 from the
address geocode, 7 without GPS, 9 with no geometry at all. All 1175 placed camps now
match their label feature exactly (1e-9). Outlines/labels drop 1178 → 1175 features
because three camps left the API roster. `camp.json: unchanged` on an idempotent re-run.
31 API-vs-drop field conflicts, all resolved API-wins; 0 placement fields filled.

## Seed + validation

`playa-seed --fetch-media` downloaded 1 new thumbnail
(`data/2026/MediaFiles/MediaFiles.bundle/a6BVI000000Gent2AC.jpg`, committed in the
submodule) and rewrote both zips at 3155 KB (was 3124 KB): 331 art, 1184 camps, 5778
occurrences, 493 MVs, 1574 thumbnail colours, no warnings.

```
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn …            → success, 0 errors, 0 warnings
swift test --package-path Packages/PlayaDB --filter ReimportUpgradeTests → 7 passed
```

## Commits (not pushed)

* `Submodules/iBurn-Data` `85101b8` — "2026 API refresh (Aug 22) + placement re-applied"
* `Submodules/iBurn-Data` `aeea85a` — "2026 media: fetch 1 thumbnail new in the Aug 22 API data"
* app repo `3708788` — submodule pointer bump
