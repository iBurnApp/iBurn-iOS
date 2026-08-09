import SwiftUI
import PlayaDB

/// Filter sheet for the global search screen. Scope lives in the segmented control on
/// the search view itself; this sheet holds the knobs that apply on top of it.
struct GlobalSearchFilterSheet: View {
    @Binding var filter: GlobalSearchFilter

    /// Event-only controls are hidden when the active scope can't return events.
    let scope: GlobalSearchScope

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text("Limits results to things you've favorited. Turns off AI suggestions, which can't see your favorites.")) {
                    Toggle("Only Favorites", isOn: $filter.onlyFavorites)
                }

                if scope.allows(.event) {
                    Section(header: Text("Events"), footer: Text("Only events running right now.")) {
                        Toggle("Happening Now", isOn: $filter.happeningNow)
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
}

#Preview {
    GlobalSearchFilterSheet(filter: .constant(GlobalSearchFilter()), scope: .all)
}
