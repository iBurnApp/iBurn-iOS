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
                    HStack(spacing: 12) {
                        Text("1h")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        GeometryReader { geo in
                            Slider(
                                value: durationBinding,
                                in: Self.durationSliderRange,
                                step: 1
                            ) {
                                Text("Max Duration")
                            }
                            // Tap-to-set: the built-in Slider only responds to thumb
                            // drags. A zero-distance drag fires on any touch-up over the
                            // track, mapping tap x -> nearest step. Simultaneous so real
                            // thumb drags still work (their onEnded lands on the same
                            // stepped value the Slider itself chose).
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { gesture in
                                        durationBinding.wrappedValue = Self.sliderValue(
                                            forTapX: gesture.location.x,
                                            trackWidth: geo.size.width
                                        )
                                    }
                            )
                        }
                        .frame(height: 32)
                        Text("Any")
                            .font(.footnote)
                            .foregroundColor(.secondary)
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

    /// Horizontal inset from the slider view's edge to the track's usable span — half the
    /// standard 27pt thumb. Tap x is mapped linearly across the remaining width and
    /// snapped to the nearest step; endpoint taps clamp, so precision only matters to
    /// within half a step. Internal (not private) for unit testing.
    static let sliderThumbInset: CGFloat = 13.5

    /// Maps a tap location on the slider to the nearest discrete position.
    /// Internal (not private) for unit testing.
    static func sliderValue(forTapX x: CGFloat, trackWidth: CGFloat) -> Double {
        let usable = trackWidth - 2 * sliderThumbInset
        guard usable > 0 else { return durationSliderRange.lowerBound }
        let fraction = min(max((x - sliderThumbInset) / usable, 0), 1)
        let span = durationSliderRange.upperBound - durationSliderRange.lowerBound
        return (durationSliderRange.lowerBound + Double(fraction) * span).rounded()
    }

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
