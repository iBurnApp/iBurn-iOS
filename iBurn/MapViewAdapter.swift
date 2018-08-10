//
//  MapViewAdapter.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/12/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import Mapbox
import YapDatabase
import BButton



public class MapViewAdapter: NSObject {
    
    enum ButtonTag: Int {
        case edit = 1,
        delete = 2,
        info = 3
    }

    // MARK: - Properties

    public let mapView: MGLMapView
    public var dataSource: AnnotationDataSource?
    public weak var parent: UIViewController?

    var annotations: [MGLAnnotation] = []
    var annotationViews: [AnyHashable: MGLAnnotationView] = [:]
    
    @objc public init(mapView: MGLMapView,
                      dataSource: AnnotationDataSource? = nil) {
        self.mapView = mapView
        self.dataSource = dataSource
        super.init()
        self.mapView.delegate = self
    }

    // MARK: - Public API
    
    @objc public func reloadAnnotations() {
        mapView.removeAnnotations(self.annotations)
        let annotations = dataSource?.allAnnotations() ?? []
        self.annotations = annotations
        self.mapView.addAnnotations(self.annotations)
    }
}


// MARK: - MGLMapViewDelegate

extension MapViewAdapter: MGLMapViewDelegate {
    public func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        guard let imageAnnotation = annotation as? ImageAnnotation,
            let image = imageAnnotation.markerImage ?? UIImage(named: "BRCPurplePin") else {
                return nil
        }
        let annotationView: ImageAnnotationView
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: ImageAnnotationView.reuseIdentifier) as? ImageAnnotationView {
            annotationView = view
        } else {
            annotationView = ImageAnnotationView(reuseIdentifier: ImageAnnotationView.reuseIdentifier)
        }
        annotationView.image = image
        if let annotation = annotation as? AnyHashable {
            annotationViews[annotation] = annotationView
        }
        return annotationView
    }
    
    public func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        guard annotation is ImageAnnotation else {
            return false
        }
        return true
    }
    
    public func mapView(_ mapView: MGLMapView, didDeselect annotation: MGLAnnotation) {}
    
    public func mapView(_ mapView: MGLMapView, leftCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        return nil
    }
    
    public func mapView(_ mapView: MGLMapView, rightCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        guard annotation is DataObjectAnnotation else {
            return nil
        }
        let infoButton = UIButton(type: .infoLight)
        infoButton.tag = ButtonTag.info.rawValue
        return infoButton
    }
    
    public func mapView(_ mapView: MGLMapView, annotation: MGLAnnotation, calloutAccessoryControlTapped control: UIControl) {
        guard let data = annotation as? DataObjectAnnotation,
            let tag = ButtonTag(rawValue: control.tag) else {
                return
        }
        switch tag {
        case .delete, .edit:
            break
        case .info:
            let vc = BRCDetailViewController(dataObject: data.object)
            parent?.navigationController?.pushViewController(vc, animated: true)
        }
    }
}



