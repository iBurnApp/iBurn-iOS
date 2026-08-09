import SwiftUI
import PlayaDB

struct NearbyView: View {
    @StateObject private var viewModel: NearbyViewModel

    /// Shared with the map's nearby card, so a change here also re-queries the card.
    @ObservedObject private var filterStore: NearbyEventFilterStore

    @State private var showingFilterSheet = false
    @Environment(\.themeColors) var themeColors

    let onSelectArt: (ArtObject) -> Void
    let onSelectCamp: (CampObject) -> Void
    let onSelectEvent: (EventObjectOccurrence) -> Void
    let onShowMap: ([PlayaObjectAnnotation]) -> Void
    let onShowTimeShift: (NearbyViewModel) -> Void

    init(
        viewModel: NearbyViewModel,
        onSelectArt: @escaping (ArtObject) -> Void = { _ in },
        onSelectCamp: @escaping (CampObject) -> Void = { _ in },
        onSelectEvent: @escaping (EventObjectOccurrence) -> Void = { _ in },
        onShowMap: @escaping ([PlayaObjectAnnotation]) -> Void = { _ in },
        onShowTimeShift: @escaping (NearbyViewModel) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _filterStore = ObservedObject(wrappedValue: viewModel.filterStore)
        self.onSelectArt = onSelectArt
        self.onSelectCamp = onSelectCamp
        self.onSelectEvent = onSelectEvent
        self.onShowMap = onShowMap
        self.onShowTimeShift = onShowTimeShift
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerControls
                Divider()
                contentList
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onShowTimeShift(viewModel) }) {
                        Text("Warp")
                            .foregroundColor(
                                viewModel.timeShiftConfig?.isActive == true
                                    ? themeColors.primaryColor
                                    : nil
                            )
                            .fontWeight(
                                viewModel.timeShiftConfig?.isActive == true
                                    ? .medium
                                    : .regular
                            )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: filterIconName)
                            .foregroundColor(themeColors.primaryColor)
                    }
                    .accessibilityLabel("Filter Nearby Events")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { onShowMap(viewModel.allAnnotations) }) {
                        Image(systemName: "map")
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                EventFilterSheet(
                    filter: $filterStore.filter,
                    defaultFilter: .nearbyDefaults,
                    // Nearby's time gate is its own now-window (evaluated at the warped
                    // date when the user is time-shifted), so an expired-events toggle
                    // would be a control with no visible effect.
                    showsExpiredToggle: false,
                    title: "Filter Nearby Events"
                )
            }

            // Loading overlay
            if viewModel.isLoading && viewModel.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading nearby...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            // Empty state
            if !viewModel.isLoading && viewModel.sections.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    if viewModel.currentLocation == nil {
                        Text("Location unavailable")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)
                        Text("Enable Location Services or use Warp")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Nothing Here")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)
                        Text("Try a bigger search area")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    /// Filled icon = at least one control differs from Nearby's defaults, matching the
    /// sheet's Reset-button visibility. Same rule the Events tab uses.
    private var filterIconName: String {
        filterStore.hasNonDefaultFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }

    // MARK: - Header Controls

    private var headerControls: some View {
        VStack(spacing: 12) {
            // Distance stepper row
            HStack {
                distanceLabel
                Spacer()
                Stepper("", value: $viewModel.searchDistance, in: 50...3200, step: 150)
                    .labelsHidden()
            }

            // Type filter
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(NearbyFilter.allValues, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            // Time shift info
            if let config = viewModel.timeShiftConfig, config.isActive {
                timeShiftInfoView(config)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var distanceLabel: some View {
        let distance = viewModel.searchDistance
        if let nsAttr = TTTLocationFormatter.brc_humanizedString(forDistance: distance) {
            let attributed = AttributedString(nsAttr)
            return Text("Within ") + Text(attributed)
        } else {
            return Text("Within \(Int(distance))m") + Text("")
        }
    }

    private func timeShiftInfoView(_ config: TimeShiftConfiguration) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d, h:mm a"
        var text = "Warped: \(formatter.string(from: config.date))"
        if let location = config.location {
            text += String(format: " (%.4f, %.4f)", location.coordinate.latitude, location.coordinate.longitude)
        }
        return Text(text)
            .font(.caption)
            .foregroundColor(themeColors.primaryColor)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    // MARK: - Content List

    private var contentList: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.items) { item in
                        nearbyRow(for: item)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func nearbyRow(for item: NearbyItem) -> some View {
        switch item {
        case .art(let art):
            ObjectRowView(
                object: art.object,
                subtitle: viewModel.distanceString(for: item),
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
                subtitle: viewModel.distanceString(for: item),
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
                subtitle: viewModel.distanceString(for: .event(event)),
                rightSubtitle: event.object.timeDescription(now: viewModel.now),
                hostName: event.object.hostName,
                hostAddress: BRCEmbargo.canShowLocation(for: event.object) ? event.object.hostAddress : nil,
                isFavorite: event.isFavorite,
                thumbnailColors: item.thumbnailColors,
                onFavoriteTap: { Task { await viewModel.toggleFavorite(.event(event)) } }
            ) { _ in
                Text(EventTypeInfo.emoji(for: event.object.eventTypeCode))
                    .font(.subheadline)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectEvent(event.object) }
        }
    }
}
