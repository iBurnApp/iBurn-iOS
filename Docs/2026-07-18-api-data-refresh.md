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

### Worktree build note (for future sessions)

Building an app-repo worktree without re-cloning everything: symlinking `Pods/` to the main
checkout works, and non-SwiftPM submodules can stay empty (Pods' dev-pod file refs resolve
relative to the real Pods dir), but `Submodules/iBurn-Data` must be a REAL checkout —
SwiftPM's sandboxed manifest loader refuses symlinked package roots ("manifest … cannot be
accessed"). `git clone --local <main>/Submodules/iBurn-Data <wt>/Submodules/iBurn-Data` +
`checkout <pinned-sha>` is fast (hardlinked objects). Also copy `BRCSecrets.m`,
`InfoPlistSecrets.h`, `GoogleService-Info.plist` into `<wt>/iBurn/`. And beware `git reset
--hard` in such a worktree: it replaces submodule-path symlinks with empty dirs.
