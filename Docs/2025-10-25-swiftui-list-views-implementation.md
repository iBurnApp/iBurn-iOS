# SwiftUI Generic Object List Implementation with PlayaDB

**Date**: 2025-10-25
**Branch**: grdb-1
**Status**: Phase 1 Complete, Phase 2 In Progress

## High-Level Plan

Implement modern SwiftUI-based list views for Art and Camps that use the PlayaDB (GRDB) data layer. The implementation will use dependency injection via a DependencyContainer, AsyncStream-based reactive data flow, and a shared helper protocol pattern. A runtime feature flag using the existing PreferenceService will allow safe rollout alongside the existing UIKit implementation.

## Problem Statement

The current list views use UIKit with YapDatabase:
- `ObjectListViewController` - Base class using `YapTableViewAdapter`
- `ArtListViewController` - Extends base with filter functionality
- Tightly coupled to YapDatabase infrastructure
- No modern SwiftUI components
- PlayaDB implementation exists but isn't being exercised by the UI

## Solution Overview

Create a new SwiftUI-based list view system that:
1. Uses PlayaDB for data access (exercises GRDB migration)
2. Employs dependency injection (no singletons)
3. Uses AsyncStream for reactive updates (no manual refresh)
4. Shares common logic via `ObjectListDataProvider` protocol
5. Toggles via feature flag for safe rollout

## Architecture Principles

Based on consultation with Gemini 2.5 Pro and iterative design:

### 1. Dependency Injection via Container
- **No singletons** - All services created once in DependencyContainer
- **Stored on AppDelegate** - `BRCAppDelegate.shared.dependencies`
- **Testable** - Easy to mock for unit tests

### 2. Shared Helper Protocol
- **`ObjectListDataProvider<Object, Filter>`** - Protocol for common data operations
- **Concrete implementations** - `ArtDataProvider`, `CampDataProvider`
- **Injected into ViewModels** - ViewModels are concrete classes, not protocols

### 3. AsyncStream-Based Observation
- **No manual refresh** - Data layer publishes AsyncStream
- **Automatic updates** - ViewModel observes stream in Task
- **PlayaDB observation wrapper** - Convert observe() callbacks to AsyncStream

### 4. Existing PreferenceService Integration
- **Runtime toggle** - `Preferences.FeatureFlags.useSwiftUILists`
- **Combine publishers** - Reactive preference changes
- **Debug UI** - Toggle in existing FeatureFlagsView

### 5. Generic Row View with Customization
- **`ObjectRowView<Object, Actions>`** - Generic row component
- **@ViewBuilder for actions** - Type-specific customization (audio button, etc.)
- **Theme support** - Uses existing `@Environment(\.themeColors)`

## Implementation Phases

### Phase 1: Core Infrastructure

#### 1.1 DependencyContainer
**File**: `iBurn/DependencyContainer.swift`

**Purpose**: Central container for app-wide dependencies

**Key Responsibilities**:
- Create PlayaDB instance once
- Create LocationProvider once
- Hold reference to PreferenceService
- Provide factory methods for ViewModels
- Lazy-load data providers

**Code Structure**:
```swift
@MainActor
class DependencyContainer {
    // Core services - created once
    let playaDB: PlayaDB
    let locationProvider: LocationProvider
    let preferenceService: PreferenceService

    // Data providers - created lazily
    private(set) lazy var artDataProvider: ArtDataProvider = {
        ArtDataProvider(playaDB: playaDB)
    }()

    private(set) lazy var campDataProvider: CampDataProvider = {
        CampDataProvider(playaDB: playaDB)
    }()

    init(preferenceService: PreferenceService = PreferenceServiceFactory.shared) throws {
        self.playaDB = try PlayaDB.create()
        self.locationProvider = CoreLocationProvider(
            locationManager: BRCAppDelegate.shared.locationManager
        )
        self.preferenceService = preferenceService
    }

    // Factory methods
    func makeArtListViewModel(initialFilter: ArtFilter = .all) -> ArtListViewModel
    func makeCampListViewModel(initialFilter: CampFilter = .all) -> CampListViewModel
}
```

#### 1.2 AppDelegate Integration
**File**: `iBurn/BRCAppDelegate.swift` or `.m/.h`

**Changes**:
```swift
extension BRCAppDelegate {
    private(set) lazy var dependencies: DependencyContainer = {
        do {
            return try DependencyContainer()
        } catch {
            fatalError("Failed to initialize dependencies: \(error)")
        }
    }()
}
```

**Access Pattern**:
```swift
BRCAppDelegate.shared.dependencies.makeArtListViewModel()
```

#### 1.3 Feature Flag Definition
**File**: `iBurn/Preferences/Preferences.swift`

**Changes**: Add to existing `Preferences.FeatureFlags` enum:
```swift
#if DEBUG
extension Preferences.FeatureFlags {
    static let useSwiftUILists = Preference<Bool>(
        key: "featureFlag.lists.useSwiftUI",
        defaultValue: false,
        description: "Use new SwiftUI list views instead of legacy UIKit for Art and Camps"
    )
}
#endif
```

#### 1.4 ObjectListDataProvider Protocol
**File**: `iBurn/ListView/ObjectListDataProvider.swift`

**Purpose**: Share common data operations across Art/Camp providers

**Protocol Definition**:
```swift
protocol ObjectListDataProvider<Object, Filter> {
    associatedtype Object: DataObject
    associatedtype Filter

    /// Observe objects matching the filter, emitting updates via AsyncStream
    func observeObjects(filter: Filter) -> AsyncStream<[Object]>

    /// Toggle favorite status for an object
    func toggleFavorite(_ object: Object) async throws

    /// Check if object is favorited
    func isFavorite(_ object: Object) async throws -> Bool

    /// Get distance string from location to object
    func distanceString(from location: CLLocation?, to object: Object) -> String?
}
```

**Key Design Decisions**:
- Uses associatedtype for type safety
- AsyncStream return type (not Combine Publisher)
- Distance calculation helper included
- Async/throws for metadata operations

#### 1.5 LocationProvider Protocol
**File**: `iBurn/ListView/LocationProvider.swift`

**Purpose**: Abstract location services for dependency injection

**Protocol**:
```swift
protocol LocationProvider {
    /// AsyncStream of location updates
    var locationStream: AsyncStream<CLLocation?> { get }

    /// Current location (synchronous accessor)
    var currentLocation: CLLocation? { get }
}
```

**Implementation**:
```swift
@MainActor
class CoreLocationProvider: LocationProvider {
    private let locationManager: CLLocationManager
    private let continuation: AsyncStream<CLLocation?>.Continuation
    let locationStream: AsyncStream<CLLocation?>

    var currentLocation: CLLocation? {
        locationManager.location
    }

    init(locationManager: CLLocationManager) {
        self.locationManager = locationManager

        // Create stream for location updates
        var cont: AsyncStream<CLLocation?>.Continuation!
        self.locationStream = AsyncStream { continuation in
            cont = continuation
        }
        self.continuation = cont

        // Subscribe to existing location notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: BRCLocationsNotificationName),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.continuation.yield(locationManager.location)
        }
    }
}
```

**Integration Points**:
- Wraps existing `CLLocationManager` from AppDelegate
- Subscribes to `BRCLocationsNotificationName` notifications
- Converts notifications to AsyncStream

#### 1.6 Generic Row View
**File**: `iBurn/ListView/ObjectRowView.swift`

**Purpose**: Reusable row component for all object types

**Component Structure**:
```swift
struct ObjectRowView<Object: DataObject, Actions: View>: View {
    let object: Object
    let distance: String?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void
    @ViewBuilder let actions: () -> Actions
    @Environment(\.themeColors) var themeColors

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(object.name)
                    .font(.headline)
                    .foregroundColor(themeColors.primaryColor)

                if let description = object.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(2)
                }

                if let distance = distance {
                    Text(distance)
                        .font(.caption)
                        .foregroundColor(themeColors.detailColor)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                actions() // Type-specific actions (audio button, etc.)

                Button(action: onFavoriteTap) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .pink : themeColors.detailColor)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
```

**Usage Pattern**:
```swift
// Art with audio button
ObjectRowView(
    object: art,
    distance: "0.5 mi",
    isFavorite: true,
    onFavoriteTap: { ... }
) {
    Button(action: { ... }) {
        Image(systemName: "play.circle.fill")
    }
}

// Camp without custom actions
ObjectRowView(
    object: camp,
    distance: "1.2 mi",
    isFavorite: false,
    onFavoriteTap: { ... }
) {
    EmptyView()
}
```

### Phase 2: Art List Implementation

#### 2.1 ArtDataProvider
**File**: `iBurn/ListView/ArtDataProvider.swift`

**Purpose**: Implement ObjectListDataProvider for ArtObject

**Key Methods**:

**observeObjects() - AsyncStream wrapper**:
```swift
func observeObjects(filter: ArtFilter) -> AsyncStream<[ArtObject]> {
    AsyncStream { continuation in
        let token = playaDB.observeArt(filter: filter) { objects in
            continuation.yield(objects)
        } onError: { error in
            print("Art observation error: \(error)")
        }

        continuation.onTermination = { @Sendable _ in
            token.cancel()
        }
    }
}
```

**Key Design Points**:
- Converts PlayaDB's callback-based observe to AsyncStream
- Properly cancels observation token on termination
- Error handling via print (could be enhanced)

**toggleFavorite() - Metadata operation**:
```swift
func toggleFavorite(_ object: ArtObject) async throws {
    try await playaDB.toggleFavorite(object)
}
```

**distanceString() - Formatting helper**:
```swift
func distanceString(from location: CLLocation?, to object: ArtObject) -> String? {
    guard let location = location, let objectLocation = object.location else {
        return nil
    }
    let distance = location.distance(from: objectLocation)
    return BRCLocations.humanReadableDistance(fromDistance: distance)
}
```

#### 2.2 ArtListViewModel
**File**: `iBurn/ListView/ArtListViewModel.swift`

**Purpose**: Concrete view model for Art list

**State Management**:
```swift
@MainActor
class ArtListViewModel: ObservableObject {
    @Published var items: [ArtObject] = []
    @Published var filter: ArtFilter {
        didSet {
            saveFilter()
            restartObservation()
        }
    }
    @Published var searchText: String = ""
    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?

    private let dataProvider: ArtDataProvider
    private let locationProvider: LocationProvider
    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
}
```

**Initialization**:
```swift
init(
    dataProvider: ArtDataProvider,
    locationProvider: LocationProvider,
    initialFilter: ArtFilter = .all
) {
    self.dataProvider = dataProvider
    self.locationProvider = locationProvider
    self.filter = loadFilter() ?? initialFilter
    self.currentLocation = locationProvider.currentLocation

    startObserving()
    startLocationUpdates()
}

deinit {
    observationTask?.cancel()
    locationTask?.cancel()
}
```

**Observation Pattern**:
```swift
private func startObserving() {
    observationTask?.cancel()
    isLoading = true

    observationTask = Task { [weak self] in
        guard let self = self else { return }
        for await items in self.dataProvider.observeObjects(filter: self.filter) {
            await MainActor.run {
                self.items = items
                self.isLoading = false
            }
        }
    }
}
```

**Key Features**:
- Automatic updates via AsyncStream observation
- Location updates via separate AsyncStream
- Filter changes trigger new observation
- Proper Task cancellation in deinit

**Filter Persistence**:
```swift
private func saveFilter() {
    if let data = try? JSONEncoder().encode(filter) {
        UserDefaults.standard.set(data, forKey: "artListFilter")
    }
}

private func loadFilter() -> ArtFilter? {
    guard let data = UserDefaults.standard.data(forKey: "artListFilter"),
          let filter = try? JSONDecoder().decode(ArtFilter.self, from: data) else {
        return nil
    }
    return filter
}
```

**Search Filtering** (in-memory):
```swift
var filteredItems: [ArtObject] {
    guard !searchText.isEmpty else { return items }
    return items.filter { art in
        art.name.localizedCaseInsensitiveContains(searchText) ||
        art.description?.localizedCaseInsensitiveContains(searchText) == true ||
        art.artistName?.localizedCaseInsensitiveContains(searchText) == true
    }
}
```

#### 2.3 ArtListView
**File**: `iBurn/ListView/ArtListView.swift`

**Purpose**: SwiftUI view for Art list

**View Structure**:
```swift
struct ArtListView: View {
    @StateObject private var viewModel: ArtListViewModel
    @State private var showingFilterSheet = false
    @Environment(\.themeColors) var themeColors

    init(viewModel: ArtListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            ForEach(viewModel.filteredItems, id: \.uid) { art in
                NavigationLink(destination: detailView(for: art)) {
                    ObjectRowView(
                        object: art,
                        distance: viewModel.distanceString(for: art),
                        isFavorite: art.isFavorite,
                        onFavoriteTap: {
                            Task { await viewModel.toggleFavorite(art) }
                        }
                    ) {
                        // Art-specific: audio button
                        if art.hasAudioTour {
                            Button(action: { playAudio(for: art) }) {
                                Image(systemName: "play.circle.fill")
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search art")
        .navigationTitle("Art")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingFilterSheet = true }) {
                    Image(systemName: viewModel.filter.onlyWithEvents ?
                        "line.3.horizontal.decrease.circle.fill" :
                        "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: showMap) {
                    Image(systemName: "map")
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            ArtFilterSheet(filter: $viewModel.filter)
        }
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            }
        }
    }
}
```

**TODO Items**:
- `detailView(for:)` - Integrate with existing DetailView
- `showMap()` - Navigate to map with art items
- `playAudio(for:)` - Integrate with audio player

#### 2.4 ArtFilterSheet
**File**: `iBurn/ListView/ArtFilterSheet.swift`

**Purpose**: Filter UI for Art list

**View Structure**:
```swift
struct ArtFilterSheet: View {
    @Binding var filter: ArtFilter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Only show art with events",
                           isOn: $filter.onlyWithEvents)
                } footer: {
                    Text("When enabled, only art installations that host events will be shown.")
                }

                Section {
                    Toggle("Only show favorites",
                           isOn: $filter.onlyFavorites)
                }
            }
            .navigationTitle("Filter Art")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

**Features**:
- Binds directly to filter
- Changes trigger ViewModel observation restart
- Simple Form-based UI matching existing patterns

#### 2.5 ArtListHostingController
**File**: `iBurn/ListView/ArtListHostingController.swift`

**Purpose**: UIKit bridge for SwiftUI view

**Implementation**:
```swift
class ArtListHostingController: UIHostingController<ArtListView> {
    init(dependencies: DependencyContainer) {
        let viewModel = dependencies.makeArtListViewModel()
        let artListView = ArtListView(viewModel: viewModel)
        super.init(rootView: artListView)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

### Phase 3: Camps List Implementation

#### 3.1 CampDataProvider
**File**: `iBurn/ListView/CampDataProvider.swift`

**Purpose**: Implement ObjectListDataProvider for CampObject

**Key Differences from Art**:
- Uses `playaDB.observeCamps(filter:)` instead of observeArt
- Otherwise identical structure

#### 3.2 CampListViewModel
**File**: `iBurn/ListView/CampListViewModel.swift`

**Purpose**: Concrete view model for Camp list

**Key Differences from Art**:
- Uses `CampFilter` (no onlyWithEvents option)
- Simpler filter logic
- Otherwise identical structure

#### 3.3 CampListView
**File**: `iBurn/ListView/CampListView.swift`

**Purpose**: SwiftUI view for Camp list

**Key Differences from Art**:
- No audio button in row actions
- Simpler or no filter sheet (depending on requirements)
- Otherwise identical structure

#### 3.4 CampListHostingController
**File**: `iBurn/ListView/CampListHostingController.swift`

**Purpose**: UIKit bridge for SwiftUI view

**Implementation**: Identical pattern to ArtListHostingController

### Phase 4: Integration with PreferenceService

#### 4.1 MoreViewController Integration
**File**: `iBurn/MoreViewController.swift`

**Changes to pushArtView()**:
```swift
func pushArtView() {
    let preferenceService = PreferenceServiceFactory.shared
    if preferenceService.getValue(Preferences.FeatureFlags.useSwiftUILists) {
        let vc = ArtListHostingController(
            dependencies: BRCAppDelegate.shared.dependencies
        )
        vc.title = "Art"
        navigationController?.pushViewController(vc, animated: true)
    } else {
        // Existing UIKit implementation
        let dbManager = BRCDatabaseManager.shared
        let artVC = ArtListViewController(
            viewName: dbManager.artFilteredByEvents,
            searchViewName: dbManager.searchArtView
        )
        artVC.title = "Art"
        navigationController?.pushViewController(artVC, animated: true)
    }
}
```

**Changes to pushCampsView()**:
```swift
func pushCampsView() {
    let preferenceService = PreferenceServiceFactory.shared
    if preferenceService.getValue(Preferences.FeatureFlags.useSwiftUILists) {
        let vc = CampListHostingController(
            dependencies: BRCAppDelegate.shared.dependencies
        )
        vc.title = "Camps"
        navigationController?.pushViewController(vc, animated: true)
    } else {
        // Existing UIKit implementation
        let dbManager = BRCDatabaseManager.shared
        let campsVC = ObjectListViewController(
            viewName: dbManager.campsViewName,
            searchViewName: dbManager.searchCampsView
        )
        campsVC.title = "Camps"
        navigationController?.pushViewController(campsVC, animated: true)
    }
}
```

#### 4.2 Feature Flags UI
**File**: `iBurn/Preferences/FeatureFlagsView.swift`

**Changes**: Add toggle to existing view:
```swift
// Add property wrapper
@PreferenceProperty(Preferences.FeatureFlags.useSwiftUILists)
private var useSwiftUILists

// Add section
Section(header: Text("List Views")) {
    Toggle(isOn: $useSwiftUILists) {
        VStack(alignment: .leading) {
            Text("SwiftUI Lists")
            if let description = Preferences.FeatureFlags.useSwiftUILists.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

## File Structure

```
iBurn/
├── DependencyContainer.swift              # App-wide dependency container
├── BRCAppDelegate.swift                   # Add dependencies property
├── ListView/                              # New directory
│   ├── ObjectListDataProvider.swift       # Shared helper protocol
│   ├── LocationProvider.swift             # Location abstraction + impl
│   ├── ObjectRowView.swift                # Generic row view
│   ├── ArtDataProvider.swift              # Art data provider
│   ├── ArtListViewModel.swift             # Art view model
│   ├── ArtListView.swift                  # Art SwiftUI view
│   ├── ArtFilterSheet.swift               # Art filter UI
│   ├── ArtListHostingController.swift     # UIKit bridge
│   ├── CampDataProvider.swift             # Camp data provider
│   ├── CampListViewModel.swift            # Camp view model
│   ├── CampListView.swift                 # Camp SwiftUI view
│   └── CampListHostingController.swift    # UIKit bridge
└── Preferences/
    ├── Preferences.swift                  # Add useSwiftUILists flag
    └── FeatureFlagsView.swift             # Add toggle

Packages/PlayaDB/                          # Existing, no changes needed
```

## Key Architecture Benefits

✅ **Single PlayaDB instance** - Created once in DependencyContainer, shared app-wide
✅ **No singletons** - All dependencies injected via initializers
✅ **Testable** - Easy to mock ObjectListDataProvider, LocationProvider
✅ **AsyncStream observation** - Automatic view updates, no manual refresh
✅ **Shared logic** - Protocol extracts common data operations
✅ **Type-safe** - Compile-time guarantees via associatedtype
✅ **Modern Swift** - async/await, AsyncStream, @MainActor
✅ **Existing PreferenceService** - Reuses proven preference system
✅ **Zero-risk rollout** - Feature flag defaults to false (UIKit)
✅ **Exercises PlayaDB** - Full validation of GRDB data layer

## Implementation Order

1. **Phase 1: Core Infrastructure**
   - DependencyContainer + AppDelegate integration
   - Feature flag definition in Preferences
   - ObjectListDataProvider protocol
   - LocationProvider protocol + implementation
   - ObjectRowView generic component

2. **Phase 2: Art List (Most Complex)**
   - ArtDataProvider (validates protocol design)
   - ArtListViewModel (validates AsyncStream pattern)
   - ArtListView + ArtFilterSheet
   - ArtListHostingController
   - MoreViewController integration

3. **Phase 3: Test Art Implementation**
   - Enable feature flag in debug UI
   - Test all Art list functionality
   - Verify PlayaDB observation works
   - Test filter persistence
   - Test location updates
   - Test favorite toggling

4. **Phase 4: Camps List (Reuse Patterns)**
   - CampDataProvider
   - CampListViewModel
   - CampListView
   - CampListHostingController
   - MoreViewController integration

5. **Phase 5: Final Testing**
   - Test both Art and Camps with feature flag
   - Compare behavior with UIKit versions
   - Performance testing
   - Memory leak testing
   - Update documentation

## Testing Strategy

### Unit Tests
- **Mock ObjectListDataProvider** for ViewModel tests
- **Mock LocationProvider** for location update tests
- **Mock PreferenceService** for feature flag tests
- **In-memory PlayaDB** for data provider tests

### Integration Tests
- Create DependencyContainer with test database
- Test full observation flow
- Test filter changes and persistence
- Test favorite toggling with real PlayaDB

### UI Tests
- Toggle feature flag in preferences
- Navigate to Art/Camps lists
- Verify search functionality
- Verify filter functionality
- Verify favorite toggling

### Comparison Testing
- Run same operations in UIKit and SwiftUI versions
- Compare results and behavior
- Verify feature parity

## Migration Path

1. **Initial State**: Feature flag defaults to `false`, all users see UIKit views
2. **Developer Testing**: Developers enable flag, test SwiftUI views
3. **Internal Testing**: Share build with flag enabled, gather feedback
4. **Beta Release**: Include flag in beta builds, allow users to opt-in
5. **Gradual Rollout**: Flip default to `true` for percentage of users
6. **Full Rollout**: Default to `true` for all users
7. **Cleanup**: Remove UIKit implementation, remove feature flag

## Known Integration Points

### TODO Items to Complete During Implementation

1. **Detail View Navigation**
   - Integrate `ArtListView.detailView(for:)` with existing DetailView
   - May need to create SwiftUI wrapper or use existing UIKit bridge

2. **Map View Navigation**
   - Integrate `showMap()` with existing `MapListViewController`
   - May need to create data source from filtered items

3. **Audio Player Integration**
   - Integrate `playAudio(for:)` with existing audio player
   - May need to access shared audio service

4. **Theme Integration**
   - Verify `@Environment(\.themeColors)` works correctly
   - Test theme switching in SwiftUI views

5. **Search Integration**
   - Verify `.searchable()` modifier works in navigation stack
   - Test search behavior consistency with UIKit

## Performance Considerations

### Memory Management
- ViewModels hold strong reference to data providers
- Data providers hold strong reference to PlayaDB
- AsyncStream automatically cleans up on cancellation
- Task cancellation in deinit prevents leaks

### Observation Efficiency
- PlayaDB observation is database-backed (efficient)
- Location updates only trigger distance recalculation
- Search filtering happens in-memory on UI thread
- Filter changes trigger full re-observation (intentional)

### Optimization Opportunities
- Could debounce search text changes
- Could virtualize very long lists (if needed)
- Could batch location distance updates

## Future Enhancements

### Potential Improvements
1. **Generic List View** - Extract common List structure into `GenericObjectListView`
2. **Combine Publishers** - Wrap AsyncStreams in Combine for advanced operators
3. **Remote Filter Sync** - Sync filters across devices
4. **Advanced Filters** - Add more filter options (distance, type, etc.)
5. **Sort Options** - Allow sorting by name, distance, etc.
6. **Empty States** - Better empty state UI
7. **Pull to Refresh** - Manual refresh capability
8. **Pagination** - If lists become very large

### Additional List Views
- **Events List** - Similar pattern for events
- **Favorites List** - Filter by favorites
- **Visit List** - Filter by visit status
- **Combined List** - All object types in one list

## Gemini Consultation Summary

Consulted Gemini 2.5 Pro on architectural decisions:

**Key Recommendations Adopted**:
1. ✅ Generic view with @ViewBuilder customization
2. ✅ Protocol-based ViewModels (modified: concrete ViewModels, protocol for providers)
3. ✅ Combine publisher wrapper (modified: AsyncStream directly)
4. ✅ @Published + @AppStorage for filter persistence
5. ✅ Generic row view with @ViewBuilder actions
6. ✅ Centralized LocationService (modified: LocationProvider protocol)

**Deviations from Recommendations**:
- Used AsyncStream directly instead of Combine (simpler, more modern)
- Concrete ViewModels instead of protocol-based (easier with SwiftUI)
- DependencyContainer instead of singleton LocationService (better testability)

## References

### Related Documentation
- `Docs/2025-10-19-grdb-composable-queries.md` - PlayaDB implementation details
- `Docs/2025-07-09-playadb-implementation-progress.md` - Original PlayaDB design
- `Docs/2025-07-12-preference-system-design.md` - PreferenceService architecture
- `Docs/2025-07-12-swiftui-detail-view-complete.md` - SwiftUI DetailView patterns

### Key Files
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` - PlayaDB protocol
- `Packages/PlayaDB/Sources/PlayaDB/Filters/ArtFilter.swift` - Filter definitions
- `iBurn/Preferences/PreferenceService.swift` - Preference system
- `iBurn/Detail/Views/DetailView.swift` - SwiftUI detail view example
- `iBurn/ObjectListViewController.swift` - Current UIKit implementation

## Success Criteria

### Phase 2 Complete (Art) When:
- ✅ Art list displays all art objects from PlayaDB
- ✅ Search filters art objects
- ✅ Filter sheet toggles onlyWithEvents
- ✅ Favorite button toggles and persists
- ✅ Distance updates when location changes
- ✅ Audio button appears for art with tours
- ✅ Navigation to detail view works
- ✅ Feature flag toggle works

### Phase 4 Complete (Camps) When:
- ✅ Camp list displays all camp objects from PlayaDB
- ✅ All features work same as Art list
- ✅ Both lists can be used interchangeably via feature flag

### Ready for Beta When:
- ✅ All success criteria met
- ✅ No crashes or memory leaks
- ✅ Performance comparable to UIKit version
- ✅ All TODO items resolved
- ✅ Documentation complete
- ✅ Code reviewed

## Next Steps

1. Review this plan with user
2. Begin Phase 1 implementation
3. Iterate on Art list until complete
4. Test thoroughly before moving to Camps
5. Document learnings and update this file

## Implementation Progress

### Phase 1: Core Infrastructure - ✅ COMPLETE

**Completed Files:**

1. **DependencyContainer.swift** ✅
   - Created app-wide dependency container
   - Manages single PlayaDB instance
   - Provides factory methods for ViewModels
   - Holds LocationProvider and PreferenceService references

2. **BRCAppDelegate+Dependencies.swift** ✅
   - Added `dependencies` property to AppDelegate
   - Lazy initialization with error handling
   - Accessible via `BRCAppDelegate.shared.dependencies`

3. **Preferences.swift** ✅
   - Added `useSwiftUILists` feature flag to `Preferences.FeatureFlags`
   - DEBUG-only flag, defaults to `false`
   - Integrates with existing PreferenceService infrastructure

4. **ObjectListDataProvider.swift** ✅
   - Protocol with associatedtype for Object and Filter
   - Defines `observeObjects(filter:)` returning AsyncStream
   - Metadata operations: `toggleFavorite`, `isFavorite`
   - Distance calculation helper: `distanceString(from:to:)`

5. **LocationProvider.swift** ✅
   - Protocol defining `locationStream` and `currentLocation`
   - `CoreLocationProvider` implementation with polling (5-second intervals)
   - `MockLocationProvider` for testing
   - Wraps existing CLLocationManager from AppDelegate

6. **ObjectRowView.swift** ✅
   - Generic SwiftUI component: `ObjectRowView<Object, Actions>`
   - Displays name, description, distance
   - Favorite button with tap handler
   - @ViewBuilder for type-specific actions (audio button, etc.)
   - Theme support via `@Environment(\.themeColors)`
   - Includes preview with mock data

### Phase 2: Art List Implementation - 🔄 IN PROGRESS

**Completed Files:**

1. **ArtDataProvider.swift** ✅
   - Implements `ObjectListDataProvider` for ArtObject
   - Wraps PlayaDB.observeArt() in AsyncStream
   - Favorite operations via PlayaDB
   - Distance formatting using TTTLocationFormatter

2. **ArtListViewModel.swift** ✅
   - `@MainActor` ObservableObject for SwiftUI
   - Published properties: items, filter, searchText, isLoading, currentLocation
   - AsyncStream observation via Task
   - Location updates via separate Task
   - Filter persistence via JSON encoding to UserDefaults
   - In-memory search filtering (name, description, artist)
   - Proper Task cancellation in deinit

3. **PlayaDB Filters** ✅
   - Added `Codable` conformance to `FilterRegion`
   - Added `Codable` conformance to `ArtFilter`
   - Enables filter persistence in UserDefaults

**Remaining Tasks:**

- **ArtListView.swift** - SwiftUI view with List, search, toolbar
- **ArtFilterSheet.swift** - Filter UI (onlyWithEvents toggle)
- **ArtListHostingController.swift** - UIKit bridge
- **MoreViewController integration** - Feature flag toggle
- **FeatureFlagsView integration** - UI toggle for beta feature
- **Testing** - Verify all functionality works

### Key Architecture Decisions Made

1. **Location Updates**: Using polling (5-second intervals) rather than delegation/notifications
   - Simpler implementation
   - Can be enhanced later with proper delegation if needed

2. **Filter Persistence**: JSON encoding to UserDefaults
   - Simple and effective
   - Could be migrated to PreferenceService later if desired

3. **Search Filtering**: Client-side filtering on top of database results
   - Search text filters in-memory for responsiveness
   - Database filter handles onlyWithEvents, onlyFavorites, region, etc.

4. **Codable Filters**: Added Codable to FilterRegion and ArtFilter
   - Enables simple persistence
   - Automatic synthesis for struct with primitives

### Next Steps

Continue Phase 2:
1. Create ArtListView with List, NavigationLink, toolbar
2. Create ArtFilterSheet for filter configuration
3. Create ArtListHostingController
4. Integrate with MoreViewController
5. Add toggle to FeatureFlagsView
6. Test with feature flag enabled

Then proceed to Phases 3-5 (Camps, Integration, Testing).

### Files Created (10 total)

**Core Infrastructure:**
- `iBurn/DependencyContainer.swift`
- `iBurn/BRCAppDelegate+Dependencies.swift`
- `iBurn/ListView/ObjectListDataProvider.swift`
- `iBurn/ListView/LocationProvider.swift`
- `iBurn/ListView/ObjectRowView.swift`

**Art Implementation:**
- `iBurn/ListView/ArtDataProvider.swift`
- `iBurn/ListView/ArtListViewModel.swift`

**Modified Files:**
- `iBurn/Preferences/Preferences.swift` - Added useSwiftUILists flag
- `Packages/PlayaDB/Sources/PlayaDB/Filters/FilterRegion.swift` - Added Codable
- `Packages/PlayaDB/Sources/PlayaDB/Filters/ArtFilter.swift` - Added Codable
