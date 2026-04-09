import SwiftUI
import PlayaDB

/// Reusable SwiftUI view for displaying global FTS5 search results grouped by type.
struct GlobalSearchView: View {
    @ObservedObject var viewModel: GlobalSearchViewModel
    @Environment(\.themeColors) var themeColors

    let onSelectArt: (ArtObject) -> Void
    let onSelectCamp: (CampObject) -> Void
    let onSelectEvent: (EventObjectOccurrence) -> Void
    let onSelectMV: (MutantVehicleObject) -> Void

    init(
        viewModel: GlobalSearchViewModel,
        onSelectArt: @escaping (ArtObject) -> Void = { _ in },
        onSelectCamp: @escaping (CampObject) -> Void = { _ in },
        onSelectEvent: @escaping (EventObjectOccurrence) -> Void = { _ in },
        onSelectMV: @escaping (MutantVehicleObject) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSelectArt = onSelectArt
        self.onSelectCamp = onSelectCamp
        self.onSelectEvent = onSelectEvent
        self.onSelectMV = onSelectMV
    }

    var body: some View {
        ZStack {
            if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                // Prompt state
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(themeColors.detailColor)
                    Text("Search art, camps, events, and vehicles")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if viewModel.isSearching && viewModel.sections.isEmpty {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            } else if !viewModel.isSearching && viewModel.sections.isEmpty {
                // No results
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(themeColors.detailColor)
                    Text("No results for \"\(viewModel.searchText)\"")
                        .font(.headline)
                        .foregroundColor(themeColors.primaryColor)
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
                .padding()
            } else {
                // Results list
                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.items) { item in
                                resultRow(for: item)
                            }
                        }
                    }
                    if viewModel.isAISearching {
                        Section {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Finding more with AI...")
                                    .font(.caption)
                                    .foregroundColor(themeColors.secondaryColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func resultRow(for item: SearchResultItem) -> some View {
        let isAISuggested = viewModel.aiSuggestedUIDs.contains(item.uid)
        switch item {
        case .art(let art):
            MediaObjectRowView(
                object: art,
                subtitle: nil,
                rightSubtitle: art.artist,
                isFavorite: false,
                onFavoriteTap: { }
            ) { _ in EmptyView() }
            .overlay(alignment: .topTrailing) { aiBadge(visible: isAISuggested) }
            .contentShape(Rectangle())
            .onTapGesture { onSelectArt(art) }

        case .camp(let camp):
            MediaObjectRowView(
                object: camp,
                subtitle: nil,
                rightSubtitle: camp.hometown,
                isFavorite: false,
                onFavoriteTap: { }
            ) { _ in EmptyView() }
            .overlay(alignment: .topTrailing) { aiBadge(visible: isAISuggested) }
            .contentShape(Rectangle())
            .onTapGesture { onSelectCamp(camp) }

        case .event(let event):
            eventRow(for: event)
                .overlay(alignment: .topTrailing) { aiBadge(visible: isAISuggested) }
                .onAppear { viewModel.resolveHosts(for: [event]) }

        case .mutantVehicle(let mv):
            MediaObjectRowView(
                object: mv,
                subtitle: nil,
                rightSubtitle: mv.artist,
                isFavorite: false,
                onFavoriteTap: { }
            ) { _ in EmptyView() }
            .overlay(alignment: .topTrailing) { aiBadge(visible: isAISuggested) }
            .contentShape(Rectangle())
            .onTapGesture { onSelectMV(mv) }
        }
    }

    @ViewBuilder
    private func aiBadge(visible: Bool) -> some View {
        if visible {
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundStyle(.purple)
                .padding(2)
        }
    }

    private func eventRow(for event: EventObjectOccurrence) -> some View {
        let host = viewModel.resolvedHost(for: event)
        return Button {
            onSelectEvent(event)
        } label: {
            EventRowView(
                event: event,
                hostName: host?.name ?? (event.event.hasOtherLocation ? event.event.otherLocation : nil),
                hostAddress: host?.address,
                hostDescription: host?.description,
                campUID: host?.thumbnailObjectID,
                isArtHosted: host?.isArt ?? false,
                distanceString: nil,
                isFavorite: false,
                now: .present,
                onFavoriteTap: { }
            )
        }
        .buttonStyle(.plain)
    }
}
