import SwiftUI
import PlayaDB

/// Drops `List`'s own opaque scroll background so an overlay's material shows through.
/// `scrollContentBackground` is iOS 16+; below that the list keeps its default fill.
private struct TransparentListBackground: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled, #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

/// Reusable SwiftUI view for displaying global FTS5 search results grouped by type.
struct GlobalSearchView: View {
    @ObservedObject var viewModel: GlobalSearchViewModel
    @Environment(\.themeColors) var themeColors

    let onSelectArt: (ArtObject) -> Void
    let onSelectCamp: (CampObject) -> Void
    let onSelectEvent: (EventObjectOccurrence) -> Void
    let onSelectMV: (MutantVehicleObject) -> Void

    /// Renders search as a layer over whatever it was opened from rather than as an opaque
    /// screen: the prompt, loading, and no-results states stay fully transparent, and only
    /// an actual list of results paints a backdrop behind itself.
    let isOverlay: Bool

    init(
        viewModel: GlobalSearchViewModel,
        isOverlay: Bool = false,
        onSelectArt: @escaping (ArtObject) -> Void = { _ in },
        onSelectCamp: @escaping (CampObject) -> Void = { _ in },
        onSelectEvent: @escaping (EventObjectOccurrence) -> Void = { _ in },
        onSelectMV: @escaping (MutantVehicleObject) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.isOverlay = isOverlay
        self.onSelectArt = onSelectArt
        self.onSelectCamp = onSelectCamp
        self.onSelectEvent = onSelectEvent
        self.onSelectMV = onSelectMV
    }

    /// True only when there is a list on screen. The empty and prompt states are just a
    /// glyph and a line of text, which read fine directly over the map.
    private var showsResultList: Bool {
        !viewModel.sections.isEmpty
    }

    var body: some View {
        ZStack {
            if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                // Prompt state
                legible {
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
                }
            } else if viewModel.isSearching && viewModel.sections.isEmpty {
                // Loading state
                legible {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching...")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                    }
                    .padding()
                }
            } else if !viewModel.isSearching && viewModel.sections.isEmpty {
                // No results
                legible {
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
                }
            } else {
                // Results list
                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.items) { item in
                                overlayRowBackground(resultRow(for: item))
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
                .modifier(TransparentListBackground(isEnabled: isOverlay))
            }
        }
        .background(overlayBackground)
    }

    /// Nothing at all in the non-overlay case, so the hosting controller's own background
    /// still shows through exactly as before.
    @ViewBuilder
    private var overlayBackground: some View {
        if isOverlay && showsResultList {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func resultRow(for item: SearchResultItem) -> some View {
        let isAISuggested = viewModel.aiSuggestedUIDs.contains(item.uid)
        switch item {
        case .art(let art):
            ObjectRowView(
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
            ObjectRowView(
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
            ObjectRowView(
                object: event,
                rightSubtitle: event.timeDescription(now: Date()),
                hostName: event.hostName,
                hostAddress: BRCEmbargo.canShowLocation(for: event) ? event.hostAddress : nil,
                isFavorite: false,
                onFavoriteTap: { }
            ) { _ in
                Text(EventTypeInfo.emoji(for: event.eventTypeCode))
                    .font(.subheadline)
            }
            .overlay(alignment: .topTrailing) { aiBadge(visible: isAISuggested) }
            .contentShape(Rectangle())
            .onTapGesture { onSelectEvent(event) }

        case .mutantVehicle(let mv):
            ObjectRowView(
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

    /// In overlay mode the placeholder states sit directly on the map, where plain text
    /// competes with streets and pins. A small glass panel keeps them readable without
    /// covering the map the way a full-screen background would. Outside overlay mode this
    /// is a no-op, so the existing search screen is untouched.
    @ViewBuilder
    private func legible<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if isOverlay {
            content()
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                )
                .padding(.horizontal, 32)
        } else {
            content()
        }
    }

    /// Clears a row's own fill in overlay mode so the shared material behind the list is
    /// what you see, instead of a second opaque layer per row.
    @ViewBuilder
    private func overlayRowBackground<Content: View>(_ content: Content) -> some View {
        if isOverlay {
            content.listRowBackground(Color.clear)
        } else {
            content
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

}
