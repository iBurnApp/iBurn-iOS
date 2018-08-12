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
import CocoaLumberjack


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
    /// key is annotation
    var annotationViews: [AnyHashable: MGLAnnotationView] = [:]
    var labelViews: [LabelAnnotationView] = []

    /// for checking if annotations overlap
    private var overlappingAnnotations: [OverlapCoordinate: Set<DataObjectAnnotation>] = [:]
    
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
        var annotationView: MGLAnnotationView?
        if let _ = annotation as? BRCMapPoint {
            let imageAnnotationView: ImageAnnotationView
            if let view = mapView.dequeueReusableAnnotationView(withIdentifier: ImageAnnotationView.reuseIdentifier) as? ImageAnnotationView {
                imageAnnotationView = view
            } else {
                imageAnnotationView = ImageAnnotationView(reuseIdentifier: ImageAnnotationView.reuseIdentifier)
            }
            imageAnnotationView.image = image
            annotationView = imageAnnotationView
        } else if let data = annotation as? DataObjectAnnotation {
            let labelAnnotationView: LabelAnnotationView
            if let view = mapView.dequeueReusableAnnotationView(withIdentifier: LabelAnnotationView.reuseIdentifier) as? LabelAnnotationView {
                labelAnnotationView = view
            } else {
                labelAnnotationView = LabelAnnotationView(reuseIdentifier: LabelAnnotationView.reuseIdentifier)
            }
            labelAnnotationView.imageView.image = image
            labelAnnotationView.label.text = data.title
            labelViews.append(labelAnnotationView)
            annotationView = labelAnnotationView
            
            let overlapCoordinate = data.originalCoordinate.overlapCoordinate
            var overlapping = overlappingAnnotations[overlapCoordinate] ?? Set<DataObjectAnnotation>()
            overlapping.insert(data)
            if overlapping.count > 1 {
                for (i, annotation) in overlapping.enumerated() {
                    let percentage = Double(i) / Double(overlapping.count) + 0.18
                    annotation.coordinate = data.originalCoordinate.offset(by: .offset(radius: 20, percentage: percentage))
                }
            }
            overlappingAnnotations[overlapCoordinate] = overlapping
        }
        
        if let annotation = annotation as? AnyHashable,
            let annotationView = annotationView {
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
    
    public func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        DDLogVerbose("New zoom level: \(mapView.zoomLevel)")
        
        let labelIsHidden = mapView.zoomLevel <= 14
        labelViews.forEach { (view) in
            view.label.isHidden = labelIsHidden
        }
    }
}

private struct Offset {
    var dx: Double
    var dy: Double
    
    /// random offset of some pixels in x/y
    static func offset(radius: Double, radian: Double) -> Offset {
        let dx = radius * cos(radian)
        let dy = radius * sin(radian)
        return Offset(dx: dx, dy: dy)
    }
    
    /// percentage is from 0.0-1.0
    static func offset(radius: Double, percentage: Double) -> Offset {
        let radian = percentage * 2 * Double.pi
        return .offset(radius: radius, radian: radian)
    }
    
    /// random offset of some pixels in x/y
    static func randomOffset(radius: Double) -> Offset {
        return .offset(radius: radius, percentage: drand48())
    }
}

private struct OverlapCoordinate: Hashable, Equatable {
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    
    init(latitude: CLLocationDegrees,
         longitude: CLLocationDegrees) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

private extension CLLocationCoordinate2D {
    /// dx/dy in meters
    func offset(by offset: Offset) -> CLLocationCoordinate2D {
        // https://gis.stackexchange.com/a/2980
        
        //Position, decimal degrees
        let lat = latitude
        let lon = longitude
        
        //Earth’s radius, sphere
        let R: Double = 6378137
        
        //offsets in meters
        let dn = offset.dy
        let de = offset.dx
        
        //Coordinate offsets in radians
        let dLat = dn/R
        let dLon = de / (R * cos(Double.pi * lat / 180))
        
        //OffsetPosition, decimal degrees
        let latO = lat + dLat * 180/Double.pi
        let lonO = lon + dLon * 180/Double.pi
        
        return CLLocationCoordinate2D(latitude: latO, longitude: lonO)
    }
}

private extension CLLocationCoordinate2D {
    var overlapCoordinate: OverlapCoordinate {
        return OverlapCoordinate(coordinate: self)
    }
}
