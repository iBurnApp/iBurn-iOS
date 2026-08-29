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

/// Zoom + embargo gate for the map's region-fetch annotation path.
///
/// `UserMapViewAdapter.regionDidChange` is a *second* annotation source, independent of
/// `PlayaDBAnnotationDataSource`: it queries PlayaDB for whatever is inside the current
/// viewport and drops pins for it. The bundled database ships real placement data, so this
/// path has to apply exactly the same two-tier embargo the observation path does, or camp
/// and art pins (with their playa addresses in the callout) leak before their tier opens.
///
/// Kept pure — no `BRCEmbargo`, no map view, no database — so the filtering is testable.
/// The caller passes the tiers in; see `UserMapViewAdapter.refreshRegionAnnotations()`.
struct MapRegionAnnotationFilter {

    /// Zoom at or above which the region path runs at all, and art pins become eligible.
    static let artMinimumZoom: Double = 16.0

    /// Zoom at or above which camp pins become eligible.
    static let campMinimumZoom: Double = 17.0

    /// - Parameters:
    ///   - objects: whatever `PlayaDB.fetchObjects(in:)` returned for the viewport.
    ///   - zoomLevel: the map's current zoom.
    ///   - activeEventUIDs: events the caller decided are happening/starting soon.
    ///   - showArtOnlyZoomedIn: `UserSettings.showArtOnlyZoomedIn`.
    ///   - showCampsOnlyZoomedIn: `UserSettings.showCampsOnlyZoomedIn`.
    ///   - artAllowed: `MapEmbargo.allowsArtLocation()`.
    ///   - campAllowed: `MapEmbargo.allowsBulkCampPlacement()` — this path draws every camp
    ///     in the viewport, so it is bulk placement and waits for gates. Passed in rather
    ///     than read here, so the tier choice stays at the call site.
    static func annotations(
        from objects: [any PlayaDataObject],
        zoomLevel: Double,
        activeEventUIDs: Set<String>,
        showArtOnlyZoomedIn: Bool,
        showCampsOnlyZoomedIn: Bool,
        artAllowed: Bool,
        campAllowed: Bool
    ) -> [PlayaObjectAnnotation] {
        var annotations: [PlayaObjectAnnotation] = []
        for object in objects {
            if let art = object as? ArtObject {
                guard artAllowed,
                      showArtOnlyZoomedIn,
                      zoomLevel >= artMinimumZoom,
                      let annotation = PlayaObjectAnnotation(art: art) else { continue }
                annotations.append(annotation)
            } else if let camp = object as? CampObject {
                guard campAllowed,
                      showCampsOnlyZoomedIn,
                      zoomLevel >= campMinimumZoom,
                      let annotation = PlayaObjectAnnotation(camp: camp) else { continue }
                annotations.append(annotation)
            } else if let event = object as? EventObject {
                // An event at an art installation leaks the art's location, so it rides the
                // art tier; everything else leaks its host camp's, so it rides whatever tier
                // the caller passes for camps — the *bulk* one here, since a viewport full of
                // event pins maps the camps hosting them.
                let allowed = (event.locatedAtArt?.isEmpty == false) ? artAllowed : campAllowed
                guard allowed,
                      activeEventUIDs.contains(event.uid),
                      let annotation = PlayaObjectAnnotation(event: event) else { continue }
                annotations.append(annotation)
            }
        }
        return annotations.sorted {
            ($0.title ?? "").localizedStandardCompare($1.title ?? "") == .orderedAscending
        }
    }
}

public class UserMapViewAdapter: MapViewAdapter {

    // MARK: - Private

    private var _playaDB: PlayaDB?
    @MainActor var playaDB: PlayaDB {
        _playaDB ?? BRCAppDelegate.shared.dependencies.playaDB
    }

    @objc public override init(mapView: MLNMapView,
                      dataSource: AnnotationDataSource? = nil) {
        super.init(mapView: mapView, dataSource: dataSource)
        commonInit()
    }

    init(mapView: MLNMapView, dataSource: AnnotationDataSource? = nil, playaDB: PlayaDB) {
        self._playaDB = playaDB
        super.init(mapView: mapView, dataSource: dataSource)
        commonInit()
    }

    private func commonInit() {
        observeEmbargo()
        // Which camps the style layer names decides which camps get a pin at all, and until
        // the geojson has been read the answer is "keep every pin". Rebuild once it lands so
        // the extra pins come off. Run after `super.init` so the override below is safe to
        // dispatch: `load(then:)` calls back synchronously when the index is already loaded.
        CampStyleLabelIndex.shared.load { [weak self] in
            self?.reloadAnnotations()
        }
    }

    /// The region path snapshots the embargo tiers each time it runs, and it only runs on a
    /// region change — so without this an unlock while the map is up leaves the viewport
    /// empty of camp/art pins until the user pans or relaunches.
    private func observeEmbargo() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(embargoDidClear),
            name: .BRCEmbargoDidClear,
            object: nil
        )
    }

    @objc private func embargoDidClear() {
        // Unlocking turns the camp style labels on, which decides both whether a camp pin
        // draws its own name and — now — whether it is drawn at all, so the whole pin set
        // has to be rebuilt, not just relabelled.
        updatePinLabelVisibility()
        reloadAnnotations()
        refreshRegionAnnotations()
    }

    // MARK: - Camp pins the style layer has already labelled

    /// The `campNamesDrawnByStyleLayer` verdict the current pin set was built against.
    ///
    /// The observation path behind `dataSource` is zoom-blind — it pushes every camp
    /// whenever the database changes — so crossing `camp-labels-big`'s minzoom silently
    /// invalidates the pin set without producing a data-source update. This is what notices.
    private var campPinsBuiltForStyleDrawing: Bool?

    private var styleDrawsCampNames: Bool {
        CampLayerVisibility.current(zoomLevel: mapView.zoomLevel).campNamesDrawnByStyleLayer
    }

    override func shouldDisplay(_ annotation: MLNAnnotation) -> Bool {
        !CampPinVisibility.pinIsHidden(
            campUID: campUID(for: annotation),
            isFavorite: (annotation as? PlayaObjectAnnotation)?.isFavorite ?? false,
            styleDrawsCampNames: styleDrawsCampNames,
            styleLabeledCampUIDs: CampStyleLabelIndex.shared.labeledCampUIDs
        )
    }

    /// Rebuilds the pin set when — and only when — the style layer starts or stops naming
    /// camps. Called from every region change, so the guard is what keeps a pan cheap.
    private func reloadAnnotationsIfStyleDrawingChanged() {
        guard campPinsBuiltForStyleDrawing != styleDrawsCampNames else { return }
        reloadAnnotations()
    }

    private let mapRegionAnnotations = MapRegionDataSource()

    /// Set this if you want draggable
    var editingAnnotation: BRCMapPoint?

    /// True while a user pin is being moved or renamed. The map's drop-person long press
    /// reads this and stands down for the duration — see `DropPersonGate`.
    var isEditingUserPin: Bool { editingAnnotation != nil }

    /// A pin this adapter put on the map itself, rather than taking from the data source:
    /// a brand-new home/bike/star that the user is still naming and that no `user_map_pins`
    /// row exists for yet.
    ///
    /// It has to be remembered separately because `reloadAnnotations` removes only the
    /// data source's own list. Once the save commits, the observation delivers a second
    /// `BRCUserMapPoint` for the same `pinId`, and this reference is what lets the adapter
    /// hand the pin over (see `willReplaceDataSourceAnnotations`) instead of leaving the
    /// placed copy on the map underneath the database's copy — the stacked-pin bug.
    private(set) var locallyPlacedAnnotation: BRCMapPoint?

    /// True while a just-placed pin is still waiting to be named and saved. The map's
    /// placement buttons check this so a second impatient tap doesn't start a second
    /// placement on top of the first.
    var hasUnsavedPlacement: Bool { locallyPlacedAnnotation != nil }

    // MARK: - Dropped person marker

    /// The transient "look from here" person, while one is standing on the map.
    ///
    /// Held here rather than in the data source on purpose: it is not data. `reloadAnnotations()`
    /// and `refreshRegionAnnotations()` both remove only the lists they own, so the person
    /// survives every pan, filter change and embargo unlock without being re-added.
    private(set) var droppedPerson: DroppedPersonAnnotation?

    /// Fires when the person is taken off the map from the map's own affordance (its callout's
    /// remove button), so the host can drop the matching card/list override.
    var onDroppedPersonRemoved: (() -> Void)?

    /// Puts the person down at `coordinate`, moving it if it was already out.
    ///
    /// Removed and re-added rather than repositioned: a fresh annotation is what closes any
    /// open callout from the previous spot, and the marker view is cheap.
    @discardableResult
    func dropPerson(at coordinate: CLLocationCoordinate2D, title: String? = nil) -> DroppedPersonAnnotation {
        removeDroppedPerson(notifyHost: false)
        let person = DroppedPersonAnnotation(coordinate: coordinate, title: title)
        droppedPerson = person
        mapView.addAnnotation(person)
        return person
    }

    /// Relabels the person's callout once the reverse geocoder answers, ignoring results for
    /// a spot the person has already left.
    func updateDroppedPersonTitle(_ title: String?, for coordinate: CLLocationCoordinate2D) {
        guard let person = droppedPerson,
              person.coordinate.isSameCoordinate(as: coordinate),
              let title, !title.isEmpty else { return }
        person.title = title
    }

    /// Picks the person back up. `notifyHost` is false for the internal move case, where the
    /// override is about to be re-pointed rather than cleared.
    func removeDroppedPerson(notifyHost: Bool = true) {
        guard let person = droppedPerson else { return }
        droppedPerson = nil
        mapView.deselectAnnotation(person, animated: false)
        mapView.removeAnnotation(person)
        if notifyHost { onDroppedPersonRemoved?() }
    }

    // MARK: - Public
    
    /// Puts `mapPoint` up for editing: on the map if it isn't already, selected, with the
    /// rename alert over it.
    func editMapPoint(_ mapPoint: BRCMapPoint) {
        if registry.annotation(matching: mapPoint) == nil {
            // Nothing on the map holds this pin's id, so it is a fresh placement and this
            // adapter owns it until the database takes over. Added through the tracked
            // path — a bare `mapView.addAnnotation` here is what let the observation's
            // copy land on top of it.
            discardUnsavedPlacement()
            locallyPlacedAnnotation = mapPoint
            addAnnotations([mapPoint])
        }
        self.editingAnnotation = mapPoint
        mapView.selectAnnotation(mapPoint, animated: true, completionHandler: nil)
        showEditMapPointTitleAlert(for: mapPoint)
    }

    /// Centres on and selects the pin already on the map for `point`.
    ///
    /// The sidebar's "find my bike/home" answers from the database, so the object it hands
    /// over is a *different instance* than the one drawn on the map; selecting that
    /// instance did nothing at all, which is why the button looked dead once a pin
    /// existed. Resolve it to the on-map pin first.
    func revealUserMapPoint(_ point: BRCUserMapPoint) {
        let onMap = (registry.annotation(matching: point) as? BRCMapPoint) ?? point
        if registry.annotation(matching: onMap) == nil {
            // The observation hasn't delivered this pin yet (a save still in flight, say).
            addAnnotations([onMap])
        }
        mapView.setCenter(onMap.coordinate, animated: true)
        mapView.selectAnnotation(onMap, animated: true, completionHandler: nil)
    }

    // MARK: - MLNMapViewDelegate Overrides

    override func willReplaceDataSourceAnnotations(with annotations: [MLNAnnotation]) {
        // A pin taken *from* the data source for editing is about to be replaced by a
        // fresh instance of itself, so the stale reference has to go — otherwise
        // `didDeselect` would later re-save an object that is no longer on the map.
        // A pin this adapter placed is not in that list and survives, so naming or
        // dragging it isn't interrupted by an unrelated reload.
        if let editing = editingAnnotation, editing !== locallyPlacedAnnotation {
            editingAnnotation = nil
        }

        guard let placed = locallyPlacedAnnotation,
              MapAnnotationRegistry.contains(keyOf: placed, in: annotations) else { return }
        // The save landed and the database now publishes this pin: hand it over, so the
        // copy on the map is the one that keeps up with later edits and peer syncs. The
        // tracked removal is what frees the key for the incoming copy.
        locallyPlacedAnnotation = nil
        if editingAnnotation === placed { editingAnnotation = nil }
        removeAnnotations([placed])
    }

    override public func reloadAnnotations() {
        campPinsBuiltForStyleDrawing = styleDrawsCampNames
        super.reloadAnnotations()
    }

    override public func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        // Handled ahead of `super`, which only builds image views for `BRCMapPoint`s — the
        // person is deliberately not one of those (nothing about it is saved).
        if let person = annotation as? DroppedPersonAnnotation {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: DroppedPersonAnnotation.reuseIdentifier) as? ImageAnnotationView
                ?? ImageAnnotationView(reuseIdentifier: DroppedPersonAnnotation.reuseIdentifier)
            view.image = person.markerImage
            view.isDraggable = false
            return view
        }

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
        // Tap the person → callout (its playa address) → this button puts it away. Chosen
        // over a bare tap-to-remove because the callout is also what *shows* the address,
        // and a marker that vanishes on a stray tap is easy to lose by accident.
        if annotation is DroppedPersonAnnotation {
            let removeButton = UIButton(type: .system)
            removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            removeButton.tag = ButtonTag.delete.rawValue
            removeButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            removeButton.accessibilityLabel = NSLocalizedString(
                "Remove dropped pin",
                comment: "callout button that takes the dropped person marker off the map"
            )
            return removeButton
        }
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
        if annotation is DroppedPersonAnnotation {
            removeDroppedPerson()
            return
        }
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
    
    /// The user-facing map keeps pin names one zoom level further out than the detail maps.
    override var pinLabelHiddenAtOrBelowZoom: Double { 13.0 }

    override public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        updatePinLabelVisibility()
        reloadAnnotationsIfStyleDrawingChanged()
        refreshRegionAnnotations()
    }

    /// Re-queries PlayaDB for the current viewport and rebuilds the region annotations.
    ///
    /// Driven by region changes, and re-run on `.BRCEmbargoDidClear` because the embargo
    /// tiers are snapshotted per run.
    func refreshRegionAnnotations() {
        let zoomLevel = mapView.zoomLevel
        guard zoomLevel >= MapRegionAnnotationFilter.artMinimumZoom else {
            removeAnnotations(mapRegionAnnotations.allAnnotations())
            mapRegionAnnotations.annotations = []
            return
        }
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

            // `shouldDisplay` is applied to the result rather than left to `addAnnotations`
            // so `mapRegionAnnotations` holds only pins that really went on the map — the
            // next run removes that list by key, and a suppressed camp left in it would
            // deregister the key its favourite twin is holding.
            let annotations = MapRegionAnnotationFilter.annotations(
                from: objects,
                zoomLevel: zoomLevel,
                activeEventUIDs: activeEventUIDs,
                showArtOnlyZoomedIn: UserSettings.showArtOnlyZoomedIn,
                showCampsOnlyZoomedIn: UserSettings.showCampsOnlyZoomedIn,
                artAllowed: MapEmbargo.allowsArtLocation(),
                // Everything the viewport holds, camp-hosted events included: bulk
                // placement, so the gates tier rather than the week-early camp release.
                campAllowed: MapEmbargo.allowsBulkCampPlacement()
            ).filter { self.shouldDisplay($0) }
            self.removeAnnotations(self.mapRegionAnnotations.allAnnotations())
            self.mapRegionAnnotations.annotations = annotations
            self.addAnnotations(annotations)
        }
    }
}

// MARK: - Public

extension UserMapViewAdapter {

    /// Takes an unsaved placement back off the map, tracking included, so nothing is left
    /// holding its key.
    func discardUnsavedPlacement() {
        guard let placed = locallyPlacedAnnotation else { return }
        locallyPlacedAnnotation = nil
        if editingAnnotation === placed { editingAnnotation = nil }
        mapView.deselectAnnotation(placed, animated: false)
        removeAnnotations([placed])
    }

    /// Backs out of the rename alert. A pin placed for this edit and never saved comes off
    /// the map entirely; one that already exists in the database keeps its old name and
    /// stays where it is.
    func cancelEdit(of mapPoint: BRCMapPoint) {
        if mapPoint === locallyPlacedAnnotation {
            discardUnsavedPlacement()
        } else if mapPoint === editingAnnotation {
            editingAnnotation = nil
        }
    }

    func saveMapPoint(_ mapPoint: BRCMapPoint) {
        // The pin stays on the map: what replaces it is the copy the observation delivers
        // once the write commits, handed over in `willReplaceDataSourceAnnotations`.
        if mapPoint === editingAnnotation {
            editingAnnotation = nil
        }
        guard let userPin = mapPoint as? BRCUserMapPoint else { return }
        let pin = userPin.toUserMapPin()
        Task { @MainActor in
            do {
                try await playaDB.saveUserMapPin(pin)
                DDLogInfo("Saved user annotation: \(mapPoint)")
            } catch {
                DDLogError("Failed to save user annotation \(mapPoint): \(error)")
                // Nothing is coming to supersede it, so release ownership rather than
                // leaving the placement buttons wedged on a pin that never landed.
                if mapPoint === self.locallyPlacedAnnotation {
                    self.locallyPlacedAnnotation = nil
                }
            }
        }
    }

    func deleteMapPoint(_ mapPoint: BRCMapPoint) {
        if let userPin = mapPoint as? BRCUserMapPoint {
            Task { try? await playaDB.deleteUserMapPin(id: userPin.pinId) }
        }

        if mapPoint === editingAnnotation {
            editingAnnotation = nil
        }
        if mapPoint === locallyPlacedAnnotation {
            locallyPlacedAnnotation = nil
        }
        // Tracked removal: a bare `mapView.removeAnnotation` left the pin's id registered,
        // so re-adding that pin later (undo, peer sync) would silently be de-duplicated
        // against a pin that is no longer there.
        mapView.deselectAnnotation(mapPoint, animated: false)
        removeAnnotations([mapPoint])

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
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelEdit(of: mapPoint)
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self,
                  let textField = alertController.textFields?.first,
                  let newTitle = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newTitle.isEmpty else {
                // An empty name discards a brand-new pin, same as Cancel.
                self?.cancelEdit(of: mapPoint)
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
