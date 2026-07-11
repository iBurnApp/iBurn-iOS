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
