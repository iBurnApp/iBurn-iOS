//
//  MapViewAdapter.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/12/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import MapLibre
import BButton
import CocoaLumberjack
import SafariServices
import EventKitUI
import PlayaDB
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
    public var onStyleLoaded: ((MLNStyle) -> Void)?

    /// Zoom at or below which a pin's name label is unreadable clutter and stays hidden.
    /// Overridable because the user-facing map keeps labels a little further out.
    var pinLabelHiddenAtOrBelowZoom: Double { 14 }

    /// key is annotation ObjectIdentifier
    var annotationViews: [ObjectIdentifier: MLNAnnotationView] = [:]
    var labelViews: [LabelAnnotationView] = []
    /// annotations that this class owns and have been added to this mapview
    private var annotations: [MLNAnnotation] = []

    /// for checking if annotations overlap
    private var overlappingAnnotations: [CLLocationCoordinate2DBox: [any OffsettableAnnotation]] = [:]

    /// Which annotation is on the map under which stable key. See `MapAnnotationRegistry`.
    private(set) var registry = MapAnnotationRegistry()

    /// For PlayaDB annotations, the host can provide routing for callout actions.
    public var onPlayaInfoTapped: ((AnyDataObjectID) -> Void)?
    
    @objc public init(mapView: MLNMapView,
                      dataSource: AnnotationDataSource? = nil) {
        self.mapView = mapView
        self.dataSource = dataSource
        super.init()
        self.mapView.delegate = self
        installStyleLabelTapRecognizer()
        // Which camps the style layer already names decides which pins draw their own name,
        // so start reading the geojson now and re-apply the verdict when it lands. Until
        // then pins assume the layer has them, which is true of all but a handful of camps.
        CampStyleLabelIndex.shared.load { [weak self] in
            self?.updatePinLabelVisibility()
        }
    }

    // MARK: - Annotation eligibility

    /// Whether this adapter is willing to put `annotation` on its map.
    ///
    /// Base adapters show everything they are handed: a detail map, or a list's "show on
    /// map", is an *explicit* selection, and the one pin the user asked for must never be
    /// filtered out from under them. `UserMapViewAdapter` — the only adapter fed by a
    /// browse-everything query — overrides this to drop camp pins the style layer already
    /// labels. Declared here rather than in an extension so it can be overridden at all.
    func shouldDisplay(_ annotation: MLNAnnotation) -> Bool { true }

    // MARK: - Public API

    @objc public func reloadAnnotations() {
        // `shouldDisplay` is applied here rather than inside `addAnnotations` so that
        // `self.annotations` tracks exactly what the data source wanted on the map.
        let incoming = (dataSource?.allAnnotations() ?? []).filter { shouldDisplay($0) }
        willReplaceDataSourceAnnotations(with: incoming)
        // Only remove annotations that came from the data source. Removal is
        // identity-checked (see `MapAnnotationRegistry.remove`), so an instance that was
        // de-duplicated away at add time can't deregister the key of the pin that really
        // is on the map.
        removeAnnotations(self.annotations)
        self.annotations = incoming
        addAnnotations(incoming)
    }

    /// Hook for subclasses, called with the pin set that is about to replace the current
    /// one, before anything is added or removed. `UserMapViewAdapter` uses it to hand a
    /// pin it placed itself over to the database's copy of that same pin.
    func willReplaceDataSourceAnnotations(with annotations: [MLNAnnotation]) {}

    @objc public func removeAnnotations(_ annotations: [MLNAnnotation]) {
        let removed = registry.remove(annotations)
        removed.forEach { annotation in
            // Clean up overlap tracking for offsettable annotations
            if let data = annotation as? any OffsettableAnnotation {
                let originalCoordinate = data.originalCoordinate
                var overlapping = overlappingAnnotations[.init(originalCoordinate)] ?? []
                overlapping = overlapping.filter { $0.stableID != data.stableID }
                overlappingAnnotations[.init(originalCoordinate)] = overlapping
            }
        }
        mapView.removeAnnotations(removed)
    }

    /// Adds annotations in a way that avoid overlap and de-duplicates
    @objc public func addAnnotations(_ annotations: [MLNAnnotation]) {
        let newAnnotations = registry.add(annotations)

        // Handle overlap offset for annotations that support it.
        for case let data as any OffsettableAnnotation in newAnnotations {
            let originalCoordinate = data.originalCoordinate
            var overlapping = overlappingAnnotations[.init(originalCoordinate)] ?? []
            overlapping.append(data)

            // Sort by stable ID for consistent ordering
            overlapping.sort { $0.stableID < $1.stableID }
            overlappingAnnotations[.init(originalCoordinate)] = overlapping

            // Re-offset ALL annotations in this group if there's overlap
            if overlapping.count > 1 {
                for (index, overlappingAnnotation) in overlapping.enumerated() {
                    let percentage = Double(index) / Double(overlapping.count) + 0.18
                    overlappingAnnotation.coordinate = originalCoordinate.offset(by: .offset(radius: 20, percentage: percentage))
                }
            }
        }

        mapView.addAnnotations(newAnnotations)
    }
}


// MARK: - MLNMapViewDelegate

extension MapViewAdapter: MLNMapViewDelegate {
    
    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        // Call the style loaded callback if set
        onStyleLoaded?(style)
        
        let imageMap = [
            "Airport": "airport",
            "Rampart": "EmergencyClinic",
            "Center Camp Plaza": "centerCamp",
            "center": "center",
            "Burner Express Bus Depot": "bus",
            "Station 3": "firstAid",
            "Station 9": "firstAid",
            "ESD Station 3": "firstAid",
            "ESD Station 9": "firstAid",
            "Playa Info": "info",
            "Ranger Station Berlin": "ranger",
            "Ranger Station Tokyo": "ranger",
            "Ranger HQ": "ranger",
            "Ice Nine Arctica": "ice",
            "Arctica Center Camp": "ice",
            "Ice Cubed Arctica 3": "ice",
            "Arctica Outpost": "ice",
            "Recycle Camp": "recycle",
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
            labelAnnotationView.campUID = campUID(for: annotation)
            labelViews.append(labelAnnotationView)
            annotationView = labelAnnotationView
        } else if let data = annotation as? PlayaObjectAnnotation {
            let labelAnnotationView: LabelAnnotationView
            if let view = mapView.dequeueReusableAnnotationView(withIdentifier: LabelAnnotationView.reuseIdentifier) as? LabelAnnotationView {
                labelAnnotationView = view
            } else {
                labelAnnotationView = LabelAnnotationView(reuseIdentifier: LabelAnnotationView.reuseIdentifier)
            }
            labelAnnotationView.imageView.image = image
            labelAnnotationView.label.text = data.title
            labelAnnotationView.campUID = campUID(for: annotation)
            labelViews.append(labelAnnotationView)
            annotationView = labelAnnotationView
        }

        if let annotationView = annotationView {
            let identifier = ObjectIdentifier(annotation)
            annotationViews[identifier] = annotationView
        }

        // Pins arrive between region changes (the region path fetches asynchronously, and
        // the observation path fires on database writes), so a fresh view has to be told
        // the current rule rather than waiting for the next pan to be corrected.
        updatePinLabelVisibility()

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
        guard annotation is DataObjectAnnotation || annotation is PlayaObjectAnnotation else {
            return nil
        }
        let infoButton = UIButton(type: .infoLight)
        infoButton.tag = ButtonTag.info.rawValue
        return infoButton
    }
    
    public func mapView(_ mapView: MLNMapView, annotation: MLNAnnotation, calloutAccessoryControlTapped control: UIControl) {
        guard let tag = ButtonTag(rawValue: control.tag) else {
                return
        }
        switch tag {
        case .delete, .edit:
            break
        case .info:
            if let data = annotation as? DataObjectAnnotation, let parentVC = parent {
                Task { @MainActor in
                    let playaDB = BRCAppDelegate.shared.dependencies.playaDB
                    let vc = await DetailViewControllerFactory.createDetailViewController(for: data.object, playaDB: playaDB)
                    parentVC.navigationController?.pushViewController(vc, animated: true)
                }
                return
            }

            if let data = annotation as? PlayaObjectAnnotation {
                onPlayaInfoTapped?(data.id)
                return
            }
        case .share:
            if let data = annotation as? DataObjectAnnotation, let parentVC = parent {
                let shareViewController = ShareQRCodeHostingController(dataObject: data.object)
                parentVC.present(shareViewController, animated: true, completion: nil)
            }
        case .more:
            // More action not used for regular data objects
            break
        }
    }
    
    public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        updatePinLabelVisibility()
    }
}

// MARK: - Pin labels

extension MapViewAdapter {

    /// Applies the current zoom's rules to every live `LabelAnnotationView`.
    ///
    /// Beyond the plain "too far out to read" cut, camp pins have a second rule: the
    /// `camp-labels-big` style layer draws camp names at each camp's polygon centroid, which
    /// is the exact coordinate the camp's pin sits on. The layer wins wherever it has a
    /// label — the pin is then a bare glyph at any zoom — and camps it has no feature for
    /// keep labelling themselves. See `PinLabelVisibility`.
    ///
    /// Call after anything that can change that verdict — zoom, embargo, the Map Filter — and
    /// once the label index finishes loading.
    func updatePinLabelVisibility() {
        let zoomLevel = mapView.zoomLevel
        let hiddenAtOrBelowZoom = pinLabelHiddenAtOrBelowZoom
        let styleDrawsCampNames = CampLayerVisibility.current(zoomLevel: zoomLevel).campNamesDrawnByStyleLayer
        let styleLabeledCampUIDs = CampStyleLabelIndex.shared.labeledCampUIDs
        for view in labelViews {
            view.label.isHidden = PinLabelVisibility.labelIsHidden(
                zoomLevel: zoomLevel,
                hiddenAtOrBelowZoom: hiddenAtOrBelowZoom,
                campUID: view.campUID,
                styleDrawsCampNames: styleDrawsCampNames,
                styleLabeledCampUIDs: styleLabeledCampUIDs
            )
        }
    }

    /// The camp uid behind this annotation, or nil when it isn't a camp. Both object graphs
    /// key camps by the API's `uid`, which is what `camp_labels.geojson` carries.
    func campUID(for annotation: MLNAnnotation) -> String? {
        if let playa = annotation as? PlayaObjectAnnotation {
            return playa.id.objectType == .camp ? playa.id.uid : nil
        }
        if let data = annotation as? DataObjectAnnotation {
            return (data.object as? BRCCampObject)?.uniqueID
        }
        return nil
    }
}

// MARK: - Tapping a style label

extension MapViewAdapter {

    /// Half-width of the square queried around a tap, in points. 22 makes a 44×44 target —
    /// the HIG minimum — around text that is only 9–14pt tall at the zooms it is drawn at.
    private static let styleLabelTapRadius: CGFloat = 22

    /// Identifies our recognizer on a map view. `DetailMapViewRepresentable` builds a fresh
    /// adapter around the *same* `MLNMapView` on every SwiftUI update, so without this the
    /// recognizers would stack up one per update.
    private static let styleLabelTapRecognizerName = "iBurn.campStyleLabelTap"

    /// Makes the camp names drawn by `camp-labels-big` behave like the pins they replaced:
    /// tap one, get that camp's detail screen.
    ///
    /// The recognizer is deliberately last in line. `MLNMapView` refuses its own single tap
    /// when the tap hits no annotation *and* nothing is selected
    /// (`-gestureRecognizerShouldBegin:`), which is exactly the case this handler wants, so
    /// requiring every built-in tap recognizer to fail first — the pattern `MLNMapView.h`
    /// documents — leaves annotation selection, callout dismissal and double-tap zoom
    /// untouched and only fires on taps the map itself declined.
    func installStyleLabelTapRecognizer() {
        let existing = mapView.gestureRecognizers ?? []
        guard !existing.contains(where: { $0.name == Self.styleLabelTapRecognizerName }) else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleStyleLabelTap(_:)))
        tap.name = Self.styleLabelTapRecognizerName
        for recognizer in existing where recognizer is UITapGestureRecognizer {
            tap.require(toFail: recognizer)
        }
        mapView.addGestureRecognizer(tap)
    }

    @objc private func handleStyleLabelTap(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended,
              let uid = campUID(forStyleLabelAt: sender.location(in: mapView)) else { return }
        showCampDetail(uid: uid)
    }

    /// The uid of the camp whose style label sits under `point`, or nil for empty map.
    ///
    /// The zoom/settings/embargo verdict is re-checked rather than trusted from the render:
    /// `visibleFeatures` reads the tiles MapLibre has already built, and a tile built while
    /// the layer was visible outlives the layer being hidden. Without this check a tap on
    /// stale text could open a camp whose location is still embargoed.
    func campUID(forStyleLabelAt point: CGPoint) -> String? {
        guard CampLayerVisibility.current(zoomLevel: mapView.zoomLevel).campNamesDrawnByStyleLayer,
              mapView.style?.layer(withIdentifier: CampLayerVisibility.labelsLayerIdentifier) != nil else {
            return nil
        }
        let radius = Self.styleLabelTapRadius
        let rect = CGRect(x: point.x - radius,
                          y: point.y - radius,
                          width: radius * 2,
                          height: radius * 2)
        let features = mapView.visibleFeatures(
            in: rect,
            styleLayerIdentifiers: [CampLayerVisibility.labelsLayerIdentifier]
        )
        return features.lazy.compactMap { $0.attribute(forKey: "uid") as? String }.first
    }

    /// Routes through the host's `onPlayaInfoTapped` so navigation stays owned by the screen,
    /// exactly as the callout's info button does; the direct push is the fallback for hosts
    /// (detail maps) that never wired one.
    private func showCampDetail(uid: String) {
        let id = AnyDataObjectID(objectType: .camp, uid: uid)
        if let onPlayaInfoTapped {
            onPlayaInfoTapped(id)
            return
        }
        guard let parentVC = parent else { return }
        Task { @MainActor in
            let playaDB = BRCAppDelegate.shared.dependencies.playaDB
            guard let camp = try? await playaDB.fetchCamp(uid: uid) else { return }
            let vc = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
            parentVC.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - Overlap Offsetting

private protocol OffsettableAnnotation: AnyObject {
    var coordinate: CLLocationCoordinate2D { get set }
    var originalCoordinate: CLLocationCoordinate2D { get }
    var stableID: String { get }
}

extension DataObjectAnnotation: OffsettableAnnotation {
    fileprivate var stableID: String { object.uniqueID }
}

extension PlayaObjectAnnotation: OffsettableAnnotation {
    fileprivate var stableID: String { "\(id.objectType.rawValue):\(id.uid)" }
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
