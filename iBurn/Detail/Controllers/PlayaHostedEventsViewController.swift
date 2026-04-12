import SwiftUI
import UIKit
import PlayaDB

/// Lightweight view controller that shows all events hosted by a camp/art.
/// Used for the "See all N events" tap from the PlayaDB event detail screen.
@MainActor
class PlayaHostedEventsViewController: UIHostingController<PlayaHostedEventsView> {
    init(events: [EventObjectOccurrence], hostName: String, playaDB: PlayaDB) {
        let view = PlayaHostedEventsView(
            events: events,
            hostName: hostName,
            playaDB: playaDB
        )
        super.init(rootView: view)
        self.title = "Events - \(hostName)"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PlayaHostedEventsView: View {
    let events: [EventObjectOccurrence]
    let hostName: String
    let playaDB: PlayaDB
    @Environment(\.themeColors) var themeColors
    @State private var favoriteIDs: Set<String> = []
    @State private var now = Date()

    var body: some View {
        List(events, id: \.uid) { event in
            ObjectRowView(
                object: event,
                rightSubtitle: event.timeDescription(now: now),
                isFavorite: favoriteIDs.contains(event.uid),
                onFavoriteTap: {
                    Task { await toggleFavorite(event) }
                }
            ) { _ in
                Text(EventTypeInfo.emoji(for: event.eventTypeCode))
                    .font(.subheadline)
            }
            .contentShape(Rectangle())
            .onTapGesture { pushDetail(for: event) }
            .listRowBackground(themeColors.backgroundColor)
        }
        .listStyle(.plain)
        .task { await loadFavorites() }
    }

    private func loadFavorites() async {
        for event in events {
            if let isFav = try? await playaDB.isFavorite(event), isFav {
                favoriteIDs.insert(event.uid)
            }
        }
    }

    private func toggleFavorite(_ event: EventObjectOccurrence) async {
        do {
            try await playaDB.toggleFavorite(event)
            let isFav = try await playaDB.isFavorite(event)
            if isFav {
                favoriteIDs.insert(event.uid)
            } else {
                favoriteIDs.remove(event.uid)
            }
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }

    private func pushDetail(for event: EventObjectOccurrence) {
        let detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
        // Walk the responder chain to find a navigation controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let navController = window.rootViewController?.findNavigationController() else {
            return
        }
        navController.pushViewController(detailVC, animated: true)
    }
}

