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


public class MapViewAdapter: NSObject {
    
    // MARK: - Properties

    public var mapView: MGLMapView
    
    public var dataSource: AnnotationDataSource?
    
    var annotations: [MGLAnnotation] = []
    var annotationViews: [AnyHashable: MGLAnnotationView] = [:]
    
    @objc public init(mapView: MGLMapView,
                      dataSource: AnnotationDataSource? = nil) {
        self.mapView = mapView
        self.dataSource = dataSource
        super.init()
    }

    // MARK: - Public API
    
    @objc public func reloadAnnotations() {
        mapView.removeAnnotations(self.annotations)
        let annotations = dataSource?.allAnnotations() ?? []
        self.annotations = annotations
        self.mapView.addAnnotations(self.annotations)
    }
}

extension MGLAnnotation {
    var markerImage: UIImage? {
        var markerImage: UIImage? = nil
        if let dataObject = self as? BRCDataObject {
            markerImage = dataObject.brc_markerImage
        } else if let mapPoint = self as? BRCMapPoint {
            markerImage = mapPoint.image
        }
        return markerImage ?? UIImage(named: "BRCPurplePin")
    }
}

