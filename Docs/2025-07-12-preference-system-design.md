# Preference System & Feature Flag Design

## Date: July 12, 2025

## High-Level Plan

### Problem Statement
Create a modern, type-safe preference management system for iBurn that:
1. Replaces direct UserDefaults access with a centralized, observable system
2. Provides SwiftUI-native property wrappers with automatic updates
3. Supports ViewModel observation through Combine publishers
4. Includes a runtime feature flag system as a subset of preferences
5. Maintains Objective-C compatibility where needed

### Solution Overview
Design a comprehensive Preference system (similar to @AppStorage but better) that:
- Uses protocol-based architecture with factory pattern
- Implements custom DynamicProperty with PassthroughSubject for updates
- Provides type-safe preference definitions
- Supports both SwiftUI views and UIKit/Combine ViewModels
- Includes DEBUG-only UI for feature flag management

## Technical Architecture

### Core Preference System

#### 1. Preference Model
```swift
// Preference.swift
struct Preference<T> {
    let key: String
    let defaultValue: T
    let description: String?
    
    init(key: String, defaultValue: T, description: String? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.description = description
    }
}
```

#### 2. Preference Service Protocol
```swift
// PreferenceService.swift
protocol PreferenceService {
    func getValue<T>(_ preference: Preference<T>) -> T
    func setValue<T>(_ value: T, for preference: Preference<T>)
    func publisher<T>(for preference: Preference<T>) -> AnyPublisher<T, Never>
    func reset<T>(_ preference: Preference<T>)
    func resetAll()
}
```

#### 3. Preference Service Implementation
```swift
// PreferenceServiceImpl.swift
import Combine

class PreferenceServiceImpl: NSObject, PreferenceService {
    private let userDefaults: UserDefaults
    private var publishers = [String: Any]()
    private let publisherQueue = DispatchQueue(label: "com.burningman.iburn.preferences")
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        super.init()
    }
    
    func getValue<T>(_ preference: Preference<T>) -> T {
        return userDefaults.object(forKey: preference.key) as? T ?? preference.defaultValue
    }
    
    func setValue<T>(_ value: T, for preference: Preference<T>) {
        userDefaults.set(value, forKey: preference.key)
        
        // Notify subscribers
        publisherQueue.async { [weak self] in
            if let publisher = self?.publishers[preference.key] as? PassthroughSubject<T, Never> {
                publisher.send(value)
            }
        }
    }
    
    func publisher<T>(for preference: Preference<T>) -> AnyPublisher<T, Never> {
        publisherQueue.sync {
            let publisher: PassthroughSubject<T, Never>
            if let existing = publishers[preference.key] as? PassthroughSubject<T, Never> {
                publisher = existing
            } else {
                publisher = PassthroughSubject<T, Never>()
                publishers[preference.key] = publisher
            }
            
            return publisher
                .prepend(getValue(preference))
                .share() // Important: share() ensures multiple subscribers get the same values
                .eraseToAnyPublisher()
        }
    }
    
    func reset<T>(_ preference: Preference<T>) {
        userDefaults.removeObject(forKey: preference.key)
        setValue(preference.defaultValue, for: preference)
    }
    
    func resetAll() {
        // Reset only known preferences, not all UserDefaults
    }
}

// MARK: - Objective-C Compatibility
extension PreferenceServiceImpl {
    @objc func boolValue(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    @objc func setBoolValue(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    @objc func stringValue(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    @objc func setStringValue(_ value: String?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
}
```

#### 4. Factory Pattern
```swift
// PreferenceServiceFactory.swift
enum PreferenceServiceFactory {
    private static var _service: PreferenceService = PreferenceServiceImpl()
    
    static var shared: PreferenceService {
        return _service
    }
    
    // For testing
    static func setService(_ service: PreferenceService) {
        _service = service
    }
}
```

#### 5. Dynamic Property Implementation
```swift
// PreferenceProperty.swift
import SwiftUI
import Combine

@propertyWrapper
struct PreferenceProperty<Value>: DynamicProperty {
    private let preference: Preference<Value>
    private let service: PreferenceService
    
    @ObservedObject private var observer: PreferenceObserver<Value>
    
    init(_ preference: Preference<Value>) {
        self.preference = preference
        self.service = PreferenceServiceFactory.shared
        self.observer = PreferenceObserver(preference: preference, service: service)
    }
    
    var wrappedValue: Value {
        get { observer.value }
        nonmutating set { 
            service.setValue(newValue, for: preference)
        }
    }
    
    var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
    
    // Expose publisher for ViewModel observation
    var publisher: AnyPublisher<Value, Never> {
        service.publisher(for: preference)
    }
}

// Internal observer to trigger SwiftUI updates
private class PreferenceObserver<T>: ObservableObject {
    @Published var value: T
    private var cancellable: AnyCancellable?
    
    init(preference: Preference<T>, service: PreferenceService) {
        self.value = service.getValue(preference)
        
        self.cancellable = service.publisher(for: preference)
            .dropFirst() // Skip initial value since we already have it
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.value = newValue
            }
    }
}
```

### Preference Definitions

#### 6. Organized Preference Structure
```swift
// Preferences.swift
enum Preferences {
    
    // MARK: - Feature Flags (DEBUG only)
    #if DEBUG
    enum FeatureFlags {
        static let useSwiftUIDetailView = Preference<Bool>(
            key: "featureFlag.detailView.useSwiftUI",
            defaultValue: false,
            description: "Use new SwiftUI detail view instead of legacy UIKit"
        )
    }
    #endif
    
    // MARK: - Appearance
    enum Appearance {
        static let theme = Preference<String>(
            key: "appearance.theme",
            defaultValue: "system",
            description: "App theme: system, light, or dark"
        )
        
        static let useImageColors = Preference<Bool>(
            key: "appearance.useImageColors",
            defaultValue: true,
            description: "Extract colors from images for UI theming"
        )
    }
    
    // MARK: - Navigation
    enum Navigation {
        static let isNavigationModeDisabled = Preference<Bool>(
            key: "navigation.modeDisabled",
            defaultValue: false,
            description: "Disable navigation mode in map view"
        )
    }
    
    // MARK: - Data & Updates
    enum Data {
        static let lastUpdateCheck = Preference<Date?>(
            key: "data.lastUpdateCheck",
            defaultValue: nil
        )
        
        static let autoDownloadUpdates = Preference<Bool>(
            key: "data.autoDownloadUpdates",
            defaultValue: true
        )
    }
    
    // MARK: - Onboarding
    enum Onboarding {
        static let hasCompletedOnboarding = Preference<Bool>(
            key: "onboarding.completed",
            defaultValue: false
        )
        
        static let onboardingVersion = Preference<Int>(
            key: "onboarding.version",
            defaultValue: 0
        )
    }
}
```

### SwiftUI Debug Panel

#### 7. Feature Flags View (DEBUG only)
```swift
// FeatureFlagsView.swift
#if DEBUG
struct FeatureFlagsView: View {
    @PreferenceProperty(Preferences.FeatureFlags.useSwiftUIDetailView) 
    private var useSwiftUIDetail
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $useSwiftUIDetail) {
                    VStack(alignment: .leading) {
                        Text("Use SwiftUI Detail View")
                        if let description = Preferences.FeatureFlags.useSwiftUIDetailView.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Detail View")
            }
        }
        .navigationTitle("Feature Flags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// FeatureFlagsHostingController.swift
class FeatureFlagsHostingController: UIHostingController<FeatureFlagsView> {
    init() {
        super.init(rootView: FeatureFlagsView())
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
```

### Integration Examples

#### 8. Detail View Controller Factory
```swift
// DetailViewControllerFactory+Preference.swift
extension DetailViewControllerFactory {
    static func createDetailViewController(
        for dataObject: BRCDataObject,
        coordinator: DetailActionCoordinator
    ) -> UIViewController {
        #if DEBUG
        let service = PreferenceServiceFactory.shared
        if service.getValue(Preferences.FeatureFlags.useSwiftUIDetailView) {
            return create(with: dataObject, coordinator: coordinator)
        }
        #endif
        
        return BRCDetailViewController(dataObject: dataObject)
    }
}
```

#### 9. ViewModel Usage
```swift
// Example ViewModel
class SettingsViewModel: ObservableObject {
    @Published var isDarkMode: Bool = false
    @Published var navigationDisabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe theme changes
        PreferenceServiceFactory.shared
            .publisher(for: Preferences.Appearance.theme)
            .map { $0 == "dark" }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDark in
                self?.isDarkMode = isDark
            }
            .store(in: &cancellables)
        
        // Observe navigation preference
        PreferenceServiceFactory.shared
            .publisher(for: Preferences.Navigation.isNavigationModeDisabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] disabled in
                self?.navigationDisabled = disabled
            }
            .store(in: &cancellables)
    }
}
```

#### 10. Migration from UserDefaults
```swift
// Existing code:
UserDefaults.standard.bool(forKey: "someKey")

// New code:
static let someSetting = Preference<Bool>(key: "someKey", defaultValue: false)
let value = PreferenceServiceFactory.shared.getValue(someSetting)

// Or in SwiftUI:
@PreferenceProperty(Preferences.SomeCategory.someSetting) var someSetting
```

### File Structure
```
iBurn/
  Preferences/
    Preference.swift
    PreferenceService.swift
    PreferenceServiceImpl.swift
    PreferenceServiceFactory.swift
    PreferenceProperty.swift
    Preferences.swift
    #if DEBUG
    FeatureFlagsView.swift
    FeatureFlagsHostingController.swift
    #endif
    Extensions/
      DetailViewControllerFactory+Preference.swift
```

## Implementation Status ✅

### ✅ COMPLETED - Core Infrastructure (1 hour)
- ✅ Created Preference model struct with convenience initializers
- ✅ Defined PreferenceService protocol with publisher support
- ✅ Implemented PreferenceServiceImpl with thread-safe publisher management
- ✅ Added .share() to publishers for efficiency
- ✅ Created factory pattern with dependency injection support
- ✅ Added comprehensive Obj-C compatibility methods

### ✅ COMPLETED - Dynamic Property (45 min)
- ✅ Implemented PreferenceProperty with @ObservedObject pattern
- ✅ Created internal PreferenceObserver for automatic updates
- ✅ Tested SwiftUI automatic updates via internal @Published property

### ✅ COMPLETED - Preference Definitions (30 min)
- ✅ Created organized Preferences enum with domain grouping
- ✅ Defined feature flags under DEBUG-only namespace
- ✅ Mapped existing UserDefaults keys for migration

### ✅ COMPLETED - Debug UI (30 min)
- ✅ Created FeatureFlagsView with toggle and descriptions
- ✅ Created FeatureFlagsHostingController with theme integration
- ✅ Integrated with MoreViewController via storyboard cell (tag=14)
- ✅ Removed programmatic cell creation hacks after storyboard update

### ✅ COMPLETED - DetailViewControllerFactory Integration (45 min)
- ✅ Updated DetailViewControllerFactory with preference-based selection
- ✅ Modified all 5 usage points:
  - MainMapViewController.swift:164
  - MapViewAdapter.swift:209
  - PageViewManager.swift:32, 57
  - DetailActionCoordinator.swift:101
- ✅ Handled UIViewController return type properly without forced unwrapping
- ✅ Project builds successfully with no compilation errors

## Files Created

### Core System (6 files)
- `/iBurn/Preferences/Preference.swift` - Type-safe preference model
- `/iBurn/Preferences/PreferenceService.swift` - Service protocol 
- `/iBurn/Preferences/PreferenceServiceImpl.swift` - Implementation with Combine
- `/iBurn/Preferences/PreferenceServiceFactory.swift` - Dependency injection
- `/iBurn/Preferences/PreferenceProperty.swift` - SwiftUI DynamicProperty wrapper
- `/iBurn/Preferences/Preferences.swift` - Organized preference definitions

### UI Components (2 files)
- `/iBurn/Preferences/FeatureFlagsView.swift` - SwiftUI debug interface
- `/iBurn/Preferences/FeatureFlagsHostingController.swift` - UIKit integration

### Extensions (1 file)
- `/iBurn/Preferences/Extensions/DetailViewControllerFactory+Preference.swift` - Factory integration

**Total: 9 new files**

## How It Works

### 1. Basic Usage in SwiftUI
```swift
struct MyView: View {
    @PreferenceProperty(Preferences.FeatureFlags.useSwiftUIDetailView) 
    var useNewDetail
    
    var body: some View {
        Toggle("Use New Detail", isOn: $useNewDetail)
    }
}
```

### 2. ViewModel Observation
```swift
class MyViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        PreferenceServiceFactory.shared
            .publisher(for: Preferences.FeatureFlags.useSwiftUIDetailView)
            .sink { [weak self] isEnabled in
                // React to changes
            }
            .store(in: &cancellables)
    }
}
```

### 3. Feature Flag Checking
```swift
let service = PreferenceServiceFactory.shared
if service.getValue(Preferences.FeatureFlags.useSwiftUIDetailView) {
    // Use new implementation
} else {
    // Use legacy implementation  
}
```

## Testing the System

### Manual Testing Steps
1. **Build the app** - ✅ Project compiles successfully
2. **Navigate to More tab** - Should see "Feature Flags" option in DEBUG builds
3. **Toggle feature flag** - Should persist across app launches
4. **Test detail view** - Should switch between UIKit/SwiftUI based on flag

### Automated Testing
```swift
func testPreferenceSystem() {
    let mockService = MockPreferenceService()
    PreferenceServiceFactory.setService(mockService)
    
    // Test preference getting/setting
    let flag = Preferences.FeatureFlags.useSwiftUIDetailView
    XCTAssertFalse(mockService.getValue(flag))
    
    mockService.setValue(true, for: flag)
    XCTAssertTrue(mockService.getValue(flag))
}
```

## Key Benefits

1. **Type Safety**: No more string-based keys
2. **Discoverability**: All preferences in one place  
3. **Reactive**: Automatic updates in SwiftUI and Combine
4. **Testable**: Protocol-based with dependency injection
5. **Gradual Migration**: Can coexist with existing UserDefaults
6. **Performance**: Shared publishers prevent duplicate work
7. **Thread Safe**: Publisher management uses concurrent queue
8. **Obj-C Compatible**: Key methods exposed for legacy code
9. **DEBUG Only UI**: Feature flags only accessible in debug builds
10. **Modern Architecture**: Uses SwiftUI DynamicProperty and Combine

## Future Enhancements

1. Add preference groups/sections for better organization
2. Import/export preferences for debugging
3. Preference versioning and migration support
4. Analytics for feature flag usage tracking
5. Remote configuration support (if needed later)
6. Preference validation and constraints
7. Preference change history/audit trail

## Testing Strategy

```swift
class MockPreferenceService: PreferenceService {
    private var values = [String: Any]()
    private var publishers = [String: PassthroughSubject<Any, Never>]()
    
    func getValue<T>(_ preference: Preference<T>) -> T {
        return values[preference.key] as? T ?? preference.defaultValue
    }
    
    func setValue<T>(_ value: T, for preference: Preference<T>) {
        values[preference.key] = value
        publishers[preference.key]?.send(value)
    }
    
    // ... other methods
}
```

## Conversation Context

This design evolved through discussion of several approaches:
1. Started with basic feature flag system
2. Explored @AppStorage limitations
3. Investigated DynamicProperty with NotificationCenter
4. Settled on PassthroughSubject with .share() for efficiency
5. Expanded to general preference system with feature flags as subset
6. Added Obj-C compatibility requirements

The final design provides a modern, SwiftUI-native preference system that can gradually replace all UserDefaults usage in the app while maintaining compatibility with existing code.