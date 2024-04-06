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
    
    @objc public override init(mapView: MLNMapView,
                      dataSource: AnnotationDataSource? = nil) {
        super.init(mapView: mapView, dataSource: dataSource)
    }
    
    let writeConnection: YapDatabaseConnection = BRCDatabaseManager.shared.readWriteConnection
    private let mapRegionAnnotations = MapRegionDataSource()
    
    /// Set this if you want draggable
    var editingAnnotation: BRCMapPoint?
    
    // MARK: - Public
    
    func editMapPoint(_ mapPoint: BRCMapPoint) {
        clearEditingAnnotation()
        self.editingAnnotation = mapPoint
        mapView.addAnnotation(mapPoint)
        mapView.selectAnnotation(mapPoint, animated: true, completionHandler: nil)
    }
    
    // MARK: - MLNMapViewDelegate Overrides
    
    override public func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        let annotationView = super.mapView(mapView, viewFor: annotation)
        guard let imageAnnotationView = annotationView as? ImageAnnotationView,
        let point = annotation as? BRCMapPoint else { return annotationView }
        if point == editingAnnotation {
            imageAnnotationView.isDraggable = true
            imageAnnotationView.startDragging()
        } else {
            imageAnnotationView.isDraggable = false
        }
        return imageAnnotationView
    }
    
    override public func mapView(_ mapView: MLNMapView, didDeselect annotation: MLNAnnotation) {
        guard let mapPoint = editingAnnotation,
            let deselected = annotation as? BRCMapPoint,
            mapPoint == deselected else {
                return
        }
        saveMapPoint(mapPoint)
    }
    
    override public func mapView(_ mapView: MLNMapView, leftCalloutAccessoryViewFor annotation: MLNAnnotation) -> UIView? {
        guard annotation is BRCUserMapPoint else {
            return super.mapView(mapView, leftCalloutAccessoryViewFor: annotation)
        }
        let button = BButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30), type: .default, style: .bootstrapV3, icon: .FAPencil, fontSize: 20)
        button?.tag = ButtonTag.edit.rawValue
        return button
    }
    
    override public func mapView(_ mapView: MLNMapView, rightCalloutAccessoryViewFor annotation: MLNAnnotation) -> UIView? {
        guard annotation is BRCUserMapPoint else {
            return super.mapView(mapView, rightCalloutAccessoryViewFor: annotation)
        }
        let button = BButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30), type: .default, style: .bootstrapV3, icon: .FATrash, fontSize: 20)
        button?.tag = ButtonTag.delete.rawValue
        return button
    }
    
    override public func mapView(_ mapView: MLNMapView, annotation: MLNAnnotation, calloutAccessoryControlTapped control: UIControl) {
        guard let point = annotation as? BRCMapPoint,
            let annotationView = annotationViews[ObjectIdentifier(point)] as? ImageAnnotationView,
            let tag = ButtonTag(rawValue: control.tag) else {
                super.mapView(mapView, annotation: annotation, calloutAccessoryControlTapped: control)
                return
        }
        switch tag {
        case .delete:
            deleteMapPoint(point)
        case .edit:
            annotationView.isDraggable = true
            annotationView.startDragging()
            editMapPoint(point)
        case .info:
            break
        }
    }
    
    override public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        let zoomLevel = mapView.zoomLevel
        let labelIsHidden = mapView.zoomLevel < 13.0
        labelViews.forEach { (view) in
            view.label.isHidden = labelIsHidden
        }
        if mapView.zoomLevel >= 16.0 {
            let coordinateBounds = mapView.visibleCoordinateBounds
            BRCDatabaseManager.shared.queryObjects(inMinCoord: coordinateBounds.sw, maxCoord: coordinateBounds.ne, completionQueue: DispatchQueue.global(qos: .default)) { (objects) in
                var objects = objects.filter {
                    if let event = $0 as? BRCEventObject {
                        return event.shouldShowOnMap()
                    } else if let _ = $0 as? BRCCampObject {
                        // nearby camps just clutter the map until we get more precise location data
                        // from the org
                        if zoomLevel >= 18.0 {
                            return true
                        } else {
                            return false
                        }
                    } else {
                        return true
                    }
                }
                objects.sort { $0.title < $1.title }
                var annotations: [MLNAnnotation] = []
                BRCDatabaseManager.shared.backgroundReadConnection.asyncRead({ (t) in
                    annotations = objects.compactMap { $0.annotation(transaction: t) }
                }, completionBlock: {
                    self.removeAnnotations(self.mapRegionAnnotations.allAnnotations())
                    self.mapRegionAnnotations.annotations = annotations
                    self.addAnnotations(annotations)
                })
            }
        } else {
            removeAnnotations(mapRegionAnnotations.allAnnotations())
        }
    }
}

// MARK: - Public

private extension UserMapViewAdapter {
    
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
