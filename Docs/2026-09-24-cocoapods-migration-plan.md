# CocoaPods → SwiftPM / Native Migration Plan

Date: 2026-09-24 (plan written, then implemented the same day; see "Outcome" at the end)
Branch at time of research: `maintenance-deps` (clean, HEAD `a9b82f72`)

## High-Level Plan

### Problem

CocoaPods trunk goes **permanently read-only on 2026-12-02** (test read-only window
2026-11-01..07; source: blog.cocoapods.org/CocoaPods-Specs-Repo). Existing `pod install`
keeps working off the CDN, but no pod will ever get another update, and the tool itself
(Ruby 3.1 + `cocoapods 1.16.2` in `Gemfile.lock`) is on borrowed time as Xcode moves.
iBurn still links 15 pods (13 trunk + 2 local podspecs in git submodules). Most are
abandoned (last releases 2015–2018, three are archived). Several are **not used at all**
any more, which the Yap/UIKit → PlayaDB/SwiftUI rewrites left behind.

### Solution overview

Leave CocoaPods in five phases. The app stays shippable after each one, and Podfile/Pods
stay in place until the last phase:

| Phase | Theme | Pods removed | Effort |
|---|---|---|---|
| **0** | Delete dead pods + trivial native swaps | DOFavoriteButton, KVOController, JTSImageViewController, TTTAttributedLabel, TUSafariActivity, CupertinoYankee, Anchorage, PureLayout, FormatterKit/TimeIntervalFormatter subspec | ~0.5–1 day |
| **1** | SPM/tool swaps | CocoaLumberjack → SPM, LicensePlist → pinned tool outside Pods | ~0.5–1 day |
| **2** | Small native rewrites | FormatterKit/LocationFormatter, BButton (+FontAwesome font), Appirater | ~1–1.5 days |
| **3** | Onboarding + permissions rewrite | Onboard, PermissionScope (+ submodule) | ~2–3 days |
| **4** | Deintegrate | CocoaPods itself (Podfile, Pods/, [CP] phases, xcconfigs, Gemfile, CI) | ~0.5–1 day |

**Total: about 5–8 focused dev days.** Phase 3 carries most of the risk because it is the
first-launch flow.

### Pod → usage → action → phase

Counts are from `rg` over `iBurn/`, `iBurnTests/` and `iBurnWatch/` (Pods, Submodules,
Docs and Packages excluded), as of 2026-09-24. "Call sites" means real API uses, not imports.

| Pod (locked ver.) | Files importing | Real call sites | ObjC? | SPM upstream / maintained | Action | Size / Risk | Phase |
|---|---|---|---|---|---|---|---|
| DOFavoriteButton 0.0.4 (submodule, local podspec) | 0 | **0** | no | no Package.swift; last release 2015 | **(d) delete** pod + submodule | S / low | 0 |
| KVOController 1.2.0 | 0 | **0** | no | archived (facebookarchive) | **(d) delete** | S / none | 0 |
| JTSImageViewController 1.5.1 | 0 | **0** | no | no SPM, last release 2015 | **(d) delete** | S / none | 0 |
| TTTAttributedLabel 2.0.0 | 1 (`BRCAppDelegate.m` `@import`) | **0** | yes (import only) | no SPM, last release 2016 | **(d) delete** the import | S / none | 0 |
| TUSafariActivity 1.0.4 | 1 (`BRCAppDelegate.m` `#import`) | **0** | yes (import only) | has SPM (1.0.5), barely maintained | **(d) delete** the import | S / none | 0 |
| CupertinoYankee 1.0.2 | 1 (`NSDateFormatter+iBurn.m` `#import`) | **0** (the "for timeZone" comment is stale: `brc_burningManTimeZone` is iBurn's own) | yes (import only) | archived | **(d) delete** the import | S / none | 0 |
| Anchorage 4.5.0 | 1 (`LabelAnnotationView.swift`) | 5 operator lines | no | has SPM, dormant since 2020 | **(b) native** `NSLayoutAnchor` | S / low | 0 |
| PureLayout 3.1.9 | 4 | 7 (`autoPinEdgesToSuperviewEdges` ×5, `autoAlignAxis` ×2) in 5 files | no | has SPM, dormant since 2021 | **(b) native** small `UIView.pinEdges(to:)` helper | S / low | 0 |
| FormatterKit/TimeIntervalFormatter 1.9.0 | 0 | **0** (`DateFormatters.stringForTimeInterval` already uses `DateComponentsFormatter`) | – | archived | **(d) drop subspec** | S / none | 0 |
| CocoaLumberjack/Swift 3.9.0 | 16 (15 Swift + `BRCAppDelegate.m`) | ~60 `DDLog*` calls; logger setup in `BRCAppDelegate.m` | **yes** | **official SPM, active** (3.10.0 released 2026-09-21) | **(a) SPM** (later optional: `os.Logger`) | S / low-med | 1 |
| LicensePlist 3.27.1 | build phase only | `${PODS_ROOT}/LicensePlist/license-plist` | – | **official SPM + build/command plugins + release binary**, active (3.28.2, 2026-09-09) | **(a) tool outside Pods** (see decision D1) | S / low | 1 |
| FormatterKit/LocationFormatter 1.9.0 | 1 (`TTTLocationFormatter+iBurn.h`, via bridging header) | 4 Swift calls of the iBurn category `brc_humanizedString(forDistance:)`; `TTTLocationFormatter` is only a namespace; `brc_distanceFormatter` is unused | **yes** (category `.h/.m`) | archived | **(b) native** Swift `TravelTimeFormatter` | S / low | 2 |
| BButton 4.0.2 | 5 (3 are stale imports) | 2: FontAwesome crosshairs glyph (`GeocodeNavigationBar.swift`), pencil callout button (`UserMapViewAdapter.swift`); also `FontAwesome.ttf` in `UIAppFonts` | no | no SPM, last push 2015 | **(b) native** SF Symbols | S / low | 2 (stale imports in 0) |
| Appirater 2.3.1 | 1 (`BRCAppDelegate.m`) | 11 lines of config + `appLaunched:` | **yes** | no SPM, dormant since 2022 | **(b) native** StoreKit `AppStore.requestReview(in:)` behind a tested policy | S–M / low | 2 |
| Onboard 2.3.3 | 2 (`BRCOnboardingViewController.swift`, `BRCAppDelegate.h` `@import`, which the bridging header exposes to all Swift) | 1 subclass (5 pages + looping video), 2 entry points (`SceneDelegate`, More → debug "Show Onboarding") | **yes** (`BRCAppDelegate.h`) | no SPM, last release 2018 | **(b) rewrite** in SwiftUI | M / **med-high** (first launch) | 3 |
| PermissionScope 1.1.1 (submodule, local podspec) | 2 (`BRCPermissions.swift`, `BRCAppDelegate.m`) | 3 prompt funcs → 3 callers (onboarding ×2, `EKEventStoreProvider` default prompt ×1) | **yes** (import only in `.m`) | abandoned/archived upstream (2017); fork last touched 2024 | **(b) native**: system prompts + small SwiftUI pre-prompt | M / med | 3 |

Actions: (a) switch to SPM, (b) replace with native API or small in-repo code,
(c) vendor into a local SPM package, (d) delete. **No pod needs (c).** Everything still in
use is either on SPM already or small enough to rewrite with Apple APIs.

### Decisions made (2026-09-24, user)

These override the recommendations listed below where they differ.

- **D1 – LicensePlist:** the user leans toward SPM and asked what upstream recommends.
  Upstream's README (mono0926/LicensePlist) still lists CocoaPods, Homebrew and Mint as
  "recommended", and says SPM isn't supported for installing the tool itself. SPM *is*
  supported through the `LicensePlistBuildTool` build-tool plugin, configured by
  `license_plist.yml`. That needs a copy-to-Settings.bundle script phase,
  `-skipPackagePluginValidation` in CI, a one-time "Trust & Enable" in Xcode, and
  `packageSourcesPath` so the sandboxed plugin can read SPM package licenses. **Going with
  option B, the SPM build-tool plugin.** Fall back to option A (the pinned artifactbundle
  binary run by a script) if the plugin can't reach the SPM checkouts under Xcode 27.
- **D2/D3 – Onboarding and permissions:** **defer the rewrites.** Keep Onboard and
  PermissionScope as they are, but ship them as **local Swift packages we control**, not pods:
  - PermissionScope is already a submodule of our fork (`Burning-Man-Earth/PermissionScope`).
    Add a `Package.swift` there and commit/push it in the fork.
  - Onboard (mamaral/Onboard 2.3.3, unmaintained, ObjC) is currently a trunk pod. **Use our
    fork `github.com/iBurnApp/Onboard` (default branch `master`) as a submodule** at
    `Submodules/Onboard`, like PermissionScope. Add a `Package.swift` in the fork (ObjC
    target over `Source/`, `publicHeadersPath`), push it there, and reference it as a local
    package. Don't copy the source into this repo.
  - That moves both out of Phase 3 and into Phase 1. The SwiftUI onboarding rewrite and
    native permission prompts become optional later work, no longer a blocker for removing
    CocoaPods.
- **D4 – Review prompt:** native StoreKit `AppStore.requestReview` behind a small tested policy,
  with no custom pre-alert.
- **D6 – Logging:** CocoaLumberjack via SPM now; `os.Logger` possibly later.
- **D5, D7:** not asked. Default to the recommendations: keep the workspace, and leave the
  privacy strings until the PermissionScope rewrite (if one ever happens).
- **DOFavoriteButton** (`chrisballinger/DOFavoriteButton` fork, unused): delete it along with
  its submodule in Phase 0.

### Decisions needed from the user (original list)

- **D1 – LicensePlist runner.** Pick one:
  - (A, recommended) Drop the always-run build phase. Add `scripts/update-acknowledgements.sh`,
    which runs a **pinned** `license-plist` binary (the release `artifactbundle` the SPM
    plugin already uses, with version and checksum pinned in the script), writes to
    `iBurn/Settings.bundle`, and gets committed like today. Run it whenever `Package.resolved`
    changes. Needs no plugin trust, adds nothing to the build, and fixes the `|| true` that
    currently hides failures.
  - (B) Use the `LicensePlistBuildTool` SPM plugin plus the documented copy-to-Settings.bundle
    run script. Output is generated at build time and no longer committed. CI then needs
    `-skipPackagePluginValidation`, and the app target gains a plugin dependency.
  - (C) Use Mint/Homebrew. Adds a developer-machine prerequisite. Not recommended.
- **D2 – Onboarding scope.** Port the five pages 1:1 in SwiftUI with the looping video
  (lowest risk), or trim/redo the copy (the PermissionScope "Don't you want reminders?"
  wording has been flagged as odd, see `Docs/2026-08-20-fab-cold-launch-fix.md`).
- **D3 – Calendar pre-prompt.** Keep a custom pre-prompt before the EventKit system alert on
  the first favorite (a native SwiftUI sheet), or call `requestFullAccessToEvents()`
  directly and rely on `NSCalendarsUsageDescription`.
- **D4 – Review prompt.** StoreKit's prompt can't show Appirater's custom "We ❤️ You" copy,
  and Apple rate-limits it (3 times per 365 days). Accept that, or add a custom pre-alert.
  Apple discourages a pre-alert, so the recommendation is no.
- **D5 – Keep `iBurn.xcworkspace`?** It isn't needed technically: every local package
  (`Packages/*`, `Submodules/iBurn-Data`) is an `XCLocalSwiftPackageReference` inside
  `iBurn.xcodeproj`. The recommendation is to **keep** it with only the Pods FileRef removed, so
  CI, fastlane, CLAUDE.md, README, the drive-app skill and XcodeBuildMCP defaults don't all
  change at once. The alternative is to switch everything to `-project iBurn.xcodeproj` later.
- **D6 – Logging.** Take CocoaLumberjack via SPM (recommended now), or use Phase 1 to move
  straight to `os.Logger` (about 60 call sites plus the DEBUG file logger), which removes the
  dependency entirely.
- **D7 – Info.plist privacy strings.** Once PermissionScope is gone, `NSBluetooth*`,
  `NSContactsUsageDescription`, `NSMicrophoneUsageDescription` and `NSMotionUsageDescription`
  look unused (PermissionScope links CoreBluetooth/Contacts/CoreMotion/Photos/Accounts/
  CloudKit, which is probably why they exist). Decide whether to prune them in Phase 3 or
  leave them.

---

## Technical Details

### Current integration facts (what deintegration has to undo)

- `Podfile`: `platform :ios, '18.0'`, `inhibit_all_warnings!`, `use_modular_headers!`, target
  `iBurn` with nested `iBurnTests` using `inherit! :search_paths` (commit `9c92cb27` made tests
  stop double-linking pods), plus a `post_install` deployment-target floor of 18.0.
- The pods are **static libraries** (`libPods-iBurn.a`, no `use_frameworks!`).
  `use_modular_headers!` generates module maps, and that is what makes `@import CocoaLumberjack;`,
  `@import Onboard;`, `@import PermissionScope;` and `@import TTTAttributedLabel;` work from ObjC
  and `import X` work from Swift. `Pods-iBurn.*.xcconfig` injects them through
  `-fmodule-map-file=` in `OTHER_CFLAGS`/`OTHER_SWIFT_FLAGS` and through `SWIFT_INCLUDE_PATHS`.
  Quoted imports (`#import "Appirater.h"`, `"TUSafariActivity.h"`, `"NSDate+CupertinoYankee.h"`)
  resolve through `HEADER_SEARCH_PATHS = ${PODS_ROOT}/Headers/Public/...`.
- The Pods xcconfig also contributes `OTHER_LDFLAGS = -ObjC -l... -framework Accelerate CFNetwork
  CoreGraphics CoreLocation CoreText ImageIO QuartzCore SystemConfiguration UIKit
  -weak_framework StoreKit`, `GCC_PREPROCESSOR_DEFINITIONS COCOAPODS=1` and `-D COCOAPODS`.
  No source uses `COCOAPODS`. But **`project.pbxproj` hard-codes
  `OTHER_SWIFT_FLAGS = "$(inherited) \"-D\" \"COCOAPODS\" -D DEBUG"`** (Debug, app target, around
  line 937). Strip the COCOAPODS part in Phase 4.
- `baseConfigurationReference` = `Pods-iBurn.{debug,release}.xcconfig` and
  `Pods-iBurnTests.{debug,release}.xcconfig` (pbxproj lines ~914/951/1012/1039).
- Build phases: `[CP] Check Pods Manifest.lock` (iBurn, iBurnTests), `[CP] Copy Pods Resources`
  (iBurn), `LicensePlist` (`${PODS_ROOT}/LicensePlist/license-plist --output-path
  $PRODUCT_NAME/Settings.bundle --add-version-numbers --suppress-opening-directory || true`,
  `alwaysOutOfDate = 1`) and `Crashlytics`.
- `[CP] Copy Pods Resources` currently copies `Appirater.bundle`, **`FontAwesome.ttf`** (BButton),
  `CocoaLumberjackPrivacy.bundle`, DOFavoriteButton's `heart/like/smile/star.png` (into the
  bundle root; nothing in the app loads those names, I checked), `FormatterKit.bundle` and
  `TUSafariActivity.bundle`. The font is load-bearing because `iBurn-Info.plist` `UIAppFonts`
  lists `FontAwesome.ttf`.
- pbxproj has **orphaned Pods references** from long-gone targets (`Pods-PlayaKit*`,
  `Pods-iBurnAbstract-*`, `Pods_*.framework`, `libPods-PlayaKitTests.a`) in the `Pods` group and
  the Frameworks group. `pod deintegrate` only removes what it knows about, so clean these up by hand.
- Workspace `contents.xcworkspacedata` = `iBurn.xcodeproj` + `Pods/Pods.xcodeproj`.
- There are **two** `Package.resolved` files: `iBurn.xcworkspace/xcshareddata/swiftpm/` (the one
  used when building the workspace, 18 pins) and `iBurn.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`.
  Keep the workspace one authoritative while the workspace stays (D5).
- The `Pods/` directory is gitignored (`.gitignore:54-60`).
- The existing SPM remotes (Firebase, GRDB, MapLibre, Zip, Siren) and local packages
  (PlayaAPI/PlayaDB/PlayaColors/PlayaGeo, iBurn-Data) already work in the test host. That is
  good evidence `@testable import iBurn` will keep resolving SPM modules once CocoaLumberjack
  moves to SPM.

### Crashlytics upload script: no Pods dependency ✅

The build phase is `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`,
which comes from the Firebase SPM checkout. Nothing needs to change. Leftovers to tidy in Phase 4:
`iBurn/crashlytics.sh.example` still references `${PODS_ROOT}/Fabric/run`. The gitignored
`iBurn/crashlytics.sh` isn't referenced by any build phase, only by README/CLAUDE.md
"required setup" text, so delete the example and drop those mentions. fastlane's
`upload_symbols_to_crashlytics` finds the Firebase SPM `upload-symbols` on its own. Verify that on
the first post-migration `beta`, and pass `binary_path:` to the SPM checkout if it can't.

### Per-pod notes

#### Phase 0 — deletions and trivial swaps
- **DOFavoriteButton**: remove the `pod` line, then `git submodule deinit -f Submodules/DOFavoriteButton`,
  `git rm Submodules/DOFavoriteButton`, and remove its entry from `.gitmodules`. No code references it.
  The flows' favorite hearts are `BRCHeart*` assets and SF Symbols.
- **KVOController, JTSImageViewController**: remove the pod lines only.
- **TTTAttributedLabel, TUSafariActivity**: delete `@import TTTAttributedLabel;` and
  `#import "TUSafariActivity.h"` from `iBurn/BRCAppDelegate.m`, then remove the pods. If a share
  sheet should ever offer "Open in Safari" again, that's a 20-line `UIActivity` subclass.
  Nothing needs it today.
- **CupertinoYankee**: delete `#import "NSDate+CupertinoYankee.h"` from
  `iBurn/NSDateFormatter+iBurn.m`. The two `endOfDay` hits in `PlayaDBAnnotationDataSource.swift`
  and `FavoritesViewModel.swift` are local variables built with `Calendar`.
- **FormatterKit/TimeIntervalFormatter**: drop the subspec line.
- **Anchorage** (`iBurn/LabelAnnotationView.swift:75-86`): the 5 operator lines become
  `NSLayoutConstraint.activate([imageView.widthAnchor.constraint(equalToConstant:), heightAnchor…,
  topAnchor…, centerXAnchor…, label.topAnchor.constraint(equalTo: imageView.bottomAnchor,
  constant: labelTopGap), label.leadingAnchor…, label.trailingAnchor…])`. Keep
  `translatesAutoresizingMaskIntoConstraints = false`, which Anchorage set implicitly. That
  implicit behavior is the one real gotcha here.
- **PureLayout**: add `iBurn/UIView+Constraints.swift` with `pinEdgesToSuperview(insets:)` and
  `centerXInSuperview()`. Call sites: `MainMapViewController.swift:208,212,321`,
  `ImageAnnotationView.swift:124`, `BRCDistanceView.swift:23`, `SidebarButtonsView.swift:85`,
  `BaseMapViewController.swift:59`. The helper must also set
  `translatesAutoresizingMaskIntoConstraints = false` (PureLayout does this for you).
- Also remove the **stale `import BButton`** from `BRCDistanceView.swift`,
  `MainMapViewController.swift` and `MapViewAdapter.swift`. Those files only use PureLayout and
  their own code.
- Regenerate acknowledgements (the LicensePlist phase still exists at this point). Check
  `iBurn/Settings.bundle/com.mono0926.LicensePlist/*.plist` and delete any orphan plist for a
  removed pod if LicensePlist leaves it behind.

#### Phase 1 — SPM swaps
- **CocoaLumberjack → SPM** (`https://github.com/CocoaLumberjack/CocoaLumberjack`, `from: "3.10.0"`).
  Link products `CocoaLumberjack` (ObjC) and `CocoaLumberjackSwift` to the iBurn target only
  (tests get it through the host, as with GRDB).
  - Swift: the pod's `/Swift` subspec merged everything into one `CocoaLumberjack` module. Under
    SPM the Swift API (`DDLogInfo("…")` functions, `dynamicLogLevel`) lives in
    **`CocoaLumberjackSwift`**, so the 15 Swift files change `import CocoaLumberjack` to
    `import CocoaLumberjackSwift`.
  - ObjC: `BRCAppDelegate.m` keeps `@import CocoaLumberjack;` because SPM generates a module map
    for the ObjC target. The `static int ddLogLevel` + `DDLogInfo` macro pattern is unchanged.
  - Remove the pod line in the **same commit**. If the pod and the package are linked together
    you get duplicate symbols.
  - Check that the privacy manifest (`CocoaLumberjackPrivacy.bundle`) still ends up in the app.
    SPM emits it as a resource bundle.
- **LicensePlist → out of Pods** (D1, option A recommended):
  - Add a repo-root `license_plist.yml` (`options: xcworkspacePath: "iBurn.xcworkspace"`,
    `outputPath: iBurn/Settings.bundle`, `addVersionNumbers: true`). LicensePlist then reads the
    workspace `Package.resolved` directly, which is how the Firebase/GRDB/etc. plists are produced
    today. `podsPath` becomes irrelevant once Pods is gone.
  - Add `scripts/update-acknowledgements.sh`. It downloads (or reuses a cached)
    `LicensePlistBinary-macos.artifactbundle.zip` at a pinned version with a pinned SHA-256
    (3.28.2 is `b7361afd…a544b7` per upstream `Package.swift`), then runs it.
  - Remove the `LicensePlist` shell build phase and the `pod 'LicensePlist'` line.
  - `iBurn/Settings.bundle/Root.plist` already links to `com.mono0926.LicensePlist`. Nothing
    changes for the Settings app.
  - Option B instead: add `https://github.com/mono0926/LicensePlist` as a package, add
    `LicensePlistBuildTool` under "Run Build Tool Plug-ins", add the upstream copy script
    (`com.mono0926.LicensePlist.Output` → `Settings.bundle`), un-commit the generated plists,
    and add `-skipPackagePluginValidation` to every CI/fastlane `xcodebuild`.

#### Phase 2 — small native rewrites
- **FormatterKit/LocationFormatter**: the only real code is the iBurn category in
  `iBurn/TTTLocationFormatter+iBurn.{h,m}` (walk/bike time estimate with a 120 s "faff"
  constant, colored green/orange/red at the 20/35 minute thresholds, text built from
  `DateFormatters.stringForTimeInterval`, which is already `DateComponentsFormatter`).
  - Port it to `iBurn/TravelTimeFormatter.swift`: a `enum TravelTimeFormatter` with
    `static func attributedEstimate(forDistance:) -> NSAttributedString?`, and `walkSeconds`/`bikeSeconds`
    as pure functions so they're testable. Or return an `AttributedString` for the SwiftUI callers.
  - Update the 4 callers: `Detail/Views/DetailView.swift:445`, `BRCDistanceView.swift:30`,
    `ListView/NearbyView.swift:173`, `ListView/PlayaDistanceString.swift:65`.
  - Delete the `.h/.m`, remove `#import "TTTLocationFormatter+iBurn.h"` from
    `iBurn-Bridging-Header.h`, and remove both FormatterKit pod lines (this also drops
    `FormatterKit.bundle`).
  - Add `iBurnTests/TravelTimeFormatterTests.swift` for the thresholds, the string shape
    ("🚶🏽 … 🚴🏽 …") and the color ranges.
- **BButton**:
  - `GeocodeNavigationBar.swift:24-40` `brc_attributedLocationStringWithCrosshairs`: replace the
    FontAwesome `FACrosshairs` glyph with an `NSTextAttachment(image: UIImage(systemName: "scope"))`
    tinted `colors.detailColor`. Use `location.viewfinder` if that looks closer.
  - `UserMapViewAdapter.swift:402`: the `BButton(... .bootstrapV3, icon: .FAPencil)` callout
    becomes `UIButton(type: .system)` with `UIImage(systemName: "pencil")` and the same `tag`. This
    matches the adjacent `xmark.circle.fill` remove button.
  - Remove `FontAwesome.ttf` from `UIAppFonts` in `iBurn/iBurn-Info.plist`, grep for
    `kFontAwesomeFont` to confirm it's gone, and remove the pod line.
- **Appirater** (`BRCAppDelegate.m:102-111`: 2 days, 5 uses, remind after 2 days):
  - Add `iBurn/Review/ReviewPromptPolicy.swift`, a protocol plus Impl per the CLAUDE.md DI
    guidance. It stores first-launch date and launch count in `UserDefaults` and exposes
    `shouldRequestReview(now:)`.
  - Add a tiny presenter that calls `AppStore.requestReview(in: windowScene)` (StoreKit, iOS 16+)
    from `SceneDelegate` on `sceneDidBecomeActive`, after onboarding is done and never over an
    alert.
  - Remove the Appirater block and `#import "Appirater.h"`.
  - Unit-test the policy with an injected clock and defaults. Siren (update nags) is already on
    SPM and unaffected.

#### Phase 3 — Onboard + PermissionScope
- The current flow is `SceneDelegate.swift:50-60`, which shows `BRCOnboardingViewController`
  when `!UserDefaults.hasViewedOnboarding`. The pages are Welcome ("📍 Continue with Location" →
  `BRCPermissions.promptForLocation`), Reminders ("⏰ Continue with Notifications" →
  `promptForPush`, which actually shows notifications **and** events permissions), Search,
  Nearby, and Thank you ("🔥 Ok let's burn!" → completion). It has a looping
  `onboarding_loop_final.mp4` background, fade transitions, and skip wired to completion.
  The More tab's debug row "Show Onboarding" (`MoreViewController.swift:486`) presents it too.
- Replacement: `iBurn/Onboarding/OnboardingView.swift` in SwiftUI.
  - Use `TabView` + `.tabViewStyle(.page)` over a looping `AVPlayerLayer` background. Put that in a
    small `UIViewRepresentable` using `AVPlayerLooper`, which replaces the manual
    `AVPlayerItemDidPlayToEndTime` seek.
  - Wrap it in a `UIHostingController` with the same completion closure so `SceneDelegate` and
    `MoreViewController` barely change.
  - Keep `hasViewedOnboarding` (ObjC `NSUserDefaults+iBurn`) as the persisted key.
  - Add accessibility identifiers on every button so the drive-app flow and UI tests have stable
    handles.
- Permissions, as a native `PermissionService` protocol + Impl:
  - Location: `CLLocationManager.requestWhenInUseAuthorization()` through the shared
    `BRCAppDelegate.shared.locationManager` (`requestLocationPermission` already exists in
    `BRCAppDelegate.h`).
  - Notifications: `UNUserNotificationCenter.requestAuthorization`. Note that `BRCAppDelegate`
    **already requests this unconditionally at launch**, which is why flows.md §1 step 1 sees the
    springboard alert before onboarding. Decide whether to move that request into the onboarding
    page. Recommended: yes, but as its own reviewed change.
  - Calendar: `EKEventStore().requestFullAccessToEvents()` (iOS 17+). That also clears the
    deprecated `requestAccessToEntityType:` follow-up from `2026-08-20-fab-cold-launch-fix.md`.
  - `EKEventStoreProvider`'s default `prompt` (`Calendar/EventStoreProviding.swift:126-130`)
    switches from `BRCPermissions.promptForEvents` to the new pre-prompt (D3). The once-per-launch
    latch and "unfavorite never prompts" behavior stay, and `EventCalendarService` tests cover them.
- Delete `BRCOnboardingViewController.swift` and `BRCPermissions.swift`, `@import Onboard;` from
  **`BRCAppDelegate.h`** and `@import PermissionScope;` from `BRCAppDelegate.m`, then the
  PermissionScope submodule (`deinit`, `git rm`, `.gitmodules`) and both pod lines.
  - **Bridging gotcha**: `BRCAppDelegate.h` is in `iBurn-Bridging-Header.h`, so `@import Onboard`
    has been implicitly exposing Onboard, and its transitive `AVFoundation`/`MediaPlayer`/`AVKit`
    imports, to **every** Swift file. Expect a few "cannot find type" errors to fix with explicit
    `import AVFoundation` / `import AVKit` once it's removed.
- D7: after PermissionScope is gone, grep for any remaining use of Bluetooth, Contacts, Microphone
  and Motion. The only related hit today is `BRCAudioPlayer.swift` using `AVAudioSession` for
  playback, which needs no mic permission. If they're unused, drop the four usage strings in a
  separate commit and watch App Store Connect's processing email for ITMS-90683 warnings.

#### Phase 4 — deintegrate
1. `bundle exec pod deintegrate`. This removes `[CP]` phases, `libPods-*.a` links, the
   `Pods-*.xcconfig` file references and `baseConfigurationReference`s.
2. Hand-clean what deintegrate misses: the orphan `Pods-PlayaKit*`/`Pods-iBurnAbstract-*` xcconfig
   references and `Pods_*.framework`/`libPods-PlayaKitTests.a` product references, the empty
   `Pods` group, and `"-D" "COCOAPODS"` in the Debug `OTHER_SWIFT_FLAGS`. Check that no target
   build setting still references `PODS_*`: `rg 'PODS_|Pods-' iBurn.xcodeproj/project.pbxproj`
   must return nothing.
3. Settings the Pods xcconfig used to supply that the app may silently depend on:
   - `-ObjC`: only matters for ObjC categories in static libs. No remaining static ObjC libs
     except SPM CocoaLumberjack, which doesn't rely on it. Firebase SPM declares its own
     `-ObjC` linker setting. Build and smoke-test before deciding to re-add it.
   - `-weak_framework StoreKit` and `-framework ...`: covered by module autolinking.
     `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` is irrelevant on iOS 18.
4. Delete `Podfile`, `Podfile.lock`, the `Pods/` directory and the CocoaPods lines in
   `.gitignore`. Remove `<FileRef location="group:Pods/Pods.xcodeproj">` from
   `iBurn.xcworkspace/contents.xcworkspacedata`, and keep the workspace (D5).
5. `Gemfile`: drop `gem 'cocoapods'`, then `bundle lock` so `Gemfile.lock` loses cocoapods and its
   transitive gems (cocoapods-core, xcodeproj if fastlane doesn't need it, molinillo, etc.).
6. Docs/tooling: remove "`pod install`" from `CLAUDE.md` (Building and Dependencies) and
   `README.md:16-22`. Drop the `crashlytics.sh` "required setup" mentions and
   `iBurn/crashlytics.sh.example`. Check `.claude/skills/drive-app/SKILL.md` for pod steps.

### CI / fastlane changes (Phase 4, some earlier)

- `.github/workflows/ci.yml`, `pr.yml`, `deploy.yml`: delete the **"Cache CocoaPods"** step
  (`path: Pods`, key on `Podfile.lock`) and the `bundle exec pod repo update --silent` /
  `bundle exec pod install` lines. Keep `bundle install`, which fastlane still needs.
- Add SPM caching instead: `actions/cache@v4` on `~/Library/Caches/org.swift.swiftpm` +
  `~/Library/Developer/Xcode/DerivedData/**/SourcePackages` (or pass
  `-clonedSourcePackagesDirPath SourcePackages` and cache that), keyed on
  `hashFiles('iBurn.xcworkspace/xcshareddata/swiftpm/Package.resolved')`.
  - **Caveat:** the Crashlytics phase resolves `${BUILD_DIR%/Build/*}/SourcePackages`. If CI
    switches to `-clonedSourcePackagesDirPath`, the phase path must match. That's another reason
    to prefer caching the default DerivedData `SourcePackages` or to leave it uncached.
    Firebase's binary targets are the slow part.
- Optionally add `xcodebuild -resolvePackageDependencies` as an explicit step so resolution
  failures surface clearly.
- If D1 = B, add `-skipPackagePluginValidation` (and `-skipMacroValidation` if any macros appear)
  to every `xcodebuild` invocation and to fastlane `build_app(xcargs:)`.
- `fastlane/Fastfile` `beta` lane: `build_app(workspace: "iBurn.xcworkspace", scheme: "iBurn")`
  never calls `pod install`, so nothing changes if the workspace is kept (D5). If the workspace
  goes, switch to `project: "iBurn.xcodeproj"`.
- The cache path/key changes can land in Phase 4. Nothing earlier requires CI changes, because
  `pod install` keeps working with fewer pods.

### Testing per phase

Every phase runs these gates before commit (per CLAUDE.md):
`xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination "$DEST" -quiet 2>&1 | xcsift -f toon -w`,
`xcodebuild test … -scheme iBurnTests …`, a watch build (`iBurnWatch`, which doesn't use pods but
shares the workspace), `pod install` producing a clean `Podfile.lock` diff (phases 0–3), and
`git status` checked for `DEVELOPMENT_TEAM` flips.

| Phase | Extra verification |
|---|---|
| 0 | Screenshots before/after of layouts that used Anchorage/PureLayout: map screen (`BaseMapViewController`, sidebar buttons, card container + tooltip in `MainMapViewController`), a **label annotation** and an **image annotation** on the map (flows.md §6), and the distance view on a detail screen (§7). Settings app → iBurn → Acknowledgements lists no removed pods. |
| 1 | Launch in DEBUG: Xcode console shows `DDLog` output, and the DEBUG file logger creates a log file (sim container `Library/Caches/Logs`). Release build compiles (the `ddLogLevel` macro path). Acknowledgements page still populated. Run `scripts/update-acknowledgements.sh` twice and check the second run is a no-op diff. |
| 2 | New unit tests (`TravelTimeFormatterTests`, `ReviewPromptPolicyTests`). Screenshots of the walk/bike estimate on Nearby (§6 Nearby screen), a Detail screen (§7) and the Recently Viewed/Search rows using `PlayaDistanceString`. User-pin callout pencil button (§6, drop/edit a pin). Geocoded nav-bar crosshairs title. Review prompt: StoreKit shows it in debug builds on the simulator, so exercise the policy with a lowered threshold. |
| 3 | Erase the simulator and run **flows.md §1 First-launch onboarding** end to end: location, notification and calendar prompts, video loop, swipe paging, "Ok let's burn". Also §4 "Calendar permission pre-prompt": first favorite prompts, Close latches per launch, unfavorite never prompts. More → debug "Show Onboarding" re-entry. Test denied-permission paths (Don't Allow) and Dynamic Type / dark mode screenshots. **Update flows.md §1 and the §4 pre-prompt section in the same change**, because the PermissionScope accessibility ids (`permissionscope.headerlabel`, `permissionscope.button.events`, `permissionscope.closeButton`) go away. |
| 4 | Fresh clone → `git submodule update --init` → open workspace → build, with **no** Ruby/CocoaPods step. CI green on a PR. `fastlane beta` dry run (or a real TestFlight build) confirms Crashlytics dSYM upload. `rg -i 'pods|cocoapods'` over the repo (excluding Docs) returns only historical mentions. |

### Ordering rationale (shippable after each phase)

- Phase 0 only deletes code paths that are provably unused or rewrites ~12 layout lines, so
  there's no behavior change.
- Phase 1 runs before the rewrites so that the only things left in `Pods/` are the pods being
  replaced. It also makes LicensePlist independent of `PODS_ROOT` before deintegration can
  break it.
- Phase 2's replacements are each isolated to 1–4 call sites with unit-testable logic.
- Phase 3 is the only user-visible redesign. It's isolated so it can ship (or slip) on its own
  without blocking Phase 4. If it slips, Phase 4 waits, and the 2026-12-02 read-only date
  doesn't break existing `pod install`s (per the CocoaPods announcement), so there's no hard
  deadline.
- Phase 4 is mechanical once the Podfile is empty.

---

## Context Preservation

- Research commands (all read-only): `rg` import/symbol sweeps per pod. Reading `Podfile`,
  `Podfile.lock`, `Gemfile(.lock)`, `project.pbxproj` (shell scripts, base configs, Pods refs),
  `Pods/Target Support Files/Pods-iBurn/*.xcconfig` and `-resources.sh`, `iBurn-Info.plist`,
  `.github/workflows/*.yml`, `fastlane/Fastfile`, the submodule podspecs, and
  `.claude/skills/drive-app/references/flows.md`.
- `gh api repos/<owner>/<repo>` (had to run outside the sandbox: Go TLS verification fails under
  Seatbelt with `x509: OSStatus -26276`). Upstream status as of 2026-09-24:
  - Anchorage: not archived, has Package.swift, last release 4.5.0 (2020-10)
  - CocoaLumberjack: Package.swift, **3.10.0 (2026-09-21)**, active
  - FormatterKit (mattt/FormatterKit): **archived**, no Package.swift
  - PureLayout: Package.swift, v3.1.9 (2021-07)
  - BButton: no Package.swift, last push 2015
  - TTTAttributedLabel: no Package.swift, 2.0.0 (2016)
  - Appirater: no Package.swift, last push 2022
  - CupertinoYankee: **archived**
  - DOFavoriteButton: no Package.swift, 0.0.4 (2015)
  - TUSafariActivity: Package.swift, 1.0.5 (2023-10)
  - KVOController: **archived**
  - Onboard: no Package.swift, v2.3.3 (2018)
  - PermissionScope: **archived** upstream (2017). The iBurn fork submodule's HEAD is `2c4a0d94` "Xcode 16.0" (2024-09)
  - JTSImageViewController: no Package.swift, 1.5.1 (2015)
  - LicensePlist: Package.swift with `LicensePlistBuildTool`, `GenerateAcknowledgementsCommand`
    and `AddAcknowledgementsCopyScriptCommand` plugins, backed by a binary artifactbundle,
    3.28.2 (2026-09-09)
- CocoaPods trunk timeline (blog.cocoapods.org/CocoaPods-Specs-Repo): new-pod `prepare_command`
  blocked May 2025, read-only test 2026-11-01..07, **permanent read-only 2026-12-02**. The post
  says existing builds keep working and only updates stop.
- Considered and rejected:
  - Vendoring (option c) for Onboard/PermissionScope. Both are larger than the replacement
    (PermissionScope is 1,539 lines of Swift for 3 prompts), and both drag in unused framework
    links and privacy strings.
  - Keeping PureLayout/Anchorage via SPM. 12 lines don't justify a dependency.
  - Adding a `Package.swift` to the DOFavoriteButton fork. Unused.
- Not verified (needs a build, which was out of scope because another agent is building in this
  checkout): the exact set of Swift files that need an explicit `import AVFoundation`/`AVKit`
  once `@import Onboard` leaves the bridging header, whether removing `-ObjC` affects anything,
  and whether LicensePlist deletes orphan plists on regeneration.

## Cross-References

- `Docs/2026-09-24-xcode-27-sdk-and-post-event-cleanup.md`: iOS 18 floor (`2c11808b`), tests
  inheriting search paths only (`9c92cb27`), "remaining libtool warnings come from vendored Pods".
- `Docs/2026-08-20-fab-cold-launch-fix.md`: calendar pre-prompt latch, and the PermissionScope
  `requestAccessToEntityType:` / odd-copy follow-ups.
- `Docs/2026-07-26-archive-cycle-and-onboarding-video.md`: onboarding video resource and the
  `moviePlayerController` IUO guard.
- `Docs/2026-09-24-live-tracks-spike.md`: location-permission path through `BRCPermissions`.
- `Docs/2025-07-23-github-actions-migration.md`: CI history.
- `.claude/skills/drive-app/references/flows.md` §1, §4 (pre-prompt), §6, §7: flows to re-run
  and update.

## Expected Outcomes

- After Phase 0: 9 fewer pod entries (6 whole pods, 2 layout pods, 1 subspec) and one fewer
  submodule, with no visible change.
- After Phase 1: logging via SPM CocoaLumberjack, and acknowledgements generated by a pinned
  tool that doesn't depend on `PODS_ROOT`.
- After Phase 2: no FontAwesome font, no FormatterKit category, and StoreKit review prompts
  driven by a tested policy.
- After Phase 3: SwiftUI onboarding with native permission requests, PermissionScope's unused
  framework links gone, and flows.md updated.
- After Phase 4: no Podfile, Pods, `[CP]` phases, Pods xcconfigs, cocoapods gem or `pod install`
  in CI. `iBurn.xcworkspace` holds only `iBurn.xcodeproj`, and all third-party code arrives via
  SPM. A fresh clone builds with `git submodule update --init` plus opening the workspace.
- Remaining after the plan: optionally move from CocoaLumberjack to `os.Logger` (D6), and
  optionally retire the workspace in favor of the project (D5).

---

## Outcome (2026-09-24, implemented)

**CocoaPods is gone.** There is no Podfile, Pods/, `[CP]` phase, Pods xcconfig, cocoapods gem
or `pod install` step. A fresh `git clone` + `git submodule update --init --recursive`
builds with `xcodebuild … -skipPackagePluginValidation`, or in Xcode after a one-time
"Trust & Enable" of the LicensePlist plug-in.

### Commits (branch `maintenance-deps`)

Phases 0 and 2 (the dead pods, Anchorage/PureLayout, FormatterKit, BButton, Appirater):
`58992e12`, `ee057a24`, `d3a9baed`, `c996ed04`, `19135535`, `acfe3e7c`.

Phases 1, 3 (as re-scoped by D2/D3) and 4:

| Commit | Change |
|---|---|
| `4b595d0c` | CocoaLumberjack → SPM 3.10.0 (`CocoaLumberjack` + `CocoaLumberjackSwift` products). Swift files `import CocoaLumberjackSwift`; `BRCAppDelegate.m` keeps `@import CocoaLumberjack;` and the DEBUG TTY + file loggers. The privacy manifest ships as `CocoaLumberjack_CocoaLumberjack.bundle`. `pod install` dropped the now-empty `[CP] Copy Pods Resources` phase. |
| `9463aaf3` | PermissionScope → local package from the `Submodules/PermissionScope` fork. The fork's new branch **`swiftpm`** (`806d397`, pushed to Burning-Man-Earth/PermissionScope) branches from `xcode-16.0`, which the submodule was already pinned to (it is not on the fork's `master`). It adds a `Package.swift` (iOS 18, Swift 5 mode, `-suppress-warnings`) and an explicit `import UIKit` in Permissions.swift, which the CocoaPods prefix header used to provide. The unused `@import PermissionScope;` in `BRCAppDelegate.m` is removed. |
| `17c5e984` | Onboard → new submodule `Submodules/Onboard` (git@github.com:iBurnApp/Onboard.git). The fork's `master` gains a `Package.swift` (`11c4e60`, pushed): an ObjC target over `Source/` with a hand-written module map in `Source/include`, so the podspec, framework project and demo keep their layout. The unused `_Private.h` is excluded, it links AVFoundation/AVKit/Accelerate, and it builds with `-w`. The fork's source is byte-identical to the 2.3.3 pod. `@import Onboard;` is gone from `BRCAppDelegate.h`. |
| `dc03e44d` | LicensePlist → `LicensePlistBuildTool` SPM plugin (D1 = B), configured by `license_plist.yml`. A "Copy Acknowledgements to Settings.bundle" phase runs after Resources. The generated plists are un-committed and gitignored. CI and fastlane pass `-skipPackagePluginValidation -skipMacroValidation`. |
| `a68548ca` | Deintegration: the Podfile/lock, the workspace Pods FileRef, the `[CP] Check Pods Manifest.lock` phases, the Pods base configs and libs, the Pods group, the orphaned PlayaKit/iBurnAbstract refs, `-D COCOAPODS`, the cocoapods gem (`bundle lock`, deletions only), the CI pod steps (replaced by an SPM cache), and `crashlytics.sh.example`. README and CLAUDE.md updated. |
| `8c215932` | `CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = NO` on the iBurn and iBurnTests targets (see "Deviations"). |

### LicensePlist: why the plugin works

The plugin runs `license-plist --sandbox-mode --package-sources-path <DerivedData>/SourcePackages`,
so SPM licenses are read from the local checkouts with no GitHub API calls. That makes
Xcode and command-line builds produce the same output, which fixes the old phase that
lost the SPM entries on CLI runs. It also computes the SourcePackages path from its own
work directory, which works under Xcode 27.1 (it handles the Xcode 16.3+
`BuildToolPluginIntermediates` layout). Option A was not needed.

Local packages are not in `Package.resolved`, and the old phase silently dropped
Onboard and PermissionScope once they became local packages. `license_plist.yml` now
lists them under `manual:` (version, source, license file inside the submodule).
LicensePlist's build-only dependencies (APIKit, Yams, XcodeEdit, …) are excluded.

Verified after a CLI `xcodebuild`: `iBurn.app/Settings.bundle/com.mono0926.LicensePlist.plist`
lists 21 entries. Diffed against the last committed pod-generated list, the only
changes are:
```
< "GRDB.swift (7.11.1)"            > "GRDB (7.11.1)"            (name from Package.swift)
< "gtm-session-fetcher (5.0.0)"    > "GTMSessionFetcher (5.0.0)"
< "LicensePlist (3.28.2)"          (removed: build tool, not shipped)
                                   > "swift-log (1.15.1)"       (CocoaLumberjack's SPM dependency)
```
An incremental rebuild keeps them, and so does a fresh clone with clean DerivedData.
The copy script fails the build with an explicit error if the plug-in didn't run.

### Deviations from the plan

- **D2/D3 re-scope**: Onboard and PermissionScope stay; they became local packages
  instead of being rewritten. Their privacy strings (D7) are untouched.
- **Warnings**: the Pods xcconfig had silently set
  `CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = NO`. Without it, a clean build
  emitted 233 `-Wquoted-include-in-framework-header` warnings from MapLibre headers
  during the explicit-module precompile. An A/B clean build of `acfe3e7c` with pods
  showed 0, so the setting was restored on the targets (`8c215932`). The other xcconfig
  settings (`-ObjC`, `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES`, search paths) were not
  needed: all builds and tests pass without them.
- **No explicit AVFoundation/AVKit imports were needed** after removing `@import Onboard`
  from the bridging path. Only `MoreViewController.swift` referenced an Onboard type
  (`OnboardingViewController?`), and it now uses `BRCOnboardingViewController?`.
- `pod install`/`pod deintegrate` rewrote the pbxproj in xcodeproj-gem style. Each time
  the functional removals were re-applied by hand to keep the diff minimal (the
  deintegrate object list was diffed by ID).
- The drive-app skill had no pod steps. flows.md §1 gained notes on the late
  notification alert and the BRC "Data Unlocked" alert.

### Validation

- iPhone 18 Pro Max / iOS 27.0, after every step: app build ✅, `iBurnTests` **699
  passed** ✅, `iBurnWatch` build ✅. The Release configuration builds ✅.
- Fresh clone of `maintenance-deps` in `$TMPDIR` with `~/Library/Developer/Xcode/DerivedData/iBurn-*`
  deleted first, then `git submodule update --init --recursive` (the forks are fetched
  from GitHub) and the three gitignored secret files copied in: **BUILD SUCCEEDED in 86 s,
  0 warnings** after `8c215932`, with no Ruby or pod step.
- Simulator (erased), fresh-install onboarding: the Onboard pages and looping video,
  PermissionScope location → system alert, the late notification alert, PermissionScope
  Reminders → calendar full access, then swipe to "Ok let's burn" → map. Settings.app →
  iBurn shows Location While Using / Calendars Full Access / Notifications, and
  Licenses lists GRDB, MapLibre Native, Firebase, CocoaLumberjack, Onboard (2.3.3),
  PermissionScope (1.1.1) and the rest, with the full GRDB license text. The DEBUG file
  logger writes `Library/Caches/Logs/com.trailbehind.iBurn2010 <date>.log`, and the
  console shows DDLog output.

### Remaining / optional follow-ups

- **SwiftUI onboarding rewrite** (the original Phase 3 plan above). Retires Onboard and
  the `Submodules/Onboard` fork.
- **Native permission prompts** (`CLLocationManager`, `UNUserNotificationCenter`,
  `requestFullAccessToEvents`) plus a SwiftUI calendar pre-prompt. Retires PermissionScope
  and its submodule, and unblocks D7 (pruning the unused privacy strings) and the
  "Don't you want reminders?" copy.
- **`os.Logger`** instead of CocoaLumberjack (D6). The console already warns
  "Usage of DDTTYLogger detected when DDOSLogger is available"; swapping in
  `DDOSLogger` is a one-line interim fix.
- The Settings.bundle `Root.plist` still has a "Modern List Views" toggle
  (`featureFlag.lists.useSwiftUI`), which the Sept 2026 cleanup retired. Remove it.
- CI still pins Xcode 26.6. The first CI run on this branch validates the SPM cache
  paths and the plugin flags. Verify `upload_symbols_to_crashlytics` on the first
  post-migration `fastlane beta`.
- D5: `iBurn.xcworkspace` now wraps only `iBurn.xcodeproj`, so it could be retired later.
  The stale second `Package.resolved` under `iBurn.xcodeproj/project.xcworkspace` is
  untouched.
- The CocoaPods CDN HTTP/2 workaround in `2026-09-24-xcode-27-sdk-and-post-event-cleanup.md`
  is now historical. The last `pod install` runs in this migration worked without it.
