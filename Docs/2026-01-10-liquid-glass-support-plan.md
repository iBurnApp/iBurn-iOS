# 2026-01-10-liquid-glass-support-plan.md

## High-Level Plan
Problem statement: iBurn has no real "liquid glass" support today. The global appearance pipeline forces opaque nav/tab bars and solid backgrounds, and the per-view theming helpers override any translucent configuration. The only material usage is a SwiftUI sheet background in one view.

Solution overview: Make glass the default (no toggle) by building nav/tab appearances using transparent backgrounds plus blur material, and update the theming pipeline so it does not overwrite glass settings. Align UIKit and SwiftUI backgrounds so glass surfaces read consistently and respect accessibility (reduce transparency).

Key changes (planned):
- Replace opaque bar configuration with a shared appearance builder that can return opaque or glass configurations.
- Update `ColorTheme` to skip background overrides when glass is enabled and apply `UINavigationBarAppearance`/`UITabBarAppearance` instead of `barTintColor`.
- Add SwiftUI list/hosting adjustments to avoid solid list backgrounds blocking glass.
- Address search bar styling and per-detail nav bar coloring so glass looks correct with themed colors.

## Technical Details

### Commands (evidence of current state)
```bash
rg -n "UIBlurEffect|UIVisualEffectView|blur" iBurn
```
```text
iBurn/CreditsViewController.swift:107:            cell.detailTextLabel!.text = creditsInfo.blurb
iBurn/BRCCreditsInfo.m:16:             NSStringFromSelector(@selector(blurb)): @"blurb"};
iBurn/BRCCreditsInfo.h:17:/** description / blurb */
iBurn/BRCCreditsInfo.h:18:@property (nonatomic, strong, readonly) NSString *blurb;
iBurn/Images.xcassets/PlayaBackground.imageset/Contents.json:9:      "filename" : "playa-blur.jpg",
```

```bash
rg -n "Material|material" iBurn
```
```text
iBurn/Detail/Views/ZoomableImageView.swift:202:            .presentationBackground(.ultraThinMaterial)
iBurn/BRCUserTrackingBarButtonItem.m:15://   and/or other materials provided with the distribution.
iBurn/Settings.bundle/com.mono0926.LicensePlist/CocoaLumberjack.plist:18:2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
iBurn/Settings.bundle/com.mono0926.LicensePlist/maplibre-gl-native-distribution.plist:25:  the documentation and/or other materials provided with the distribution.
iBurn/BRCUserTrackingBarButtonItem.h:15://   and/or other materials provided with the distribution.
iBurn/Settings.bundle/com.mono0926.LicensePlist/TUSafariActivity.plist:20:and/or other materials provided with the distribution.
iBurn/Settings.bundle/com.mono0926.LicensePlist/leveldb.plist:19:in the documentation and/or other materials provided with the distribution.
iBurn/Settings.bundle/com.mono0926.LicensePlist/KVOController.plist:23:   and/or other materials provided with the distribution.
```

```bash
rg -n "standardAppearance|scrollEdgeAppearance|compactAppearance" iBurn
```
```text
iBurn/Appearance.swift:89:        UINavigationBar.appearance().standardAppearance = coloredAppearance
iBurn/Appearance.swift:90:        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
```

### Current Implementation Notes (snippets)
File: `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Appearance.swift`
```swift
    private func setGlobalAppearance() {
        let colors = Appearance.currentColors
        
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = colors.backgroundColor
        coloredAppearance.titleTextAttributes = [.foregroundColor: colors.secondaryColor]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: colors.secondaryColor]
               
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance

        UINavigationBar.appearance().backgroundColor = colors.backgroundColor
        UINavigationBar.appearance().tintColor = colors.primaryColor
        UINavigationBar.appearance().barTintColor = colors.backgroundColor
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: colors.primaryColor]
        UITabBar.appearance().backgroundColor = colors.backgroundColor
        UITabBar.appearance().tintColor = colors.primaryColor
        UITabBar.appearance().barTintColor = colors.backgroundColor
        UITableView.appearance().backgroundColor = colors.backgroundColor
        UITableView.appearance().tintColor = colors.primaryColor
        UISwitch.appearance().tintColor = colors.primaryColor
        UISwitch.appearance().onTintColor = colors.primaryColor
    }
```

File: `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/ColorCache.swift`
```swift
extension UINavigationBar: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        self.titleTextAttributes = [.foregroundColor: colors.secondaryColor]
        let theme = {
            self.barTintColor = colors.backgroundColor
            self.tintColor = colors.primaryColor
        }
        if animated {
            UIView.transition(with: self, duration: 0.25, options: [.beginFromCurrentState, .transitionCrossDissolve], animations: theme, completion: nil)
        } else {
            theme()
        }
    }
}
```

File: `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Detail/Views/ZoomableImageView.swift`
```swift
        ZoomableImageView(uiImage: image)
            // The following modifiers are on the content *inside* the sheet
            .presentationBackground(.ultraThinMaterial)
```

### Planned Touchpoints (full paths, not yet modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Appearance.swift` (build glass vs opaque bar appearances, central toggle)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/ColorCache.swift` (update `ColorTheme` to avoid forcing opaque colors)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/AppearanceViewController.swift` (add toggle UI if desired)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Preferences/Preferences.swift` (new preference for liquid glass)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/UserSettings.swift` (backing store if needed by `Appearance`)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/SearchDisplayManager.swift` (search bar styling for glass)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BRCDetailViewController.m` (per-object nav bar styling with glass)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/TabController.swift` (refresh path should apply appearances, not barTintColor)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/ListView/ArtListView.swift` (SwiftUI list background and toolbar)
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Detail/Views/DetailView.swift` (SwiftUI detail toolbar background if needed)

### Update (2026-01-10): No Toggle + Map Fullscreen Requirement
User guidance: do not add a toggle; ensure nav/tab bars are glass by default, and make main map extend under bars.

Implemented changes:
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Appearance.swift`: added shared glass appearance builders for nav/tab bars with reduce-transparency fallback; centralized application via `applyNavigationBarAppearance` and `applyTabBarAppearance`.
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/ColorCache.swift`: `setColorTheme` now delegates to Appearance helpers instead of forcing opaque bar tints.
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BaseMapViewController.swift`: set `edgesForExtendedLayout = [.all]` and `extendedLayoutIncludesOpaqueBars = true` so the map extends under bars.

Key snippets:
```swift
// /Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Appearance.swift
private static func makeNavigationBarAppearance(colors: BRCImageColors) -> UINavigationBarAppearance {
    let appearance = UINavigationBarAppearance()
    if UIAccessibility.isReduceTransparencyEnabled {
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colors.backgroundColor
    } else {
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: glassBlurStyle)
        appearance.backgroundColor = glassTintedColor(base: colors.backgroundColor, alpha: navBarGlassAlpha)
    }
    appearance.titleTextAttributes = [.foregroundColor: colors.secondaryColor]
    appearance.largeTitleTextAttributes = [.foregroundColor: colors.secondaryColor]
    appearance.shadowColor = .clear
    return appearance
}
```

```swift
// /Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/Appearance.swift
@objc public static func applyTabBarAppearance(_ tabBar: UITabBar, colors: BRCImageColors) {
    let appearance = makeTabBarAppearance(colors: colors)
    tabBar.standardAppearance = appearance
    if #available(iOS 15.0, *) {
        tabBar.scrollEdgeAppearance = appearance
    }
    tabBar.tintColor = colors.primaryColor
    tabBar.unselectedItemTintColor = colors.detailColor
    tabBar.isTranslucent = !UIAccessibility.isReduceTransparencyEnabled
}
```

```swift
// /Users/chrisbal/Documents/Code/iBurn-iOS-2/iBurn/BaseMapViewController.swift
override public func viewDidLoad() {
    super.viewDidLoad()
    edgesForExtendedLayout = [.all]
    extendedLayoutIncludesOpaqueBars = true
    view.addSubview(mapView)
    ...
}
```

## Context Preservation
User request: "okay we're working on liquid glass support. evaluate our current impl and plan fixes"

Key observations:
- No UIKit blur or `UIVisualEffectView` usage in the app (only a blurred image asset and a SwiftUI sheet material).
- Global appearance is configured with `configureWithOpaqueBackground` and then reinforced by `barTintColor`/`backgroundColor` in multiple places.
- The ColorTheme helpers and ThemeRefreshable refresh path will override any attempt to make bars translucent.

Decision rationale:
- Use `UINavigationBarAppearance`/`UITabBarAppearance` with transparent backgrounds and `UIBlurEffect` to achieve glass without per-view hacks.
- Remove background overrides in `ColorTheme` so per-view theme updates don't kill blur.
- Avoid deep SwiftUI rewrites; rely on UIKit appearances with light SwiftUI tweaks for list backgrounds and toolbars.

## Cross-References
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/Docs/2025-07-12-detail-view-swiftui-rewrite.md`
- `/Users/chrisbal/Documents/Code/iBurn-iOS-2/Docs/2025-10-25-swiftui-list-views-implementation.md`

## Expected Outcomes
- Nav and tab bars render with glass (blur + translucency) while preserving theme colors and readability.
- Theme refreshes no longer force opaque backgrounds when glass is enabled.
- SwiftUI lists avoid solid backgrounds that block the glass effect.
- Search bars and detail screens remain legible and consistent with the chosen appearance mode.
