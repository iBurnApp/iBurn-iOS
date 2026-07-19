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

    private static let rowVerticalInset: CGFloat = 11
    private static let rowLeadingInset: CGFloat = 20
    private static let rowDefaultTrailingInset: CGFloat = 20
    /// Fixed trailing inset for browse rows. Sized for the strip's *active* visual
    /// footprint (digit 18 + 8 leading + 8 trailing pad + 2 gap = 36) so the table
    /// doesn't reflow when the strip expands on scrub-active.
    private static let browseRowTrailingInset: CGFloat = 36

    private static let browseRowInsets = EdgeInsets(
        top: rowVerticalInset,
        leading: rowLeadingInset,
        bottom: rowVerticalInset,
        trailing: browseRowTrailingInset
    )

    private static let searchRowInsets = EdgeInsets(
        top: rowVerticalInset,
        leading: rowLeadingInset,
        bottom: rowVerticalInset,
        trailing: rowDefaultTrailingInset
    )

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
                    // ScrollView+LazyVStack instead of List: SwiftUI's List eagerly processes
                    // all row identities on diff/recreate, which costs 400-600ms for ~1500
                    // event rows per day. LazyVStack only materializes visible rows, so day
                    // swaps are bounded by visible row count, not total row count.
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            switch viewModel.mode {
                            case .browse:
                                ForEach(viewModel.browseSections, id: \.hour) { section in
                                    ForEach(section.rows, id: \.object.uid) { row in
                                        rowButton(for: row)
                                            .padding(Self.browseRowInsets)
                                        Divider()
                                    }
                                }
                            case .search:
                                ForEach(viewModel.searchResults, id: \.object.uid) { row in
                                    Button {
                                        onSelect(row.object)
                                    } label: {
                                        eventRow(for: row)
                                            .contentShape(Rectangle())
                                            .padding(Self.searchRowInsets)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                        }
                    }
                    .searchable(
                        text: $viewModel.searchText,
                        prompt: "Search events"
                    )
                    .overlay(alignment: .trailing) {
                        if case .browse = viewModel.mode, !viewModel.browseSections.isEmpty {
                            EventHourIndexView(sections: viewModel.browseSections) { hour in
                                guard let anchorUID = viewModel.browseSections
                                    .first(where: { $0.hour == hour })?
                                    .rows.first?.object.uid else { return }
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo(anchorUID, anchor: .top)
                                }
                            }
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

    /// The tappable row. Deliberately NO explicit `.id()` modifier: rows are
    /// identified solely by their ForEach identity (`\.object.uid`), which
    /// `ScrollViewReader.scrollTo` can target directly for the hour scrub strip
    /// (hour → first-row uid resolved from `browseSections` at scroll time).
    ///
    /// History: the strip's anchor was previously a synthesized explicit id on
    /// first-in-section rows — first `.id(hour)`, then `.id(day+hour)`, then
    /// `.id(uid)`. The LazyVStack persists across day switches AND filter
    /// changes, and any identity layered on top of the row's own let a data
    /// change resurrect or orphan a cached row view (stale occurrence label +
    /// stale tap closure that fails showDetail's visibleRows guard = dead tap).
    /// Content identity only, applied exactly once, leaves nothing to collide.
    private func rowButton(for row: ListRow<EventObjectOccurrence>) -> some View {
        Button {
            onSelect(row.object)
        } label: {
            eventRow(for: row)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        // Filled icon = any control differs from its default, matching the filter
        // sheet's Reset-button visibility. Defaults: hide expired (includeExpired
        // false), all favorites, all types, 6h duration cap — so a nil-vs-non-nil
        // duration check (or the old `!includeExpired`) would always read active.
        let hasActiveFilters = viewModel.filter.onlyFavorites
            || viewModel.filter.includeExpired
            || viewModel.filter.eventTypeCodes != nil
            || viewModel.filter.maxDuration != EventListViewModel.defaultMaxDuration
        return hasActiveFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }

    private func showMap() {
        onShowMap(viewModel.visibleObjects)
    }
}
