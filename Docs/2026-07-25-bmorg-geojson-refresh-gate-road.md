# 2026-07-25 — BMorg GeoJSON refresh + Gate Road layer

## High-Level Plan

**Problem**: BMorg published an update to the official GIS dataset
(`burningmantech/innovate-GIS-data`). The 2026 map tiles were generated from the
previous commit, so the shipped tiles were stale.

**Solution**: Bump the nested `bmorg/innovate-GIS-data` submodule, regenerate
`data/2026/Map/Map.bundle/map.mbtiles`, and add the newly-published Gate Road as
a rendered layer.

**Key Changes**:
1. `Submodules/iBurn-Data/bmorg/innovate-GIS-data`: `3c69f43` → `e9e33e0`.
2. Regenerated `data/2026/Map/Map.bundle/map.mbtiles` — now **9 layers / 952
   features / 290,816 bytes** (was 8 / 949 / 286,720).
3. Added a `gate-road` line layer to `iburn-light.json` and `iburn-dark.json`.
4. Checked in `scripts/rename_official_streets.py` so the street-rename step is
   reproducible (it was an unsaved temp script last time — see "Reproducibility").
5. Updated the tippecanoe command in iBurn-Data `CLAUDE.md` + `README.md`.
6. `drive-app` skill: corrected the Appirater dismissal note in `flows.md`.

## Technical Details

### What changed upstream (`3c69f43..e9e33e0`, "2026 cpns gate road (#8)")

Two files:

- **`2026/GeoJSON/cpns.geojson`** — still 59 features; 4 gate-area CPNs moved
  (BMorg realigned the gate complex):

  | CPN | old | new |
  |---|---|---|
  | Box Office | `-119.239013,40.765055` | `-119.235670,40.768227` |
  | D Lot | `-119.239329,40.764309` | `-119.233825,40.768178` |
  | Gate Actual | `-119.237693,40.765087` | `-119.234088,40.768725` |
  | Will Call Lot | `-119.240781,40.764932` | `-119.237046,40.768406` |

  No renames, so **no style-filter or `imageMap` changes were needed** —
  `Will Call Lot` and `D Lot` remain in the points-layer `!in NAME` exclusion
  list, `Box Office` and `Gate Actual` still render.

- **`2026/GeoJSON/gate_road.geojson`** — new file, 3 LineStrings (148 points
  each), properties carry only `FID` (no name). This was the only file in
  `2026/GeoJSON/` not being tiled.

### Tile regeneration

Run from `Submodules/iBurn-Data/data/2026/`. `-t "$TMPDIR"` is required under the
Claude sandbox.

```bash
python3 ../../scripts/rename_official_streets.py \
  layouts/layout.json \
  ../../bmorg/innovate-GIS-data/2026/GeoJSON/street_lines.geojson \
  "$TMPDIR/street_lines_named_2026.geojson"

tippecanoe -t "$TMPDIR" --output=Map/Map.bundle/map.mbtiles -f \
  -L fence:../../bmorg/innovate-GIS-data/2026/GeoJSON/trash_fence.geojson \
  -L outline:../../bmorg/innovate-GIS-data/2026/GeoJSON/street_outlines.geojson \
  -L points:../../bmorg/innovate-GIS-data/2026/GeoJSON/cpns.geojson \
  -L blocks:../../bmorg/innovate-GIS-data/2026/GeoJSON/city_blocks.geojson \
  -L plazas:../../bmorg/innovate-GIS-data/2026/GeoJSON/plazas.geojson \
  -L streets:"$TMPDIR/street_lines_named_2026.geojson" \
  -L toilets:../../bmorg/innovate-GIS-data/2026/GeoJSON/toilets.geojson \
  -L dmz:../../bmorg/innovate-GIS-data/2026/GeoJSON/dmz.geojson \
  -L gate_road:../../bmorg/innovate-GIS-data/2026/GeoJSON/gate_road.geojson \
  -z 14 -Z 4 -B0
```

Result:

```
bounds = -119.273565,40.745943,-119.181240,40.803521   (was -119.240781,40.760545,-119.181240,40.803521)
tiles  = 35                                            (was 28)
layers = blocks dmz fence gate_road outline plazas points streets toilets
size   = 290816 bytes                                  (was 286720)
```

The west edge moves twice, for two independent reasons:

1. The 4 gate CPNs moving **east** pulled the old western bound in
   (`-119.240781` → `-119.237418` on the 8-layer intermediate run).
2. Adding `gate_road` then pushed it far **west** to `-119.273565`, since the
   approach road runs ~4 km southwest toward the highway.

### Reproducibility fix

The 2026-07-13 session generated the renamed streets file with an ad-hoc script
in a session scratchpad, which was garbage-collected — the mbtiles
`generator_options` still pointed at
`/private/tmp/.../1f727389-.../street_lines_named_2026.geojson`, a path that no
longer exists. That script had to be rewritten from the prose description in
`Docs/2026-07-13-official-2026-map-tiles.md`.

It's now checked in at `scripts/rename_official_streets.py`. Verified the
committed script reproduces the exact input used for these tiles
(`cmp` → byte-identical), renaming 291 of 573 features:

```
ESP→Esplanade(17) A→Ararat(18) B→Bodhi(18) C→Chomolungma(18) D→Delphi(16)
E→Eternal(16) F→Fulcrum(32) G→Great Oak(32) H→Heiau(32) I→Iroko(32)
J→Jiba(28) K→Kundalini(32)
```

### Gate Road style layer

`street_outlines` is a **fill** polygon (it carries the street bodies) and the
`streets` layer is symbol/labels only — so Gate Road, being a LineString with no
polygon counterpart, needed a real `line` layer. Inserted directly after
`outline` so it draws over the fence it crosses but under camp boundaries:

```json
{
  "id": "gate-road",
  "type": "line",
  "source": "composite",
  "source-layer": "gate_road",
  "layout": {"visibility": "visible", "line-join": "round", "line-cap": "round"},
  "paint": {
    "line-color": "#C3B8AB",
    "line-width": {"base": 1.4, "stops": [[8, 0.5], [12, 1.5], [14, 3], [17, 8], [22, 20]]}
  }
}
```

`line-color` matches each theme's `outline` fill so the road reads as the same
material as the city streets: `#C3B8AB` (light) / `#574e26` (dark). Layer order in
both styles is now `… fence → outline → gate-road → camp-boundaries → …`.

Features carry no `name`, so the line is deliberately unlabelled.

## Verification

- `tippecanoe-decode` over all 35 tiles: `gate_road` present with 57 tiled
  segments; tiled extent `-119.273758,40.745176 → -119.223633,40.772222` matches
  the source (small overshoot is the tile buffer).
- All 4 moved CPNs confirmed at their **new** coordinates in the max-zoom tiles;
  no features remaining at the old gate positions.
- All 12 themed street names present in the `streets` layer; zero leftover
  single-letter names.
- Both style files parse as valid JSON; `source-layer` is `gate_road`, matching
  the tippecanoe layer name exactly.
- `xcodebuild` iBurn scheme: **0 errors, 0 warnings**.
- Drove the app in the simulator (iPhone 17 Pro Max, iOS 26.2): city renders with
  themed street labels; panning southwest shows the three Gate Road lines running
  off toward the highway. Confirmed visually.

No app-target code changes were required. The stale-tile-cache fix from
2026-07-13 (`iBurn/Bundle+iBurn.swift:87`, `FileManager.contentsEqual`) is still
in place, so existing installs will pick up the regenerated tiles on next launch.

## Cross-References

- `Docs/2026-07-13-official-2026-map-tiles.md` — original migration to official
  BMorg geometry; CPN rename table and the stale-cache fix.
- `Submodules/iBurn-Data/Docs/2025-07-19-map-tiles-official-data.md` — 2025 work.
- `Submodules/iBurn-Data/CLAUDE.md` / `README.md` — canonical tippecanoe command.

## Expected Outcomes

- 2026 map tiles reflect BMorg's latest gate-complex geometry.
- Gate Road renders in both light and dark themes, giving arriving burners the
  approach road from the highway to the gate.
- Regenerating tiles next time is a two-command process with no unsaved
  intermediate steps.
