import SwiftUI
import PlayaDB

/// SwiftUI view for displaying a list of events.
/// - Browse mode (search empty): day picker + sectioned list grouped by hour-of-day
///   with a tappable + drag-scrubbable hour quick-scroll strip on the trailing edge.
/// - Search mode (search non-empty): flat FTS-backed results, no day picker, no strip.
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
                if case .browse = viewModel.mode {
                    EventDayPickerView(
                        days: viewModel.festivalDays,
                        selectedDay: $viewModel.selectedDay
                    )
                    Divider()
                }

                ScrollViewReader { proxy in
                    List {
                        switch viewModel.mode {
                        case .browse:
                            ForEach(viewModel.browseSections, id: \.hour) { section in
                                ForEach(Array(section.rows.enumerated()), id: \.element.object.uid) { idx, row in
                                    rowButton(for: row, scrollAnchorHour: idx == 0 ? section.hour : nil)
                                }
                            }
                        case .search:
                            ForEach(viewModel.searchResults, id: \.object.uid) { row in
                                Button {
                                    onSelect(row.object)
                                } label: {
                                    eventRow(for: row)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(
                        text: $viewModel.searchText,
                        prompt: "Search events"
                    )
                    .overlay(alignment: .trailing) {
                        if case .browse = viewModel.mode, !viewModel.browseSections.isEmpty {
                            EventHourIndexView(sections: viewModel.browseSections) { hour in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo(hour, anchor: .top)
                                }
                            }
                            .padding(.trailing, 4)
                        }
                    }
                }
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
            if viewModel.isLoading && viewModel.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading events...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            // Empty state
            if !viewModel.isLoading && viewModel.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.searchText.isEmpty ? "calendar" : "magnifyingglass")
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

    // MARK: - Row Builder

    /// Wraps the tappable row with a conditional `.id(hour)` anchor so
    /// `ScrollViewReader` can target the first row of each section.
    @ViewBuilder
    private func rowButton(
        for row: ListRow<EventObjectOccurrence>,
        scrollAnchorHour: Int?
    ) -> some View {
        let button = Button {
            onSelect(row.object)
        } label: {
            eventRow(for: row)
        }
        .buttonStyle(.plain)

        if let hour = scrollAnchorHour {
            button.id(hour)
        } else {
            button
        }
    }

    private func eventRow(for row: ListRow<EventObjectOccurrence>) -> some View {
        return ObjectRowView(
            object: row.object,
            subtitle: viewModel.distanceAttributedString(for: row.object),
            rightSubtitle: row.object.timeDescription(now: viewModel.now),
            hostName: row.object.hostName,
            hostAddress: BRCEmbargo.allowEmbargoedData() ? row.object.hostAddress : nil,
            isFavorite: row.isFavorite,
            thumbnailColors: row.thumbnailColors,
            onFavoriteTap: {
                Task { await viewModel.toggleFavorite(row) }
            }
        ) { _ in
            Text(EventTypeInfo.emoji(for: row.object.eventTypeCode))
                .font(.subheadline)
        }
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
        onShowMap(viewModel.visibleObjects)
    }
}
