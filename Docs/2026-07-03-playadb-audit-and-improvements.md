# PlayaDB Audit: Correctness & Performance Improvements

**Date:** 2026-07-03 (Pacific)
**Branch:** `2026-updates`
**Related:** `2026-04-06-grdb-performance-optimization.md`, `2026-05-09-events-hour-index-and-fts.md`, `2026-05-17-event-list-day-tab-perf-round-2.md`, `2026-07-03-2026-year-update-plan.md`

## High-Level Plan

Full audit of `Packages/PlayaDB` (GRDB implementation, importer, query layer, observations) for correctness and performance, followed by staged fixes. Baseline: `swift test` in `Packages/PlayaDB` green (146 tests) before changes.

### Audit Findings

#### Correctness

1. **FTS5 external-content triggers are wrong** (`PlayaDBImpl.setupFTS5Tables`). The
   `*_ad` / `*_au` triggers use `DELETE FROM <fts> WHERE rowid = old.rowid`. For
   external-content FTS5 tables (`content=<table>`), delete/update must use the special
   `INSERT INTO fts(fts, rowid, <cols>) VALUES('delete', old.rowid, old.<cols>)` command
   because FTS5 needs the *old* column values to remove index entries — with the plain
   DELETE it reads the content table where the row is already gone/changed, silently
   corrupting the index. Currently masked because import ends with a full `rebuild`,
   but any out-of-import UPDATE/DELETE corrupts search.
2. **Occurrence favorite identity mismatch.** `EventObjectOccurrence.uid` is a synthesized
   `"<eventUID>_<occurrenceID>"`. `setLastViewed` maps occurrence → parent event uid, but
   `toggleFavorite` / `setFavorite` / `isFavorite` / `metadata(for:)` do **not**. Favoriting an
   occurrence writes metadata under the synthesized uid, which:
   - the JOIN path (`eventObjectOccurrencesJoined`, used by `observeEventsByDayThenHour`)
     never matches (its SQL EXISTS checks `event_occurrences.event_id` only), and
   - `observeListRows` metadata batch-fetch (keyed by `event.uid`) never inflates → stale hearts.
   The non-JOIN path checks both uids (`PlayaDBImpl.swift:1208-1217`), so the two code paths
   disagree. App-side is currently safe by accident (dual-write mirrors favorites via
   `fetchEvent(uid:)` → EventObject), but the PlayaDB API itself is a footgun.
3. **`observeEvents` tracked regions omit `object_metadata`/`thumbnail_colors`** even though
   its fetch reads both for ListRow inflation. Favorite toggles and color-cache writes don't
   re-fire the observation → stale hearts/colors in event lists and the favorites-only map
   annotation layer (`PlayaDBAnnotationDataSource` uses `observeEvents(onlyFavorites:)`).
   `observeEventsByDayThenHour` deliberately includes them; art/camp/MV observations
   auto-track everything. Inconsistent semantics.
4. **Retain cycle + dead API in `setupObservations`.** The event observation captures
   `self` strongly while `self.observations` retains the cancellable → `PlayaDBImpl` can never
   deinit. Worse, the 5 always-on full-table observations back `allArt/allCamps/allEvents/
   allMutantVehicles/favorites` which are **unused by the app** (verified via grep) — they
   re-fetch entire tables on every write and fire `ensureMetadata` storms.
5. (Minor) SwiftUI previews build ad-hoc `try! createPlayaDB()` instances
   (`CampListView.swift:163`, `ArtListView.swift:224`) — second connections to the on-disk
   DB. Preview-only; low priority.

#### Performance

6. **`DatabaseQueue` instead of `DatabasePool`/WAL.** Single serialized connection: every
   read blocks behind writes. First-launch seed import is one giant write transaction, so
   all UI reads stall until it finishes; `ensureMetadata` write bursts serialize all list
   observations. `DatabasePool` gives concurrent WAL readers + GRDB's observation fast path.
7. **Read paths perform writes.** Nearly every fetch/observe calls `ensureMetadata`,
   pre-populating blank `object_metadata` rows (~10k rows on first launch). ListRow already
   tolerates nil metadata (`observeEventsByDayThenHour` sets `skipEnsureMetadata: true` for
   exactly this reason). Blank prepopulation should be removed everywhere; metadata should be
   created lazily on actual writes only.
8. **Import inefficiencies** (`importFromData`): per-event `CampObject.fetchOne` /
   `ArtObject.fetchOne` for GPS denormalization (≈2 × 8k point queries); spatial index rebuild
   fetches full model objects then inserts row-by-row instead of `INSERT INTO … SELECT`;
   FTS triggers do per-row indexing during bulk insert even though a full `rebuild` follows.
9. **Missing `end_time` index.** `happeningNow` / `notExpired` / `activeWindow` all filter on
   `event_occurrences.end_time`; only `start_time` is indexed.
10. **No `removeDuplicates()`** on any observation — identical result sets re-emit and reload
    UI (e.g. `setLastViewed` on a *camp* re-runs + re-emits the full 8k-row event JOIN because
    byDayThenHour tracks the whole `object_metadata` table).
11. (Minor) `fetch*ImageURLs` load all image rows then dedupe in memory — `GROUP BY mv_id`
    with `MIN(id)` would do it in SQL.
12. (Minor) Schema managed with ad-hoc `CREATE TABLE IF NOT EXISTS` + column checks instead of
    `DatabaseMigrator` — works, but fragile as migrations accumulate.

### Phased Fix Plan (task list mirrors this)

- **Phase 1 — Correctness:** FTS triggers (#1), favorite identity normalization (#2),
  observeEvents regions (#3), remove dead reactive props + retain cycle (#4).
- **Phase 2 — Concurrency core:** DatabasePool/WAL (#6), remove ensureMetadata from read
  paths (#7).
- **Phase 3 — Query/index:** end_time index + EXPLAIN QUERY PLAN pass (#9), image URL
  GROUP BY (#11), removeDuplicates where profitable (#10).
- **Phase 4 — Import:** batch GPS resolution, SQL-side spatial rebuild, FTS trigger churn (#8).
- Each phase: `swift test` in `Packages/PlayaDB` + new targeted tests; app build via
  xcodebuild at the end.

## Technical Details

### Key context

- App integration: single shared instance via `DependencyContainer` (`iBurn/DependencyContainer.swift:69-71`),
  seeded once per install by `PlayaDBSeeder.seedIfNeeded()` (bundle JSON only; network updates
  still go through legacy YapDatabase/`BRCDataImporter` — dual-database migration in progress).
- Favorites are dual-written Yap → PlayaDB by uid (`DetailDataService.syncFavoriteToPlayaDB`,
  `BRCDataObjectTableViewCell`).
- Consumers: `*DataProvider` (SwiftUI lists), `PlayaDBAnnotationDataSource` (map),
  `PlayaSearchTools`/`RightNowWorkflow` (AI), detail screens, deep links, global search.
- `Packages/PlayaDB` GRDB pin: `.upToNextMajor(from: "7.6.1")`.
- Test data: `iBurn2026APIData` bundle from `Submodules/iBurn-Data`.

### Canonical FTS5 external-content trigger form (fix for #1)

```sql
CREATE TRIGGER art_objects_ad AFTER DELETE ON art_objects BEGIN
  INSERT INTO art_objects_fts(art_objects_fts, rowid, uid, name, description, artist, hometown, category)
  VALUES('delete', old.rowid, old.uid, old.name, old.description, old.artist, old.hometown, old.category);
END;
-- _au = 'delete' with old values, then plain INSERT with new values
```

Existing wrong triggers must be dropped (CREATE TRIGGER IF NOT EXISTS won't replace them),
then recreated in the new form; follow with an FTS `rebuild` for any DB that may have
corrupted index state.

## Progress Log

- 2026-07-03: Audit complete (impl read end-to-end; app integration mapped; findings above).
  Baseline `swift test` green. Starting Phase 1.
- 2026-07-03 (later): **All phases implemented.** 162 tests green (was 157 baseline; +9 new,
  −4 rewritten). Suite runtime halved (~14s → ~7.5s) from the import rewrite; full 2026
  dataset import now ~0.3s inside one transaction.

### Changes landed (all in `Packages/PlayaDB`)

1. **FTS5 triggers** (`PlayaDBImpl.setupFTS5Tables/setupFTS5Triggers`): rewritten data-driven
   (`ftsTableConfigs`) with canonical external-content `'delete'`-command triggers. Legacy
   plain-DELETE triggers detected via sqlite_master and replaced + index rebuilt once on
   open. New `FTSTriggerTests` (5 tests incl. corruption→migration→rebuild end-to-end).
2. **Metadata identity** (`metadataIdentity(for:)`): toggleFavorite/setFavorite/isFavorite/
   metadata(for:)/setUserNotes/setLastViewed/clearLastViewed all normalize
   EventObjectOccurrence → parent event uid. `migrateOccurrenceKeyedMetadata` folds legacy
   `"<uid>_<occ>"` rows into parent rows on open (OR favorite, min/max viewed dates,
   coalesce notes). Non-JOIN onlyFavorites filter now matches JOIN path (event uid only).
   This fixed a live bug: `EventDataProvider.toggleFavorite` passes occurrences directly.
   New `MetadataIdentityTests` (4 tests).
3. **observeEvents regions**: now include `ObjectMetadata` + `ThumbnailColors` (was event
   tables only → stale hearts / favorites map layer). 2 new regression tests in
   `FilterObservationTests`.
4. **Removed dead reactive API**: `allArt/allCamps/allEvents/allMutantVehicles/favorites`
   props + `setupObservations()` (5 always-on full-table observations, ensureMetadata storms,
   and a `[self]` retain cycle) deleted from protocol + impl. No app callers existed.
5. **DatabasePool/WAL**: `dbQueue` is now `any DatabaseWriter` — DatabasePool for on-disk
   paths (concurrent WAL reads; seed import no longer blocks UI), DatabaseQueue retained for
   `:memory:` test databases. Test helpers updated to `any DatabaseWriter`.
6. **Read paths are write-free**: all ensureMetadata calls removed from fetch/observe paths
   (blank-row prepopulation, ~10k rows first launch). Metadata created lazily only by actual
   writes. Two tests rewritten to assert reads create no rows.
7. **Indexes**: added `idx_event_occurrences_end_time` (notExpired/happeningNow/activeWindow).
   New `QueryPlanTests` with EXPLAIN QUERY PLAN assertions on hot queries. Image URL fetches
   (`fetch*ImageURLs`) now aggregate first-thumbnail-per-object in SQL (GROUP BY + MIN(id)).
8. **Import**: per-event camp/art GPS `fetchOne`s replaced with dictionaries built during
   insert (~16k point queries eliminated); spatial index rebuilt via set-based
   INSERT…SELECT; occurrence R*Tree rebuild likewise; FTS/spatial sync triggers dropped for
   the bulk phase and recreated before commit (rebuild was already wholesale); duplicate-UID
   warnings aggregated to one line; import duration logged.
9. **removeDuplicates()** on all list observations (observeListRows) + user map pins +
   update info. Added `Equatable` to ArtObject/CampObject/EventObject/EventOccurrence/
   MutantVehicleObject/ObjectMetadata/UserMapPin/UpdateInfo, manual `==` for
   EventObjectOccurrence (existential host compared by concrete value), conditional
   `ListRow: Equatable`. Unrelated metadata writes no longer re-emit identical 8k-row arrays.

### Verification
- `swift test` in `Packages/PlayaDB`: 162 passed, 0 failed (4 skipped, pre-existing).
- Full app `xcodebuild` (iPhone 17 Pro Max sim): **succeeded**, 0 errors, only pre-existing
  warnings (unrelated to these changes). Uncommitted on `2026-updates` pending review.

### Follow-up round (same day, committed separately after ed0b174)

10. **Narrowed metadata observation regions.** All list observations now track
    `ObjectMetadata.select(object_type, object_id, is_favorite, user_notes)` instead of the
    whole table (`listMetadataRegion` helper), and art/camp/MV observations moved from
    auto-tracking to explicit regions (own table + narrowed metadata + colors;
    + `event_objects` when `onlyWithEvents`; + `mv_tags` when tag-filtered). Required
    switching all metadata writers to **column-limited updates**
    (`metadata.update(db, columns:)`) — GRDB's full-row `update(db)` touches every column,
    which made even a last_viewed write intersect the is_favorite region. Result: viewing a
    detail screen (setLastViewed) no longer re-runs *any* list query, including the 8k-row
    event JOIN; favorite toggles and notes edits still re-fire. Two inverted-expectation
    regression tests in `FilterObservationTests`.
11. **DatabaseMigrator adoption.** `setupDatabase` now registers the full current schema as
    migration `v1-initial-schema` (idempotent DDL, so pre-migrator installs adopt cleanly)
    and runs `migrator.migrate()`. FTS/R*Tree virtual tables + sync triggers, the occurrence
    R*Tree backfill, and the occurrence-keyed metadata fold stay as open-time maintenance
    (they carry self-repair logic and are data-dependent/idempotent; imports re-invoke the
    trigger setup). Future schema changes are new numbered migrations — v1 must not be
    extended. New `SchemaMigrationTests` covering fresh-install recording and pre-migrator
    adoption with data preservation.

Test count after follow-ups: **166 passed, 0 failed** (4 skipped, pre-existing).

### Remaining / follow-up candidates (not done)
- SwiftUI-preview `try! createPlayaDB()` instances (finding #5) — harmless, low priority.
- PlayaDB is still bundle-seeded only; network updates flow through legacy YapDatabase.
  Unifying update ingestion is a larger project (see 2026-01-25 roadmap doc).

## Expected Outcomes

- Search index stays correct under row updates/deletes outside import.
- Favoriting an occurrence and favoriting its event agree across all query paths.
- Event lists/map refresh on favorite + color-cache writes.
- No always-on full-table observations; PlayaDBImpl can deinit.
- Reads never block on the seed import; first-launch UI responsive during import.
- Fewer redundant observation emissions; hot event queries fully indexed.
