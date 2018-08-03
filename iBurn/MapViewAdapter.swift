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
        delete = 2
    }
    
    // MARK: - Properties

    public var mapView: MGLMapView {
        didSet {
            mapView.delegate = self
        }
    }
    
    let uiConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    
    
    
    /// This takes control of the mapView delegate
    @objc public init(mapView: MGLMapView) {
        self.mapView = mapView
        uiConnection = BRCDatabaseManager.shared.uiConnection
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        super.init()
        mapView.delegate = self
    }
    
    var userAnnotations: [BRCMapPoint] = []
    var annotationViews: [AnyHashable: ImageAnnotationView] = [:]
    
    /// Set this if you want draggable
    var editingAnnotation: BRCMapPoint?
    
    // MARK: - Public API
    
    func reloadUserAnnotations() {
        mapView.removeAnnotations(self.userAnnotations)
        var userAnnotations: [BRCMapPoint] = []
        uiConnection.read({ transaction in
            transaction.enumerateKeysAndObjects(inCollection: BRCUserMapPoint.yapCollection, using: { (key, object, stop) in
                if let mapPoint = object as? BRCUserMapPoint {
                    userAnnotations.append(mapPoint)
                }
            })
        })
        self.userAnnotations = userAnnotations
        self.mapView.addAnnotations(self.userAnnotations)
    }
    
    func editMapPoint(_ mapPoint: BRCMapPoint) {
        clearEditingAnnotation()
        self.editingAnnotation = mapPoint
        mapView.addAnnotation(mapPoint)
        mapView.selectAnnotation(mapPoint, animated: true)
    }
}

private extension MapViewAdapter {
    func clearEditingAnnotation() {
        if let existingMapPoint = self.editingAnnotation {
            mapView.removeAnnotation(existingMapPoint)
        }
        editingAnnotation = nil
    }
    
    func saveMapPoint(_ mapPoint: BRCMapPoint) {
        writeConnection.asyncReadWrite({ (transaction) in
            mapPoint.save(with: transaction, metadata: nil)
        }) {
            self.clearEditingAnnotation()
            self.mapView.removeAnnotation(mapPoint)
            DDLogInfo("Saved user annotation: \(mapPoint)")
            self.reloadUserAnnotations()
        }
    }
    
    func deleteMapPoint(_ mapPoint: BRCMapPoint) {
        writeConnection.asyncReadWrite({ (transaction) in
            mapPoint.remove(with: transaction)
        }) {
            self.clearEditingAnnotation()
            self.mapView.removeAnnotation(mapPoint)
            DDLogInfo("Deleted user annotation: \(mapPoint)")
            self.reloadUserAnnotations()
        }
    }
}

// MARK: - MGLMapViewDelegate

extension MapViewAdapter: MGLMapViewDelegate {
    public func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        guard let point = annotation as? BRCMapPoint,
            let image = annotation.markerImage else {
                return nil
        }
        let annotationView: ImageAnnotationView
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: ImageAnnotationView.reuseIdentifier) as? ImageAnnotationView {
            annotationView = view
        } else {
            annotationView = ImageAnnotationView(reuseIdentifier: ImageAnnotationView.reuseIdentifier)
        }
        annotationView.image = image
        if point == editingAnnotation {
            annotationView.isDraggable = true
            annotationView.startDragging()
        } else {
            annotationView.isDraggable = false
        }
        annotationViews[point] = annotationView
        return annotationView
    }
    
    public func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    public func mapView(_ mapView: MGLMapView, didDeselect annotation: MGLAnnotation) {
        guard let mapPoint = editingAnnotation,
            let deselected = annotation as? BRCMapPoint,
            mapPoint == deselected else {
                return
        }
        saveMapPoint(mapPoint)
    }
    
    public func mapView(_ mapView: MGLMapView, leftCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        guard annotation is BRCUserMapPoint else {
            return nil
        }
        let button = BButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30), type: .default, style: .bootstrapV3, icon: .FAPencil, fontSize: 20)
        button?.tag = ButtonTag.edit.rawValue
        return button
    }
    
    public func mapView(_ mapView: MGLMapView, rightCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        guard annotation is BRCUserMapPoint else {
            return nil
        }
        let button = BButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30), type: .default, style: .bootstrapV3, icon: .FATrash, fontSize: 20)
        button?.tag = ButtonTag.delete.rawValue
        return button
    }
    
    public func mapView(_ mapView: MGLMapView, annotation: MGLAnnotation, calloutAccessoryControlTapped control: UIControl) {
        guard let point = annotation as? BRCMapPoint,
            let annotationView = annotationViews[point],
            let tag = ButtonTag(rawValue: control.tag) else {
                return
        }
        switch tag {
        case .delete:
            deleteMapPoint(point)
        case .edit:
            annotationView.isDraggable = true
            annotationView.startDragging()
            editMapPoint(point)
        }
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

