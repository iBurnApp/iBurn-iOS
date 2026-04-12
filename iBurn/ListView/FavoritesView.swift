import SwiftUI
import PlayaDB

/// SwiftUI view for displaying favorited objects across all types.
struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @State private var showingFilterSheet = false
    @Environment(\.themeColors) var themeColors

    let onSelectArt: (ArtObject) -> Void
    let onSelectCamp: (CampObject) -> Void
    let onSelectEvent: (EventObjectOccurrence) -> Void
    let onSelectMV: (MutantVehicleObject) -> Void
    let onShowMap: ([PlayaObjectAnnotation]) -> Void

    init(
        viewModel: FavoritesViewModel,
        onSelectArt: @escaping (ArtObject) -> Void = { _ in },
        onSelectCamp: @escaping (CampObject) -> Void = { _ in },
        onSelectEvent: @escaping (EventObjectOccurrence) -> Void = { _ in },
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
                // Type filter segmented control
                Picker("Type", selection: $viewModel.selectedTypeFilter) {
                    ForEach(FavoritesTypeFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Sectioned list
                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.items) { item in
                                favoriteRow(for: item)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(
                    text: $viewModel.searchText,
                    prompt: "Search favorites"
                )
            }
            .navigationTitle("Favorites")
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
                NavigationView {
                    FavoritesFilterView(viewModel: FavoritesFilterViewModel(
                        onFilterChanged: { [weak viewModel] in
                            viewModel?.reloadEventFilter()
                        }
                    ))
                }
            }

            // Loading overlay
            if viewModel.isLoading && viewModel.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading favorites...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            // Empty state
            if !viewModel.isLoading && viewModel.sections.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    if viewModel.searchText.isEmpty {
                        Text("No favorites yet")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Tap the heart icon on any item to add it to your favorites")
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

    @ViewBuilder
    private func favoriteRow(for item: FavoriteItem) -> some View {
        switch item {
        case .art(let art):
            ObjectRowView(
                object: art.object,
                subtitle: viewModel.distanceAttributedString(for: item),
                rightSubtitle: art.object.artist,
                isFavorite: art.isFavorite,
                thumbnailColors: item.thumbnailColors,
                onFavoriteTap: { Task { await viewModel.toggleFavorite(item) } }
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectArt(art.object) }

        case .camp(let camp):
            ObjectRowView(
                object: camp.object,
                subtitle: viewModel.distanceAttributedString(for: item),
                rightSubtitle: camp.object.hometown,
                isFavorite: camp.isFavorite,
                thumbnailColors: item.thumbnailColors,
                onFavoriteTap: { Task { await viewModel.toggleFavorite(item) } }
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectCamp(camp.object) }

        case .event(let event):
            ObjectRowView(
                object: event.object,
                subtitle: viewModel.distanceAttributedString(for: .event(event)),
                rightSubtitle: event.object.timeDescription(now: viewModel.now),
                isFavorite: event.isFavorite,
                thumbnailColors: item.thumbnailColors,
                onFavoriteTap: { Task { await viewModel.toggleFavorite(.event(event)) } }
            ) { _ in
                Text(EventTypeInfo.emoji(for: event.object.eventTypeCode))
                    .font(.subheadline)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectEvent(event.object) }

        case .mutantVehicle(let mv):
            ObjectRowView(
                object: mv.object,
                subtitle: nil,
                rightSubtitle: mv.object.artist,
                isFavorite: mv.isFavorite,
                thumbnailColors: item.thumbnailColors,
                onFavoriteTap: { Task { await viewModel.toggleFavorite(item) } }
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectMV(mv.object) }
        }
    }

    // MARK: - Helpers

    private var filterIconName: String {
        let hasActiveFilters = !UserSettings.showExpiredEventsInFavorites
            || UserSettings.showTodayOnlyInFavorites
        return hasActiveFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }

    private func showMap() {
        onShowMap(viewModel.allAnnotations)
    }
}
