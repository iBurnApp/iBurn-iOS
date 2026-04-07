import SwiftUI
import PlayaDB

struct RecentlyViewedView: View {
    @StateObject private var viewModel: RecentlyViewedViewModel
    @State private var showingClearConfirmation = false
    @Environment(\.themeColors) var themeColors

    let onSelectArt: (ArtObject) -> Void
    let onSelectCamp: (CampObject) -> Void
    let onSelectEvent: (EventObject) -> Void
    let onSelectMV: (MutantVehicleObject) -> Void
    let onShowMap: ([PlayaObjectAnnotation]) -> Void

    init(
        viewModel: RecentlyViewedViewModel,
        onSelectArt: @escaping (ArtObject) -> Void = { _ in },
        onSelectCamp: @escaping (CampObject) -> Void = { _ in },
        onSelectEvent: @escaping (EventObject) -> Void = { _ in },
        onSelectMV: @escaping (MutantVehicleObject) -> Void = { _ in },
        onShowMap: @escaping ([PlayaObjectAnnotation]) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectArt = onSelectArt
        self.onSelectCamp = onSelectCamp
        self.onSelectEvent = onSelectEvent
        self.onSelectMV = onSelectMV
        self.onShowMap = onShowMap
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Type filter + sort controls
                HStack(spacing: 8) {
                    Picker("Type", selection: $viewModel.selectedTypeFilter) {
                        ForEach(RecentlyViewedTypeFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Sort", selection: $viewModel.sortOrder) {
                        ForEach(RecentlyViewedSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.items) { item in
                                recentRow(for: item)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await viewModel.removeItem(item) }
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(
                    text: $viewModel.searchText,
                    prompt: "Search history"
                )
            }
            .navigationTitle("Recently Viewed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { onShowMap(viewModel.allAnnotations) }) {
                        Image(systemName: "map")
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
            }
            .alert("Clear All History?", isPresented: $showingClearConfirmation) {
                Button("Clear All", role: .destructive) {
                    Task { await viewModel.clearAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all recently viewed items. This cannot be undone.")
            }

            // Loading
            if viewModel.isLoading && viewModel.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading history...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            // Empty state
            if !viewModel.isLoading && viewModel.sections.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    if viewModel.searchText.isEmpty {
                        Text("No history yet")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Items you view will appear here")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No results for \"\(viewModel.searchText)\"")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func recentRow(for item: RecentlyViewedItem) -> some View {
        let isFav = viewModel.isFavorite(item.uid)
        let favAction: () -> Void = { Task { await viewModel.toggleFavorite(item) } }
        let subtitle = subtitleString(for: item)

        switch item {
        case .art(let art, _):
            MediaObjectRowView(
                object: art,
                subtitle: subtitle,
                rightSubtitle: art.artist,
                isFavorite: isFav,
                onFavoriteTap: favAction
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectArt(art) }

        case .camp(let camp, _):
            MediaObjectRowView(
                object: camp,
                subtitle: subtitle,
                rightSubtitle: camp.hometown,
                isFavorite: isFav,
                onFavoriteTap: favAction
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectCamp(camp) }

        case .event(let event, _):
            EventRecentRow(
                event: event,
                subtitle: subtitle,
                isFavorite: isFav,
                onFavoriteTap: favAction
            )
            .contentShape(Rectangle())
            .onTapGesture { onSelectEvent(event) }

        case .mutantVehicle(let mv, _):
            MediaObjectRowView(
                object: mv,
                subtitle: subtitle,
                rightSubtitle: mv.artist,
                isFavorite: isFav,
                onFavoriteTap: favAction
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectMV(mv) }
        }
    }

    // MARK: - Subtitle

    private func subtitleString(for item: RecentlyViewedItem) -> AttributedString? {
        guard let dist = viewModel.distanceString(for: item) else { return nil }
        return AttributedString(dist)
    }
}

/// Event row that loads the host camp/art thumbnail instead of the event's own (nonexistent) image.
private struct EventRecentRow: View {
    let event: EventObject
    let subtitle: AttributedString?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    @StateObject private var assets: RowAssetsLoader

    init(event: EventObject, subtitle: AttributedString?, isFavorite: Bool, onFavoriteTap: @escaping () -> Void) {
        self.event = event
        self.subtitle = subtitle
        self.isFavorite = isFavorite
        self.onFavoriteTap = onFavoriteTap
        // Load thumbnail from the hosting camp or art, not the event itself
        let hostUID = event.hostedByCamp ?? event.locatedAtArt ?? event.uid
        _assets = StateObject(wrappedValue: RowAssetsLoader(objectID: hostUID))
    }

    var body: some View {
        ObjectRowView(
            object: event,
            thumbnail: assets.thumbnail,
            colorsOverride: assets.colors,
            subtitle: subtitle,
            rightSubtitle: event.eventTypeLabel,
            isFavorite: isFavorite,
            onFavoriteTap: onFavoriteTap,
            actions: { EmptyView() }
        )
        .onAppear { assets.startIfNeeded() }
    }
}
