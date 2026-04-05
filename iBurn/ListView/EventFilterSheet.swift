import SwiftUI
import PlayaDB

/// Filter sheet for event list options.
struct EventFilterSheet: View {
    @Binding var filter: EventFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Time")) {
                    Toggle("Show Expired Events", isOn: $filter.includeExpired)
                    Toggle("Only Favorites", isOn: $filter.onlyFavorites)
                }

                Section(header: Text("Event Types")) {
                    ForEach(EventTypeInfo.visibleTypes) { typeInfo in
                        Toggle(
                            "\(typeInfo.emoji) \(typeInfo.displayName)",
                            isOn: eventTypeBinding(for: typeInfo.code)
                        )
                    }
                }
            }
            .navigationTitle("Filter Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Creates a binding for whether a specific event type code is enabled.
    ///
    /// When `filter.eventTypeCodes` is nil, all types are enabled.
    /// When a type is toggled off, we initialize the set with all visible types minus the toggled one.
    /// When all types are re-enabled, we set the set back to nil.
    private func eventTypeBinding(for code: String) -> Binding<Bool> {
        Binding(
            get: {
                guard let codes = filter.eventTypeCodes else { return true }
                return codes.contains(code)
            },
            set: { isEnabled in
                let allCodes = Set(EventTypeInfo.visibleTypes.map(\.code))
                var currentCodes = filter.eventTypeCodes ?? allCodes

                if isEnabled {
                    currentCodes.insert(code)
                } else {
                    currentCodes.remove(code)
                }

                // If all types selected, set to nil (no filtering)
                filter.eventTypeCodes = currentCodes == allCodes ? nil : currentCodes
            }
        )
    }
}
