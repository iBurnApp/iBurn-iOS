import SwiftUI
import PlayaDB

/// Filter sheet for the global search screen. Scope lives in the segmented control on
/// the search view itself; this sheet holds the knobs that apply on top of it.
struct GlobalSearchFilterSheet: View {
    @Binding var filter: GlobalSearchFilter

    /// Event-only controls are hidden when the active scope can't return events.
    let scope: GlobalSearchScope

    /// Days offered by the day picker. Injected so the sheet is previewable and testable
    /// without the bundled `YearSettings` plist.
    let festivalDays: [Date]

    @Environment(\.dismiss) private var dismiss

    init(
        filter: Binding<GlobalSearchFilter>,
        scope: GlobalSearchScope,
        festivalDays: [Date] = YearSettings.festivalDays
    ) {
        self._filter = filter
        self.scope = scope
        self.festivalDays = festivalDays
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text("Limits results to things you've favorited. Turns off AI suggestions, which can't see your favorites.")) {
                    Toggle("Only Favorites", isOn: $filter.onlyFavorites)
                }

                if scope.allows(.event) {
                    Section(header: Text("Events"), footer: Text(eventFooter)) {
                        Toggle("Happening Now", isOn: $filter.happeningNow)

                        Group {
                            Picker("Day", selection: $filter.day) {
                                Text("Any day").tag(Date?.none)
                                ForEach(festivalDays, id: \.self) { day in
                                    Text(Self.dayFormatter.string(from: day)).tag(Date?.some(day))
                                }
                            }

                            Picker("Time of Day", selection: $filter.timeOfDay) {
                                ForEach(SearchTimeOfDay.allCases) { time in
                                    Text(time.title).tag(time)
                                }
                            }
                        }
                        // "Happening Now" already pins the window to this moment; leaving
                        // the day/time pickers live would let them silently fight it.
                        .disabled(filter.happeningNow)
                    }
                }
            }
            .navigationTitle("Filter Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !filter.isDefault {
                        Button("Reset") { filter = GlobalSearchFilter() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// "Happening Now" already pins the window to this moment, so the day and time
    /// controls are greyed out rather than silently fighting it.
    private var eventFooter: String {
        if filter.happeningNow {
            return "Only events running right now. Turn this off to pick a day or time of day."
        }
        if let range = filter.timeOfDay.rangeDescription {
            return "Narrows events by when they start. \(filter.timeOfDay.title): \(range)."
        }
        return "Narrows events by when they start."
    }
}

#Preview {
    GlobalSearchFilterSheet(
        filter: .constant(GlobalSearchFilter()),
        scope: .all,
        festivalDays: (0..<8).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: Date())
        }
    )
}
