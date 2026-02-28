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

    var body: some View {
        List(events, id: \.uid) { event in
            Button {
                pushDetail(for: event)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundColor(themeColors.primaryColor)

                    Text(DetailViewModel.formatEventTimeAndDuration(
                        startDate: event.startDate,
                        endDate: event.endDate
                    ))
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryColor)

                    if let desc = event.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(themeColors.detailColor)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowBackground(themeColors.backgroundColor)
        }
        .listStyle(.plain)
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

private extension UIViewController {
    func findNavigationController() -> UINavigationController? {
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.findNavigationController() ?? nav
        }
        if let tab = self as? UITabBarController,
           let selected = tab.selectedViewController {
            return selected.findNavigationController()
        }
        if let nav = navigationController {
            return nav
        }
        for child in children {
            if let nav = child.findNavigationController() {
                return nav
            }
        }
        return nil
    }
}
