# Handoff — org-GeoJSON geocoder (branch `reverse-geocoder`)

**Status: complete and verified. Ready to merge.**
Full session notes and rationale: `Docs/2026-07-25-reverse-geocoder-2026-audit.md`.

## What this delivers

BMorg's official GeoJSON (`bmorg/innovate-GIS-data`) is now the source of truth
for geocoding in **both** directions, replacing the handcrafted `layout.json`
city synthesis. Forward matters as much as reverse because the API data pipeline
geocodes camp GPS from playa addresses.

It also fixes two wrong 2026 street facts that had reached shipped artifacts:

| | was | now | reached |
|---|---|---|---|
| C street | Chomolungma | **Ceiba** | layout, geocoder bundle, **map tile labels** |
| Center Camp frontage arc | (unnamed → `"6:26 & undefined"`) | unnamed, falls back to nearest real street | geocoder bundle |

Rod's Road was removed by BMorg for 2026; the `Rods Road` features still in the
GIS drop are carryover and are listed as `retired_streets` in the config.

## Commits to merge (3 repos, bottom-up)

Nothing is pushed. **Push in this order** — the parent repo's gitlink is
unreachable until the submodule commits exist on their remotes.

### 1. BlackRockCityPlanner (`git@github.com:iBurnApp/BlackRockCityPlanner.git`), branch `2026-updates`
```
8f8a932 Geocoder over BMorg's official GeoJSON, both directions
3b84cb5 2026 corrections: C street is Ceiba; Rod's Road no longer exists
7a8ae48 2026 layout support: name the frontage arc, never emit undefined streets
```
Base: `ec84cd3`. New code lives in `src/orggeocoder/`; `src/geocoder/` (legacy)
is retained as the fallback for years with no GIS drop.

### 2. iBurn-Data, branch `2026-updates`
```
84a16bb 2026 geocoder: ship the org-GeoJSON build; add per-year geocoder configs
c69e44d 2026 corrections: C street is Ceiba; drop Rod's Road (street removed)
f8911da 2026: Rod's Road on the Center Camp frontage arc; geocoder validated vs BMorg GIS
```
Base: `c9f7bdb`.

> **Check the remote before pushing.** This worktree's `Submodules/iBurn-Data`
> has `origin = iBurnApp/iBurn-Data.git`, but the main checkout at
> `~/Documents/Code/iBurn-iOS` has `origin = iBurnApp/iBurn-Data-Private.git`.
> Push from the main checkout, or confirm with the user which is correct.
> (Same caution for the planner: this worktree's `origin` is a **local path**
> set up for submodule syncing; the main checkout has the real GitHub URL.)

Note `f8911da` names the frontage arc "Rod's Road" and `c69e44d` reverts that.
The intermediate state is wrong but the sequence is honest about the correction;
squash if you prefer a clean history.

### 3. iBurn-iOS, branch `reverse-geocoder`
```
a05ca4d Bump iBurn-Data: geocoder now reads BMorg's official GeoJSON
b48ef7b Bump iBurn-Data: C street is Ceiba, Rod's Road removed (2026 corrections)
156ae24 Bump iBurn-Data: 2026 geocoder validated vs BMorg GIS; Rod's Road fix
```
Base: `8cbdbde`. Only two kinds of change: the `Submodules/iBurn-Data` gitlink
and two `Docs/` files. **No app source was modified.**

## Merging into `2026-updates`

`2026-updates` has moved 7 commits ahead of this branch's base (PlayaDB
migration work + a CLAUDE.md simulator bump). **None of them touch
`Submodules/iBurn-Data`**, and both the old and new tips record the same
submodule SHA (`c9f7bdb`), so there is no gitlink conflict.

Verified conflict-free — `git merge-tree --write-tree 2026-updates
reverse-geocoder` exits 0:

```bash
git rebase 2026-updates reverse-geocoder    # clean
```

After merging, the submodule must be at `84a16bb`:
```bash
git submodule update --init --recursive
git -C Submodules/iBurn-Data rev-parse HEAD   # 84a16bb…
```

## Loose ends the merging agent must handle

1. **Android bundle is updated but UNCOMMITTED.** `iBurn-Android` has a modified
   `iBurn/src/main/assets/js/bundle.js` (verified byte-identical to the shipped
   iOS bundle). It had still been the **2025** build, so this is a real fix, but
   it belongs to a repo outside this branch's scope — commit it there separately.

2. **The full `iBurn` app target was never built.** This worktree has no `Pods/`
   installed (pre-existing condition, unrelated to these changes), so
   `xcodebuild -scheme iBurn` fails at the Pods xcconfig. What *was* verified:
   the `PlayaGeocoder (iOS)` framework builds clean (0 errors, 0 warnings) and
   embeds the correct 868KB bundle. Since no app source changed and the bundle
   path in `PlayaGeocoder.xcodeproj` is unchanged, risk is low — but do a build
   from the main checkout before merging.

3. **`PlayaGeocoderTests` was not executed** — the `PlayaGeocoder (iOS)` scheme
   has no test action configured. Its three assertions were instead verified
   directly against the new geocoder (`"6:15 & A"` and `"A & 6:15"` return
   identical valid coordinates; `"Center Camp Plaza @ 7:30"` resolves; reverse
   returns non-nil). Wiring up the test action would be a small win.

## Verification evidence

Re-runnable from `Submodules/iBurn-Data/scripts/BlackRockCityPlanner`:

```bash
npm install && npm test      # 17/17 files pass, coverage gates met, exit 0
```

| check | result |
|---|---|
| 512 official radial×ring intersections → reverse | 489 exact, 23 correctly named as the plaza on top, **0 wrong** (legacy: 44 wrong + 4 misclassified) |
| 1369 published 2025 camp addresses → forward | **all resolve** (legacy: 30 fail), median **7'** from published GPS, 98% within 150' |
| parity sweep, 2773-point city grid | 95.6% identical to legacy or within 5'; all 123 remaining differences favor org data |
| real JavaScriptCore (iOS engine) | 47ms setup, correct results |
| Android J2V8 call pattern | `window.prepare()` / `reverse` / `forward` / `forwardAsString` all correct |
| bundle | 868KB, prepares in 13ms (legacy: 1.2MB, 36ms) |
| map tiles | `tippecanoe-decode`: 211× Ceiba, 0× Chomolungma |

The forward-accuracy number measures *agreement*, not independent truth: those
published 2025 coordinates were themselves produced by the legacy geocoder. Its
tail is portals, where the org CPN is surveyed truth and legacy's position was
computed.

## How the pieces fit (for whoever maintains this next)

- `src/orggeocoder/schema.js` — absorbs BMorg's year-to-year schema drift.
  2024/25 ship `{type: arc|radial, width}` with themed ring names; 2026 ships
  `{source: annular|radial, kind, width_ft}` with bare letters; the plaza name
  key changed case. Expect this to need extending each year.
- `data/<year>/geocoder/config.json` (~20 lines) — the only handcrafted input
  left: letter→themed-name map, city bearing, `retired_streets`, and
  `gap_landmark_cpn` (names the Center Camp keyhole, where Esplanade has a real
  5:45–6:15 gap). Configs exist for 2025 and 2026.
- **Bundle build is two steps** (browserify can't `require` a `.geojson`):
  ```bash
  node src/cli/build_geocoder_data.js --data-root ../../ --year 2026 \
    --output ../../data/2026/geocoder/geocoder-data.json
  browserify src/orggeocoder/index.js -o ../../data/2026/geocoder/bundle.js
  ```
  The year is now hardcoded in exactly one place (`src/orggeocoder/index.js`),
  down from two.
- `src/orggeocoder/factory.js` — CLI tools keep their `--layout` argument and
  infer year/checkout-root from it, so every documented pipeline command is
  unchanged while running on org data.

## Suggested next work (not blocking)

- Source POIs from `cpns.geojson`: `poi.json` still places Greeters and the
  Airport by time+distance, landing 263' and 700' from their official CPNs.
- Point `PlayaGeo` (watch renderer) at org GeoJSON so `data/<year>/geo/*` and
  `layout.json` can retire for GIS-covered years.
- Native Swift/Kotlin ports of the reverse geocoder — it needs only bearing,
  haversine distance, point-in-polygon and a sorted-sample lookup (no
  turf/JSTS). `tests/OrgGeocoderTest.js`'s 512-intersection sweep is the shared
  conformance vector. This removes the JSContext startup cost behind the three
  blocking iOS call sites and would give the watch app addresses it currently
  lacks.
