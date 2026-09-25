# 2026-09-24 — Xcode 27 SDK, UIScene, iOS 18 minimum, post-event cleanup

Branch `xcode-27-sdk`, draft PR [#254](https://github.com/iBurnApp/iBurn-iOS/pull/254).

## High-Level Plan

**Problem.** The 2026 event is over. Work had piled up on local `master` (188 commits ahead of `origin/master`, 2 behind), and the submodules were still on `2026-updates` branches. The user then installed **Xcode 27.1 beta 1**, which adds the iPhone Duo foldable. On that SDK the app aborted at launch, because apps built with the iOS 27 SDK must adopt the UIScene lifecycle.

**What we did.**
1. **Landed the 2026 season on remotes.**
   - Merged `origin/master` (README Play Store link, PR #252) into local `master` and pushed it (`bc90c998..d2eaf2d7`).
   - Fast-forwarded each submodule's `2026-updates` onto its `master` and pushed: iBurn-Data `3719d15..737b510`, BlackRockCityPlanner `3c3d264..38d81ec`. The SHAs didn't change, so the parent repo needed no submodule-pointer commit.
2. **New work goes on `xcode-27-sdk`,** with draft PR #254 against `master`. The user asked for this: master stays at the post-season state.
3. **Xcode 27 SDK bring-up.**
   - Adopted the UIScene lifecycle.
   - Raised the minimum OS to iOS 18 (a user decision).
   - Fixed an iOS 27 `UITab` assertion.
   - Fixed every deprecation and warning in our own targets.
4. **Crash fixes from Crashlytics** for the 2026 season (build 114).
5. **Leftover cleanup** from the 2026-09-12 Yap-removal session.
6. **Live Tracks design spike** for 2027: [`2026-09-24-live-tracks-spike.md`](2026-09-24-live-tracks-spike.md).

**How the session ran.** The main session orchestrated and handed work to subagents: Sonnet for read-only triage, Opus for implementation. Agents that ran in parallel edited only, with a single agent at a time owning `xcodebuild`. Late in the session builds and tests went through the **Xcode MCP** (`mcp__xcode__BuildProject` / `RunProject` / `RunAllTests`) against the user's open Xcode. The Xcode MCP is new in Xcode 27 and needs `XcodeOpenWorkspace` first to get user approval.

## Commits on `xcode-27-sdk`

| Commit | Change |
|---|---|
| `c1008608` | PlayaGeocoder iOS deployment target 12.0 → 16.6. Xcode 27's minimum is 15.0, and this was the only compile error. |
| `6691325d` | Accept Xcode 27 scheme format (drops `BlueprintName`). User preference: commit Xcode format rewrites, don't revert them. |
| `ef44f250` | Docs: Live Tracks spike. |
| `a44205cf` | Accept Xcode 27 pbxproj format. Remove the stale `DetailActionCoordinatorTests.swift` entry from the iBurnTests `membershipExceptions`; left over from a deleted test, it would have silently excluded the new file. |
| `9145e4a3` | Remove the dead `EKEventEditViewDelegate` from `DetailActionCoordinatorImpl`, which now imports CoreLocation instead of EventKitUI. Add `DetailActionCoordinatorTests` (13 tests). Fix the `DetailPageViewController` doc comment. |
| `b6b88d33` | Search index rail crash: `SearchResultIndex.scrollTarget(for:in:isUpdating:)`; the rail ignores taps while AI results are streaming; `isAISearching` is reset when a new search starts. 3 tests. |
| `611adf3f` | Emoji preload moved from a background queue to `DispatchQueue.main.async`; `preloadCommonEmojis` is `@MainActor`. |
| `601794dd` | `BRCMapView.reloadStyleIfNeeded()`: reloads only when in a window, not backgrounded, and the appearance actually changed. It catches up on `didMoveToWindow` and `didBecomeActive`. |
| `729a528f` | **Adopt UIScene lifecycle:** new `SceneDelegate.swift` and `UIApplication+MainWindow.swift`; Info.plist gets a `UIApplicationSceneManifest` with a single scene. |
| `04ffa3cc` | Reuse cached `UITab`s across map/search layout switches, for the iOS 27 assertion. |
| `2c11808b` | Minimum OS → iOS 18: pbxproj, PlayaGeocoder, Podfile and its post_install floor, and packages (`.iOS("18.0")`, `.watchOS("11.0")`, string form because the tools version is 5.9). Remove `#available` checks that are now always true. |
| `c668375d` | `UIScreen.main` → `UIApplication.shared.mainWindowScene?.screen`. |
| `56952381` | `applicationIconBadgeNumber` → `UNUserNotificationCenter setBadgeCount:`. |
| `88d67c62` | `String(contentsOf:)` with an explicit `.utf8` encoding. |
| `2576c175` | `traitCollectionDidChange` → `registerForTraitChanges`, in MLNMapView+iBurn, FloatingActionButton, BaseMapViewController and TabController. |
| `ffd44190` | `onChange(of:)` two-parameter and zero-parameter forms, 12 call sites. |
| `21ec9315` | `ObjectListDataProvider: SendableMetatype` for the isolated-conformance warning; `FavoritesView` capture changed to `[viewModel]`. |
| `9c92cb27` | Podfile: `target 'iBurnTests' do inherit! :search_paths end`. "Class X is implemented in both" console messages went from 144 to 0. |
| (this doc) | Docs, plus the CLAUDE.md default destination changed to iPhone 18 Pro Max, iOS 27.0. |

## Technical Details

### UIScene migration (`729a528f`)
- **Stays in `BRCAppDelegate`:**
  - Firebase, Appearance, and the UNUserNotificationCenter delegate with authorization and remote registration.
  - BGTask setup, logging, the OTA data check, and the location manager and its delegate.
  - Region unlock, badge, Appirater, `LocationStorage`, memory warning and willTerminate.
  - `startLocationUpdatesIfAuthorized` is now public in the header.
- **Moves to `SceneDelegate`:**
  - Window creation, the onboarding-vs-tabs root, `setupNormalRootViewController`, the "Locations Are Hidden" alert, onboarding completion, and removing the More tab's "Edit" button.
  - Deep links: `scene(_:openURLContexts:)` and `scene(_:continue:)`, plus the cold-launch `connectionOptions.urlContexts` and `.userActivities`, keeping the old 0.5 s delay.
  - `sceneDidBecomeActive` → start location updates.
- **Removed:** the empty resign, background and foreground app-delegate methods. The broken launch-options remote-notification path passed an NSDictionary where a `UNNotification` was expected.
- **Launch-order fix:** the location manager is now created before `dependencies` is first touched. Before, `CoreLocationProvider` could get a nil manager, which may be the real cause of the "Nearby: Location unavailable" backlog item.
- **Alerts** now go through `presentOnFrontmostViewController`, which presents over sheets and waits for `UIScene.didActivateNotification` if no scene is visible yet.
- **Other observers:** `UIApplication.didBecomeActive` and related notifications still post under a single scene, so the existing observers keep working (EmbargoUnlockScheduler, MapEventRefreshScheduler and others).
- **Deferred:** iPad multi-window (`BRCDeepLinkRouter` is a singleton holding one tab controller), state restoration.

### iOS 27 `UITab` assertion (`04ffa3cc`)
`NSInternalInconsistencyException: UIViewController cannot be shared between multiple UITab` came from `TabController.rebuildTabs`.
- A root view controller stays bound to the first `UITab` that wrapped it, even after `tabs = []`.
- Clearing `tabCache` on the switch to the plain layout meant switching back to `.searchTab` wrapped each root in a second tab.
- **Fix:** keep `tabCache` for the controller's whole lifetime.
- It showed up as 3 `TabConfigurationTests` failures. It would also have crashed the real app when toggling the Map Search Layout in Debug.

### Why deprecations didn't show as warnings before
Clang and Swift only warn about a deprecation when its version is at or below the deployment target, which was 16.6. The iOS 26 app-delegate lifecycle deprecations therefore stayed silent, and iOS 27 enforced them at runtime instead. Raising the target to 18 surfaced the rest.

### Crashlytics triage (read-only, Firebase MCP)
Scope: project `iburn-app`, iOS app `1:374351838691:ios:027f801ca9495902`, FATAL issues from 2026-08-01 to 2026-09-24. Builds seen: 108–111 and 114; 112 and 113 never shipped. There is no watch app in Firebase, so no watch crash data exists.

**Crashlytics grouping caveat:** issue `fe741015…` ("`_userInfoForFileAndLine`", 175 events) mixes unrelated crashes.
- 166 of its events are the nearby-card pager crash on build 111, already fixed in `4e04fdee`.
- The 3 events on build 114 are the search rail crash and a UIPageViewController crash (see Remaining Work).

| Issue | Status |
|---|---|
| Nearby-card pager out-of-bounds | Fixed in `4e04fdee` |
| TabController floating-button constraint | Fixed in `7557adda` |
| MapViewAdapter NaN CALayer position | Fixed in `31c3eb33` |
| `BRCDataImporter.m`, `YapViewHandler.swift` | Moot: Yap was removed in `d956ac2e` |
| Search rail scroll, emoji preload, map style during termination | **Fixed this session** |
| MapLibre `std::bad_alloc` (59 events / 33 users), `std::out_of_range` in the Metal renderer (54 / 10) | Third-party. Reason to do the MapLibre upgrade. |
| Keyboard/text internals, GRDB `EXC_BREAKPOINT` (1 each) | Third-party or OS |

The Xcode MCP `GetTopCrashIssues` (App Store Connect) only covers the last 14 days and returned nothing for `com.trailbehind.iBurn2010`.

## Test Results (final)
- **iBurnTests:** 663/663, via Xcode MCP on iPhone 18 Pro Max, iOS 27.0.
- **Package tests:** PlayaDB 368, PlayaAPI 74, PlayaColors 11, PlayaGeo 26, PlayaSeed 20, all passing.
- **Warnings:** zero from our own targets (app, iBurnWatch, iBurnTests, PlayaGeocoder, packages). The remaining libtool "has no symbols" warnings come from vendored Pods.
- **Manual app checks:**
  - Onboarding through the tab UI; background → foreground.
  - `iburn://art?uid=…` deep link, both warm and cold.
  - Map Search Layout cycled through every option with no crash.
  - iPhone Duo launches without the abort, but screenshots were black and `snapshot_ui` timed out.

## Context Preservation
- **Simulators:** Xcode 27.1 beta 1 ships the iOS 27.1 runtime, which has only the iPhone Duo. The user then installed the iOS 27.0 runtime (iPhone 18 Pro / Pro Max, 17, Air, 17e, iPads, and Apple Watch Series 12 / Ultra 4 / SE 3). The old iPhone 17 Pro Max iOS 26.5 destination is gone.
- **Sandbox:** `xcodebuild`, `xcrun` and `simctl` fail inside the sandbox (xcrun_db cache errors, CoreSimulatorService connection refused), so they need the sandbox disabled.
- **Permission-classifier denials this session:**
  - `git worktree remove` of the 4 merged worktrees (the user may run it themselves).
  - A read of files for the cleanup.
  - The scene agent's `xcodebuild`, which is why we moved to the Xcode MCP.
- **Xcode MCP:** the connection dropped once mid-session and came back with a new workspace id. Xcode tends to switch the run destination back to iPhone 18 Pro.
- **Xcode noise:** Xcode 27 rewrites the pbxproj and scheme format. The user prefers committing those rewrites; `DEVELOPMENT_TEAM` flips still get reverted.

## Remaining Work
- **UIPageViewController "No view controller managing visible view"** (1 event, build 114, backgrounded mid-swipe). Hypothesis:
  - `DetailPagingDataSource` builds a new `DetailHostingController` for every before/after request, so UIKit may get a different instance than the one it's scrolling.
  - `DetailHostingController`'s navigation-item updates cause relayouts mid-transition.
  - Suggested fixes: cache neighbouring controllers by index, and skip navigation-item updates while backgrounded.
- **Tab highlight after a layout switch** from More → Debug: the bar highlights Map, or nothing, while More's content stays on screen. It probably predates this branch, or it's iOS 27 beta behavior.
- **MapLibre upgrade** off the exact `6.18.0-patch0` pin to 6.20.0 or later, for the VoiceOver crash fix and the native OOM/out_of_range crashes above.
- **Dependabot:** 8 alerts on iBurn-iOS, 72 on BlackRockCityPlanner.
- **Repo hygiene:**
  - Remove the 4 merged worktrees (`../iBurn-iOS-2`, `../iBurn-iOS-3`, `.claude/worktrees/fervent-knuth-adf76a`, `.claude/worktrees/fix-event-day-occurrence`).
  - Triage the 13 unmerged local branches from 2025 plus `worktree-fix-ci-runner-labels`.
- **drive-app skill** (`.claude/skills/drive-app/SKILL.md`, `references/flows.md`) still says iPhone 17 Pro Max / iOS 26.5. The sandbox blocks writing to `.claude/skills`, so it needs a manual edit. It also needs the UIScene and Xcode MCP notes.
- **iPhone Duo:** verifying the foldable layout is still to do.
- **The old location recorder** (`LocationStorage`) is on by default with no opt-in. See the Live Tracks spike, and consider making it opt-in before 2027.
- The package tools version is 5.9; moving to 6.0 would switch on Swift 6 language mode, which would be a separate project.

## Dependency updates (`maintenance-deps`, stacked on `xcode-27-sdk`)

| Commit | Change |
|---|---|
| `1bc5c075` | SPM: MapLibre 6.18.0-patch0 (exact) → 6.31.0 (upToNextMajor; no 7.x exists; VoiceOver crash fixed upstream in 6.20.0). Firebase 12.1.0 → 12.19.2. Siren 6.1.3 → 7.0.3 (iOS 17 min, no API change). Zip/GRDB already latest (2.1.2 / 7.11.1). swift-protobuf dropped out of Firebase's graph. LicensePlist output regenerated. |
| `ca7943c2` | `bundle update`: fastlane 2.240.1, cocoapods 1.17.0, Bundler 4.0.21. dotenv held at 2.8.1 (fastlane requires `< 3`). CI Ruby 3.1 → 3.4, because excon/rbs/google-apis-* now need Ruby ≥ 3.2/3.3. Fixes all 8 open Dependabot alerts (json, excon, faraday, concurrent-ruby ×3, jwt, addressable); they close once the lock reaches the default branch. |
| `51435780` | `pod update`: CocoaLumberjack 3.9.0 → 3.10.0, LicensePlist 3.27.1 → 3.28.2; every other pod was already at its latest release. |
| `25369328` | Actions: checkout v7, cache v6, upload-artifact v7, github-script v9, claude-code-action @beta → @v1 (`direct_prompt` → `prompt`, tools via `claude_args`). |

**CocoaPods CDN workaround.** `pod update` under cocoapods 1.17 kept failing with `CDN: trunk URL couldn't be downloaded … Error in the HTTP2 framing layer`, although plain `curl` fetched the same URL fine. Forcing HTTP/1.1 in Typhoeus got past it:
```ruby
# h1.rb, used via RUBYOPT="-r/path/h1.rb" bundle exec pod update
require 'typhoeus'
module ForceH1
  def initialize(url, options = {}) = super(url, options.merge(http_version: :httpv1_1))
end
Typhoeus::Request.prepend(ForceH1)
```
`pod install` also rewrites the pbxproj in the xcodeproj gem's style (it renames the `XCLocalSwiftPackageReference` comments and adds empty lists). That rewrite is only cosmetic and was reverted.

**CI Xcode.** The workflows pin `Xcode_26.6` on `macos-26-arm64`. For Xcode 27, GitHub's preview image needs `runs-on: xcode-27` (actions/runner-images#14404), plus a matching `DEVELOPER_DIR` and `xcode-version`. Not changed yet.

**Submodules (unchanged).** DOFavoriteButton is 2 commits ahead of okmr-d/DOFavoriteButton (Swift 5, 2019), with nothing new upstream. PermissionScope is 7 ahead of nickoneill/PermissionScope, which is archived; the one upstream commit we lack is a 2017 ISSUE_TEMPLATE edit.

## Cross-References
- [2026-09-12-yap-removal-and-playa-bug-fixes.md](2026-09-12-yap-removal-and-playa-bug-fixes.md): known follow-ups closed here (EKEventEditViewDelegate, DetailAction tests, doc comment).
- [2026-08-28-maplibre-voiceover-crash-and-boundary-passcode.md](2026-08-28-maplibre-voiceover-crash-and-boundary-passcode.md): MapLibre pin context.
- [2026-09-24-live-tracks-spike.md](2026-09-24-live-tracks-spike.md): 2027 feature design. The user decided Q1 (minimum iOS 18) this session.

## Expected Outcomes
- The app builds with Xcode 27.1 beta 1 and launches on iOS 27 without the scene-lifecycle abort. Deep links, onboarding and background/foreground behave as before.
- The minimum OS is iOS 18, and our own targets have zero warnings.
- The three open build-114 crashes are fixed.
- All tests pass.
