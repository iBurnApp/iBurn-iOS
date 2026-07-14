# Official 2026 Map Tiles from BMorg GIS Data - 2026-07-13

## High-Level Plan

**Problem Statement**: BMorg published official 2026 GIS data
(`burningmantech/innovate-GIS-data` commit `3c69f43` "2026 GeoJSON (#7)",
2026-07-13). The 2026 tiles shipped so far (`Docs/2026-07-03-2026-year-update-plan.md`,
step A6) were built from *generated* geometry as a stopgap; the plan deferred an
official-data redo until BMorg published. This session completes that deferred item.

**Solution Overview**: Update the `bmorg/innovate-GIS-data` submodule inside
iBurn-Data, regenerate `data/2026/Map/Map.bundle/map.mbtiles` with tippecanoe from
the official GeoJSON (same layer mapping as 2025), and adapt the style filter +
app `imageMap` to BMorg's renamed CPN points. Also fix a stale-cache bug that
would have prevented existing installs from ever seeing new bundled tiles.

**Key Changes**:
1. `Submodules/iBurn-Data/bmorg/innovate-GIS-data`: `9d9892f` → `3c69f43` (adds `2026/GeoJSON/`).
2. Regenerated `data/2026/Map/Map.bundle/map.mbtiles` from official data (286 KB, 949 features, z4–14, 8 layers: blocks/dmz/fence/outline/plazas/points/streets/toilets — same set 2025 shipped).
3. `data/2026/Map/Map.bundle/styles/iburn-{light,dark}.json`: points-layer exclusion filter extended for renamed CPNs.
4. `iBurn/MapViewAdapter.swift`: `imageMap` entries for renamed/new CPNs.
5. `iBurn/Bundle+iBurn.swift`: refresh the Application Support mbtiles cache when the bundled file changes.

## Technical Details

### Tile generation (run from `Submodules/iBurn-Data/data/2026/`)

2026 official data is *more complete* than 2025: `toilets.geojson` and
`dmz.geojson` are now included (2025 had to fall back to generated geo for both).
All 8 layers now come from official data.

**Gotcha — street names**: official `street_lines.geojson` only carries letter
names (`A`, `B`, … `K`, `ESP`, plus `Rods Road`, `Route 66`). The MapLibre style
labels streets via `{name}`, so letters were rewritten to the real 2026 names
using the mapping in `layouts/layout.json` `cStreets`:

```
ESP→Esplanade, A→Ararat, B→Bodhi, C→Chomolungma, D→Delphi, E→Eternal,
F→Fulcrum, G→Great Oak, H→Heiau, I→Iroko, J→Jiba, K→Kundalini
```

(291 of 573 features renamed; radial clock streets keep their `H:MM` names.)

```bash
# 1. rewrite letters → names into a temp copy (python json round-trip on
#    bmorg/innovate-GIS-data/2026/GeoJSON/street_lines.geojson)
# 2. tippecanoe (needs -t "$TMPDIR" under the Claude sandbox):
tippecanoe -t "$TMPDIR" --output=Map/Map.bundle/map.mbtiles -f \
  -L fence:../../bmorg/innovate-GIS-data/2026/GeoJSON/trash_fence.geojson \
  -L outline:../../bmorg/innovate-GIS-data/2026/GeoJSON/street_outlines.geojson \
  -L points:../../bmorg/innovate-GIS-data/2026/GeoJSON/cpns.geojson \
  -L blocks:../../bmorg/innovate-GIS-data/2026/GeoJSON/city_blocks.geojson \
  -L plazas:../../bmorg/innovate-GIS-data/2026/GeoJSON/plazas.geojson \
  -L streets:<temp renamed street_lines>.geojson \
  -L toilets:../../bmorg/innovate-GIS-data/2026/GeoJSON/toilets.geojson \
  -L dmz:../../bmorg/innovate-GIS-data/2026/GeoJSON/dmz.geojson \
  -z 14 -Z 4 -B0
```

The same command (with placeholder path) is documented in iBurn-Data `README.md`
and `CLAUDE.md`.

### CPN renames (points layer)

BMorg renamed several CPNs vs 2025. The style hides some points behind a `!in
NAME` filter and the app registers runtime icons keyed by exact `NAME`, so both
needed updating:

| 2025 NAME | 2026 NAME | Handling |
|---|---|---|
| `DMV` | `Department of Mutant Vehicles (DMV)` | added to style exclusion filter |
| `DMZ` | `Deep-Playa Music Zone (DMZ)` | added to style exclusion filter |
| `Station 6` | `ESD Station 6` | added to style exclusion filter |
| `Station 3` / `Station 9` | `ESD Station 3` / `ESD Station 9` | added `firstAid` imageMap entries |
| — (new) | `Arctica Outpost` | added `ice` imageMap entry |
| — (new) | `Recycle Camp` | added `recycle` imageMap entry (`pin_recycle` asset exists) |

Old keys were kept in both places, so the styles/app remain compatible with
either dataset.

### Stale tile cache fix (`iBurn/Bundle+iBurn.swift`)

`brc_cachedMbtilesURL` copies the bundled `map.mbtiles` into
`Application Support/iBurn/<year>/Map/` **only if the file is missing** — so any
install that had already launched the app would keep the old tiles forever after
an app update. (Observed live in the simulator: the map kept rendering the old
generated tiles until the fix.) Remote tile updates are dead code
(`BRCDataImporter.m` `loadDataFromLocalURL` early-returns for
`BRCUpdateDataTypeTiles`), so the bundle is the only writer of that file and it's
safe to refresh: the getter now deletes the cached copy when
`FileManager.contentsEqual` says it differs from the bundle, then falls through
to the existing copy-if-missing path.

### Verification

- `tippecanoe-decode` on z12/z13 tiles: all 12 themed street names + `Rods Road`
  present; CPN `NAME` properties intact.
- mbtiles metadata: 8 vector layers, bounds `-119.2408,40.7605,-119.1812,40.8035`
  (matches 2026 fence; city center moved ~south-west vs 2025).
- Official fence agrees with our generated `geo/fence.geojson` within ~10 m, so
  the existing layout/geocoder data needs no change.
- App built and driven in the simulator (iPhone 17 Pro Max, iOS 26.2): city
  renders from official blocks/outline, street labels show themed names, toilets
  / fence / DMZ / POI icons all present. Cache-refresh verified via md5 of the
  Application Support copy matching the new bundle after relaunch.

## Context Preservation

- 2025 precedent: `Submodules/iBurn-Data/Docs/2025-07-19-map-tiles-official-data.md`
  (same layer mapping; 2025 used generated toilets/dmz fallbacks that are no
  longer needed).
- Style contract: layer names `fence/outline/points/blocks/plazas/streets/toilets/dmz`;
  styles only reference `dmz, fence, outline, points, streets, toilets`. The
  `points` layer must carry uppercase `NAME` (satisfied natively by cpns.geojson).
  Street labels use lowercase `{name}`.
- `points` icons resolve via runtime images registered in
  `MapViewAdapter.mapView(_:didFinishLoading:)` — the bundle sprite sheet keys
  (`sprite.json`) are legacy and not what `icon-image: {NAME}` matches against.
- In-flight watchOS work (PlayaGeo `StreetLabelLayout`, `MapScreen`) was present
  in the working tree during this session and deliberately left uncommitted; the
  watch map draws from generated geo, not these tiles.

## Expected Outcomes

- Map shows official 2026 city geometry (streets, blocks, plazas, toilets, DMZ,
  fence) with correct themed street names and POI icons.
- Existing installs pick up new bundled tiles on next launch after updating.
- When BMorg pushes revised 2026 GeoJSON, rerun the documented tippecanoe command
  (README.md / CLAUDE.md in iBurn-Data) after bumping the submodule.

## Remaining Work

- 2026 placement data (camp_labels/camp_outlines geojson in Map.bundle) is still
  a placeholder — arrives closer to the event (see 2025 timeline: late August).
