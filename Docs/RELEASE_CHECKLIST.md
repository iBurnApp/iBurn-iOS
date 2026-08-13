# iBurn iOS — Release Checklist

A **maintained, year-over-year** checklist for shipping an iBurn release to TestFlight and the
App Store. This is not a dated session doc — update it in place whenever a release surfaces a new
gotcha, and re-use it every season.

Companion runbooks (read these for the *how*; this file is the *what*):

- `Docs/2026-07-03-2026-year-update-plan.md` — annual rollover master runbook
- `Docs/2026-07-18-api-data-refresh.md` — API fetch + seed regeneration
- `Docs/2026-08-06-placement-data-embargo-and-passcode.md` — embargo tiers + unlock passcode
- `Submodules/iBurn-Data/CLAUDE.md` and `scripts/BlackRockCityPlanner/CLAUDE.md` — data pipelines

> **Public document.** Never record the embargo passcode, its hash, or where embargoed data comes
> from in this file. Secrets live in gitignored `iBurn/BRCSecrets.m` and in GitHub Secrets.

---

## First-2026-Build Status (2026.0 / build 109, as of 2026-08-11)

Snapshot for the first 2026 App Store submission. Replace this section wholesale each season.

**Verified / done**

- [x] Year rollover complete — `YearSettings.plist` on 2026 (Aug 30 – Sep 7, new Man coordinates),
      packages renamed `iBurn2026*`, database file bumped, embargo defaults key re-armed.
- [x] Both year-hardcoded geocoder paths bumped to `data/2026`
      (`PlayaGeocoder.xcodeproj` `bundle.js` reference + BRCP `src/geocoder/index.js`).
- [x] Two-tier embargo shipped: camps + camp-hosted events unlock at `CampLocationUnlock`
      (2026-08-23T07:01Z), art + art-located events at `EventStart`.
- [x] Camp boundary map layers embargo-gated (`CampLayerVisibility` → `MapLayerManager`),
      live re-resolve on `.BRCEmbargoDidClear`.
- [x] Annotation gating routed through the pure `MapRegionAnnotationFilter` seam, covered by
      `EmbargoTierTests`.
- [x] Real placement geojson dropped into `Map.bundle` (Aug 9) — outlines + labels non-empty and
      gated; no `MOCK_LOCATIONS` sentinel present in `APIData.bundle`.
- [x] Data refreshed Aug 11 (iBurn-Data `179f801`): API counts 331 art / 1190 camps / 2606 events /
      495 MVs; placement re-applied (1183 camps with distinct centroid GPS); tiles regenerated for
      the upstream Point 3 CPN move; PlayaDB suite 291 green.
- [x] Seeds regenerated Aug 11 from that data and **verified on-sim**: fresh install restores both
      seeds instantly (log: `PlayaDB seed restored`), and a backdated `update_info` + deleted row
      correctly triggered a full re-import from the newer bundled JSON.
- [x] `MARKETING_VERSION = 2026.0` on all targets; `CURRENT_PROJECT_VERSION = 109` on **both**
      app and watch targets (watch was 108 — fixed 2026-08-11).
- [x] CI/deploy/PR workflows moved to `macos-26-arm64` + Xcode 26.6 (was 16.4, which predates the
      iOS 26 SDK) with iPhone 17 Pro test destinations. Runner image confirmed to ship 26.6.
- [x] Mock-data ship guards in place at all three layers (playa-seed, `MockDataShipGuardTests`,
      deploy.yml "Refuse mock placement data").
- [x] Nearby-screen / nearby-card embargo leak found in the Aug 11 audit (region-sourced
      art/camps/events with no tier gate — presence and rank leak placement) and gated like the
      map path, with `.BRCEmbargoDidClear` restart on unlock.
- [x] **Watch app had no embargo gating at all** (found in the Aug 12 watch audit: list
      distances, metre-precision Nearby, Navigate with live bearing — `BRCEmbargo` was
      iOS-only). Fixed via the shared `LocationEmbargo` seam in PlayaDB + `WatchEmbargo`
      glue; phone passcode unlock latches over `PeerSyncManager`. Verified locked on an
      erased Ultra 3 sim (`375e0399`).
- [x] SwiftUI detail share button now emits real iburnapp.com deeplinks via the
      `ShareURLBuilder` seam (it previously shared a plain string; locked tiers omit
      lat/lng/addr) (`9a38cc78`).
- [x] Watch scheme builds clean at 2026.0 (109); watch seed restore verified on-sim
      (331/1190/2587/5240). Five locked-state 410×502 watch screenshots in
      `fastlane/screenshots/watch/en-US/` (ASC natives at 422×514 kept alongside).

**Pending / needs human action before tagging**

- [ ] App Store metadata entry (release notes / description / keywords / screenshots) —
      drafts live in `fastlane/metadata/en-US/`; still must be pasted into App Store Connect.
- [ ] Full test pass + archive on the release commit.
- [ ] Passcode distribution to authorized early users (Placement etc.).

*(Removed from this list 2026-08-12: `UPDATES_URL` secret verification and public `data/2026/`
publish — those assumed an in-app OTA data-update feature, which does not exist in 2026. See §5.)*

---

## 1. Annual Year Rollover

Do this in June/July. Everything below is year-stamped and silently wrong if missed.

- [ ] `iBurn/YearSettings.plist` — `PlayaYear`, `EventStart`, `EventEnd`, `CampLocationUnlock`.
      *Why:* drives event windows, gate countdown, and every embargo unlock date. `EventStart`/
      `EventEnd` use the midnight-PDT-as-UTC convention (`07:00:00Z`).
- [ ] `YearSettings.plist` — `ManCenterLatitude` / `ManCenterLongitude`.
      *Why:* the Man moves most years; map centering, distance sorting, and the geocoder origin all
      depend on it.
- [ ] `CampLocationUnlock` present. *Why:* a missing key falls back to `EventStart`, which is
      *stricter*, so camps stay locked past the date the API ToS allows — a silent regression.
- [ ] Rename data packages `iBurn<YEAR>APIData` / `Map` / `MediaFiles` — `Bundle+iBurn.swift`,
      `project.pbxproj` package product deps, `Packages/PlayaAPI/Package.swift`,
      `Packages/PlayaDB/Package.swift`, and the iBurn-Data root `Package.swift`.
- [ ] `iBurn/BRCDatabaseManager.m` — `iBurn-<YEAR>.sqlite` + folder name.
      *Why:* forces a clean rebuild so last year's rows can't linger.
- [ ] `iBurn/NSUserDefaults+iBurn.m` — `kBRCEntered<YEAR>EmbargoPasscodeKey` **and**
      `kBRCEntered<YEAR>BurningManRegionKey`.
      *Why:* re-arms the embargo so last year's unlock — passcode or playa visit — doesn't
      carry over.
- [ ] `iBurn/BRCArtObject.m` — default year.
- [ ] `iBurn/NSDate+iBurn.m` — mock-date fallback (used by the `iBurn (Mock Date)` scheme).
- [ ] **Hardcoded year paths (both, every year):**
      - [ ] `PlayaGeocoder/PlayaGeocoder.xcodeproj/project.pbxproj` — the `bundle.js` file
            reference embeds `Submodules/iBurn-Data/data/<YEAR>/geocoder/bundle.js`.
      - [ ] `Submodules/iBurn-Data/scripts/BlackRockCityPlanner/src/geocoder/index.js` — hardcodes
            the layout path for the year.
      *Why:* neither fails to build. The app just reverse-geocodes to **last year's street names**,
      which is easy to miss until someone reads a wrong address on playa.
- [ ] Re-date test fixtures into the new event window.
      *Why:* `BRCRecurringEventObject.eventObjects()` drops occurrences outside
      `eventStart…eventEnd`, so prior-year fixtures import **zero events** with no error.
      Touches `iBurnTests/Fixtures/*/event.json`, `BRCDataSorterTests`, `MockServices`.
- [ ] Grep for stragglers: `rg -n "20(2[0-9])" --glob '!Submodules' iBurn iBurnWatch Packages`.

## 2. Data Freshness

- [ ] API re-fetched for the current year (`fetch_and_geocode.js -y <YEAR>`), with real geocode
      success counts once placement drops. *Why:* early-season pulls have all-`null` locations.
- [ ] `update.json` timestamps refreshed and strictly `.iso8601` (**no fractional seconds**).
      *Why:* PlayaAPI decoding is strict and will throw.
- [ ] `update.json` has only `{file, updated}` top-level keys. *Why:* the legacy Yap importer
      crashes at launch on any extra key.
- [ ] Record counts sanity-checked against expectation (art / camps / events / MVs).
- [ ] `dates_info.json` range + major events match the year.
- [ ] Placement applied: camps geocoded, `camp_outlines.geojson` + `camp_labels.geojson` in
      `data/<YEAR>/Map/Map.bundle/` are real (not empty FeatureCollections, not last year's).
- [ ] GIS / map tiles regenerated from the official BMorg dataset for the year (or the generated-geo
      tippecanoe fallback if the org hasn't published). Bounds and street names spot-checked.
      *Note:* tippecanoe needs `-t "$TMPDIR"` under the agent sandbox.
- [ ] Geocoder `bundle.js` rebuilt after **any** `layouts/layout.json` change, and smoke-tested on a
      few addresses (a radial-and-annular intersection, a plaza, a distance-based address).
- [ ] Map styles reference the current year's asset bundle
      (`asset://iBurnData_iBurn<YEAR>Map.bundle`) in both light and dark JSON.
- [ ] Media/thumbnails downloaded for new records; audio tour present if released.
- [ ] URL sanitization held: no user-entered `url` values with spaces/commas.
      *Why:* strict `URL` decoding in PlayaAPI throws on them.
- [ ] No null-island (0,0) GPS records and no upstream test rows in the shipped JSON.
      *Why:* Aug 2026's `art.json` carried 17 records at `0,0` (rendering as 4,800-hour
      walks before the `PlayaDistanceString` clamp) including 4 BMorg test entries
      ("deputy test", "spec", "WG Test"…). The display clamp hides the distances, but the
      records still ship — filter or fix them at refresh time.

## 3. Seeds Regenerated

Run `swift run --package-path Packages/PlayaSeed playa-seed --fetch-media` — one run writes both
PlayaDB copies.

- [ ] `iBurn/PlayaDB-<YEAR>.zip` regenerated *after* the final data commit.
- [ ] `iBurnWatch/PlayaDB-<YEAR>.zip` regenerated (phone and watch restore from their own bundle).
- [ ] Legacy `iBurn/iBurn-<YEAR>.zip` (Yap seed) regenerated.
- [ ] Seed timestamps are newer than the API bundle they were built from.
      *Why:* the zips are gitignored and easy to leave stale; a stale seed ships last week's data
      and only re-imports if `needsImport` notices the bundled JSON is newer.
- [ ] New thumbnails committed to `MediaFiles.bundle` in the submodule.
- [ ] Row counts verified on-device after a fresh install (see the `drive-app` skill).

## 4. Embargo Verification

The highest-stakes section. A leak here is a real-world problem, not a bug.

- [ ] Two-tier unlock dates correct for the year: camps + camp-hosted events at
      `CampLocationUnlock`; art + art-located events at `EventStart`.
- [ ] **The unlock rule is strict on both platforms** (since 2026.0). A tier's locations are
      shown only when

          passcodeUnlocked || (inRegion && now >= <tier unlock date>)

      A date alone never unlocks anything: the device clock is user-settable, so the old
      "after `EventStart`" check was defeated by moving Settings ▸ Date & Time forward — and
      it *latched* that into the passcode flag, unlocking the device for the season. The
      un-forgeable half (having been inside `BRCLocations.burningManRegion`) is what
      persists: `kBRCEntered<YEAR>BurningManRegionKey` on the phone,
      `embargoRegionSeen` on the watch. One rule, one implementation:
      `PlayaDB.LocationEmbargo`, adopted by `iBurn/EmbargoService.swift` (which `BRCEmbargo`
      now merely fronts) and `iBurnWatch/WatchEmbargo.swift`.
      *Consequence — check before every submission:* **off-playa users, including App Review,
      now always see a locked map.** Nothing unlocks by waiting. The App Store Connect review
      notes must therefore carry unlock instructions and the passcode (private ASC field
      only — never in this repo). Same for TestFlight testers who want to see locations from
      home.
      *Consequence for users:* someone at home stays locked past the unlock dates unless they
      enter the passcode. Accepted for 2026.0; a server-side design for no-GPS auto-unlock is
      2027 work.
- [ ] No `MOCK_LOCATIONS` sentinel in `data/<YEAR>/APIData/APIData.bundle/`.
- [ ] `camp_outlines.geojson` / `camp_labels.geojson` are not the previous year's fixtures
      (the deploy workflow greps for `<name>_<lastyear>`).
- [ ] `MockDataShipGuardTests` green (this is the in-app copy of the same guard).
- [ ] **Audit every new annotation / location surface added this season.** Any code path that can
      put a coordinate on screen — map annotations, callouts, address strings, search results,
      "nearby" cards, watch complications, widgets, deep links, exports — must route through the
      embargo check (`MapRegionAnnotationFilter` is the pure, testable seam for the map path) and
      have a unit test for the locked case. *Why:* the 2026 camp-boundary layers rendered
      unconditionally for a full year because the style JSON bypassed `BRCEmbargo` entirely.
      Assume any surface written since last season is ungated until proven otherwise.
      *Known-ungated but unreachable in 2026.0:* the AI "Right Now" flow
      (`iBurn/AISearch/RightNowViewModel.swift` / `RightNowWorkflow.swift`) takes a region with
      no embargo check — it ships dark behind `featureFlag.search.useAI` (default off). Gate it
      before that flag ever defaults on.
      *Live-refresh note:* both remaining unlock paths post `.BRCEmbargoDidClear` — passcode
      entry (`EmbargoPasscodeViewModel`) and region entry (`BRCAppDelegate
      -enteredBurningManRegion`, which posts only when the verdict actually flips). The one
      case with no live refresh is a tier's date arriving while the app is already running on
      playa (nothing re-evaluates on a timer); locations appear on the next relaunch, or the
      next region callback.
- [ ] **The watch target gates through `WatchEmbargo`/`LocationEmbargo`, not `BRCEmbargo`** —
      any new watch surface must call `WatchEmbargo.distance(for:from:)` /
      `canShowLocation(for:)`. `BRCEmbargo` is invisible to the watch target, so an iOS-side
      audit passes while the watch leaks (exactly what shipped-almost-happened in 2026.0:
      the watch had zero gating until the Aug 12 audit). Watch unlock = same dates from the
      shared `YearSettings.plist` + phone-passcode latch via `PeerSyncManager`.
- [ ] Share/deeplink URLs (`ShareURLBuilder`) omit lat/lng/addr for locked tiers — covered by
      `ShareURLBuilderTests`; keep those green and re-audit if new params are added.
- [ ] Manual sim check: fresh install → locked state hides camp outlines even with
      "Show Camp Boundaries (Always)" enabled → unlock reveals them live, without relaunch.
      Unlock for this check with the passcode, or by simulating a playa fix
      (`xcrun simctl location <UDID> set 40.7864,-119.2065`) once the tier's date has passed —
      **not** by moving the clock, which no longer unlocks anything.
- [ ] Manual sim check: locked state shows no coordinates in list rows, detail views, or search.
- [ ] Passcode: hash present in gitignored `iBurn/BRCSecrets.m` and in the
      `EMBARGO_PASSCODE_SHA256` GitHub secret; unlock verified in the sim.
- [ ] **Nothing embargoed in the public repo.** No placement data pushed to public
      `iBurnApp/iBurn-Data` before the org releases it.
- [ ] **Nothing embargoed in screenshots.** App Store screenshots and any marketing images must be
      captured in the locked state, or with fixture data — no real camp locations, no camp outlines.
- [ ] **Nothing embargoed in `Docs/`, commit messages, or PR descriptions.** This directory is
      public: no passcode, no hash, no provenance details about where restricted data comes from.

## 5. OTA Updates — not a 2026 feature

There is **no in-app remote data-update feature** in 2026 (possible 2027 work). Data ships only
inside app builds: the pre-baked seed plus bundled JSON, with `needsImport` re-importing when a
build ships JSON newer than the seeded DB (this path is verified — see §3). Consequences:

- [ ] Mid-event data refreshes require **point releases** (`<YEAR>.1`, `.2`, …) — keep the archive
      lane warm and budget for App Review turnaround during the event.
- [ ] Public `iBurnApp/iBurn-Data` publishing still matters for the open-source project and the
      Android app, but on the *post-release* schedule (§10), not as a ship blocker.

If OTA lands in 2027, restore these checks: `UPDATES_URL` secret re-pointed to the year's public
`update.json` (verify manually — secrets can't be diffed); the public repo serves that path with a
200 and valid JSON; `data/<YEAR>/` published with embargo timing respected; an in-app update
verified to apply cleanly over a shipped seed.

## 6. Versioning

- [ ] `MARKETING_VERSION` set on **both** the `iBurn` and `iBurnWatch` targets (Debug *and* Release
      configurations — there are four build-config entries in total).
- [ ] `CURRENT_PROJECT_VERSION` **identical** on the `iBurn` and `iBurnWatch` targets.
      *Why:* App Store Connect rejects a paired watch app whose build number doesn't match the
      phone app. This has drifted before — 2026.0 sat at app 109 / watch 108.
- [ ] Build number is higher than the last uploaded build for this marketing version.
- [ ] `git status` clean of accidental pbxproj noise before committing — `xcodebuild` flips
      `DEVELOPMENT_TEAM`; revert that rather than committing it.

## 7. Tests

- [ ] `xcodebuild test -scheme iBurnTests` green, including `MockDataShipGuardTests` and
      `EmbargoTierTests`.
- [ ] `swift test --package-path Packages/PlayaDB` green (embargo-dependent tests may legitimately
      *skip* pre-drop — confirm they run once real locations exist).
- [ ] `swift test --package-path Packages/PlayaAPI` green.
- [ ] Watch scheme (`iBurnWatch`) builds.
- [ ] `iBurn (Mock Date)` scheme launches and lands inside the event week.
- [ ] Manual flow pass per `.claude/skills/drive-app/references/flows.md`; update that doc if
      reality has diverged.
- [ ] **Launch on an iPad simulator** (e.g. iPad Pro 13-inch, current iOS) — fresh install through
      onboarding *and* a second launch, in both orientations. *Why:* iPad's floating top tab bar
      puts views in a different hierarchy than iPhone's docked bottom bar; 2026.0 shipped a
      launch-blocking `no common ancestor` constraint crash that no iPhone run could ever hit.

## 8. Build / Archive

- [ ] `git submodule update --init --recursive` — submodule pointer is at the intended data commit.
- [ ] `pod install` after any Podfile change.
- [ ] Local secret files exist: `iBurn/BRCSecrets.m`, `iBurn/InfoPlistSecrets.h`,
      `iBurn/GoogleService-Info.plist` (CI regenerates these from GitHub Secrets).
- [ ] Xcode version pinned in `.github/workflows/{ci,deploy}.yml` (`DEVELOPER_DIR` **and**
      `xcode-version`) matches what the app actually builds with locally, and is available on the
      runner image. *Why:* an SDK-version mismatch fails late, inside the archive step.
- [ ] Archive builds from `iBurn.xcworkspace` (never the `.xcodeproj`), scheme `iBurn`, Release.
- [ ] `bundle exec fastlane ios beta` succeeds locally or via the deploy workflow.
- [ ] dSYMs uploaded to Crashlytics (the `beta` lane does this; `refresh_dsyms` covers Apple-signed
      rebuilds afterward).

## 9. App Store

- [ ] Release notes written for this version — `fastlane/metadata/en-US/release_notes.txt`.
- [ ] Description and keywords reviewed — `fastlane/metadata/en-US/{description,keywords}.txt`
      (keywords ≤ 100 characters including commas).
- [ ] Screenshots refreshed for the current device sizes, **captured without embargoed placement
      data** (see Embargo).
- [ ] **Screenshot pixel sizes match what ASC actually accepts** — simulator-native captures are
      usually NOT accepted sizes; aspect-resize + center-crop rather than re-shooting. As of
      2026 ASC accepts (portrait):
      - iPhone 6.5"-class: **1284×2778** (or 1242×2688) — iPhone 17 Pro Max native is 1320×2868;
        `sips --resampleWidth 1284` then `--cropToHeightWidth 2778 1284` (≈6 px off top+bottom).
      - iPad 13": **2064×2752** (or 2048×2732) — iPad Pro 13" sim is natively 2064×2752.
      - Apple Watch: **410×502** — Ultra sim is natively 422×514; scale to 410 wide, letterbox or
        crop to 502.
      Keep the untouched natives in a sibling `*-native-<WxH>/` folder; check "View All Sizes in
      Media Manager" in ASC if these numbers have drifted since 2026.
- [ ] Age rating, privacy nutrition label, and support/marketing URLs still accurate.
- [ ] App Review notes mention that location data is embargoed by the event organizer and that some
      map content unlocks on a date — reviewers otherwise see an "empty" map and may reject.
- [ ] Phased release / manual release decision made relative to gates opening.

## 10. Post-Release

- [ ] Tag the release `v<MARKETING_VERSION>` (e.g. `v2026.0`) — the deploy workflow triggers on
      `v*` tags and runs the `beta` lane.
- [ ] Confirm the deploy run passed its "Refuse mock placement data" guard.
- [ ] Verify the build appears in TestFlight and installs on a real device.
- [ ] **Public repo sync after the org releases location data** (2026: gates open 2026-08-30) —
      push `data/<YEAR>/` to public `iBurnApp/iBurn-Data`, and flip `.gitmodules` back to the
      public URL if it was pointed at the private repo.
- [ ] Push the app and submodule branches; merge to `master`.
- [ ] Watch Crashlytics for the first 24–48 hours; keep a point-release lane warm — in-event
      releases (`<YEAR>.1`, `.2`, …) are the norm.
- [ ] Update this checklist with anything that bit you this season.
