//
//  UserMapViewAdapter.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import CocoaLumberjack
import BButton

public class UserMapViewAdapter: MapViewAdapter {
    
    // MARK: - Private
    
    @objc public override init(mapView: MGLMapView,
                      dataSource: AnnotationDataSource? = nil) {
        super.init(mapView: mapView, dataSource: dataSource)
        self.mapView.delegate = self
    }
    
    let writeConnection: YapDatabaseConnection = BRCDatabaseManager.shared.readWriteConnection
    
    /// Set this if you want draggable
    var editingAnnotation: BRCMapPoint?
    
    // MARK: - Public
    
    func editMapPoint(_ mapPoint: BRCMapPoint) {
        clearEditingAnnotation()
        self.editingAnnotation = mapPoint
        mapView.addAnnotation(mapPoint)
        mapView.selectAnnotation(mapPoint, animated: true)
    }
}

// MARK: - Public

private extension UserMapViewAdapter {

    enum ButtonTag: Int {
        case edit = 1,
        delete = 2
    }
    
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
            self.reloadAnnotations()
        }
    }
    
    func deleteMapPoint(_ mapPoint: BRCMapPoint) {
        writeConnection.asyncReadWrite({ (transaction) in
            mapPoint.remove(with: transaction)
        }) {
            self.clearEditingAnnotation()
            self.mapView.removeAnnotation(mapPoint)
            DDLogInfo("Deleted user annotation: \(mapPoint)")
            self.reloadAnnotations()
        }
    }
}

// MARK: - MGLMapViewDelegate

extension UserMapViewAdapter: MGLMapViewDelegate {
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
            let annotationView = annotationViews[point] as? ImageAnnotationView,
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
