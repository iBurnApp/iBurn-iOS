# 2026-07-06: Watch Map Blank When Off-Playa + Location Simulation

## High-Level Plan

**Problem:** On a real Apple Watch far from Black Rock City, the watch app's map screen renders blank (background only). Console shows repeated "Crown Sequencer was set up without a view property" warnings and `NSOSStatusErrorDomain Code=-536870187` errors, but neither is the cause.

**Root cause:** `MapScreen` starts with `followUser = true`. As soon as the watch gets a real GPS fix, `displayCamera` centers on the user's projected position. `PlayaProjection` is a local equirectangular projection centered on The Man — a fix in (say) the Bay Area projects to a point hundreds of kilometers from the city in world space. The Canvas then draws only background: every street/fence/plaza is off-screen. The simulator never reproduced this because it had no (or no far-away) location fix, leaving the camera at `.zero` (city center).

`NavigationScreen` (Detail → Navigate) had the same hazard in a different form: it fits the camera to *you + the target*, so an off-playa fix zooms out to a ~500 km span where the city is an invisible dot.

**Solution:**

1. New `PlayaMapData.pointOnPlaya(for:maxDistanceMeters:)` in PlayaGeo (default radius 10 km — covers the fence, deep playa, and the airport with margin). Projects a coordinate and returns `nil` when it's farther than the radius from The Man.
2. `MapScreen.userPoint` and `NavigationScreen.userWorldPoint` use it. Off-playa fixes now behave exactly like "no location": map shows the city overview, no user dot, recenter button centers the city; Navigate fits the target (or city bounds).
3. Location simulation for at-home testing: added `iBurnWatch/BlackRockCity.gpx` (The Man, 2026 coords from `YearSettings.plist`) and set it as the `LocationScenarioReference` in the shared `iBurnWatch` scheme (which already had `allowLocationSimulation = YES`). Running the watch app from Xcode now simulates standing at The Man; switch via Debug ▸ Simulate Location (choose "Don't Simulate" for real GPS).

**Log noise (not the bug):**
- "Crown Sequencer was set up without a view property" — known watchOS/SwiftUI framework noise triggered by `.digitalCrownRotation`; harmless.
- `NSOSStatusErrorDomain Code=-536870187` (0xE00002D5) — watchOS system-framework log spam (commonly haptics/audio related), not emitted by app code.

## Technical Details

### Files Modified
- `Packages/PlayaGeo/Sources/PlayaGeo/PlayaMapData.swift` — added `pointOnPlaya(for:maxDistanceMeters:)`.
- `iBurnWatch/MapScreen.swift` — `userPoint` uses the clamped projection.
- `iBurnWatch/DetailScreen.swift` — `NavigationScreen.userWorldPoint` uses the clamped projection.
- `iBurnWatch/BlackRockCity.gpx` — new; The Man at 40.783242, -119.207871.
- `iBurn.xcodeproj/xcshareddata/xcschemes/iBurnWatch.xcscheme` — `LocationScenarioReference` → the GPX (referenceType 0 = project-relative path; no pbxproj change needed for GPX files).
- `Packages/PlayaGeo/Tests/PlayaGeoTests/PlayaGeoTests.swift` — `testPointOnPlayaClampsFarOffFixes`: origin → (0,0); ~3 km deep playa → non-nil; San Francisco → nil.

### Behavior notes
- Nearby/Favorites screens intentionally unchanged: off-playa, Nearby's region query truthfully returns nothing ("Waiting for GPS…"/empty), Favorites shows large-but-true distances. Only camera math needed the clamp.
- iBurnWatch is *not* a filesystem-synchronized group in the pbxproj (unlike `iBurn`/`iBurnTests`), so new Swift files there need manual project surgery — that's why the helper lives in the PlayaGeo SPM package instead.

## Verification
- `swift test` in `Packages/PlayaGeo` — 19/19 pass (18 existing + new clamp test).
- `xcodebuild -workspace iBurn.xcworkspace -scheme iBurn` (iPhone 17 Pro Max sim) — succeeds, watch app embedded.
- Not yet re-run on the physical watch — user to rebuild `iBurnWatch` scheme to the watch; map should show the city overview immediately, and with the GPX active the blue user dot should sit at The Man.

## Cross-References
- `Docs/2026-07-04-events-empty-on-device-stale-seed.md` — previous on-device bug in the same 2026 update cycle.
- `Docs/2026-07-03-watchos-mvp-plan.md` — watch MVP that introduced MapScreen/NavigationScreen.
