import SwiftUI
import PlayaDB

/// SwiftUI view for displaying a list of events grouped by hour within a selected day.
struct EventListView: View {
    @StateObject private var viewModel: EventListViewModel
    @State private var showingFilterSheet = false
    @Environment(\.themeColors) var themeColors
    private let onSelect: (EventObjectOccurrence) -> Void
    private let onShowMap: ([EventObjectOccurrence]) -> Void

    init(
        viewModel: EventListViewModel,
        onSelect: @escaping (EventObjectOccurrence) -> Void = { _ in },
        onShowMap: @escaping ([EventObjectOccurrence]) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelect = onSelect
        self.onShowMap = onShowMap
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Day picker at top
                EventDayPickerView(
                    days: viewModel.festivalDays,
                    selectedDay: $viewModel.selectedDay
                )

                Divider()

                // Event list grouped by hour
                List {
                    ForEach(viewModel.groupedItems, id: \.header) { group in
                        Section(header: Text(group.header)) {
                            ForEach(group.items, id: \.uid) { event in
                                Button {
                                    onSelect(event)
                                } label: {
                                    eventRow(for: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(
                    text: $viewModel.searchText,
                    prompt: "Search events"
                )
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: filterIconName)
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: showMap) {
                        Image(systemName: "map")
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                EventFilterSheet(filter: $viewModel.filter)
            }

            // Loading overlay
            if viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading events...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            // Empty state
            if !viewModel.isLoading && viewModel.filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    if viewModel.searchText.isEmpty {
                        Text("No events found")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Try adjusting your filters or selecting a different day")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No results for \"\(viewModel.searchText)\"")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Row Builder

    private func eventRow(for event: EventObjectOccurrence) -> some View {
        let host = viewModel.resolvedHost(for: event)
        return EventRowView(
            event: event,
            hostName: host?.name ?? (event.event.hasOtherLocation ? event.event.otherLocation : nil),
            hostAddress: host?.address,
            hostDescription: host?.description,
            campUID: host?.thumbnailObjectID,
            isArtHosted: host?.isArt ?? false,
            distanceString: viewModel.distanceAttributedString(for: event),
            isFavorite: viewModel.isFavorite(event),
            now: viewModel.now,
            onFavoriteTap: {
                Task { await viewModel.toggleFavorite(event) }
            }
        )
    }

    // MARK: - Helpers

    private var filterIconName: String {
        let hasActiveFilters = viewModel.filter.onlyFavorites
            || !viewModel.filter.includeExpired
            || viewModel.filter.eventTypeCodes != nil
        return hasActiveFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }

    private func showMap() {
        onShowMap(viewModel.filteredItems)
    }
}
