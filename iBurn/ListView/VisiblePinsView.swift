//
//  VisiblePinsView.swift
//  iBurn
//
//  PlayaDB-native replacement for the (Yap-only, always-empty) MapPinListViewController
//  on maps that draw PlayaObjectAnnotations and user map pins.
//

import PlayaDB
import SwiftUI

struct VisiblePinsView: View {
    @StateObject private var viewModel: VisiblePinsViewModel
    @Environment(\.themeColors) var themeColors

    private let onSelect: (DetailSubject) -> Void
    private let onSelectUserPin: (BRCUserMapPoint) -> Void

    init(
        viewModel: VisiblePinsViewModel,
        onSelect: @escaping (DetailSubject) -> Void = { _ in },
        onSelectUserPin: @escaping (BRCUserMapPoint) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelect = onSelect
        self.onSelectUserPin = onSelectUserPin
    }

    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.sections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.items) { item in
                            row(for: item)
                        }
                    }
                }
            }
            .listStyle(.plain)

            if viewModel.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    Text("No pins visible")
                        .font(.headline)
                        .foregroundColor(themeColors.primaryColor)

                    Text("Pan or zoom the map to bring pins into view.")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for item: VisiblePinItem) -> some View {
        let subtitle = viewModel.distanceString(for: item)
        let isFavorite = viewModel.isFavorite(item)
        let favoriteAction: () -> Void = { Task { await viewModel.toggleFavorite(item) } }

        switch item {
        case .art(let art):
            ObjectRowView(
                object: art,
                subtitle: subtitle,
                rightSubtitle: art.artist,
                isFavorite: isFavorite,
                onFavoriteTap: favoriteAction
            ) { _ in EmptyView() }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(.art(art)) }

        case .camp(let camp):
            ObjectRowView(
                object: camp,
                subtitle: subtitle,
                rightSubtitle: camp.hometown,
                isFavorite: isFavorite,
                onFavoriteTap: favoriteAction
            ) { _ in EmptyView() }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(.camp(camp)) }

        case .eventOccurrence(let occurrence):
            ObjectRowView(
                object: occurrence,
                subtitle: subtitle,
                rightSubtitle: occurrence.timeDescription(now: Date()),
                hostName: occurrence.hostName,
                hostAddress: BRCEmbargo.allowEmbargoedData() ? occurrence.hostAddress : nil,
                isFavorite: isFavorite,
                onFavoriteTap: favoriteAction
            ) { _ in
                Text(EventTypeInfo.emoji(for: occurrence.eventTypeCode))
                    .font(.subheadline)
            }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(.eventOccurrence(occurrence)) }

        case .event(let event):
            ObjectRowView(
                object: event,
                subtitle: subtitle,
                rightSubtitle: nil,
                isFavorite: isFavorite,
                onFavoriteTap: favoriteAction
            ) { _ in EmptyView() }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(.event(event)) }

        case .userPin(let pin):
            userPinRow(pin: pin, subtitle: subtitle)
                .contentShape(Rectangle())
                .onTapGesture { onSelectUserPin(pin) }
        }
    }

    /// Compact row for user-dropped map pins: the same marker art shown on the map,
    /// the pin's title, and the distance from the user.
    private func userPinRow(pin: BRCUserMapPoint, subtitle: AttributedString?) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: pin.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(pin.displayTitle)
                    .font(.headline)
                    .foregroundColor(themeColors.primaryColor)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    Text(pin.type.pinDisplayName)
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "scope")
                .foregroundColor(themeColors.detailColor)
        }
        .padding(.vertical, 4)
        .listRowBackground(themeColors.backgroundColor)
    }
}

private extension BRCUserMapPoint {
    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { return trimmed }
        return type.pinDisplayName
    }
}
