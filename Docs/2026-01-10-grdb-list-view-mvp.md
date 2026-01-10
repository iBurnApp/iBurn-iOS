# GRDB List View MVP (2026-01-10)

## High-Level Plan
- **Problem Statement**: Finish the GRDB-backed list view migration for MVP (Art + Camps), bridge to legacy detail/map flows, and ensure build/tests pass without new warnings.
- **Solution Overview**: Seed PlayaDB from bundled data, introduce Camp list stack (provider/view model/SwiftUI view/hosting controller), integrate favorites sync with legacy YapDatabase metadata, and add feature-flag routing in `MoreViewController`.
- **Key Changes**:
  - New `PlayaDBSeeder` to import bundled data on first launch.
  - `LegacyDataStore` bridge for favorites, detail objects, and map annotations.
  - New Camp list stack mirroring Art list architecture.
  - Art list updates to use favorites from legacy metadata and map/detail bridging.

## Technical Details

### Modified/New Files (Full Paths)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/PlayaDBSeeder.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LegacyDataStore.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampDataProvider.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListViewModel.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListView.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampFilterSheet.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListHostingController.swift` (new)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/DependencyContainer.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListViewModel.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListView.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListHostingController.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/DisplayableObject.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/MoreViewController.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/Packages/PlayaDB/Sources/PlayaDB/Filters/CampFilter.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurnTests/BRCDataImportTests.swift` (modified)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/BRCOnboardingViewController.swift` (modified, warning fixes)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LocationProvider.swift` (modified, warning fixes)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/Preferences/FeatureFlagsView.swift` (modified, warning fixes)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcodeproj/project.pbxproj` (modified, user warning fixes)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcodeproj/xcshareddata/xcschemes/iBurn.xcscheme` (modified, user warning fixes)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcodeproj/xcshareddata/xcschemes/iBurnTests.xcscheme` (modified, user warning fixes)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcodeproj/xcshareddata/xcschemes/iBurn (Mock Date).xcscheme` (modified, user warning fixes)
- `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcodeproj/xcshareddata/xcschemes/PlayaKitTests.xcscheme` (modified, user warning fixes)

### Key Code Snippets

**Legacy favorites read moved to background connection to avoid Sendable warnings**

File: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LegacyDataStore.swift`
```swift
    func favoriteIDs(for type: DataObjectType) async -> Set<String> {
        guard let collection = collectionName(for: type) else { return [] }

        return await withCheckedContinuation { continuation in
            databaseManager.backgroundReadConnection.asyncRead { transaction in
                var ids = Set<String>()
                transaction.iterateKeysAndObjects(inCollection: collection) { (key: String, _: Any, _: inout Bool) in
                    if let metadata = transaction.metadata(forKey: key, inCollection: collection) as? BRCObjectMetadata,
                       metadata.isFavorite {
                        ids.insert(key)
                    }
                }
                continuation.resume(returning: ids)
            }
        }
    }
```

**Hosting controllers use a two-step rootView init to avoid using `self` before `super.init`**

File: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListHostingController.swift`
```swift
        let viewModel = dependencies.makeArtListViewModel()
        super.init(rootView: ArtListView(viewModel: viewModel))
        self.rootView = ArtListView(
            viewModel: viewModel,
            onSelect: { [weak self] art in
                self?.showDetail(for: art)
            },
            onShowMap: { [weak self] arts in
                self?.showMap(for: arts)
            }
        )
```

File: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListHostingController.swift`
```swift
        let viewModel = dependencies.makeCampListViewModel()
        super.init(rootView: CampListView(viewModel: viewModel))
        self.rootView = CampListView(
            viewModel: viewModel,
            onSelect: { [weak self] camp in
                self?.showDetail(for: camp)
            },
            onShowMap: { [weak self] camps in
                self?.showMap(for: camps)
            }
        )
```

**Test warning silenced with Sendable annotation**

File: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurnTests/BRCDataImportTests.swift`
```swift
extension BRCUpdateInfo: @unchecked Sendable {}
```

### Command Outputs

**Initial build (failed)**

Command:
```bash
xcodebuild -workspace /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet
```
Output:
```
/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LegacyDataStore.swift:35:17: warning: capture of 'self' with non-Sendable type 'LegacyDataStore' in a '@Sendable' closure
                self.databaseManager.uiConnection.read { transaction in
                ^
/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/LegacyDataStore.swift:14:13: note: class 'LegacyDataStore' does not conform to the 'Sendable' protocol
final class LegacyDataStore {
            ^
...
/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListHostingController.swift:42:32: error: 'self' used before 'super.init' call
            onShowMap: { [weak self] arts in
                               ^
/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/ArtListHostingController.swift:39:31: error: 'self' used before 'super.init' call
            onSelect: { [weak self] art in
                              ^
...
/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListHostingController.swift:25:32: error: 'self' used before 'super.init' call
            onShowMap: { [weak self] camps in
                               ^
/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn/ListView/CampListHostingController.swift:22:31: error: 'self' used before 'super.init' call
            onSelect: { [weak self] camp in
                              ^
Failed frontend command:
/Applications/Xcode-26.2.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend ... (output truncated by tool)
** BUILD FAILED **
```

**Build after fixes (succeeded)**

Command:
```bash
xcodebuild -workspace /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet
```
Output:
```
```

**iBurnTests (succeeded)**

Command:
```bash
xcodebuild test -workspace /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace -scheme iBurnTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet
```
Output:
```
2026-01-10 14:52:53.216 xcodebuild[90277:6845648] [MT] IDETestOperationsObserverDebug: 19.387 elapsed -- Testing started completed.
2026-01-10 14:52:53.217 xcodebuild[90277:6845648] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-01-10 14:52:53.217 xcodebuild[90277:6845648] [MT] IDETestOperationsObserverDebug: 19.387 sec, +19.387 sec -- end
Testing started
```

**PlayaKitTests attempt (failed, scheme not configured)**

Command:
```bash
xcodebuild -workspace /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace -scheme PlayaKitTests -showdestinations
```
Output:
```
Resolve Package Graph


Resolved source packages:
  Firebase: https://github.com/firebase/firebase-ios-sdk @ 12.1.0
  GoogleAdsOnDeviceConversion: https://github.com/google/GoogleAppMeasurement.git @ 2.2.0
  MapLibre Native: https://github.com/maplibre/maplibre-gl-native-distribution @ 6.18.0
  GTMSessionFetcher: https://github.com/google/gtm-session-fetcher.git @ 5.0.0
  GoogleAppMeasurement: https://github.com/google/GoogleAppMeasurement.git @ 12.1.0
  Promises: https://github.com/google/promises.git @ 2.4.0
  iBurnData: /Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data @ local
  InteropForGoogle: https://github.com/google/interop-ios-for-google-sdks.git @ 101.0.0
  Siren: https://github.com/ArtSabintsev/Siren.git @ 6.1.3
  PlayaAPI: /Users/chrisbal/Documents/Code/iBurn-iOS/Packages/PlayaAPI @ local
  GoogleDataTransport: https://github.com/google/GoogleDataTransport.git @ 10.1.0
  nanopb: https://github.com/firebase/nanopb.git @ 2.30910.0
  Zip: https://github.com/marmelroy/Zip.git @ 2.1.2
  AppCheck: https://github.com/google/app-check.git @ 11.2.0
  GRDB: https://github.com/groue/GRDB.swift.git @ 7.6.1
  gRPC: https://github.com/google/grpc-binary.git @ 1.69.0
  abseil: https://github.com/google/abseil-cpp-binary.git @ 1.2024072200.0
  leveldb: https://github.com/firebase/leveldb.git @ 1.22.5
  PlayaDB: /Users/chrisbal/Documents/Code/iBurn-iOS/Packages/PlayaDB @ local
  GoogleUtilities: https://github.com/google/GoogleUtilities.git @ 8.1.0
  SwiftProtobuf: https://github.com/apple/swift-protobuf.git @ 1.30.0

2026-01-10 14:53:59.334 xcodebuild[91899:6855964] Writing error result bundle to /var/folders/53/22cyk0_d44z19slm8vtydj440000gn/T/ResultBundle_2026-10-01_14-53-0059.xcresult
xcodebuild: error: Scheme PlayaKitTests is not currently configured for the build action.
```

## Context Preservation
- **Root cause (build failure)**: `UIHostingController` init used `self` in closures before `super.init`. Fixed by initializing with a placeholder root view and then assigning `rootView`.
- **Warning**: `LegacyDataStore.favoriteIDs` captured `self` in a `@Sendable` closure. Fixed by using `backgroundReadConnection.asyncRead`.
- **Tests**: `iBurnTests` passed; PlayaKitTests scheme not configured for build action.

## Cross-References
- `/Users/chrisbal/Documents/Code/iBurn-iOS/Docs/2025-10-25-swiftui-list-views-implementation.md`
- `/Users/chrisbal/Documents/Code/iBurn-iOS/Docs/2025-07-09-grdb-transition-complete.md`

## Expected Outcomes
- App builds cleanly with GRDB-backed Art/Camp SwiftUI lists behind the debug feature flag.
- Tapping a list row opens the legacy detail screen; map button routes to list map when coordinates exist.
- Favorites toggle updates both PlayaDB and legacy Yap metadata.
- `xcodebuild test` for `iBurnTests` succeeds on iPhone 17 Pro Max (OS 26.2).
