import CoreLocation
import SwiftUI
import UIKit
import PlayaDB
import PlayaGeocoder

@MainActor
class NearbyListHostingController: UIHostingController<NearbyView> {
    private let playaDB: PlayaDB
    private let viewModel: NearbyViewModel
    private var pagingDataSource: DetailPagingDataSource?
    private var geocoderTimer: Timer?

    /// - Parameter locationOverride: transient "look from here" spot handed over by the
    ///   map card's "See all" when the user has the person marker dropped. Nil for every
    ///   other entry point. Nothing about it is persisted.
    init(dependencies: DependencyContainer, locationOverride: CLLocation? = nil) {
        self.playaDB = dependencies.playaDB
        let vm = dependencies.makeNearbyViewModel(locationOverride: locationOverride)
        self.viewModel = vm
        super.init(rootView: NearbyView(viewModel: vm))
        self.rootView = makeRootView()
        self.title = "Nearby"
        observeEmbargoDidClear()
        geocodeSourceLocation(locationOverride)
    }

    /// Labels the dropped-pin banner with the offline reverse geocoder's playa address.
    ///
    /// The result is applied through the view model's coordinate-checked setter, so a lookup
    /// still in flight when the user clears the override can't relabel the screen.
    private func geocodeSourceLocation(_ location: CLLocation?) {
        guard let location else { return }
        let coordinate = location.coordinate
        PlayaGeocoder.shared.asyncReverseLookup(coordinate) { [weak self] address in
            Task { @MainActor in
                self?.viewModel.setSourceLocationAddress(address, for: coordinate)
            }
        }
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRootView() -> NearbyView {
        NearbyView(
            viewModel: viewModel,
            onSelectArt: { [weak self] art in
                self?.showDetail(.art(art))
            },
            onSelectCamp: { [weak self] camp in
                self?.showDetail(.camp(camp))
            },
            onSelectEvent: { [weak self] event in
                self?.showDetail(.eventOccurrence(event))
            },
            onShowMap: { [weak self] annotations in
                self?.showMap(annotations: annotations)
            },
            onShowTimeShift: { [weak self] vm in
                self?.showTimeShift(vm)
            }
        )
    }

    // MARK: - Embargo

    /// Rows read `BRCEmbargo.allowEmbargoedData()` while building their body, so an unlock
    /// while this screen is alive needs an explicit re-render to reveal host addresses.
    private func observeEmbargoDidClear() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(embargoDidClear),
            name: .BRCEmbargoDidClear,
            object: nil
        )
    }

    @objc private func embargoDidClear() {
        rootView = makeRootView()
    }

    // MARK: - View Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        geocodeNavigationBar()
        geocoderTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(geocoderTimerDidFire), userInfo: nil, repeats: true)
        geocoderTimer?.tolerance = 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        geocoderTimer?.invalidate()
        geocoderTimer = nil
    }

    @objc private func geocoderTimerDidFire() {
        geocodeNavigationBar()
    }

    // MARK: - Navigation

    private func showDetail(_ subject: DetailSubject) {
        let allItems = viewModel.sections.flatMap(\.items)
        let pageItems = allItems.map(\.detailPageItem)
        let uid = subject.uid
        if let index = allItems.firstIndex(where: { $0.detailSubject.uid == uid }) {
            let dataSource = DetailPagingDataSource(items: pageItems, playaDB: playaDB)
            self.pagingDataSource = dataSource
            let pageVC = dataSource.makePageViewController(initialIndex: index)
            navigationController?.pushViewController(pageVC, animated: true)
        } else {
            let detailVC = DetailViewControllerFactory.create(with: subject, playaDB: playaDB)
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    private func showMap(annotations: [PlayaObjectAnnotation]) {
        guard BRCEmbargo.allowEmbargoedData() else {
            showAlert(title: "Location Restricted", message: "Location data is currently restricted.")
            return
        }
        guard !annotations.isEmpty else {
            showAlert(title: "Nothing Nearby", message: "No nearby objects have map coordinates.")
            return
        }

        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        mapVC.mapViewAdapter.onPlayaInfoTapped = { [weak self] anyID in
            self?.handleMapAnnotationTap(anyID)
        }
        navigationController?.pushViewController(mapVC, animated: true)
    }

    private func handleMapAnnotationTap(_ anyID: AnyDataObjectID) {
        Task {
            let uid = anyID.uid
            switch anyID.objectType {
            case .art:
                if let art = try? await playaDB.fetchArt(uid: uid) {
                    showDetail(.art(art))
                }
            case .camp:
                if let camp = try? await playaDB.fetchCamp(uid: uid) {
                    showDetail(.camp(camp))
                }
            case .event:
                if let event = try? await playaDB.fetchEvent(uid: uid) {
                    showDetail(.event(event))
                }
            case .mutantVehicle:
                if let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
                    showDetail(.mutantVehicle(mv))
                }
            }
        }
    }

    private func showTimeShift(_ vm: NearbyViewModel) {
        let timeShiftVM = TimeShiftViewModel(
            currentConfiguration: vm.timeShiftConfig,
            currentLocation: vm.currentLocation
        )
        timeShiftVM.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }
        timeShiftVM.onApply = { [weak self] config in
            if config.isActive {
                vm.timeShiftConfig = config
            } else {
                vm.timeShiftConfig = nil
            }
            self?.dismiss(animated: true)
        }

        let timeShiftVC = TimeShiftViewController(viewModel: timeShiftVM)
        present(timeShiftVC, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
