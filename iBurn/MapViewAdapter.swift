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

    /// key is annotation ObjectIdentifier
    var annotationViews: [ObjectIdentifier: MGLAnnotationView] = [:]
    var labelViews: [LabelAnnotationView] = []
    /// annotations that this class owns and have been added to this mapview
    private var annotations: [MGLAnnotation] = []

    /// for checking if annotations overlap
    private var overlappingAnnotations: [CLLocationCoordinate2D: [DataObjectAnnotation]] = [:]
    
    @objc public init(mapView: MGLMapView,
                      dataSource: AnnotationDataSource? = nil) {
        self.mapView = mapView
        self.dataSource = dataSource
        super.init()
        self.mapView.delegate = self
    }

    // MARK: - Public API
    
    @objc public func reloadAnnotations() {
        removeAnnotations(self.annotations)
        self.annotations = dataSource?.allAnnotations() ?? []
        addAnnotations(self.annotations)
    }
    
    @objc public func removeAnnotations(_ annotations: [MGLAnnotation]) {
        annotations.forEach { (annotation) in
            if let data = annotation as? DataObjectAnnotation {
                let originalCoordinate = data.originalCoordinate
                var overlapping = overlappingAnnotations[originalCoordinate] ?? []
                overlapping = overlapping.filter({
                    if data.object.uniqueID == $0.object.uniqueID {
                        return false
                    } else {
                        return true
                    }
                })
                overlappingAnnotations[originalCoordinate] = overlapping
            }
        }
        mapView.removeAnnotations(annotations)
    }
    
    /// Adds annotations in a way that avoid overlap
    @objc public func addAnnotations(_ annotations: [MGLAnnotation]) {
        annotations.forEach { (annotation) in
            if let data = annotation as? DataObjectAnnotation {
                let originalCoordinate = data.originalCoordinate
                var overlapping = overlappingAnnotations[originalCoordinate] ?? []
                overlapping.append(data)
                overlappingAnnotations[originalCoordinate] = overlapping
            }
        }
        annotations.forEach {
            guard let data = $0 as? DataObjectAnnotation else {
                return
            }
            let originalCoordinate = data.originalCoordinate
            let overlapping = overlappingAnnotations[originalCoordinate] ?? []
            if overlapping.count > 1 {
                for (i, annotation) in overlapping.enumerated() {
                    let percentage = Double(i) / Double(overlapping.count) + 0.18
                    annotation.coordinate = data.originalCoordinate.offset(by: .offset(radius: 20, percentage: percentage))
                }
            }
        }
        mapView.addAnnotations(annotations)
    }
}


// MARK: - MGLMapViewDelegate

extension MapViewAdapter: MGLMapViewDelegate {
    
    public func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        let imageNames = [
            "airport", "bus", "centerCamp", "center",
            "firstAid", "EmergencyClinic", "ice", "info", "ranger",
            "recycle", "temple", "toilet"
        ]
        for imageName in imageNames {
            guard let image = UIImage(named: "pin_" + imageName) else {
                assertionFailure()
                continue
            }
            style.setImage(image, forName: imageName)
        }
    }
    
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
        }
        
        if let annotationView = annotationView {
            let identifier = ObjectIdentifier(annotation)
            annotationViews[identifier] = annotationView
        }

        return annotationView
    }
    
    public func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
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

extension CLLocationCoordinate2D: Hashable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.longitude == rhs.longitude &&
            lhs.latitude == rhs.latitude
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}
