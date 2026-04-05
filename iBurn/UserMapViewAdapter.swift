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
import MapKit
import PlayaDB

public class UserMapViewAdapter: MapViewAdapter {

    // MARK: - Private

    private var _playaDB: PlayaDB?
    @MainActor var playaDB: PlayaDB {
        _playaDB ?? BRCAppDelegate.shared.dependencies.playaDB
    }

    @objc public override init(mapView: MLNMapView,
                      dataSource: AnnotationDataSource? = nil) {
        super.init(mapView: mapView, dataSource: dataSource)
    }

    init(mapView: MLNMapView, dataSource: AnnotationDataSource? = nil, playaDB: PlayaDB) {
        self._playaDB = playaDB
        super.init(mapView: mapView, dataSource: dataSource)
    }

    private let mapRegionAnnotations = MapRegionDataSource()
    
    /// Set this if you want draggable
    var editingAnnotation: BRCMapPoint?
    
    // MARK: - Public
    
    func editMapPoint(_ mapPoint: BRCMapPoint) {
        clearEditingAnnotation()
        self.editingAnnotation = mapPoint
        mapView.addAnnotation(mapPoint)
        mapView.selectAnnotation(mapPoint, animated: true, completionHandler: nil)
        showEditMapPointTitleAlert(for: mapPoint)
    }
    
    // MARK: - MLNMapViewDelegate Overrides
    
    override public func reloadAnnotations() {
        // Clear editing annotation - removes from map and nils reference
        clearEditingAnnotation()
        super.reloadAnnotations()
    }
    
    override public func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        let annotationView = super.mapView(mapView, viewFor: annotation)
        guard let imageAnnotationView = annotationView as? ImageAnnotationView,
        let point = annotation as? BRCMapPoint else { return annotationView }
        if point is BRCUserMapPoint {
            imageAnnotationView.isDraggable = true
            imageAnnotationView.isUserInteractionEnabled = true
            imageAnnotationView.addLongPressGestureIfNeeded(target: self, action: #selector(handleCalloutLongPress(_:)), minimumPressDuration: 0.5)
            imageAnnotationView.onDragEnded = { [weak self] annotation in
                if let mapPoint = annotation as? BRCUserMapPoint {
                    let pin = mapPoint.toUserMapPin()
                    Task { try? await self?.playaDB.saveUserMapPin(pin) }
                    DDLogInfo("Saved dragged annotation: \(mapPoint)")
                }
            }
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
        // Keep the edit button
        let button = BButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30), type: .default, style: .bootstrapV3, icon: .FAPencil, fontSize: 20)
        button?.tag = ButtonTag.edit.rawValue
        return button
    }
    
    override public func mapView(_ mapView: MLNMapView, rightCalloutAccessoryViewFor annotation: MLNAnnotation) -> UIView? {
        guard annotation is BRCUserMapPoint else {
            return super.mapView(mapView, rightCalloutAccessoryViewFor: annotation)
        }
        // More button (replaces delete button)
        let moreButton = UIButton(type: .system)
        moreButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        moreButton.tag = ButtonTag.more.rawValue
        moreButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        return moreButton
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
            // Restore edit functionality
            annotationView.isDraggable = true
            annotationView.startDragging()
            editMapPoint(point)
        case .info:
            break
        case .share:
            // Direct share (not used for user map points in callout)
            shareMapPoint(point, sourceView: control)
        case .more:
            // Show action sheet with Delete and Share options
            showMoreActionsForMapPoint(point, sourceView: control)
        }
    }
    
    private func shareMapPoint(_ point: BRCMapPoint, sourceView: UIView) {
        // Show QR code share screen for map points
        let shareViewController = ShareQRCodeHostingController(mapPoint: point)
        if let parentVC = parent {
            parentVC.present(shareViewController, animated: true, completion: nil)
        }
    }
    
    private func showMoreActionsForMapPoint(_ point: BRCMapPoint, sourceView: UIView) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Share action
        let shareAction = UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.shareMapPoint(point, sourceView: sourceView)
        }
        shareAction.setValue(UIImage(systemName: "square.and.arrow.up"), forKey: "image")
        actionSheet.addAction(shareAction)
        
        // Delete action
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteMapPoint(point)
        }
        deleteAction.setValue(UIImage(systemName: "trash"), forKey: "image")
        actionSheet.addAction(deleteAction)
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(cancelAction)
        
        // iPad support
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        
        if let parentVC = parent {
            parentVC.present(actionSheet, animated: true)
        }
    }
    
    override public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        let zoomLevel = mapView.zoomLevel
        let labelIsHidden = zoomLevel <= 13.0
        labelViews.forEach { (view) in
            view.label.isHidden = labelIsHidden
        }
        if zoomLevel >= 16.0 {
            let bounds = mapView.visibleCoordinateBounds
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (bounds.sw.latitude + bounds.ne.latitude) / 2,
                    longitude: (bounds.sw.longitude + bounds.ne.longitude) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: bounds.ne.latitude - bounds.sw.latitude,
                    longitudeDelta: bounds.ne.longitude - bounds.sw.longitude
                )
            )
            Task { @MainActor in
                guard let objects = try? await playaDB.fetchObjects(in: region) else { return }
                let now = Date.present
                let startingSoonThreshold: TimeInterval = 30 * 60
                let endingSoonThreshold: TimeInterval = 15 * 60

                // Fetch current/upcoming events once for time filtering
                let currentEvents = (try? await playaDB.fetchUpcomingEvents(within: 1, from: now)) ?? []
                let activeEventUIDs = Set(currentEvents.compactMap { occ -> String? in
                    let hasEnded = now > occ.occurrence.endTime
                    let isHappening = now >= occ.occurrence.startTime && now <= occ.occurrence.endTime
                    let timeUntilStart = occ.occurrence.startTime.timeIntervalSince(now)
                    let isStartingSoon = timeUntilStart > 0 && timeUntilStart < startingSoonThreshold
                    let timeUntilEnd = occ.occurrence.endTime.timeIntervalSince(now)
                    let isEndingSoon = timeUntilEnd > 0 && timeUntilEnd < endingSoonThreshold
                    if !hasEnded && (isHappening || isStartingSoon) && !isEndingSoon {
                        return occ.event.uid
                    }
                    return nil
                })

                var annotations: [MLNAnnotation] = []
                for object in objects {
                    if let art = object as? ArtObject {
                        if UserSettings.showArtOnlyZoomedIn {
                            if let annotation = PlayaObjectAnnotation(art: art) {
                                annotations.append(annotation)
                            }
                        }
                    } else if let camp = object as? CampObject {
                        if UserSettings.showCampsOnlyZoomedIn && zoomLevel >= 17.0 {
                            if let annotation = PlayaObjectAnnotation(camp: camp) {
                                annotations.append(annotation)
                            }
                        }
                    } else if let event = object as? EventObject {
                        if activeEventUIDs.contains(event.uid),
                           let annotation = PlayaObjectAnnotation(event: event) {
                            annotations.append(annotation)
                        }
                    }
                }
                annotations.sort { ($0.title.flatMap { $0 } ?? "") < ($1.title.flatMap { $0 } ?? "") }
                self.removeAnnotations(self.mapRegionAnnotations.allAnnotations())
                self.mapRegionAnnotations.annotations = annotations
                self.addAnnotations(annotations)
            }
        } else {
            removeAnnotations(mapRegionAnnotations.allAnnotations())
        }
    }
}

// MARK: - Public

private extension UserMapViewAdapter {
    
    func clearEditingAnnotation() {
        guard let existingMapPoint = self.editingAnnotation else { return }
        editingAnnotation = nil  // Clear reference first
        mapView.removeAnnotation(existingMapPoint)
    }
    
    func saveMapPoint(_ mapPoint: BRCMapPoint) {
        if let userPin = mapPoint as? BRCUserMapPoint {
            let pin = userPin.toUserMapPin()
            Task { try? await playaDB.saveUserMapPin(pin) }
        }

        // For new/edited pins, just clear the editing reference
        // Don't remove from map - it should stay visible
        if mapPoint === editingAnnotation {
            editingAnnotation = nil
        }

        DDLogInfo("Saved user annotation: \(mapPoint)")
    }

    func deleteMapPoint(_ mapPoint: BRCMapPoint) {
        if let userPin = mapPoint as? BRCUserMapPoint {
            Task { try? await playaDB.deleteUserMapPin(id: userPin.pinId) }
        }

        // Remove from map immediately
        if mapPoint === editingAnnotation {
            editingAnnotation = nil
        }
        mapView.removeAnnotation(mapPoint)

        DDLogInfo("Deleted user annotation: \(mapPoint)")
    }
}

// MARK: // Private

private extension UserMapViewAdapter {
    
    @objc func handleCalloutLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let annotationView = gesture.view as? ImageAnnotationView,
              let selectedAnnotation = mapView.selectedAnnotations.first,
              let mapPoint = selectedAnnotation as? BRCMapPoint else { return }
        
        mapView.deselectAnnotation(selectedAnnotation, animated: false)
        
        self.editingAnnotation = mapPoint
        annotationView.setDragState(.starting, animated: true)
    }
    
    func showEditMapPointTitleAlert(for mapPoint: BRCMapPoint) {
        guard let parentViewController = parent else {
            return
        }
        
        let alertController = UIAlertController(
            title: "Edit Favorite",
            message: "Enter a new name for this location",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.text = mapPoint.title
            textField.autocapitalizationType = .words
            textField.returnKeyType = .done
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self,
                  let textField = alertController.textFields?.first,
                  let newTitle = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newTitle.isEmpty else {
                guard let self else { return }
                self.clearEditingAnnotation()
                return
            }
            
            mapPoint.title = newTitle
            
            self.saveMapPoint(mapPoint)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        // Present the alert
        parentViewController.present(alertController, animated: true)
    }
}
