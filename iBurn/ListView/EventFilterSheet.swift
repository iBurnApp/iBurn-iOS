import SwiftUI
import PlayaDB

/// Filter sheet for event list options.
///
/// Shared by the Events tab and Nearby. The two differ only in their baseline and in
/// whether the expired toggle makes sense: Nearby's time gate is its own now-window, so
/// "Show Expired Events" would be a control with no visible effect there and is hidden.
struct EventFilterSheet: View {
    @Binding var filter: EventFilter

    /// What Reset restores, and what the sheet compares against to decide whether Reset is
    /// worth offering. Callers pass the same baseline their toolbar badge uses.
    var defaultFilter: EventFilter = .eventListDefaults

    /// Whether to show "Show Expired Events". Off for Nearby — see the type doc.
    var showsExpiredToggle: Bool = true

    var title: String = "Filter Events"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(showsExpiredToggle ? "Time" : "Favorites")) {
                    if showsExpiredToggle {
                        Toggle("Show Expired Events", isOn: $filter.includeExpired)
                    }
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
            .navigationTitle(title)
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

    /// The sheet's controls at `defaultFilter`. Reset is offered whenever any differ.
    private var isDefaultFilter: Bool {
        filter.matchesSheetDefaults(defaultFilter, includingExpired: showsExpiredToggle)
    }

    /// One field at a time (not a wholesale `filter = EventFilter(...)`) so fields the
    /// sheet doesn't expose (searchText, dates, activeWindow, region) are left untouched.
    private func resetToDefaults() {
        if showsExpiredToggle {
            filter.includeExpired = defaultFilter.includeExpired
        }
        filter.onlyFavorites = defaultFilter.onlyFavorites
        filter.eventTypeCodes = defaultFilter.eventTypeCodes
        filter.maxDuration = defaultFilter.maxDuration
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
