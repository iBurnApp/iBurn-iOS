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
    @State private var isShowingFilters = false

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
        VStack(spacing: 0) {
            // Overlay mode docks the text field to the keyboard at the bottom of the
            // screen, so the scope controls belong down there with it; hosted normally,
            // the field is at the top and so is the bar.
            if isOverlay {
                results
                scopeBar
            } else {
                scopeBar
                results
            }
        }
        .background(overlayBackground)
        .sheet(isPresented: $isShowingFilters) {
            GlobalSearchFilterSheet(filter: $viewModel.filter, scope: viewModel.scope)
        }
    }

    // MARK: - Scope + Filter

    /// Lives inside the SwiftUI view rather than on a navigation item or the search bar's
    /// scope buttons: this view is hosted three different ways (search-results controller,
    /// map overlay, inline search tab) and only one of those has a navigation item of its own.
    private var scopeBar: some View {
        HStack(spacing: 12) {
            Picker("Scope", selection: $viewModel.scope) {
                ForEach(GlobalSearchScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button {
                isShowingFilters = true
            } label: {
                Image(systemName: filterIconName)
                    .font(.title3)
            }
            .accessibilityLabel(Text("Search Filters"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(scopeBarBackground)
        .padding(.horizontal, isOverlay && !showsResultList ? 12 : 0)
        .padding(.vertical, isOverlay ? 6 : 0)
    }

    /// The results list paints a full-screen material behind everything in overlay mode, so
    /// the bar only needs its own backing while that material is absent.
    @ViewBuilder
    private var scopeBarBackground: some View {
        if isOverlay && !showsResultList {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var filterIconName: String {
        viewModel.filter.isDefault
            ? "line.3.horizontal.decrease.circle"
            : "line.3.horizontal.decrease.circle.fill"
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        ZStack {
            if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                legible {
                    placeholder(
                        symbol: "magnifyingglass",
                        title: "Search Black Rock City",
                        message: "Art, camps, events, and mutant vehicles — by name, by camp, or by what's happening.",
                        hint: "Try \u{201C}temple\u{201D}, \u{201C}pancakes\u{201D}, or \u{201C}yoga\u{201D}"
                    )
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
                legible {
                    placeholder(
                        // `questionmark.magnifyingglass` is not a real SF Symbol — it drew
                        // an empty circle. This one exists.
                        symbol: "exclamationmark.magnifyingglass",
                        title: "No \(viewModel.scope.resultNoun) for \u{201C}\(viewModel.searchText)\u{201D}",
                        message: noResultsMessage,
                        hint: noResultsHint
                    )
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
    }

    private var noResultsMessage: String {
        if !viewModel.filter.isDefault {
            return "Nothing matches that with these filters on."
        }
        return viewModel.scope == .all
            ? "Nothing in this year's data matches that."
            : "Nothing under \(viewModel.scope.title) matches that."
    }

    private var noResultsHint: String {
        if !viewModel.filter.isDefault {
            return "Try clearing the filters"
        }
        return viewModel.scope == .all
            ? "Try a shorter word, or check the spelling"
            : "Try All, a shorter word, or check the spelling"
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
        let isAISuggested = viewModel.isAISuggested(item)
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

    /// The prompt and no-results states are the whole screen when there's nothing to list,
    /// so they get a proper illustration-weight treatment rather than a lone glyph and a
    /// line of grey text.
    private func placeholder(symbol: String, title: String, message: String, hint: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(themeColors.detailColor)
                .frame(width: 84, height: 84)
                .background(Circle().fill(themeColors.detailColor.opacity(0.12)))

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(themeColors.primaryColor)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(themeColors.secondaryColor)
                    .multilineTextAlignment(.center)
            }

            Text(hint)
                .font(.footnote)
                .foregroundColor(themeColors.detailColor)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
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
