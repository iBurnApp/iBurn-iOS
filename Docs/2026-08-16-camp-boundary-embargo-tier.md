# 2026-08-16 — Camp boundary map layer moves to the gates-open embargo tier

## High-Level Plan

**Problem.** The `camp-boundaries` style layer was gated on
`BRCEmbargo.canShowCampLocations()` — the *camp* tier, which for 2026 unlocks at
`CampLocationUnlock = 2026-08-23 00:01 PDT`, the Sunday one week before gates. The
boundary polygons are BMorg placement geometry and must stay hidden until gates open
(`EventStart = 2026-08-30`), the same tier art locations use.

**Fix.** Split the single `embargoAllowsCamps` input of
`CampLayerVisibility.resolve(...)` into two:

- `embargoAllowsBoundaries` ← `BRCEmbargo.canShowArtLocations()` — drives
  `camp-boundaries`.
- `embargoAllowsCamps` ← `BRCEmbargo.canShowCampLocations()` — still drives
  `camp-labels-big`, since a camp name at its placement centroid *is* camp-location
  data and is legitimately released a week early.

Both are still `&&`-ed with the user settings, so the settings toggles can only ever
subtract visibility.

## Technical Details

### `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/MapLayerManager.swift`

```swift
static func resolve(showCampBoundaries: Bool,
                    showCampBoundariesAlways: Bool,
                    showBigCampNames: Bool,
                    embargoAllowsBoundaries: Bool,
                    embargoAllowsCamps: Bool,
                    zoomLevel: Double) -> CampLayerVisibility {
    let boundariesVisible = showCampBoundaries && embargoAllowsBoundaries
    let labelsVisible = showBigCampNames && embargoAllowsCamps
    ...
}

static func current(zoomLevel: Double) -> CampLayerVisibility {
    resolve(showCampBoundaries: UserSettings.showCampBoundaries,
            showCampBoundariesAlways: UserSettings.showCampBoundariesAlways,
            showBigCampNames: UserSettings.showBigCampNames,
            embargoAllowsBoundaries: BRCEmbargo.canShowArtLocations(),
            embargoAllowsCamps: BRCEmbargo.canShowCampLocations(),
            zoomLevel: zoomLevel)
}
```

`current(zoomLevel:)` is the single entry point for both consumers
(`MapLayerManager` for the style layers, `MapViewAdapter` for the pin labels), so no
other call site needed changing. `BaseMapViewController` already re-resolves on
embargo unlock, which now covers the art-tier transition too.

### `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurnTests/EmbargoTierTests.swift`

- `makeCampLayers(...)` gained an `embargoAllowsBoundaries` parameter (defaults to
  `true`, matching the existing "unlocked" default).
- `testCampLayersHiddenWhileEmbargoedRegardlessOfSettings` now passes both flags
  `false`.
- New `testBoundariesStayHiddenAfterCampUnlockUntilGatesOpen` — pure-resolve check of
  the week between camp unlock and gates: labels draw, boundaries do not.
- New `testCurrentBoundaryVisibilityTracksTheArtTier` — end-to-end through
  `CampLayerVisibility.current`, time-travelling to `2026-08-25` (camps unlocked, art
  not → boundaries hidden) and `2026-08-31` (gates open → boundaries visible). Saves
  and restores `UserSettings.showCampBoundaries` / `showBigCampNames`.

The suite's `setUpWithError` sets `enteredBurningManRegion = true`, so the strict
rule (a date alone never unlocks) is satisfied and these cases exercise the tier dates
only — the strict half stays in `EmbargoStrictUnlockTests`.

## Commands

```bash
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64' \
  -only-testing:iBurnTests/EmbargoTierTests 2>&1 | xcsift -f toon -w
# passed_tests: 48, failures: 0
```

Note: package resolution needs network, so this run required the sandbox disabled.

## Expected Outcomes

- Between 2026-08-23 and 2026-08-30, camp names may draw at their centroids but no
  camp boundary polygons appear, regardless of the map filter toggles.
- At `EventStart` (or on passcode unlock / in-region + date), boundaries appear and
  follow the "Zoomed" / "Always" settings as before.

## Cross-References

- `Docs/2026-08-06-placement-data-embargo-and-passcode.md` — the two-tier embargo
  design and passcode flow.
- `Docs/2025-08-23-camp-layer-implementation.md` — original camp boundary layer.
