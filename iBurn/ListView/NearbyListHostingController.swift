import SwiftUI
import UIKit
import PlayaDB
import PlayaGeocoder

@MainActor
class NearbyListHostingController: UIHostingController<NearbyView> {
    private let playaDB: PlayaDB
    private let viewModel: NearbyViewModel
    private var geocoderTimer: Timer?

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        let vm = dependencies.makeNearbyViewModel()
        self.viewModel = vm
        super.init(rootView: NearbyView(viewModel: vm))
        self.rootView = NearbyView(
            viewModel: vm,
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
        self.title = "Nearby"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        geocodeNavigationBar()
        geocoderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.geocodeNavigationBar()
        }
        geocoderTimer?.tolerance = 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        geocoderTimer?.invalidate()
        geocoderTimer = nil
    }

    // MARK: - Navigation

    private func showDetail(_ subject: DetailSubject) {
        let detailVC = DetailViewControllerFactory.create(with: subject, playaDB: playaDB)
        navigationController?.pushViewController(detailVC, animated: true)
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
