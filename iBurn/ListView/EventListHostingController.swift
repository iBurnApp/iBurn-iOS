import SwiftUI
import UIKit
import PlayaDB

/// UIKit hosting controller that wraps the SwiftUI EventListView.
///
/// Bridges UIKit navigation (detail, map) with the new SwiftUI event list.
/// Initialized with dependencies from the DependencyContainer.
@MainActor
class EventListHostingController: UIHostingController<EventListView> {
    private let playaDB: PlayaDB

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        let viewModel = dependencies.makeEventListViewModel()
        super.init(rootView: EventListView(viewModel: viewModel))
        self.rootView = EventListView(
            viewModel: viewModel,
            onSelect: { [weak self] event in
                self?.showDetail(for: event)
            },
            onShowMap: { [weak self] events in
                self?.showMap(for: events)
            }
        )
        self.title = "Events"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    private func showDetail(for event: EventObjectOccurrence) {
        let detailVC = DetailViewControllerFactory.create(with: event.event, playaDB: playaDB)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func showMap(for events: [EventObjectOccurrence]) {
        guard BRCEmbargo.allowEmbargoedData() else {
            showMissingMapAlert()
            return
        }

        let annotations = events.compactMap { PlayaObjectAnnotation(event: $0) }
        guard !annotations.isEmpty else {
            showMissingMapAlert()
            return
        }

        let lookup = Dictionary(uniqueKeysWithValues: events.compactMap { event -> (AnyDataObjectID, EventObjectOccurrence)? in
            guard event.hasLocation else { return nil }
            return (event.event.anyID, event)
        })
        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        mapVC.mapViewAdapter.onPlayaInfoTapped = { [weak self] anyID in
            guard let event = lookup[anyID] else { return }
            self?.showDetail(for: event)
        }
        navigationController?.pushViewController(mapVC, animated: true)
    }

    private func showMissingMapAlert() {
        let alert = UIAlertController(
            title: "No Mappable Events",
            message: BRCEmbargo.allowEmbargoedData()
                ? "None of the selected events have map coordinates."
                : "Location data is currently restricted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
