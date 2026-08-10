//
//  MainMapViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import CoreLocation
import BButton
import CocoaLumberjack
import PlayaGeocoder
import SafariServices
import EventKitUI
import SwiftUI
import PlayaDB

public class MainMapViewController: BaseMapViewController, ListButtonHelper {
    /// This contains the buttons for finding the nearest POIs e.g. bathrooms
    let sidebarButtons: SidebarButtonsView
    let geocoder = PlayaGeocoder.shared
    private let globalSearchController: UISearchController
    private let globalSearchHostingController: GlobalSearchHostingController
    private let filteredDataSource: FilteredMapDataSource
    private let dependencies: DependencyContainer
    /// Compact on-map card showing art/camps/events within ~100m of the user.
    private lazy var nearbyCardController = NearbyCardHostingController(dependencies: dependencies)
    /// Live only while the "card hidden" hint is on screen.
    private weak var nearbyCardTooltip: UIVisualEffectView?
    /// Prototype: drives the tab-accessory search when the bottom layout is selected.
    private lazy var bottomSearchController = MapBottomSearchController(
        host: self,
        resultsController: globalSearchHostingController
    )
    private var searchLayout: MapSearchLayout = .current
    var userMapViewAdapter: UserMapViewAdapter? {
        return mapViewAdapter as? UserMapViewAdapter
    }
    private var geocoderTimer: Timer? {
        didSet {
            oldValue?.invalidate()
            geocoderTimer?.tolerance = 1
        }
    }

    deinit {
        geocoderTimer?.invalidate()
    }

    public init() {
        let dependencies = BRCAppDelegate.shared.dependencies
        self.dependencies = dependencies
        sidebarButtons = SidebarButtonsView()

        // Set up PlayaDB-backed global search
        let searchHosting = dependencies.makeGlobalSearchHostingController()
        globalSearchHostingController = searchHosting
        globalSearchController = UISearchController(searchResultsController: searchHosting)
        globalSearchController.searchBar.barStyle = Appearance.currentBarStyle
        globalSearchController.obscuresBackgroundDuringPresentation = true
        globalSearchController.hidesNavigationBarDuringPresentation = false

        // PlayaDB-backed map annotations (replaces YapDB data sources)
        let dataSource = FilteredMapDataSource(playaDB: dependencies.playaDB)
        filteredDataSource = dataSource

        let mapView = MLNMapView.brcMapView()
        let mapViewAdapter = UserMapViewAdapter(mapView: mapView, dataSource: dataSource)
        super.init(mapViewAdapter: mapViewAdapter)

        // Reactive annotation updates from PlayaDB observations
        dataSource.onAnnotationsChanged = { [weak self] in
            self?.mapViewAdapter.reloadAnnotations()
        }

        // Route PlayaDB annotation info-button taps to detail views
        mapViewAdapter.onPlayaInfoTapped = { [weak self] anyID in
            guard let self else { return }
            let playaDB = dependencies.playaDB
            Task { @MainActor in
                let uid = anyID.uid
                var detailVC: UIViewController?
                switch anyID.objectType {
                case .art:
                    if let art = try? await playaDB.fetchArt(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
                    }
                case .camp:
                    if let camp = try? await playaDB.fetchCamp(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
                    }
                case .event:
                    if let event = try? await playaDB.fetchEvent(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
                    }
                case .mutantVehicle:
                    if let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
                    }
                }
                if let detailVC {
                    self.navigationController?.pushViewController(detailVC, animated: true)
                }
            }
        }

        globalSearchController.searchResultsUpdater = self
        title = NSLocalizedString("Map", comment: "title for map view")
        setupUserGuide()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        // TODO: make sidebar buttons work
        setupSidebarButtons()
        setupListButton()
        setupFilterButton()
        setupNearbyCard()
        installDropPersonRecognizer()
        applySearchLayout()
        definesPresentationContext = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(searchLayoutDidChange),
            name: .mapSearchLayoutDidChange,
            object: nil
        )
    }

    // MARK: - Prototype search layout

    @objc private func searchLayoutDidChange() {
        guard isViewLoaded else { return }
        bottomSearchController.deactivate()
        bottomSearchController.removeAccessory(animated: false)
        applySearchLayout()
        if isVisible {
            installBottomAccessoryIfNeeded()
        }
    }

    /// Attaches the search affordance for the active layout.
    private func applySearchLayout() {
        searchLayout = .current

        // Only the classic layout hangs search off the navigation item; the bottom
        // layouts own their own field and would otherwise show two search bars.
        navigationItem.searchController = searchLayout == .navigationBar ? globalSearchController : nil
    }

    private func installBottomAccessoryIfNeeded() {
        guard searchLayout == .bottomAccessory else { return }
        bottomSearchController.installAccessory()
    }

    /// Embeds the nearby card as a proper child view controller, top-centered. The
    /// hosting controller uses intrinsic content sizing, so the card defines its own
    /// frame and the rest of the map stays interactive around it.
    ///
    /// The card lives at the top now that search owns the bottom of the screen — the two
    /// were fighting for the same corner, and the card is the thing you read rather than
    /// reach for.
    private func setupNearbyCard() {
        addChild(nearbyCardController)
        nearbyCardController.onCardHidden = { [weak self] action in
            // Hiding the card is also how you put the person away: with the card possibly
            // gone there'd be nothing left on screen tied to the dropped spot.
            self?.clearDroppedPerson()
            // Only a real "the card is switched off now" needs the hint about where it went.
            // Retiring a dropped pin leaves the card's own setting exactly as it was.
            if action.disablesCard {
                self?.showNearbyCardHiddenTooltip()
            }
        }
        userMapViewAdapter?.onDroppedPersonRemoved = { [weak self] in
            self?.nearbyCardController.viewModel.clearSourceLocationOverride()
        }

        // The hosting view goes inside a container that hands touches outside the card
        // back to the map. See `NearbyCardTouchContainer`.
        let container = NearbyCardTouchContainer()
        container.backgroundColor = .clear
        container.interactiveRect = { [weak self] in
            guard let self else { return .zero }
            return self.nearbyCardController.interactiveRect(in: container.bounds)
        }

        let card = nearbyCardController.view!
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        card.autoPinEdgesToSuperviewEdges()

        view.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.autoAlignAxis(toSuperviewAxis: .vertical)
        container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12).isActive = true

        nearbyCardController.didMove(toParent: self)
    }

    // MARK: - Dropped person marker

    /// Identifies our recognizer on the map view, the same way the style-label tap does, so
    /// a second `viewDidLoad` (or a rebuilt adapter) can't stack recognizers up.
    private static let dropPersonRecognizerName = "iBurn.dropPersonLongPress"

    /// Long-press anywhere on the main map to stand the person there.
    ///
    /// `MLNMapView` has no long-press of its own — the only long press in the app is the
    /// per-annotation-view one that starts a user pin drag — so this is added directly to the
    /// map view, following `MapViewAdapter.installStyleLabelTapRecognizer()`.
    ///
    /// Scoped to this screen alone rather than to `MapViewAdapter`: the nearby card is the
    /// thing the drop re-sources, and it only exists here. Detail maps and the "show on map"
    /// list maps keep their plain behaviour.
    private func installDropPersonRecognizer() {
        let existing = mapView.gestureRecognizers ?? []
        guard !existing.contains(where: { $0.name == Self.dropPersonRecognizerName }) else { return }
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleMapLongPress(_:)))
        longPress.name = Self.dropPersonRecognizerName
        // Long enough not to fire during the pause at the start of a slow pan, short enough
        // to feel like a deliberate press rather than a wait.
        longPress.minimumPressDuration = 0.45
        mapView.addGestureRecognizer(longPress)
    }

    @objc private func handleMapLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began, let adapter = userMapViewAdapter else { return }
        let coordinate = mapView.convert(sender.location(in: mapView), toCoordinateFrom: mapView)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        dropPerson(at: coordinate, adapter: adapter)
    }

    private func dropPerson(at coordinate: CLLocationCoordinate2D, adapter: UserMapViewAdapter) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        adapter.dropPerson(at: coordinate)

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        nearbyCardController.viewModel.setSourceLocationOverride(location)

        // The address arrives asynchronously; both sinks re-check the coordinate, so a
        // second drop while this one is in flight can't relabel the new spot.
        geocoder.asyncReverseLookup(coordinate) { [weak self] address in
            DispatchQueue.main.async {
                guard let self else { return }
                self.nearbyCardController.viewModel.setSourceLocationAddress(address, for: coordinate)
                self.userMapViewAdapter?.updateDroppedPersonTitle(address, for: coordinate)
            }
        }
    }

    /// Takes the person off the map and puts the card back on the device's own location.
    private func clearDroppedPerson() {
        // `notifyHost: false` — we're already the host, and are about to clear the override
        // ourselves; letting the callback fire too would just do it twice.
        userMapViewAdapter?.removeDroppedPerson(notifyHost: false)
        nearbyCardController.viewModel.clearSourceLocationOverride()
    }

    // MARK: - Nearby card tooltip

    /// Transient hint shown after the nearby card's close button hides it. The card is the
    /// only entry point to its own setting, so dismissing it without saying where it went
    /// leaves no way back.
    ///
    /// Added straight to `view` rather than inside a full-screen container so it can only
    /// take touches within its own bounds; the map stays live around it.
    private func showNearbyCardHiddenTooltip() {
        dismissNearbyCardTooltip(animated: false)

        let tooltip = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        tooltip.layer.cornerRadius = 18
        tooltip.layer.cornerCurve = .continuous
        tooltip.clipsToBounds = true
        tooltip.alpha = 0

        let label = UILabel()
        label.text = NSLocalizedString("Nearby card hidden — turn it back on in Map Filter.",
                                       comment: "shown after the user closes the on-map nearby card")
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = Appearance.currentColors.primaryColor
        label.numberOfLines = 0
        label.textAlignment = .center
        tooltip.contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tooltip)
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        tooltip.autoAlignAxis(toSuperviewAxis: .vertical)
        // The label is constrained to the effect view itself, not to `contentView`:
        // `contentView` is laid out by `UIVisualEffectView` rather than by Auto Layout, so
        // pinning to it leaves the effect view with no intrinsic size and the tooltip
        // renders as an invisible zero-height box.
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -14),
            tooltip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            tooltip.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
        ])
        // The map's own chrome (Liquid Glass buttons, the playa-address bar) sits at the
        // same place; keep the hint above it for the few seconds it is on screen.
        view.bringSubviewToFront(tooltip)
        tooltip.layer.zPosition = 100

        tooltip.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(nearbyCardTooltipTapped))
        )
        nearbyCardTooltip = tooltip

        UIView.animate(withDuration: 0.2) { tooltip.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self, weak tooltip] in
            guard let self, let tooltip, self.nearbyCardTooltip === tooltip else { return }
            self.dismissNearbyCardTooltip(animated: true)
        }
    }

    @objc private func nearbyCardTooltipTapped() {
        dismissNearbyCardTooltip(animated: true)
    }

    private func dismissNearbyCardTooltip(animated: Bool) {
        guard let tooltip = nearbyCardTooltip else { return }
        nearbyCardTooltip = nil
        guard animated else {
            tooltip.removeFromSuperview()
            return
        }
        UIView.animate(withDuration: 0.2, animations: { tooltip.alpha = 0 }) { _ in
            tooltip.removeFromSuperview()
        }
    }

    private func setupSidebarButtons() {
        view.addSubview(sidebarButtons)
        sidebarButtons.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sidebarButtons.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            // Pinned to the safe area rather than layout margins so the tab accessory,
            // which grows the safe area when installed, lifts the column automatically.
            // The nearby card has vacated the bottom, but MapLibre's attribution still
            // sits down there and has to stay legible.
            sidebarButtons.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            sidebarButtons.widthAnchor.constraint(equalToConstant: SidebarButtonsView.buttonDiameter),
            sidebarButtons.heightAnchor.constraint(equalToConstant: SidebarButtonsView.columnHeight),
        ])
    }
    
    func setupListButton() {
        let listImage = UIImage(systemName: "list.bullet")
        let listButton = UIBarButtonItem(image: listImage, style: .plain) { [weak self] button in
            self?.listButtonPressed(button)
        }
        navigationItem.leftBarButtonItem = listButton
    }
    
    func setupFilterButton() {
        let filterImage = UIImage(systemName: "line.horizontal.3.decrease.circle")
        let filterButton = UIBarButtonItem(image: filterImage, style: .plain) { [weak self] button in
            self?.filterButtonPressed(button)
        }
        navigationItem.leftBarButtonItems = [navigationItem.leftBarButtonItem, filterButton].compactMap { $0 }
    }
    
    @objc func filterButtonPressed(_ sender: Any?) {
        let filterVC = MapFilterViewController { [weak self] in
            guard let self else { return }
            // Update PlayaDB observations with new filter settings
            self.filteredDataSource.updateFilters()
            // Update map layers based on new filter settings
            self.mapLayerManager.updateAllLayers()
            // The camp toggles add and remove pins, and "Show Camp Names" decides both
            // whether a camp pin has to label itself and whether it is drawn at all, so all
            // three have to be re-resolved on Done — otherwise the change doesn't land until
            // the user happens to pan the map.
            self.userMapViewAdapter?.refreshRegionAnnotations()
            self.mapViewAdapter.reloadAnnotations()
            self.mapViewAdapter.updatePinLabelVisibility()
        }
        let nav = UINavigationController(rootViewController: filterVC)
        present(nav, animated: true)
    }
    
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navBar = navigationController?.navigationBar {
            Appearance.applyTransparentNavigationBarAppearance(navBar, colors: Appearance.currentColors, animated: animated)
        }
        if let tabBar = tabBarController?.tabBar {
            Appearance.applyTransparentTabBarAppearance(tabBar, colors: Appearance.currentColors)
        }
        mapViewAdapter.reloadAnnotations()
        geocodeNavigationBar()
        geocoderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.geocodeNavigationBar()
        }
        installBottomAccessoryIfNeeded()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // The accessory belongs to the shared tab bar controller, so it has to come
        // down when the map goes away or it would follow the user onto other tabs.
        bottomSearchController.deactivate()
        bottomSearchController.removeAccessory()
        if let navBar = navigationController?.navigationBar {
            Appearance.applyNavigationBarAppearance(navBar, colors: Appearance.currentColors, animated: animated)
        }
        if let tabBar = tabBarController?.tabBar {
            Appearance.applyTabBarAppearance(tabBar, colors: Appearance.currentColors)
        }
        self.tabBarController?.tabBar.isHidden = false
        self.tabBarController?.tabBar.alpha = 1.0
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.sidebarButtons.isHidden = false
        geocoderTimer = nil
    }
}

private extension MainMapViewController {

    // MARK: - Annotations

    func setupUserGuide() {
        sidebarButtons.findNearestAction = { [weak self] mapPointType, sender in
            guard let self, let location = self.mapView.userLocation?.location else {
                DDLogWarn("User location not found!")
                return
            }
            let playaDB = BRCAppDelegate.shared.dependencies.playaDB
            Task { @MainActor in
                if let point = await UserGuidance.findNearest(userLocation: location, mapPointType: mapPointType, playaDB: playaDB) {
                    DDLogInfo("Found closest point: \(point)")
                    // Hand it to the adapter rather than selecting it here: the object
                    // `UserGuidance` built from the database is not the instance drawn on
                    // the map, and selecting it does nothing.
                    self.userMapViewAdapter?.revealUserMapPoint(point)
                } else if mapPointType == .userBike || mapPointType == .userHome {
                    self.addUserMapPoint(type: mapPointType)
                }
            }
        }
        sidebarButtons.placePinAction = { [weak self] sender in
            self?.addUserMapPoint(type: .userStar)
        }
    }
    
    func addUserMapPoint(type: BRCMapPointType) {
        // One placement at a time. "Find my bike" answers from the database, so two quick
        // taps both used to see "no bike yet" and both placed one; the second alert can't
        // even present over the first.
        guard let adapter = userMapViewAdapter, !adapter.hasUnsavedPlacement else {
            DDLogInfo("Ignoring placement request: a pin is already waiting to be named")
            return
        }
        // On playa the pin lands on the user; off playa it lands in the middle of whatever
        // they've panned to, so it's on screen and draggable. See
        // `BRCLocations.userMapPointCoordinate(forUserLocation:viewportCenter:)`.
        let coordinate = BRCLocations.userMapPointCoordinate(
            forUserLocation: self.mapView.userLocation?.location,
            viewportCenter: self.mapView.centerCoordinate
        )
        let mapPoint = BRCUserMapPoint(title: nil, coordinate: coordinate, type: type)
        adapter.editMapPoint(mapPoint)
    }
}

extension MainMapViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        globalSearchHostingController.viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

extension MainMapViewController: SearchCooordinator {
    var searchController: UISearchController {
        return globalSearchController
    }
}
