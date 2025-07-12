# BRCDetailViewController SwiftUI Migration - Technical Specification

## Problem Statement

The current `BRCDetailViewController` is implemented in Objective-C with UIKit patterns from iOS 8-era. We need to modernize this critical component to SwiftUI while maintaining full feature parity and improving maintainability.

## Solution Overview

Migrate to SwiftUI using modern iOS 16+ patterns with protocol-based dependency injection, actions-based navigation, and a single ViewModel approach. The implementation will be wrapped in a UIViewController factory to maintain compatibility with the existing UIKit-based navigation system.

## High-Level Architecture

### Core Principles
- **Single ViewModel Pattern**: One `DetailViewModel` with `@Published` properties, no `@State` in views
- **Protocol-Based Dependencies**: Inject database, calendar, and other services for testability and flexibility
- **Actions-Based Navigation**: Use enum + closure handler, delegate navigation to coordinator pattern
- **Modern Swift Patterns**: Target iOS 16+, use enum with associated values for cell types
- **UIKit Compatibility**: Wrap in UIViewController factory to maintain existing integration points

## Technical Design

### 1. Data Layer Protocols

```swift
protocol DetailDataServiceProtocol {
    func updateFavoriteStatus(for object: BRCDataObject, isFavorite: Bool) async throws
    func updateUserNotes(for object: BRCDataObject, notes: String) async throws
    func getMetadata(for object: BRCDataObject) -> BRCObjectMetadata?
}

protocol CalendarServiceProtocol {
    func addEventToCalendar(_ event: BRCEventObject) async throws -> String?
    func removeEventFromCalendar(identifier: String) async throws
    func canAddEvents() -> Bool
    func requestCalendarPermission() async -> Bool
}

protocol AudioServiceProtocol {
    func playAudio(tour: BRCAudioTour)
    func pauseAudio()
    func isPlaying(tour: BRCAudioTour) -> Bool
}
```

### 2. Cell Type System

```swift
// Wrapper struct for unique identification in SwiftUI
struct DetailCell: Identifiable {
    let id = UUID()
    let type: DetailCellType
    
    init(_ type: DetailCellType) {
        self.type = type
    }
}

// Non-identifiable enum for cell types
enum DetailCellType {
    case image(UIImage, aspectRatio: CGFloat)
    case text(String, style: DetailTextStyle)
    case email(String, label: String?)
    case url(URL, title: String)
    case coordinates(CLLocationCoordinate2D, label: String)
    case schedule(NSAttributedString)
    case relationship(BRCDataObject, type: RelationshipType)
    case eventRelationship([BRCEventObject], hostName: String)
    case playaAddress(String, tappable: Bool)
    case distance(CLLocationDistance)
    case audio(BRCAudioTour, isPlaying: Bool)
    case userNotes(String)
    case date(Date, format: DateFormatStyle)
}

enum DetailTextStyle {
    case body
    case caption
    case title
    case subtitle
}

enum RelationshipType {
    case hostedBy(String) // "Hosted by Camp Name"
    case presentedBy(String) // "Presented by Artist"
    case relatedCamp
    case relatedArt
}
```

### 3. Actions System

```swift
enum DetailAction {
    case openEmail(String)
    case openURL(URL)
    case showMap(BRCDataObject)
    case navigateToObject(BRCDataObject)
    case showEventsList([BRCEventObject], hostName: String)
    case showImageViewer(UIImage)
    case shareCoordinates(CLLocationCoordinate2D)
    case playAudio(BRCAudioTour)
    case pauseAudio
    case editNotes(current: String, completion: (String) -> Void)
}
```

### 4. ViewModel Architecture

```swift
@MainActor
class DetailViewModel: ObservableObject {
    // Published State
    @Published var dataObject: BRCDataObject
    @Published var metadata: BRCObjectMetadata
    @Published var cells: [DetailCell] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var canAddToCalendar = false
    @Published var isAudioPlaying = false
    
    // Dependencies
    private let dataService: DetailDataServiceProtocol
    private let calendarService: CalendarServiceProtocol
    private let audioService: AudioServiceProtocol
    private let locationService: LocationServiceProtocol
    
    // Actions Handler
    let actionsHandler: (DetailAction) -> Void
    
    init(
        dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        calendarService: CalendarServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        actionsHandler: @escaping (DetailAction) -> Void
    ) {
        self.dataObject = dataObject
        self.dataService = dataService
        self.calendarService = calendarService
        self.audioService = audioService
        self.locationService = locationService
        self.actionsHandler = actionsHandler
        
        // Initialize with basic data object - no side effects in init
        self.metadata = dataService.getMetadata(for: dataObject) ?? BRCObjectMetadata()
    }
    
    // Public Methods
    func toggleFavorite() async {
        // Implementation
    }
    
    func addToCalendar() async {
        // Implementation for events only
    }
    
    func updateNotes(_ notes: String) async {
        // Implementation
    }
    
    func handleCellTap(_ cell: DetailCell) {
        // Route to appropriate action based on cell.type
    }
    
    func loadData() async {
        // Load metadata and generate cell types - called from onAppear
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update metadata
            if let updatedMetadata = dataService.getMetadata(for: dataObject) {
                self.metadata = updatedMetadata
            }
            
            // Check calendar capability
            self.canAddToCalendar = calendarService.canAddEvents() && dataObject is BRCEventObject
            
            // Generate cells
            self.cells = generateCells()
            
        } catch {
            self.error = error
        }
    }
    
    // Private Methods
    private func generateCells() -> [DetailCell] {
        // Factory method to create cells based on data object type
        let cellTypes = generateCellTypes()
        return cellTypes.map { DetailCell($0) }
    }
    
    private func generateCellTypes() -> [DetailCellType] {
        // Factory method to create cell types based on data object type
    }
}
```

### 5. SwiftUI View Structure

```swift
struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header with image/map if available
                if let headerCell = viewModel.cells.first(where: { 
                    if case .image = $0.type { return true }
                    return false
                }) {
                    DetailHeaderView(cell: headerCell, viewModel: viewModel)
                }
                
                // Content cells
                ForEach(viewModel.cells) { cell in
                    DetailCellView(cell: cell, viewModel: viewModel)
                        .onTapGesture {
                            viewModel.handleCellTap(cell)
                        }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if viewModel.canAddToCalendar {
                        Button("Add to Calendar") {
                            Task { await viewModel.addToCalendar() }
                        }
                    }
                    
                    Button(action: {
                        Task { await viewModel.toggleFavorite() }
                    }) {
                        Image(systemName: viewModel.metadata.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(.pink)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
    }
}
```

### 6. Custom UIHostingController

```swift
class DetailHostingController: UIHostingController<DetailView> {
    let viewModel: DetailViewModel
    
    init(
        dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        calendarService: CalendarServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        actionsHandler: @escaping (DetailAction) -> Void
    ) {
        // Create ViewModel without side effects
        self.viewModel = DetailViewModel(
            dataObject: dataObject,
            dataService: dataService,
            calendarService: calendarService,
            audioService: audioService,
            locationService: locationService,
            actionsHandler: actionsHandler
        )
        
        // Create SwiftUI view
        let detailView = DetailView(viewModel: viewModel)
        super.init(rootView: detailView)
        
        // Configure UIKit properties
        self.title = dataObject.title
        self.hidesBottomBarWhenPushed = true
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Any UIKit-specific setup
    }
}

// Factory for creating the controller
class DetailViewControllerFactory {
    static func create(
        with dataObject: BRCDataObject,
        actionsHandler: @escaping (DetailAction) -> Void
    ) -> DetailHostingController {
        
        // Create services
        let dataService = DetailDataService()
        let calendarService = CalendarService()
        let audioService = AudioService.shared
        let locationService = LocationService.shared
        
        return DetailHostingController(
            dataObject: dataObject,
            dataService: dataService,
            calendarService: calendarService,
            audioService: audioService,
            locationService: locationService,
            actionsHandler: actionsHandler
        )
    }
}
```

### 7. Xcode Previews Support

```swift
// Mock services for previews
class MockDetailDataService: DetailDataServiceProtocol {
    func updateFavoriteStatus(for object: BRCDataObject, isFavorite: Bool) async throws {
        // Mock implementation
    }
    
    func updateUserNotes(for object: BRCDataObject, notes: String) async throws {
        // Mock implementation
    }
    
    func getMetadata(for object: BRCDataObject) -> BRCObjectMetadata? {
        let metadata = BRCObjectMetadata()
        metadata.isFavorite = false
        metadata.userNotes = "Sample notes for preview"
        return metadata
    }
}

class MockCalendarService: CalendarServiceProtocol {
    func addEventToCalendar(_ event: BRCEventObject) async throws -> String? {
        return "mock-calendar-id"
    }
    
    func removeEventFromCalendar(identifier: String) async throws {
        // Mock implementation
    }
    
    func canAddEvents() -> Bool { true }
    func requestCalendarPermission() async -> Bool { true }
}

class MockAudioService: AudioServiceProtocol {
    func playAudio(tour: BRCAudioTour) {}
    func pauseAudio() {}
    func isPlaying(tour: BRCAudioTour) -> Bool { false }
}

// Preview factory
extension DetailViewModel {
    static func createPreview(with dataObject: BRCDataObject) -> DetailViewModel {
        return DetailViewModel(
            dataObject: dataObject,
            dataService: MockDetailDataService(),
            calendarService: MockCalendarService(),
            audioService: MockAudioService(),
            locationService: LocationService.shared,
            actionsHandler: { action in
                print("Preview action: \(action)")
            }
        )
    }
}

// SwiftUI Previews
struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Art object preview
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.artObject))
            }
            .previewDisplayName("Art Detail")
            
            // Camp object preview  
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.campObject))
            }
            .previewDisplayName("Camp Detail")
            
            // Event object preview
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.eventObject))
            }
            .previewDisplayName("Event Detail")
            
            // Dark mode preview
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.artObject))
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}

// Mock data objects for previews
enum MockDataObjects {
    static let artObject: BRCArtObject = {
        let art = BRCArtObject()
        art.title = "Sample Art Installation"
        art.detailDescription = "This is a beautiful art installation located on the playa."
        art.artistName = "Sample Artist"
        art.playaLocation = "3:00 & 500'"
        art.url = URL(string: "https://example.com")
        return art
    }()
    
    static let campObject: BRCCampObject = {
        let camp = BRCCampObject()
        camp.title = "Sample Camp"
        camp.detailDescription = "A welcoming camp with great vibes."
        camp.email = "camp@example.com"
        camp.playaLocation = "6:00 & Esplanade"
        return camp
    }()
    
    static let eventObject: BRCEventObject = {
        let event = BRCEventObject()
        event.title = "Sample Event"
        event.detailDescription = "An amazing event you won't want to miss."
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600) // 1 hour later
        event.playaLocation = "Center Camp"
        return event
    }()
}
```

### 8. Unit Testing Strategy

```swift
// Test target: DetailViewModelTests.swift
import XCTest
@testable import iBurn

class DetailViewModelTests: XCTestCase {
    var viewModel: DetailViewModel!
    var mockDataService: MockDetailDataService!
    var mockCalendarService: MockCalendarService!
    var mockAudioService: MockAudioService!
    var mockLocationService: MockLocationService!
    var capturedActions: [DetailAction] = []
    
    override func setUp() {
        super.setUp()
        mockDataService = MockDetailDataService()
        mockCalendarService = MockCalendarService()
        mockAudioService = MockAudioService()
        mockLocationService = MockLocationService()
        capturedActions = []
        
        viewModel = DetailViewModel(
            dataObject: MockDataObjects.artObject,
            dataService: mockDataService,
            calendarService: mockCalendarService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            actionsHandler: { action in
                self.capturedActions.append(action)
            }
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockDataService = nil
        mockCalendarService = nil
        mockAudioService = nil
        mockLocationService = nil
        capturedActions = []
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.dataObject.title, "Sample Art Installation")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.cells.isEmpty) // Not loaded until onAppear
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadData() async {
        await viewModel.loadData()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.cells.isEmpty)
    }
    
    func testLoadDataSetsCanAddToCalendarForEvents() async {
        let eventViewModel = DetailViewModel(
            dataObject: MockDataObjects.eventObject,
            dataService: mockDataService,
            calendarService: mockCalendarService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            actionsHandler: { _ in }
        )
        
        await eventViewModel.loadData()
        
        XCTAssertTrue(eventViewModel.canAddToCalendar)
    }
    
    func testLoadDataDoesNotSetCanAddToCalendarForNonEvents() async {
        await viewModel.loadData() // Art object
        
        XCTAssertFalse(viewModel.canAddToCalendar)
    }
    
    // MARK: - Favorite Tests
    
    func testToggleFavoriteFromFalseToTrue() async {
        mockDataService.favoriteStatus = false
        
        await viewModel.toggleFavorite()
        
        XCTAssertTrue(mockDataService.updateFavoriteCalled)
        XCTAssertTrue(mockDataService.lastFavoriteValue!)
    }
    
    func testToggleFavoriteFromTrueToFalse() async {
        mockDataService.favoriteStatus = true
        viewModel.metadata.isFavorite = true
        
        await viewModel.toggleFavorite()
        
        XCTAssertTrue(mockDataService.updateFavoriteCalled)
        XCTAssertFalse(mockDataService.lastFavoriteValue!)
    }
    
    // MARK: - Calendar Tests
    
    func testAddToCalendarForEvent() async {
        let eventViewModel = DetailViewModel(
            dataObject: MockDataObjects.eventObject,
            dataService: mockDataService,
            calendarService: mockCalendarService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            actionsHandler: { _ in }
        )
        
        await eventViewModel.addToCalendar()
        
        XCTAssertTrue(mockCalendarService.addEventCalled)
    }
    
    // MARK: - Cell Generation Tests
    
    func testCellGenerationForArtObject() async {
        await viewModel.loadData()
        
        let cells = viewModel.cells
        XCTAssertTrue(cells.contains { if case .text = $0.type { return true }; return false })
        XCTAssertTrue(cells.contains { if case .url = $0.type { return true }; return false })
    }
    
    func testCellGenerationForEventObject() async {
        let eventViewModel = DetailViewModel(
            dataObject: MockDataObjects.eventObject,
            dataService: mockDataService,
            calendarService: mockCalendarService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            actionsHandler: { _ in }
        )
        
        await eventViewModel.loadData()
        
        let cells = eventViewModel.cells
        XCTAssertTrue(cells.contains { if case .schedule = $0.type { return true }; return false })
    }
    
    // MARK: - Actions Tests
    
    func testCellTapTriggersAction() {
        let urlCellType = DetailCellType.url(URL(string: "https://example.com")!, title: "Test")
        let urlCell = DetailCell(urlCellType)
        
        viewModel.handleCellTap(urlCell)
        
        XCTAssertEqual(capturedActions.count, 1)
        if case .openURL(let url) = capturedActions.first {
            XCTAssertEqual(url.absoluteString, "https://example.com")
        } else {
            XCTFail("Expected openURL action")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadDataHandlesErrors() async {
        mockDataService.shouldThrowError = true
        
        await viewModel.loadData()
        
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
}

// MARK: - Mock Service Implementations for Testing

class MockDetailDataService: DetailDataServiceProtocol {
    var updateFavoriteCalled = false
    var updateNotesCalled = false
    var lastFavoriteValue: Bool?
    var favoriteStatus = false
    var shouldThrowError = false
    
    func updateFavoriteStatus(for object: BRCDataObject, isFavorite: Bool) async throws {
        if shouldThrowError {
            throw DetailError.updateFailed
        }
        updateFavoriteCalled = true
        lastFavoriteValue = isFavorite
        favoriteStatus = isFavorite
    }
    
    func updateUserNotes(for object: BRCDataObject, notes: String) async throws {
        if shouldThrowError {
            throw DetailError.updateFailed
        }
        updateNotesCalled = true
    }
    
    func getMetadata(for object: BRCDataObject) -> BRCObjectMetadata? {
        let metadata = BRCObjectMetadata()
        metadata.isFavorite = favoriteStatus
        return metadata
    }
}

class MockCalendarService: CalendarServiceProtocol {
    var addEventCalled = false
    var removeEventCalled = false
    
    func addEventToCalendar(_ event: BRCEventObject) async throws -> String? {
        addEventCalled = true
        return "mock-event-id"
    }
    
    func removeEventFromCalendar(identifier: String) async throws {
        removeEventCalled = true
    }
    
    func canAddEvents() -> Bool { true }
    func requestCalendarPermission() async -> Bool { true }
}

enum DetailError: Error {
    case updateFailed
}
```

## Implementation Plan

### Phase 1: Core Foundation (P0) - Week 1-2

#### Week 1: Protocols & Data Layer
- [ ] Define all service protocols (`DetailDataServiceProtocol`, `CalendarServiceProtocol`, etc.)
- [ ] Create concrete implementations wrapping existing Objective-C code
- [ ] Build `DetailCellType` enum with all 15+ cell variants
- [ ] Create base cell view components for testing

#### Week 2: ViewModel & Basic UI
- [ ] Implement `DetailViewModel` with dependency injection
- [ ] Create basic `DetailView` SwiftUI structure with scroll view
- [ ] Add actions handler system and ensure navigation delegation works
- [ ] Build UIViewController factory wrapper
- [ ] Test with simple Art objects (text and image cells only)

### Phase 2: Cell Implementation (P0) - Week 3-4

#### Week 3: Static Cell Types
- [ ] Implement all non-interactive cells (text, image, schedule, date)
- [ ] Add proper styling and theming support via Environment values
- [ ] Implement user notes cell with editing capability
- [ ] Test scrolling performance with complex cell layouts

#### Week 4: Interactive Cell Types
- [ ] Implement email, URL, and coordinates cells with tap handlers
- [ ] Add relationship navigation cells
- [ ] Implement playa address cells (some tappable for map)
- [ ] Add distance calculation cell with location updates

### Phase 3: Advanced Features (P1) - Week 5-6

#### Week 5: Media & Map Integration
- [ ] Map integration using UIViewRepresentable for MapLibre
- [ ] Audio player controls integration with existing audio system
- [ ] Image viewer implementation (replace JTSImageViewController)
- [ ] Share functionality for coordinates and other shareable content

#### Week 6: Calendar & Polish
- [ ] Implement separated calendar integration (remove from favorite button)
- [ ] Add "Add to Calendar" button for events only
- [ ] Request minimal calendar permissions using EventKitUI
- [ ] Polish animations and transitions
- [ ] Performance optimization for @Published updates

### Phase 4: Integration & Testing (P1) - Week 7-8

#### Week 7: Navigation Integration
- [ ] Create navigation coordinator protocol and implementation
- [ ] Update all calling sites to use new factory method
- [ ] Test integration with page view controller for swiping
- [ ] Ensure proper navigation stack management across the app

#### Week 8: Testing & Rollout
- [ ] Comprehensive unit tests for ViewModel and services
- [ ] UI tests for all critical user flows and interactions
- [ ] Performance testing with large datasets
- [ ] Feature flag implementation for gradual rollout
- [ ] Documentation and code review

## Risk Mitigation Strategies

### Performance Concerns
1. **@Published Optimization**: 
   - Batch updates using `withAnimation`
   - Use `willSet`/`didSet` carefully to avoid unnecessary UI updates
   - Implement proper debouncing for frequent updates (like distance)

2. **Cell Rendering Performance**:
   - Use `LazyVStack` for efficient memory usage
   - Implement proper cell identification for reuse patterns
   - Test with large data objects (camps with many events)

3. **Memory Management**:
   - Ensure proper cleanup of closures and observers in ViewModel
   - Test for retain cycles with coordinator pattern
   - Monitor memory usage during navigation

### Migration Risks
1. **Gradual Rollout Strategy**:
   - Feature flag to switch between old/new implementations
   - A/B testing capability for performance comparison
   - Easy rollback mechanism if issues arise

2. **Compatibility Strategy**:
   - Keep old UIKit version available during transition period
   - Maintain identical public interfaces for calling code
   - Test all navigation flows from different entry points

3. **Data Consistency**:
   - Ensure metadata updates work identically in both systems
   - Test favorite/unfavorite functionality thoroughly
   - Verify calendar integration maintains existing behavior

### Calendar Integration Changes
1. **Permission Model**:
   - Use EventKitUI framework for minimal permission requests
   - Clear user communication about what access is needed
   - Graceful degradation when permissions are denied

2. **User Experience**:
   - Clear visual separation between favorite and calendar actions
   - Informative error messages for calendar failures
   - Consistent behavior across all event types

## Success Criteria

### Functional Requirements
- ✅ Complete feature parity with existing Objective-C implementation
- ✅ All 15+ cell types render correctly with proper interactions
- ✅ Navigation to related objects works from all contexts
- ✅ Favorite/unfavorite functionality maintains database consistency
- ✅ Calendar integration works with improved user control
- ✅ Audio tour integration maintains existing playback behavior
- ✅ User notes editing preserves all existing functionality
- ✅ Map integration works with existing MapLibre setup
- ✅ Image viewing provides equivalent user experience
- ✅ Theming system works with light/dark mode switching

### Non-Functional Requirements  
- ✅ Performance matches or exceeds current implementation
- ✅ Memory usage remains stable during extended navigation
- ✅ Smooth scrolling maintained with complex cell layouts
- ✅ Loading times for detail view remain under 100ms
- ✅ No crashes or memory leaks during typical usage patterns

### Architecture Goals
- ✅ Protocol-based dependency injection enables easy testing
- ✅ Actions-based navigation decouples view from navigation logic
- ✅ Single ViewModel pattern reduces state management complexity
- ✅ Modern SwiftUI patterns improve maintainability
- ✅ UIKit compatibility maintained for seamless integration

## Context from Current Implementation

### BRCDetailViewController Analysis
The current implementation uses a `UITableViewController` with grouped style that displays detailed information for Art, Camp, and Event objects. Key components include:

- **Data Model**: `BRCDataObject` base class with subclasses for Art, Camp, Event
- **Metadata**: `BRCObjectMetadata` with favorite status, user notes, and timestamps  
- **Cell System**: 15 different cell types via `BRCDetailCellInfo` factory pattern
- **Navigation**: Push-based navigation with support for page view controller
- **Theming**: Dynamic colors via `BRCImageColors` with light/dark mode support

### Current User Interactions
- Favorite/unfavorite with automatic calendar integration for events
- Email contact via mail composer
- Web links opening in embedded web view
- Image viewing with full-screen capability
- Map navigation from addresses and header map
- Related object navigation (camps ↔ art ↔ events)
- GPS coordinate sharing via activity sheet
- Audio tour play/pause controls
- User notes editing with alert dialogs

### Integration Points
- **Factory Method**: `initWithDataObject:` for instantiation
- **Usage Contexts**: Map annotations, table selections, page view swiping
- **Presentation**: Always pushed onto navigation stack
- **Database**: YapDatabase for persistence via `BRCDatabaseManager`
- **Theming**: `ColorTheme` protocol with `BRCImageColors` integration

This SwiftUI migration maintains all existing functionality while modernizing the architecture for better maintainability and future development.