import SwiftUI

// MARK: - Models

// MARK: - Models

struct EventTypeContainer: Identifiable {
    let id = UUID()
    let type: BRCEventType
    let title: String
    var isSelected: Bool
}

// MARK: - View Model

class EventsFilterViewModel: ObservableObject {
    @Published var showExpiredEvents: Bool
    @Published var searchSelectedDayOnly: Bool
    @Published var showAllDayEvents: Bool
    @Published var eventTypes: [EventTypeContainer]
    
    private let onFilterChanged: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    init(onFilterChanged: (() -> Void)? = nil) {
        self.onFilterChanged = onFilterChanged
        // Initialize from UserSettings
        self.showExpiredEvents = UserSettings.showExpiredEvents
        self.searchSelectedDayOnly = UserSettings.searchSelectedDayOnly
        self.showAllDayEvents = UserSettings.showAllDayEvents
        
        // Initialize event types
        let storedTypes = UserSettings.selectedEventTypes
        self.eventTypes = BRCEventObject.allVisibleEventTypes.compactMap { number -> EventTypeContainer? in
            guard let type = BRCEventType(rawValue: number.uintValue) else { return nil }
            return EventTypeContainer(
                type: type,
                title: BRCEventObject.stringForEventType(type),
                isSelected: storedTypes.contains(type)
            )
        }
    }
    
    func selectAll() {
        eventTypes.indices.forEach { eventTypes[$0].isSelected = true }
    }
    
    func selectNone() {
        eventTypes.indices.forEach { eventTypes[$0].isSelected = false }
    }
    
    func saveSettings() {
        // Save to UserSettings
        UserSettings.showExpiredEvents = showExpiredEvents
        UserSettings.searchSelectedDayOnly = searchSelectedDayOnly
        UserSettings.showAllDayEvents = showAllDayEvents
        
        // Save selected event types
        let selectedTypes = eventTypes
            .filter { $0.isSelected }
            .map { $0.type }
        UserSettings.selectedEventTypes = selectedTypes
        
        // Notify of changes
        onFilterChanged?()
    }
    
    func dismiss() {
        onDismiss?()
    }
}

// MARK: - SwiftUI View

struct EventsFilterView: View {
    @ObservedObject var viewModel: EventsFilterViewModel
    
    var body: some View {
        Form {
            // Time Section
            Section(header: Text("Time")) {
                Toggle("Show Expired Events", isOn: $viewModel.showExpiredEvents)
                Toggle("Search Selected Day Only", isOn: $viewModel.searchSelectedDayOnly)
                Toggle("Show All Day Events", isOn: $viewModel.showAllDayEvents)
            }
            
            // Actions Section
            Section {
                Button("Select All") {
                    viewModel.selectAll()
                }
                Button("Select None") {
                    viewModel.selectNone()
                }
            }
            
            // Type Section
            Section(header: Text("Type")) {
                ForEach($viewModel.eventTypes) { $type in
                    Toggle(type.title, isOn: $type.isSelected)
                        .foregroundColor(Color(BRCImageColors.colors(for: type.type).secondaryColor))
                }
            }
        }
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    viewModel.saveSettings()
                    viewModel.dismiss()
                }
            }
        }
    }
}

// MARK: - UIKit Wrapper

class EventsFilterViewController: UIHostingController<EventsFilterView> {
    private let viewModel: EventsFilterViewModel
    private let onFilterChanged: (() -> Void)?
    
    init(onFilterChanged: (() -> Void)? = nil) {
        self.onFilterChanged = onFilterChanged
        self.viewModel = EventsFilterViewModel(
            onFilterChanged: onFilterChanged
        )
        super.init(rootView: EventsFilterView(viewModel: viewModel))
        viewModel.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
} 
