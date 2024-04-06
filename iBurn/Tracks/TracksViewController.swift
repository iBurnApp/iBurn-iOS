//
//  TracksViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import UIKit
import MapLibre
import GRDB
import PlayaGeocoder

final class TracksViewController: UIViewController {
    // MARK: - Private Properties

    private let mapView = MLNMapView.brcMapView()
    private var storage: LocationStorage?
    private var annotations: [MLNAnnotation] = []
    private lazy var settingsBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: "Settings", style: .plain, closure: { [weak self] (_) in
            self?.showAlert()
        })
    }()
    
    // MARK: - Init
    
    init() {
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Location History", comment: "")
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        
        try? setupStorage()
        startMonitoring()
        
        navigationItem.rightBarButtonItem = settingsBarButtonItem
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshLocationHistory()
    }
}

private extension TracksViewController {
    func showAlert() {
        let alert = UIAlertController(title: "Location History Settings", message:"Every time you open the app, iBurn will automatically save a pin so know where you've been.", preferredStyle: .actionSheet)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let toggleTitle: String = UserDefaults.isLocationHistoryDisabled ? "Resume" : "Pause"
        let toggle = UIAlertAction(title: toggleTitle, style: .default) { (_) in
            UserDefaults.isLocationHistoryDisabled.toggle()
            self.storage?.restart()
        }
        let delete = UIAlertAction(title: "Clear History", style: .destructive) { (_) in
            let confirmation = UIAlertController(title: "Clear History", message: "Are you sure? This will permanently delete all of your location history.", preferredStyle: .alert)
            let delete = UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
                self.storage?.dbQueue.asyncWrite({ (db) in
                    try Breadcrumb.deleteAll(db)
                }, completion: { (db, result) in
                    DispatchQueue.main.async {
                        self.refreshLocationHistory()
                    }
                })
            })
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            confirmation.addAction(delete)
            confirmation.addAction(cancel)
            self.present(confirmation, animated: true, completion: nil)
        }
        alert.addAction(toggle)
        alert.addAction(delete)
        alert.addAction(cancel)
        alert.popoverPresentationController?.barButtonItem = settingsBarButtonItem
        present(alert, animated: true, completion: nil)
    }
    
    func setupStorage() throws {
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("LocationHistory.sqlite")
        self.storage = try LocationStorage(path: databaseURL.path)
    }
    
    func startMonitoring() {
        storage?.start()
    }
    
    func refreshLocationHistory() {
        mapView.removeAnnotations(annotations)
        annotations.removeAll()
        
        var crumbs: [Breadcrumb] = []
        do {
            try storage?.dbQueue.read { db in
                crumbs = try Breadcrumb.fetchAll(db)
            }
        } catch {
            print("Error fetching breadcrumbs: \(error)")
        }

        let coordinates = crumbs.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }
        let polyLine = MLNPolyline(coordinates: coordinates, count: UInt(coordinates.count))
        annotations.append(polyLine)
        mapView.addAnnotation(polyLine)
        
        let annotations = crumbs.map { BreadcrumbAnnotation(breadcrumb: $0) }
        mapView.addAnnotations(annotations)
        self.annotations += annotations
    }
}

private final class BreadcrumbAnnotation: NSObject, MLNAnnotation {
    let breadcrumb: Breadcrumb
    
    init(breadcrumb: Breadcrumb) {
        self.breadcrumb = breadcrumb
    }
    
    var coordinate: CLLocationCoordinate2D {
        return breadcrumb.coordinate
    }
    
    var title: String? {
        return "\(PlayaGeocoder.shared.syncReverseLookup(coordinate) ?? "Address Unknown")"
    }
    
    var subtitle: String? {
        return "\(DateFormatter.annotationDateFormatter.string(from: breadcrumb.timestamp)) - \(coordinate.latitude), \(coordinate.longitude)"
    }
}

extension TracksViewController: MLNMapViewDelegate {
    
    func mapView(_ mapView: MLNMapView, alphaForShapeAnnotation annotation: MLNShape) -> CGFloat {
        // Set the alpha for all shape annotations to 1 (full opacity)
        return 0.25
    }
    
    func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat {
        // Set the line width for polyline annotations
        return 2.0
    }
    
    func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
        return .red
    }
    
    func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
        return true
    }
}
