# 2026-07-11 — SwiftUI lists default ON (YapDB list migration complete)

**Branch:** `2026-updates`
**Related:** `2026-07-07-architecture-analysis-and-roadmap.md` (this executes its §3.2 decision
early, per Chris), `2026-01-25-playadb-migration-next-steps.md`, `2026-02-28-event-list-migration.md`

## High-Level Plan

Chris's direction: *"finish our yapdb migration and default on for SwiftUI lists. The network
updater can wait."* Explicitly descoped: PlayaDB network/OTA ingestion (accepted: PlayaDB stays
bundle-seeded this season) and any Yap→GRDB user-data migration (2026 is a fresh year —
`iBurn-2026.sqlite` starts empty, nobody has this year's version installed; a migrator was built
and then **removed** on that basis).

Work executed with parallel Fable subagents (flag flip / adult gating / favorite sync /
parity audit), integrated, built, tested, and sim-verified end-to-end.

### What shipped

1. **`useSwiftUILists` promoted to all builds, default `true`** (`Preferences.swift`).
   The five list tabs (Favorites, Nearby, Events, Art, Camps) now default to SwiftUI/PlayaDB;
   the preference remains a kill-switch (legacy UIKit/Yap code retained for one season).
   `#if DEBUG` wrappers removed at the 5 branch points (`BRCAppDelegate+Dependencies.swift` ×3,
   `MoreViewController.swift` ×2). Debug Feature Flags screen stays DEBUG-only, but its toggle
   now reads/writes through `PreferenceServiceFactory` (raw `UserDefaults.bool` would show OFF
   for the unset-default-true state).
2. **Release kill-switch** via `Settings.bundle/Root.plist`: "Modern List Views"
   `PSToggleSwitchSpecifier` on `featureFlag.lists.useSwiftUI` — field fallback without an
   app-store update.
3. **Adult-event region gating restored** (App Store content risk). Legacy hid `adlt` events
   until `BRCLocations.hasEnteredBurningManRegion` (`BRCDatabaseManager.m:945-948`, events tab
   list + its search only). Replicated exactly: new `iBurn/ListView/RegionStatusService.swift`
   (protocol + factory + `EventFilter.excludingAdultEvents()` via the existing `eventTypeCodes`
   inclusion mechanism — no new PlayaDB API; empty-after-exclusion selections use a
   match-nothing sentinel so "only adult selected outside region" stays empty like legacy).
   Applied in `EventListViewModel` browse + search filters, observation-time only (never
   persisted into the user's filter). Deliberately NOT gated (matching legacy): favorites,
   global search, nearby, map, filter-sheet type list, AI Right Now.
   Tests: `iBurnTests/EventListAdultGatingTests.swift` (8).
4. **`FavoriteSyncService` — SwiftUI list hearts mirror into Yap** (`iBurn/FavoriteSyncService.swift`).
   Previously list hearts wrote PlayaDB only → VisitList/AudioTour hearts disagreed, kill-switch
   fallback would "lose" favorites, and un-favoriting from a list left stale EKEvents.
   - Protocol + Impl + Factory; injected into the four `*DataProvider.toggleFavorite`s
     (fire-and-forget after the PlayaDB write; PlayaDB is source of truth) and reused by
     `DetailViewModel` (its private sync deleted).
   - **Event fan-out:** PlayaDB events are keyed by API uid; Yap splits events per-occurrence
     as `"<apiUID>-<index>"` (`BRCRecurringEventObject.eventObjects()`). The mirror updates
     every matching `"<apiUID>-<digits>"` key (+ exact-uid defensively).
   - **Calendar parity:** after the metadata write **commits**, a
     `FavoriteSyncCalendarRefreshHook` fires per occurrence uid; the production hook opens its
     own transaction and calls `BRCEventObject.refreshCalendarEntry(_:)` (EKEvent create/remove,
     `calendarEventIdentifier` bookkeeping) — same path as legacy detail favoriting. Note: only
     detail toggles ever scheduled calendar entries in legacy; list hearts now do too, which is
     an upgrade, and un-favoriting from a list correctly removes the EKEvent.
   - **Fixed latent bugs found en route:** `DetailViewModel.syncFavoriteToYapDB` and
     `DetailDataService.syncFavoriteToPlayaDB`/`syncNotesToPlayaDB` looked events up by the
     wrong uid form (bare API uid against suffixed Yap keys, and suffixed Yap uid against
     PlayaDB respectively) — both silently no-oped for events. Suffix normalization:
     `FavoriteSyncServiceImpl.apiEventUID(fromYapUID:)`.
   - Tests: `iBurnTests/FavoriteSyncServiceTests.swift` (11; temp Yap DB + in-memory PlayaDB,
     EventKit replaced by a spy hook that re-reads committed Yap state).
5. **Nearby "starting soon" window restored** (`NearbyViewModel.happeningEvents`): now includes
   events starting within 30 min, matching legacy `BRCDataSorter`'s `isStartingSoon`.
6. **Final festival day browsable** (`YearSettings.festivalDays` now end-inclusive
   `(0...numberOfDays)`): the Events day strip gains MON Sep 7 (Exodus), matching the legacy
   end-inclusive ASDayPicker. Also feeds the AI Right Now day picker.
7. Cleanup: dead `favoritesViewController`/`eventsViewController` properties deleted from
   `BRCAppDelegate.h`.

### Parity audit — accepted gaps / follow-ups (not fixed this session)

Ranked findings from the audit agent, with disposition:

- **OTA updates never reach PlayaDB** (all five lists frozen to bundled data until an app
  update) — *explicitly accepted by Chris; "network updater can wait."* This is the roadmap's
  Phase 1. During August data drops, both DBs are refreshed via app updates anyway.
- Events filter feature loss: "Show All Day Events" + "only events hosted at art" toggles have
  no SwiftUI equivalent; all-day events bucket by start hour instead of end-of-day.
- Art/camp rows: no event-count badge ("📅 N"); camp rows lack image-color theming.
- Event time labels: no green/orange/red status coloring; expired events not auto-dropped by
  the 60s tick (labels refresh, filter doesn't re-run).
- Day/hour bucketing uses `Calendar.current` (device TZ) not fixed PDT (`playaCalendar` exists
  unused in `PlayaDBImpl`) — wrong grouping when browsing from home timezones pre-event.
- Art/Camps/Favorites list search is in-memory `.contains`, not FTS (`filter.searchText` never
  set) — contradicts the house FTS-at-SQL rule; Events list does use FTS. "Search selected day
  only" option dropped.
- `"FavoritesFilter"` shared key: new stack writes "Vehicles", which the legacy enum parses as
  All (only matters if kill-switch used).
- Filter prefs don't carry over (legacy discrete keys vs new JSON blobs) — moot, fresh year.
- `GlobalSearchView` hardcodes `isFavorite: false` (pre-existing).

## Technical Details

### The swiftmodule/@testable gotcha (cost ~4 build cycles — remember this)

`iBurnTests` failed with *"type 'FavoriteSyncServiceFactory' has no member 'makeService'"* /
*"'FavoriteSyncServiceImpl' cannot be constructed because it has no accessible initializers"*
while the app target compiled clean. Root cause, isolated with a probe file compiled into the
test target:

- App-module members whose **signatures** reference `YapDatabaseReadWriteTransaction` are
  silently dropped when the test target imports the `iBurn` module (`@testable` or not).
- `YapDatabaseConnection` in signatures is fine; the read-write transaction type is not
  (probe: `zzProbeYapConnection` resolved, `zzProbeYapTransaction` → "cannot find in scope").
- Bodies are unaffected — only serialized signatures (params, property types, typealiases).

Fix pattern: keep cross-module-visible signatures free of that type. The calendar hook became
`(_ yapUID: String, _ isFavorite: Bool) -> Void`, invoked **post-commit**, with the production
hook opening its own transaction. (Nested-typealias and default-argument variants of the same
symptom were chased first; the transaction type in the signature was the real poison.)

### Verification

- App build: clean (0 errors/warnings), iPhone 17 Pro Max iOS 26.2 sim.
- `iBurnTests`: full suite green (includes 19 new tests).
- **Fresh-install sim pass with NO flag override** (pure defaults): onboarding → all five
  surfaces render SwiftUI (Events day strip scrolls to MON 7; Nearby shows correct pre-embargo
  empty state; Camps show "Location Restricted").
- DB assertions: PlayaDB seeded 321/1201/2101/4431, WAL, `v1-initial-schema`; favoriting one
  event from detail wrote exactly one `object_metadata` row keyed by the **parent** uid, and
  the Yap mirror updated **all six** `"<uid>-<n>"` occurrence rows — decoded blob shows
  `isFavorite: true` + a real EKEvent `calendarEventIdentifier` (calendar permission granted
  in onboarding).
- flows.md updated (day strip end date; Yap-mirror verification steps).

### What "finish the YapDB migration" still leaves on Yap (post-season work, roadmap §4)

Network update pipeline (`BRCDataImporter`), user map pins/breadcrumbs on the map, Visit List,
Audio Tour, legacy list VCs (kept one season as kill-switch), embargo internals. The five list
tabs + detail + map annotations + search + AI are now all PlayaDB-first in shipping defaults.

---

# Session 2: watchOS Phase 2 — WatchConnectivity favorites sync + watch polish

Chris: *"The watchOS app needs some work. Let's fix it up. Use lower effort fable subagents
for implementation."* The one remaining documented MVP item
(`2026-07-03-watchos-mvp-plan.md`) is **Phase 2: phone↔watch favorites sync**; plus polish
gaps found in survey.

## Plan

1. **PlayaDB sync core** (`Packages/PlayaDB`):
   - Migration `v2-favorite-sync`: `ALTER TABLE object_metadata ADD COLUMN favorite_updated_at
     DATETIME` + backfill `= updated_at WHERE is_favorite = 1`.
     **Why a new column:** `updated_at` is bumped by view-tracking and notes writes, so
     LWW on it would let "viewed after favoriting elsewhere" propagate a stale unfavorite.
   - `FavoriteSyncItem` (Codable: objectType/objectId/isFavorite/updatedAt).
   - Protocol: `favoriteSyncSnapshot()` (rows with non-NULL `favorite_updated_at`),
     `applyFavoriteSync(_:) -> [FavoriteSyncItem]` (per-item LWW; skip when local state
     already matches — prevents observation/push loops; skip missing-row unfavorites;
     returns applied items), `observeFavoriteSyncState(...)`.
   - `toggleFavorite`/`setFavorite` stamp `favorite_updated_at`.
   - Tests: LWW newer-wins/older-ignored/same-state-no-write, insert-favorite,
     skip-missing-unfavorite, snapshot excludes viewed-only rows, stamping, backfill.
2. **`FavoritesSyncManager`** in the PlayaDB package (`#if canImport(WatchConnectivity)`),
   symmetric on both platforms: WCSession activate → apply `receivedApplicationContext` →
   push snapshot; observation on snapshot → `updateApplicationContext(["favoritesV1": json])`;
   `didReceiveApplicationContext` → `applyFavoriteSync` → `onApplied` hook.
   Lives in the package so **no pbxproj surgery** (iBurnWatch is not a synchronized group;
   both targets already link PlayaDB).
3. **Phone integration**: `DependencyContainer` owns the manager; `onApplied` mirrors
   incoming favorites into Yap via the existing `FavoriteSyncService` (Session 1).
4. **Watch integration**: instantiate + start in `iBurnWatchApp` (existing file edit only).
5. **Watch polish**: FavoritesScreen surfaces load errors; DetailScreen shows event
   occurrence times (favorited events synced from the phone were time-less);
   FavoritesScreen refreshes when synced favorites land.
6. Explicitly out of scope: embargo-flag sync (moot — bundled data has no GPS this season),
   events browsing on watch, complications.

## Results

All shipped; executed with 3 Fable subagents (PlayaDB core / watch polish / WCSession
wiring) + integration and E2E verification in the main session.

### What shipped

1. **PlayaDB migration `v2-favorite-sync`** — `object_metadata.favorite_updated_at`
   (backfilled from `updated_at` for existing favorites); stamped only by
   `toggleFavorite`/`setFavorite`. Verified applying cleanly to an existing v1 phone DB.
2. **Merge API** — `FavoriteSyncItem`, `favoriteSyncSnapshot()`,
   `applyFavoriteSync(_:) -> [applied]`, `observeFavoriteSyncState(...)`. LWW rules:
   unknown type skipped; missing row + unfavorite skipped; same-state skipped with NO
   write (loop prevention); otherwise applied iff incoming stamp newer (or local nil).
   12 new tests in `FavoriteSyncMergeTests`; package suite 189/189.
3. **`FavoritesSyncManager`** (in the PlayaDB package — both targets already link it, so
   no pbxproj surgery; iBurnWatch is not a synchronized group): symmetric WCSession
   wrapper, `applicationContext` key `favoritesV1` (JSON, `.secondsSince1970`), NSLock
   around tiny state, push on observation change + on activation +
   `sessionWatchStateDidChange`/`sessionCompanionAppInstalledDidChange` (see bug below),
   incoming context → `applyFavoriteSync` → `onApplied` (only when non-empty; empty
   payloads ignored so a fresh peer can't clobber).
4. **Phone wiring** — `DependencyContainer` owns/starts the manager; `onApplied` maps
   `DataObjectType` → `FavoriteSyncObjectType` and mirrors into Yap via Session 1's
   `FavoriteSyncService` (event occurrence fan-out + EKEvent refresh come free).
5. **Watch wiring** — manager started in `iBurnWatchApp.task` after seeding; `onApplied`
   posts `.favoritesSyncDidApply`; FavoritesScreen bumps its `refreshToken` on receipt so
   phone favorites appear live.
6. **Watch polish** — FavoritesScreen real error state (was silently showing "No
   favorites yet" on DB errors); DetailScreen shows up to 5 upcoming occurrence times
   for events ("Sun 5:00 – 7:00 PM"), which synced phone favorites made reachable.

### Bug found during E2E (fixed)

First E2E run: phone pushed while the watch app wasn't installed yet →
`WCErrorDomain 7006` → favorite never delivered (context is only re-pushed on change).
Fix: implement `sessionWatchStateDidChange` (iOS) / `sessionCompanionAppInstalledDidChange`
(watchOS) → `pushLatestSnapshot()`, so installs/pairing changes re-publish state.

### Verification

- PlayaDB package: 189/189. iBurnTests: full suite, 0 failures. Both app builds
  0 errors / 0 warnings; no pbxproj churn.
- Paired-sim E2E (iPhone 17 Pro Max + Watch Series 11 46mm, pair "active, connected"):
  - Phone → watch: favorited "Booty Hour" event on phone → watch `object_metadata`
    `event|pZKm9hfsiDbnz8QXueVW|1`; watch Favorites lists it; detail shows occurrence
    times. Existing phone DB migrated v1→v2 in place; fresh watch install converged on
    first launch (post-fix).
  - Watch → phone: injected GPS into 2 camps on watch (flows.md trick), favorited
    "Snuggles" via watch Nearby → phone PlayaDB `camp|a1XVI00000FBBVz2AP|1` AND phone
    Yap `BRCCampObject` blob decoded `isFavorite=True` (non-favorited peer decodes
    False). Phone Favorites tab showed the camp via live observation.
  - Watch app uninstalled afterward to purge the GPS-tampered test DB.
- flows.md §9 updated with the sync flow + verification recipe.

### Notes / accepted limitations

- `applicationContext` is best-effort latest-state: intermediate toggles coalesce
  (fine — final state is what matters) and delivery needs an eventual connection.
- LWW trusts device clocks (normal for this pattern; worst case a stale toggle wins
  within clock skew).
- Embargo-flag sync deliberately skipped: bundled watch data has no GPS this season and
  there's no watch network updater; revisit with roadmap Phase 1.
- Legacy-only phone surfaces that write favorites straight to Yap (Visit List, Audio
  Tour) don't reach PlayaDB and therefore don't reach the watch — same pre-existing gap
  as Session 1, tracked for post-season Yap retirement.
