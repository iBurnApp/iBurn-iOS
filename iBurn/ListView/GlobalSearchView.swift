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

/// Backing for the scope bar.
///
/// On iOS 26 the bar is its own Liquid Glass element — the same treatment as the app's
/// other floating map chrome — rather than a strip painted across the top of the results.
/// Glass adapts its own contrast to whatever scrolls under it, which a flat `.bar` fill
/// cannot: the plain fill read as a dirty band over the list, and dropping it altogether
/// left the segmented control unreadable over passing rows.
///
/// Earlier releases have no glass, so they keep the arrangement that was already legible:
/// a material capsule where the bar floats over the map, the opaque strip where the list
/// scrolls under it.
///
/// Both branches stay behind `canImport` as well as the availability check — the fallback
/// is what compiles against pre-26 SDKs.
private struct ScopeBarChrome: ViewModifier {
    let isOverlay: Bool
    let showsResultList: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            fallback(content, shape: shape)
        }
        #else
        fallback(content, shape: shape)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content, shape: Capsule) -> some View {
        if isOverlay {
            // The results list already paints a full-screen material behind everything in
            // overlay mode, so the bar only needs its own backing while that is absent.
            if showsResultList {
                content
            } else {
                content.background(.regularMaterial, in: shape)
            }
        } else {
            content.background(Rectangle().fill(.bar))
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

    /// Whether the scope bar carries its own filter button. Off when the host has a
    /// navigation bar to put one on, so there is exactly one filter affordance per layout.
    let showsInlineFilterButton: Bool

    init(
        viewModel: GlobalSearchViewModel,
        isOverlay: Bool = false,
        showsInlineFilterButton: Bool = true,
        onSelectArt: @escaping (ArtObject) -> Void = { _ in },
        onSelectCamp: @escaping (CampObject) -> Void = { _ in },
        onSelectEvent: @escaping (EventObjectOccurrence) -> Void = { _ in },
        onSelectMV: @escaping (MutantVehicleObject) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.isOverlay = isOverlay
        self.showsInlineFilterButton = showsInlineFilterButton
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
        Group {
            // Overlay mode docks the text field to the keyboard at the bottom of the
            // screen, so the scope controls belong down there with it; hosted normally,
            // the field is at the top and so is the bar.
            if isOverlay {
                VStack(spacing: 0) {
                    results
                    scopeBar
                }
            } else if #available(iOS 26.0, *) {
                // `safeAreaBar` rather than `safeAreaInset`: it treats the scope control
                // as chrome, which is what earns it the scroll edge effect — the system
                // softens the results passing underneath so the Liquid Glass segmented
                // control stays legible without a background strip of its own.
                results
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaBar(edge: .top, spacing: 0) { scopeBar }
            } else {
                // A safe-area inset rather than the top half of a `VStack`: the bar stays
                // pinned to the top of the screen in every state — prompt, loading,
                // no-results and results alike — and the result list scrolls underneath
                // it instead of starting below a bar that moved with the content.
                //
                // The explicit greedy frame is what makes "the top of the screen" mean
                // that: the empty states are a fixed-size glyph and label, so without it
                // `results` sizes to them and the hosting controller centers the whole
                // view — which is how the bar ended up floating in the middle of an
                // otherwise blank screen.
                results
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .top, spacing: 0) { scopeBar }
            }
        }
        .background(overlayBackground)
        .sheet(isPresented: $viewModel.isShowingFilters) {
            GlobalSearchFilterSheet(filter: $viewModel.filter, scope: viewModel.scope)
        }
    }

    // MARK: - Scope + Filter

    /// The scope control lives inside the SwiftUI view rather than on the search bar's
    /// scope buttons: this view is hosted three different ways (search-results controller,
    /// map overlay, search tab) and the bar has to look the same in all of them.
    ///
    /// The deeper filter knobs are different — they only ride along here when the host has
    /// no navigation bar to put them on. See `showsInlineFilterButton`.
    private var scopeBar: some View {
        HStack(spacing: 12) {
            Picker("Scope", selection: $viewModel.scope) {
                ForEach(GlobalSearchScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if showsInlineFilterButton {
                Button {
                    viewModel.isShowingFilters = true
                } label: {
                    Image(systemName: filterIconName)
                        .font(.title3)
                }
                .accessibilityLabel(Text("Search Filters"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .modifier(ScopeBarChrome(isOverlay: isOverlay, showsResultList: showsResultList))
        .padding(.horizontal, scopeBarOuterPadding)
        .padding(.vertical, isOverlay ? 6 : 0)
    }

    /// A floating capsule needs room to read as one; a full-width strip does not.
    private var scopeBarOuterPadding: CGFloat {
        if isOverlay { return showsResultList ? 0 : 12 }
        if #available(iOS 26.0, *) { return 12 }
        return 0
    }

    /// Room the rows give up to the index rail, so their trailing text doesn't run
    /// underneath it. Zero when the results are too short for a rail.
    private var indexRailInset: CGFloat {
        SearchResultIndex.isEnabled(for: viewModel.sections) ? SearchResultIndex.railRowInset : 0
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
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.sections) { section in
                            Section(header: Text(section.title).padding(.trailing, indexRailInset)) {
                                ForEach(section.items) { item in
                                    overlayRowBackground(
                                        resultRow(for: item).padding(.trailing, indexRailInset)
                                    )
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
                    // The rail is sized to the list, not to the screen: how many index
                    // stops it can show depends on how tall it is allowed to be.
                    .overlay(alignment: .trailing) {
                        GeometryReader { geo in
                            let entries = SearchResultIndex.entries(
                                for: viewModel.sections,
                                maxCount: SearchResultIndex.maxEntries(forHeight: geo.size.height - 24)
                            )
                            if !entries.isEmpty {
                                SearchResultIndexView(entries: entries) { anchorID in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        proxy.scrollTo(anchorID, anchor: .top)
                                    }
                                }
                                .padding(.trailing, 2)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .trailing
                                )
                            }
                        }
                    }
                }
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
        let isFavorite = viewModel.isFavorite(item)
        switch item {
        case .art(let art):
            ObjectRowView(
                object: art,
                subtitle: nil,
                rightSubtitle: art.artist,
                isFavorite: isFavorite,
                onFavoriteTap: { viewModel.toggleFavorite(item) }
            ) { _ in EmptyView() }
            .overlay(alignment: .topTrailing) { aiBadge(visible: isAISuggested) }
            .contentShape(Rectangle())
            .onTapGesture { onSelectArt(art) }

        case .camp(let camp):
            ObjectRowView(
                object: camp,
                subtitle: nil,
                rightSubtitle: camp.hometown,
                isFavorite: isFavorite,
                onFavoriteTap: { viewModel.toggleFavorite(item) }
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
                isFavorite: isFavorite,
                onFavoriteTap: { viewModel.toggleFavorite(item) }
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
                isFavorite: isFavorite,
                onFavoriteTap: { viewModel.toggleFavorite(item) }
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
