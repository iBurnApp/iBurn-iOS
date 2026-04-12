import SwiftUI
import PlayaDB

struct MutantVehicleListView: View {
    @StateObject private var viewModel: MutantVehicleListViewModel
    @State private var showingFilterSheet = false
    @Environment(\.themeColors) var themeColors
    private let onSelect: (MutantVehicleObject) -> Void

    init(
        viewModel: MutantVehicleListViewModel,
        onSelect: @escaping (MutantVehicleObject) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelect = onSelect
    }

    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.filteredItems, id: \.uid) { mv in
                    ObjectRowView(
                        object: mv,
                        subtitle: nil,
                        rightSubtitle: mv.artist,
                        isFavorite: viewModel.isFavorite(mv),
                        onFavoriteTap: {
                            Task { await viewModel.toggleFavorite(mv) }
                        }
                    ) { _ in
                        EmptyView()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(mv)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search vehicles, artists, descriptions"
            )
            .navigationTitle("Mutant Vehicles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: filterIconName)
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                MutantVehicleFilterSheet(filter: $viewModel.filter)
            }

            if viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading mutant vehicles...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            if !viewModel.isLoading && viewModel.filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    if viewModel.searchText.isEmpty {
                        Text("No mutant vehicles found")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                    } else {
                        Text("No results for \"\(viewModel.searchText)\"")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                    }
                }
            }
        }
    }

    private var filterIconName: String {
        if viewModel.filter.onlyFavorites || viewModel.filter.tag != nil {
            return "line.3.horizontal.decrease.circle.fill"
        } else {
            return "line.3.horizontal.decrease.circle"
        }
    }
}

// MARK: - Filter Sheet

struct MutantVehicleFilterSheet: View {
    @Binding var filter: MutantVehicleFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Favorites Only", isOn: $filter.onlyFavorites)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
