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

                Section(
                    header: Text("Max Duration"),
                    footer: Text("Hide events longer than this. Filters out all-day amenity listings (open camps, mailboxes). Set to Any to show everything.")
                ) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(durationValueLabel)
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: durationBinding,
                        in: Self.durationSliderRange,
                        step: 1
                    ) {
                        Text("Max Duration")
                    } minimumValueLabel: {
                        Text("1h")
                    } maximumValueLabel: {
                        Text("Any")
                    }
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
                ToolbarItem(placement: .cancellationAction) {
                    if !isDefaultFilter {
                        Button("Reset") { resetToDefaults() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Defaults / Reset

    /// The sheet's controls at their defaults: hide expired, all favorites, all types,
    /// and the Events-tab 6h duration cap. Reset is offered whenever any differ.
    private var isDefaultFilter: Bool {
        !filter.includeExpired
            && !filter.onlyFavorites
            && filter.eventTypeCodes == nil
            && filter.maxDuration == EventListViewModel.defaultMaxDuration
    }

    /// One field at a time (not a wholesale `filter = EventFilter(...)`) so fields the
    /// sheet doesn't expose (searchText, dates, activeWindow) are left untouched.
    private func resetToDefaults() {
        filter.includeExpired = false
        filter.onlyFavorites = false
        filter.eventTypeCodes = nil
        filter.maxDuration = EventListViewModel.defaultMaxDuration
    }

    // MARK: - Max Duration

    /// Slider positions: 1...12 map to whole-hour caps; the rightmost position (13) is
    /// "Any" (no limit, `filter.maxDuration == nil`).
    private static let anyPosition = 13
    private static let durationSliderRange: ClosedRange<Double> = 1...Double(anyPosition)

    /// Current-value readout shown beside the slider ("6h" / "Any").
    private var durationValueLabel: String {
        guard let maxDuration = filter.maxDuration else { return "Any" }
        let hours = Int((maxDuration / 3600).rounded())
        return "\(hours)h"
    }

    /// Maps `filter.maxDuration` (seconds, nil = no limit) to/from the discrete slider index.
    private var durationBinding: Binding<Double> {
        Binding(
            get: {
                guard let maxDuration = filter.maxDuration else {
                    return Double(Self.anyPosition)
                }
                let hours = Int((maxDuration / 3600).rounded())
                return Double(min(max(hours, 1), 12))
            },
            set: { newValue in
                let position = Int(newValue.rounded())
                if position >= Self.anyPosition {
                    filter.maxDuration = nil
                } else {
                    filter.maxDuration = TimeInterval(position) * 3600
                }
            }
        )
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
