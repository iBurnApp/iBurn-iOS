//
//  TracksViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import UIKit
import Mapbox
import GRDB
import PlayaGeocoder

protocol UserTrackDataSource {
    
}

final class TracksViewController: UIViewController {
    // MARK: - Private Properties

    private let mapView = MGLMapView.brcMapView()
    private var storage: LocationStorage?
    
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
        showLocationHistory()
    }
}

private extension TracksViewController {
    func setupStorage() throws {
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("LocationHistory.sqlite")
        self.storage = try LocationStorage(path: databaseURL.path)
    }
    
    func startMonitoring() {
        storage?.start()
    }
    
    func showLocationHistory() {
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
        let polyLine = MGLPolyline(coordinates: coordinates, count: UInt(coordinates.count))
        mapView.addAnnotation(polyLine)
        
        let annotations = crumbs.map { BreadcrumbAnnotation(breadcrumb: $0) }
        mapView.addAnnotations(annotations)
    }
}

private final class BreadcrumbAnnotation: NSObject, MGLAnnotation {
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

extension TracksViewController: MGLMapViewDelegate {
    
    func mapView(_ mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        // Set the alpha for all shape annotations to 1 (full opacity)
        return 0.25
    }
    
    func mapView(_ mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        // Set the line width for polyline annotations
        return 2.0
    }
    
    func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        return .red
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
}
