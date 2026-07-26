# 2026-07-26 — Archive dependency cycle + missing onboarding video

## High-Level Plan

Two release-blocking regressions surfaced while preparing the 2026 build, both traceable to
project-structure changes made after the 2025 release:

1. **`Cycle inside iBurn; building could produce unreliable results.`** on archive builds —
   caused by the `Embed Watch Content` copy phase running *after* the `Crashlytics` run-script
   phase. Fix: reorder the two phases.
2. **The onboarding background video no longer plays** — `Media/onboarding_loop_final.mp4` was
   dropped from the target when `iBurn.xcodeproj` was converted to file-system-synchronized
   folder groups. Fix: move the asset inside the synchronized `iBurn/` folder.

Both fixes verified by a clean simulator build and a full `xcodebuild archive`.

---

## Problem 1 — Archive dependency cycle

### Symptom

```
Cycle inside iBurn; building could produce unreliable results.
Cycle details:
→ Target 'iBurn' has process command with output '…/InstallationBuildProductsLocation/Applications/iBurn.app/Info.plist'
○ Target 'iBurn' has copy command from '…/Release-watchos/iBurn.app' to '…/Release-iphoneos/iBurn.app/Watch/iBurn.app'
○ That command depends on command in Target 'iBurn': script phase “Crashlytics”
○ Target 'iBurn' has a command with output '…/Release-iphoneos/iBurn.app.dSYM'
```

### Root cause

The iBurn target's build phase order was:

```
… → [CP] Copy Pods Resources → Crashlytics → Embed Watch Content
```

Xcode gates each build phase on the previous one, which produced this cycle in **install/archive**
builds (it does not appear for normal `build` because the dSYM and installation-location tasks
aren't scheduled the same way):

| Edge | Why |
| --- | --- |
| `Copy Watch/iBurn.app` → `Crashlytics` gate | phase ordering — Embed Watch Content came last |
| `Crashlytics` → `GenerateDSYMFile` | the phase declares `${DWARF_DSYM_FOLDER_PATH}/…/DWARF/${TARGET_NAME}` as an input path |
| `GenerateDSYMFile` → installed `iBurn.app/Info.plist` | dSYM is generated from the binary inside the installed `.app` wrapper |
| `ProcessInfoPlistFile` → `Copy Watch/iBurn.app` | both tasks mutate the `.app` wrapper; Xcode orders the plist write after the watch embed |

…which closes back on `Info.plist`. Hence "CYCLE POINT" at
`InstallationBuildProductsLocation/Applications/iBurn.app/Info.plist`.

### Fix

`iBurn.xcodeproj/project.pbxproj`, target `63CE2A531987140F00F65B01 /* iBurn */`:

```diff
 				53B58DC0D493DF731BDDB99A /* [CP] Copy Pods Resources */,
-				D907AD6821215F20004A255A /* Crashlytics */,
 				00F14D6A9BA2DC60398A7732 /* Embed Watch Content */,
+				D907AD6821215F20004A255A /* Crashlytics */,
 			);
```

Embedding the watch app before the Crashlytics upload removes the
`Copy Watch → Crashlytics` edge; the remaining chain
(`Crashlytics → dSYM → Info.plist → ProcessInfoPlistFile → Copy Watch → earlier phases`) is acyclic.
It's also semantically correct: symbol upload should be the last thing the target does.

### Notes considered but not changed

* The Crashlytics phase declares `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)` as an input.
  `BUILT_PRODUCTS_DIR` is already absolute, so this expands to a nonexistent path
  (`/Users/…/iBurn-iOS//Users/…/Release-iphoneos/iBurn.app/Info.plist`) and creates no build-graph
  edge. It is Firebase's documented recommendation, so it was left in place.
* Both the phone and watch targets ship a product named `iBurn.app` (deliberate — the watch app
  installs as "iBurn"), so the archive contains `iBurn.app.dSYM` **and** `iBurn.app 1.dSYM`.
  That's expected, not a symptom of the cycle.

---

## Problem 2 — Onboarding background video missing

### Root cause

Commit `99b8cbd` ("Cleanup", 2025-10-18) converted the project to
`PBXFileSystemSynchronizedRootGroup` folders and emptied the iBurn target's Resources build phase.
Three resources lived *outside* the synchronized `iBurn/` folder and lost target membership:

| Old reference | Outcome |
| --- | --- |
| `Submodules/iBurn-Data/data/2025/iBurn-2025.zip` | already restored as `iBurn/iBurn-2026.zip` |
| `Submodules/iBurn-Data/data/2019/bundle.js` | dead — no code references it, left out |
| `Media/onboarding_loop_final.mp4` | **still missing** — this bug |

`BRCOnboardingViewController` looked the file up with
`bundle.path(forResource:ofType:)`, got `nil`, and then built
`URL(fileURLWithPath: moviePath ?? "")` — an empty path that silently produced a black background
instead of an error.

Confirmed against the built product: `iBurn.app/` contained no `onboarding_loop_final.mp4`.

### Fix

```bash
git mv Media/onboarding_loop_final.mp4 iBurn/onboarding_loop_final.mp4
rmdir Media
```

No pbxproj change is needed — the synchronized `iBurn/` root group picks the file up automatically
and classifies `.mp4` into the Resources phase. This matches how the database zips
(`iBurn/iBurn-2026.zip`, `iBurn/PlayaDB-2026.zip`) were already handled.

Also hardened `iBurn/BRCOnboardingViewController.swift` so a future regression is loud rather than
silent:

```swift
let contents = [firstPage, secondPage, thirdPage, fourthPage, lastPage]
if let movieURL = Bundle.main.url(forResource: "onboarding_loop_final", withExtension: "mp4") {
    super.init(backgroundVideoURL: movieURL, contents: contents)
} else {
    // The video ships as a resource in the iBurn folder; if it goes missing
    // fall back to a plain background instead of a black screen.
    assertionFailure("onboarding_loop_final.mp4 is missing from the app bundle")
    super.init(backgroundImage: nil, contents: contents)
}
```

`viewDidLoad` now guards `moviePlayerController` (imported from Onboard as an implicitly-unwrapped
optional, and `nil` on the image-background path) before configuring video gravity and the loop
observer.

---

## Verification

```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64'
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination "$DEST" 2>&1 | xcsift -f toon -w
# → status: success, 0 errors, 0 warnings

xcodebuild archive -workspace iBurn.xcworkspace -scheme iBurn \
  -destination 'generic/platform=iOS' \
  -archivePath "$TMPDIR/iBurn-cycle-check.xcarchive" CODE_SIGNING_ALLOWED=NO
# → ** ARCHIVE SUCCEEDED **  (no cycle diagnostic)
```

Archive contents checked:

```
iBurn.xcarchive/Products/Applications/iBurn.app/onboarding_loop_final.mp4   4990093 bytes
iBurn.xcarchive/Products/Applications/iBurn.app/Watch/iBurn.app            present
iBurn.xcarchive/dSYMs/{iBurn.app.dSYM, iBurn.app 1.dSYM, PlayaGeocoder.framework.dSYM}
```

Simulator product also confirmed to contain the video.

## Expected Outcomes

* `Product ▸ Archive` in Xcode completes without the dependency-cycle diagnostic.
* Onboarding shows the looping background video again on first launch.
* Crashlytics dSYM upload still runs (it's now the final phase).

## Remaining Work

* None for these two issues. Worth remembering the general rule for this project: **any new
  bundled resource must live inside `iBurn/` (or `iBurnWatch/`)** — root-level files are invisible
  to the synchronized folder groups.

## Cross-References

* `Docs/2026-07-25-playadb-default-yap-audit-and-migration.md` — the 2026 release prep this feeds into
* Commit `99b8cbd` — the synchronized-folder conversion that dropped the resource
* Commit `c30f29d` — embedded iBurnWatch as a companion app, which introduced the phase ordering
