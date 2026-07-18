# 2026 API Data Refresh (July 18)

## High-Level Plan

Pull the latest 2026 camp/art/event data from the Burning Man API using the existing sync script from last year, verify the result, and commit it in the iBurn-Data submodule.

**Outcome:** Success. Data refreshed, validated, and committed (`iBurn-Data` `79d9748`, parent pointer bump `e56a543`, both on `2026-updates`).

## Technical Details

### The script (built last year, reused as-is)

`Submodules/iBurn-Data/scripts/BlackRockCityPlanner/src/cli/fetch_and_geocode.js` — fetches camp/art/event from `api.burningman.org`, geocodes camps against the year's layout, writes `update.json`. Requires `BMORG_API_KEY` (already exported in `~/.zprofile`).

```bash
cd Submodules/iBurn-Data/scripts/BlackRockCityPlanner
node src/cli/fetch_and_geocode.js -y 2026 \
  -l ../../data/2026/layouts/layout.json \
  -o ../../data/2026/APIData/APIData.bundle
```

Note: `api.burningman.org` is not in the Claude Code sandbox network allowlist — the first run failed with `getaddrinfo ENOTFOUND` and had to be re-run with sandbox disabled. Consider adding the host via `/sandbox` for future runs. A failed run still overwrites `update.json` (with all-failed timestamps), so always re-run to completion.

### Results (old → new)

| File | HEAD | New | Notes |
|---|---|---|---|
| camp.json | 1201 | 1201 | 4 dropped, 4 added; only 9 real content changes (urls/emails). Large diff is null-key stripping, not data churn. |
| art.json | 321 | 321 | 8 dropped, 8 added |
| event.json | 2140 | 2217 | +77 net (9 removed, 116 added) |

- **"Geocoded 0 camps"** is expected: API returns no `location_string`/`location` for camps or art yet (embargo until gates open). HEAD data was identically location-free — no regression.
- Duplicate event uids: 9 byte-identical dupes (upstream API quirk; was 39 at HEAD, so improved).
- 2 events reference a camp uid absent from the roster (`a1XVI00000FJ1B32AL`) — pre-existing upstream inconsistency.

### Script bug discovered and fixed: mv support

`fetch_and_geocode.js` fully rewrote `update.json` with only art/camps/events keys, silently dropping the `mv` (mutant vehicles) entry; `mv.json` itself had been fetched manually (499 records, July 3). Fixed by making mv a first-class data source: the script now fetches `https://api.burningman.org/api/mv?year=N` (same shape as art, saved as-is) and writes an `mv` entry to `update.json` each run. Verified end-to-end: 496 vehicles fetched (3 dropped upstream since the manual pull), all uids unique. The script lives in the nested BlackRockCityPlanner submodule, so the fix is a three-level commit chain: BRCP `ec84cd3` → iBurn-Data `be53e0b` → app repo `17addfc`.

## Context Preservation

- First attempt delegated the whole run to a subagent; blocked by the permission classifier (prompt pre-authorized a sandbox bypass). Ran the fetch inline instead; verification/diff analysis was delegated to a Sonnet subagent (read-only, no sandbox issues).
- 2026 dir also has loose `art.json`/`camp.json`/etc. at `APIData/` level (outside `APIData.bundle/`) — these were not touched and appear to be leftovers; the app consumes `APIData.bundle`.

## Expected Outcomes

- App picks up refreshed 2026 rosters and +77 events on next build (bundled data).
- Locations remain null until BMorg lifts the embargo — re-run the same command then, and expect real geocode success/failure counts at that point.

## Cross-References

- `Docs/2026-07-13-official-2026-map-tiles.md` — map tile side of 2026 data
- `Submodules/iBurn-Data/CLAUDE.md` — full data-generation workflow (geometry, tiles, geocoder bundle)

---

# Same-day session 2: 2026 release-readiness audit + event list day-switch bug fix

## Part A — Release-readiness audit (first 2026 release prep)

Verified locally on `2026-updates` (a8b07f3): app builds clean (Xcode 26.x, iPhone 17 Pro Max
OS 26.2 sim) and the `iBurnTests` scheme passes with 0 failures. Note the shared `iBurnTests`
scheme already includes `PlayaKitTests` + `PlayaGeocoderTests` as testables; a separate shared
`PlayaKitTests` scheme no longer exists (CLAUDE.md's separate test command is stale).
Version state: `MARKETING_VERSION 2026.0`, build 108. App-repo branch pushed (0 unpushed).

### Blockers / action items found

1. **GitHub Actions CI has never worked since the July 2025 migration.** All three workflows
   (`ci.yml`, `pr.yml`, `deploy.yml`) use `runs-on: macos-15-arm64`, which is not a valid
   GitHub-hosted runner label — every job queues for 24h with **zero steps executed**, then is
   auto-cancelled. Last 100 runs: 94 cancelled, only successes are Dependabot bundler jobs.
   Consequence: tagging `v*` for a release would never deploy to TestFlight.
   **Fix committed** on local branch `worktree-fix-ci-runner-labels` (`20f7bd1`, based on
   master, not pushed): `macos-26` runners, Xcode 26.2 (watchOS 26 target requires Xcode 26;
   old pin was 16.4), Ruby 3.1→3.4 (EOL; 3.4 matches local), destination iPhone 16 Pro →
   iPhone 17 Pro Max, `xcpretty` (not in Gemfile) → preinstalled `xcbeautify`, and test matrix
   drops the nonexistent `PlayaKitTests` scheme. Evidence: `actions/runner-images`
   macos-26-arm64 readme (Xcode 26.0.1–26.6, iPhone 17 Pro Max sims).
2. **iBurn-Data submodule `2026-updates` branch exists ONLY on this machine.** Not pushed to
   `origin` (iBurn-Data-Private) nor `public` (iBurn-Data). The app repo's pushed
   `2026-updates` branch points at submodule commit `be53e0b` that no remote has — fresh
   clones/CI can't init the submodule, and the entire 2026 data work has no off-machine
   backup. Needs a push decision (private vs public; data is currently embargo-clean — all
   locations null).
3. **Remote updates endpoint has no 2026 data.** Production `UPDATES_URL` (GitHub secret)
   serves from the public `iBurnApp/iBurn-Data` repo raw path
   `data/YYYY/APIData.bundle/update.json`; the public repo has no `data/2026/`. Before
   release: push 2026 data to the public repo and point the `UPDATES_URL` secret at the 2026
   path, else shipped apps can't receive OTA data refreshes (or worse, would fetch 2025 data
   if the secret still embeds `data/2025`).
4. **2026 embargo passcode hash still pending from BMorg** — local `BRCSecrets.m` and the
   `EMBARGO_PASSCODE_SHA256` GitHub secret presumably still carry the 2025 hash.
5. **Deploy signing predates the watch app.** `deploy.yml` installs a single
   `BUILD_PROVISION_PROFILE_BASE64`; the new iBurnWatch target needs its own bundle-id
   provisioning for archive/export (App Store Connect + secrets work required before a
   TestFlight deploy can succeed).

## Part B — Event list bug: wrong day-of-week on first row + dead tap (FIXED)

**Symptom (user screenshot, sim iOS 26.5):** Events tab, SAT 5 selected; first row
("Drama Dump & Gift", hour-0 section) shows trailing label "Wed 12:00am (12h)" and tapping
it does nothing. Other rows correct ("Sat 12:00am …") and tappable.

**Data:** two 2026 events titled "Drama Dump & Gift"; the relevant one (event_id 56449, uid
`EJVpjWpfy6uUjvATLNh3`) has six occurrences, midnight→noon Mon Aug 31 … Sat Sep 5. So a
Saturday occurrence exists; the row was rendering the Wednesday one.

**Root cause** (`iBurn/ListView/EventListView.swift`): since the day-tab perf work
(`ceb0f42`, 2026-05-17), day switching does NOT rebuild the list — the same
`ScrollView`+`LazyVStack` persists and `selectedDay` just swaps the `dayBuckets` slice.
Rows have occurrence-unique `ForEach` ids (`EventObjectOccurrence.uid` =
`eventUid_occurrenceRowid`), BUT the first row of each hour section carried a bare
`.id(hour)` (0–23) as a `ScrollViewReader` anchor for the hour scrub strip
(`EventHourIndexView`). Hours repeat every day, so after a day switch the new day's anchor
row has the SAME explicit identity as the old day's — SwiftUI/LazyVStack treats it as the
same view and keeps the cached row: stale trailing label AND stale tap closure. The stale
closure sends the old day's occurrence to `EventListHostingController.showDetail`
(`EventListHostingController.swift:41`), whose
`firstIndex(where: uid && occurrence.startTime match)` guard finds no match in the current
day's `visibleRows` and silently `return`s — hence the dead tap. (The May-17 perf doc
records that `.id(selectedDay)` full-remount was tried and reverted for perf; the identity
collision this leaves behind wasn't noticed.)

**Fix** (branch `fix-event-day-occurrence`): namespace the anchor identity by day —
`private struct HourAnchorID: Hashable { let day: Date; let hour: Int }`, applied as
`.id(HourAnchorID(day: anchorDay, hour: hour))` on first-in-section rows and matching
`proxy.scrollTo(HourAnchorID(day: anchorDay, hour: hour))` in the hour-index overlay, where
`anchorDay = Calendar.current.startOfDay(for: viewModel.selectedDay)` (same key derivation
as the viewmodel's day buckets). Anchor identity now changes on every day switch, so the
lazy stack can never resurrect the previous day's row; scrub-strip scrolling behavior is
unchanged; no extra remounts (≤24 anchor rows affected per day), preserving the May perf
work.

**Verification:** clean build green; simulator drive (WED→SAT/THU/FRI switches, first-row
label + detail push on first and second rows) — see session log / PR.

## Part C — Pre-populated YapDatabase seed restored for 2026

The bundled Yap seed (`iBurn-YYYY.zip`, shipped 2022–2024) was collateral damage of the
Oct 2025 SPM/pbxproj cleanup (`99b8cbd`): the consumption code survived
(`BRCDataImporter.copyDatabaseFromBundle()` unzips a main-bundle `iBurn-2026.zip` into
`App Support/iBurn/iBurn-2026/`), but nothing bundled the zip, so 2026 first launches were
doing the full JSON import (~3m10s on an iPhone 17 Pro Max sim). The zip artifact itself was
always local-only/gitignored, regenerated by hand each season — no script ever existed.

**2026 mechanism (simpler than the old pbxproj wiring):** the `iBurn/` folder is now a
filesystem-synchronized group, so the seed just lives at **`iBurn/iBurn-2026.zip`**
(gitignored via the new `iBurn/iBurn-*.zip` rule) and is auto-copied into the app bundle —
no pbxproj entries needed. If the file is absent at build time the app silently falls back
to JSON import (non-fatal), so the release builder must have the zip present.

**Regeneration procedure** (redo whenever `APIData.bundle` JSON is refreshed — especially
the final pre-release August data drop, or the seed's saved timestamps go stale and first
launch pays seed-copy + full re-import):
1. Fresh install (`xcrun simctl uninstall <sim> com.trailbehind.iBurn2010` — note bundle id)
   of the current build; launch; complete onboarding; let the JSON import finish. Poll
   `sqlite3 "<container>/Library/Application Support/iBurn/iBurn-2026/iBurn-2026.sqlite"
   "SELECT count(*) FROM database2;"` until stable (>6000; 2026 July data: **6456**).
   Container via `xcrun simctl get_app_container <sim> com.trailbehind.iBurn2010 data`.
2. `xcrun simctl terminate <sim> com.trailbehind.iBurn2010`, then from
   `<container>/Library/Application Support/iBurn`: `zip -r -X iBurn-2026.zip iBurn-2026`
   (top-level zip entry MUST be the `iBurn-2026` folder; include sqlite + -wal/-shm).
3. Drop it at `iBurn/iBurn-2026.zip`. Done (synced group bundles it automatically).

**Verified 2026-07-18:** built app contains the 4.2 MB zip; after uninstall + fresh
install, `database2` reads 6456 rows 12 s after launch (vs 190 s import). PlayaDB (GRDB,
SwiftUI lists) intentionally has no seed — its bundle-JSON import is ~0.3 s
(`Docs/2026-07-07-architecture-analysis-and-roadmap.md`). A copy of the zip also sits at
`Submodules/iBurn-Data/data/2026/iBurn-2026.zip` (archival convention from prior years;
the live one is the `iBurn/` copy).

## Part D — CRITICAL: July 18 data refresh silently broke PlayaDB import (fixed) + PlayaDB seed

**Regression discovered while generating the PlayaDB seed:** the July 18 API refresh
(`79d9748`) reintroduced user-entered junk `url` values that the July 3 session had
sanitized by hand (camp.json 5, art.json 4, mv.json 1 — e.g. Hel's Diner
`"http://www.campporta.org, www.helsdiner.com"`). PlayaAPI decoded `url` strictly as
`URL`, so decoding threw, and since `PlayaDB.importFromData` runs art+camp+event+mv in ONE
GRDB transaction, the whole import rolled back: **fresh installs of `2026-updates` had a
completely empty PlayaDB** (Events tab "No events found"), while existing installs
silently kept stale July-3 data (reimport failed on every launch). The failure was
invisible because `PlayaDBSeeder` logged via `print()`, which the sim console drops. The
July 3 notes predicted exactly this ("Consider adding sanitization to fetch_and_geocode.js
for the August re-fetches").

**Fix (code hardening, not data patching):** new
`Packages/PlayaAPI/Sources/PlayaAPI/Models/Shared/LenientURL.swift` — user-entered URL
fields (`Camp.url`, `Art.url`/`donationLink`, `Event.url`, `MutantVehicle.url`/
`donationLink`) now decode leniently via explicit `init(from:)`: clean single-token web
URL accepted as-is; dirty values salvage the first comma/whitespace-separated token that
parses with scheme+host (bare `www.*` gets `http://`); otherwise nil. Never throws, so one
bad upstream record can never blank the database again. Org-generated `thumbnailUrl`
fields stay strict. Encoding unchanged. `PlayaDBSeeder`'s `print`s upgraded to
`DDLogError`/`DDLogInfo`. Tests: PlayaAPI 67 passed (incl. 12 new LenientURL cases),
PlayaDB 206 passed, and the previously-failing real-bundle acceptance test
`testImportRealDataFromiBurnBundle` now passes. Data files untouched; optional follow-up:
sanitize at the source in `fetch_and_geocode.js` for hygiene.

**PlayaDB seed (per Chris: "we need a pre seeded PlayaDB as well"):** unlike Yap, PlayaDB
had no copy-from-bundle path, so one was added:
`PlayaDBSeeder.restoreBundledSeedIfNeeded(documentsURL:seedZipURL:bundle:)` — synchronous,
called from `DependencyContainer.init` before `PlayaDB.create()`. No-op when
`Documents/PlayaDB.sqlite` exists or the seed resource is absent; otherwise unzips the
bundled `PlayaDB-<YearSettings.playaYear>.zip` to a temp dir, clears stray `-wal`/`-shm`
sidecars, and moves `PlayaDB.sqlite` into place; any failure removes partial files and
falls back to JSON import. 5 unit tests (`iBurnTests/PlayaDBSeedRestoreTests.swift`) with
runtime-built fixture zips. Existing installs are untouched (their data updates still flow
through `needsImport` timestamp checks).

**Seed artifact:** `iBurn/PlayaDB-2026.zip` (gitignored, auto-bundled by the synced
group like the Yap zip; also add to the seasonal regeneration checklist). Generation:
same fresh-install procedure as the Yap seed (Part C) but harvest
`<container>/Documents/PlayaDB.sqlite` after `PRAGMA wal_checkpoint(TRUNCATE)`, then
`zip -X -j PlayaDB-2026.zip PlayaDB.sqlite` (single top-level file entry, no folder).
July data: 321 art / 1201 camps / 2208 events / 4697 occurrences, 4.7 MB sqlite →
1.7 MB zip. Verified end-to-end: fresh install restores a byte-identical
(md5-matched) PlayaDB.sqlite instead of importing JSON, and both seeds coexist.
(Note: 2208 events in PlayaDB vs 2217 fetched — PlayaDB dedupes the 9 byte-identical
duplicate-uid events noted in the refresh section.)

**Watch follow-up:** the watch app's own GRDB store still JSON-imports on first launch
(`WatchSeeder`); no seed there yet — its dataset import is small, revisit only if watch
first-launch feels slow.

## Part E — Max-duration event filter (hide amenity-listing pseudo-events)

Per Chris: camps list amenities as day-long "events" (e.g. a mailbox open midnight–noon
daily, 12h) that aren't real events to attend. New filter hides them by duration.

- **PlayaDB:** `EventFilter.maxDuration: TimeInterval?` (package default nil — watch/
  Nearby/Right Now/detail consumers unchanged). Predicate in `eventOccurrenceRequest`
  (so browse + search + fetch paths all get it):
  `(julianday(end_time) - julianday(start_time)) * 86400.0 <= ? + 0.5` — inclusive, so
  exactly-6h events stay visible; +0.5 s absorbs julianday float rounding at the boundary.
- **Events tab:** default **6h**, defined in `EventListViewModel`
  (`defaultMaxDuration`). Persisted under a separate UserDefaults key
  (`<filterKey>.maxDuration`, `StoredMaxDuration` `.limited/.unlimited`) rather than in
  the EventFilter JSON blob, because synthesized Codable omits nil optionals — a nil in
  the blob would be indistinguishable from a pre-field legacy blob, and an explicit "Any"
  would get re-coerced to 6h. Key absent → 6h; `.unlimited` → no limit.
- **UI:** "Max Duration" section in `EventFilterSheet` — discrete slider, positions
  1–12 = hour caps, rightmost = "Any" (nil), value readout ("6h"/"Any"), footer copy
  explains the amenity-listing rationale. Filter-icon active indicator deliberately does
  NOT include maxDuration (the default is non-nil; it would always read active).
- **Tests:** PlayaDB `testEventOccurrenceRequestMaxDurationFilter` (5h59m/6h in,
  6h1m/12h out, nil = all; suite 207 green); iBurnTests `EventListDurationFilterTests`
  ×6 (default, browse/search flow-through, legacy-blob default, 3h round-trip, explicit
  Any persistence; suite 133 green).
- **Sim-verified:** SAT 5 default hides "Drama Dump & Gift" 12h and keeps the exactly-6h
  "Sunset to Sunrise" (inclusive boundary) and SUN 30's 5h45m twin; default persists
  across relaunch; search results exclude 12h rows. The "Any" path was verified by
  injecting the persisted `.unlimited` pref into the app-container plist and relaunching
  (12h rows reappear, matching the original bug screenshot lineup) — the XcodeBuildMCP
  HID layer cannot drag SwiftUI sliders, so the slider gesture itself is covered by unit
  tests + code review. **Gotcha for future automation:** the app reads prefs from the
  app-container plist; `simctl spawn defaults write <bundle-id>` writes the user-level
  domain the app never reads (procedure now in drive-app flows.md).
- **Pre-existing bug found during verification (follow-up):** event SEARCH results
  drop one of two same-timestamp events — searching "Drama" shows "Drama Prevention
  Darkwad Station" (5h45m, Sun 6pm) but not "Drama Dump & Gift" (5h45m, same exact
  start/end), though browse mode shows both and both are in the FTS index. Likely a
  dedup/collision keyed on occurrence timestamps rather than event uid somewhere in the
  search result assembly. Unrelated to the duration filter (reproduces with it set to
  Any). Not fixed in this session.
- **Test hygiene note:** `EventListDurationFilterTests` leaves its UUID-keyed
  `EventListDurationFilterTests.<UUID>.maxDuration` entries in the simulator app's
  UserDefaults plist (keys are unique per run, so no cross-test pollution — just litter).

## Part F — Stale first row again: anchor-id collision on same-day filter changes (FIXED)

**Symptom (user screenshot, 26.5 sim, 3:21 PM):** Events tab, THU 3 selected; first row
shows "Drama Dump & Gift — Thu 12:00am (12h)" even though the max-duration filter is 6h.
Rows 2+ correct (Midnight Tacos 30m, Midnight Ramen 2h, Jazz Jam Session 2).

**Diagnosis — stale rendered row, not a query bug.** The sim's app-container plist held
`eventListFilter.maxDuration = {"limited":{"_0":21600}}` (6h), so the SQL query provably
excluded 12h occurrences at screenshot time; the rendered 12h row could not be in the
result set. Confirmed by the fixed build: THU hour-0's true first row is
"Sunset to Sunrise at the LandHo! Port (6h)" — in the user's screenshot the stale Drama
Dump row sat exactly where LandHo should be, with rows 2+ matching the query.

**Root cause** (`iBurn/ListView/EventListView.swift`): the b211090 fix namespaced the
hour-scrub anchor id by day (`HourAnchorID{day, hour}`), which fixes day-switch collisions
but is still a *positional* identity. Any same-day data change that swaps which row is
first in an hour section — moving the Max Duration slider (Any ↔ 6h), toggling an event
type, etc. — re-emits the buckets while day+hour stay constant, so the NEW first row gets
the SAME anchor id as the OLD one and the persistent LazyVStack resurrects the cached old
row view (stale label + stale tap closure; same mechanism as Part B, different trigger).

**Fix:** eliminate synthesized positional identity. First-in-section rows now use their own
occurrence uid as the anchor id (`button.id(row.object.uid)` — identity ≡ content, so
collisions are impossible for any data change), and the hour-index overlay resolves
hour → first-row uid from `viewModel.browseSections` at `scrollTo` time (with a guard for
vanished sections). `HourAnchorID` and `anchorDay` deleted; `rowButton` takes
`isScrollAnchor: Bool` instead of `scrollAnchorHour: Int?`.

**Verification (26.5 sim, fixed build):** THU first row = LandHo 6h (inclusive boundary
still honored, no 12h rows); filter sheet type toggle 🎉 off → first row updates live to
Midnight Tacos 30m (this exact step went stale pre-fix), toggle back on → LandHo returns;
first-row tap pushes the correct occurrence detail (Thursday 9/3 12:00 AM–6:00 AM);
hour scrub still scrolls (short jumps land exactly; a cross-day-length jump, e.g.
12am → 8pm, can land on a blank viewport until the next touch materializes rows — a
pre-existing LazyVStack far-target estimation artifact, identical under the old id scheme
since scrollTo resolves the same destination row). iBurnTests suite green.

**Automation notes:** the strip's digit labels are text-only AX elements — `tap` refuses
them, but `touch {down:true, up:true}` on the digit's elementRef drives the scrub
(the "8 PM" scrubber bubble may stick afterwards because the synthetic touch skips the
DragGesture `.onEnded` reset — harmless artifact, not app state).

### Worktree build note (for future sessions)

Building an app-repo worktree without re-cloning everything: symlinking `Pods/` to the main
checkout works, and non-SwiftPM submodules can stay empty (Pods' dev-pod file refs resolve
relative to the real Pods dir), but `Submodules/iBurn-Data` must be a REAL checkout —
SwiftPM's sandboxed manifest loader refuses symlinked package roots ("manifest … cannot be
accessed"). `git clone --local <main>/Submodules/iBurn-Data <wt>/Submodules/iBurn-Data` +
`checkout <pinned-sha>` is fast (hardlinked objects). Also copy `BRCSecrets.m`,
`InfoPlistSecrets.h`, `GoogleService-Info.plist` into `<wt>/iBurn/`. And beware `git reset
--hard` in such a worktree: it replaces submodule-path symlinks with empty dirs.
