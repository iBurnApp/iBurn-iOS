//
//  MapViewAdapter.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/12/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import MapLibre
import YapDatabase
import BButton
import CocoaLumberjack
import SafariServices
import EventKitUI
import SwiftUI

public class MapViewAdapter: NSObject {
    
    enum ButtonTag: Int {
        case edit = 1,
        delete = 2,
        info = 3,
        share = 4,
        more = 5
    }

    // MARK: - Properties

    public let mapView: MLNMapView
    public var dataSource: AnnotationDataSource?
    public weak var parent: UIViewController?

    /// key is annotation ObjectIdentifier
    var annotationViews: [ObjectIdentifier: MLNAnnotationView] = [:]
    var labelViews: [LabelAnnotationView] = []
    /// annotations that this class owns and have been added to this mapview
    private var annotations: [MLNAnnotation] = []

    /// for checking if annotations overlap
    private var overlappingAnnotations: [CLLocationCoordinate2DBox: [DataObjectAnnotation]] = [:]
    
    /// Dictionary tracking all annotations currently on the map by type-prefixed ID
    private var annotationsByID: [String: MLNAnnotation] = [:]
    
    @objc public init(mapView: MLNMapView,
                      dataSource: AnnotationDataSource? = nil) {
        self.mapView = mapView
        self.dataSource = dataSource
        super.init()
        self.mapView.delegate = self
    }
    
    // MARK: - Helper Methods
    
    /// Generate unique key for an annotation
    private func keyForAnnotation(_ annotation: MLNAnnotation) -> String? {
        if let data = annotation as? DataObjectAnnotation {
            let className = String(describing: type(of: data.object))
            return "\(className):\(data.object.uniqueID)"
        } else if let mapPoint = annotation as? BRCMapPoint {
            let className = String(describing: type(of: mapPoint))
            return "\(className):\(mapPoint.yapKey)"
        }
        return nil // Non-trackable annotations
    }

    // MARK: - Public API
    
    @objc public func reloadAnnotations() {
        removeAnnotations(self.annotations)
        annotationsByID.removeAll() // Clear tracking
        self.annotations = dataSource?.allAnnotations() ?? []
        addAnnotations(self.annotations)
    }
    
    @objc public func removeAnnotations(_ annotations: [MLNAnnotation]) {
        annotations.forEach { annotation in
            // Remove from tracking dictionary
            if let key = keyForAnnotation(annotation) {
                annotationsByID.removeValue(forKey: key)
            }
            
            // Clean up overlap tracking for DataObjectAnnotations
            if let data = annotation as? DataObjectAnnotation {
                let originalCoordinate = data.originalCoordinate
                var overlapping = overlappingAnnotations[.init(originalCoordinate)] ?? []
                overlapping = overlapping.filter { $0.object.uniqueID != data.object.uniqueID }
                overlappingAnnotations[.init(originalCoordinate)] = overlapping
            }
        }
        mapView.removeAnnotations(annotations)
    }
    
    /// Adds annotations in a way that avoid overlap and de-duplicates
    @objc public func addAnnotations(_ annotations: [MLNAnnotation]) {
        // Single pass: filter, track, and offset
        let newAnnotations = annotations.filter { annotation in
            guard let key = keyForAnnotation(annotation) else {
                return true // Non-trackable always added
            }
            
            if annotationsByID[key] != nil {
                return false // Already on map
            }
            
            // Track it
            annotationsByID[key] = annotation
            
            // Handle overlap offset for DataObjectAnnotation
            if let data = annotation as? DataObjectAnnotation {
                let originalCoordinate = data.originalCoordinate
                var overlapping = overlappingAnnotations[.init(originalCoordinate)] ?? []
                overlapping.append(data)
                
                // Sort by uniqueID for consistent ordering
                overlapping.sort { $0.object.uniqueID < $1.object.uniqueID }
                overlappingAnnotations[.init(originalCoordinate)] = overlapping
                
                // Apply offset to this new annotation based on its sorted position
                if overlapping.count > 1,
                   let index = overlapping.firstIndex(where: { $0.object.uniqueID == data.object.uniqueID }) {
                    let percentage = Double(index) / Double(overlapping.count) + 0.18
                    data.coordinate = originalCoordinate.offset(by: .offset(radius: 20, percentage: percentage))
                }
            }
            
            return true
        }
        
        mapView.addAnnotations(newAnnotations)
    }
}


// MARK: - MLNMapViewDelegate

extension MapViewAdapter: MLNMapViewDelegate {
    
    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        
        let imageMap = [
            "Airport": "airport",
            "Rampart": "EmergencyClinic",
            "Center Camp Plaza": "centerCamp",
            "center": "center",
            "Burner Express Bus Depot": "bus",
            "Station 3": "firstAid",
            "Station 9": "firstAid",
            "Playa Info": "info",
            "Ranger Station Berlin": "ranger",
            "Ranger Station Tokyo": "ranger",
            "Ranger HQ": "ranger",
            "Ice Nine Arctica": "ice",
            "Arctica Center Camp": "ice",
            "Ice Cubed Arctica 3": "ice",
            "The Temple": "temple",
            "toilet": "toilet",
            "Artery": "artery",
            "Yellow Bike Project": "bike",
            "Hell Station": "fuel",
            "Census Checkpoint": "census",
            "BLM LE Substation": "police",
            "Gate Actual": "gate",
            "Box Office": "boxOffice",
            "Greeters": "greeters",
        ]
        for (key, imageName) in imageMap {
            guard let image = UIImage(named: "pin_" + imageName) else {
                assertionFailure()
                continue
            }
            style.setImage(image, forName: key)
        }
    }
    
    public func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        guard let imageAnnotation = annotation as? ImageAnnotation,
            let image = imageAnnotation.markerImage ?? UIImage(named: "BRCPurplePin") else {
                return nil
        }
        var annotationView: MLNAnnotationView?
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
    
    public func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
        return true
    }
    
    public func mapView(_ mapView: MLNMapView, didDeselect annotation: MLNAnnotation) {}
    
    public func mapView(_ mapView: MLNMapView, leftCalloutAccessoryViewFor annotation: MLNAnnotation) -> UIView? {
        guard annotation is DataObjectAnnotation else {
            return nil
        }
        // Share button
        let shareButton = UIButton(type: .system)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tag = ButtonTag.share.rawValue
        shareButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        return shareButton
    }
    
    public func mapView(_ mapView: MLNMapView, rightCalloutAccessoryViewFor annotation: MLNAnnotation) -> UIView? {
        guard annotation is DataObjectAnnotation else {
            return nil
        }
        let infoButton = UIButton(type: .infoLight)
        infoButton.tag = ButtonTag.info.rawValue
        return infoButton
    }
    
    public func mapView(_ mapView: MLNMapView, annotation: MLNAnnotation, calloutAccessoryControlTapped control: UIControl) {
        guard let data = annotation as? DataObjectAnnotation,
            let tag = ButtonTag(rawValue: control.tag) else {
                return
        }
        switch tag {
        case .delete, .edit:
            break
        case .info:
            if let parentVC = parent {
                let vc = DetailViewControllerFactory.createDetailViewController(for: data.object)
                parentVC.navigationController?.pushViewController(vc, animated: true)
            }
        case .share:
            if let parentVC = parent {
                let shareViewController = ShareQRCodeHostingController(dataObject: data.object)
                parentVC.present(shareViewController, animated: true, completion: nil)
            }
        case .more:
            // More action not used for regular data objects
            break
        }
    }
    
    public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {        
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

struct CLLocationCoordinate2DBox {
    var coordinate: CLLocationCoordinate2D
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

extension CLLocationCoordinate2DBox: RawRepresentable {
    var rawValue: CLLocationCoordinate2D { coordinate }
    init(rawValue: CLLocationCoordinate2D) {
        self.init(rawValue)
    }
}

extension CLLocationCoordinate2DBox: Hashable {
    public static func == (lhs: CLLocationCoordinate2DBox, rhs: CLLocationCoordinate2DBox) -> Bool {
        return lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.coordinate.latitude == rhs.coordinate.latitude
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}
