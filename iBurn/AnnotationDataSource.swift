//
//  AnnotationDataSource.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc public protocol AnnotationDataSource: NSObjectProtocol {
    func allAnnotations() -> [MLNAnnotation]
}

public class StaticAnnotationDataSource: NSObject {
    public let annotations: [MLNAnnotation]
    
    @objc public init(annotations: [MLNAnnotation]) {
        self.annotations = annotations
    }
    
    @objc public convenience init(annotation: MLNAnnotation) {
        self.init(annotations: [annotation])
    }
}

extension StaticAnnotationDataSource: AnnotationDataSource {
    /// Filtered on read, not at init: this data source is built once and handed to a map that
    /// may outlive an embargo *change* in either direction, and the annotations it holds are
    /// the pins a detail screen or a list's "Show on Map" asked for. Every caller already
    /// gates its own fetch at or above these tiers, so this subtracts nothing legitimate —
    /// it is the last line before a coordinate reaches a map view.
    public func allAnnotations() -> [MLNAnnotation] {
        return annotations.filter { AnnotationEmbargo.allows($0) }
    }
}

/// The embargo tier an already-built annotation answers to.
///
/// Annotation objects are the one place both object graphs meet — `PlayaObjectAnnotation`
/// from PlayaDB, `DataObjectAnnotation` from Yap — so this is where a map can ask "may this
/// pin be drawn?" without knowing which side built it. Annotations that carry no placement
/// data (user map points, the Man, ordinary `MLNAnnotation`s) are always allowed.
///
/// These are the *single-object* tiers: a pin already selected by the user. The bulk map
/// paths pick their own, stricter, tier — see `MapEmbargo`.
enum AnnotationEmbargo {
    static func allows(_ annotation: MLNAnnotation) -> Bool {
        if let playa = annotation as? PlayaObjectAnnotation {
            return allows(playa)
        }
        if let legacy = annotation as? DataObjectAnnotation {
            return BRCEmbargo.canShowLocation(for: legacy.object)
        }
        return true
    }

    private static func allows(_ annotation: PlayaObjectAnnotation) -> Bool {
        switch annotation.object {
        case .art:
            return MapEmbargo.allowsArtLocation()
        case .camp:
            return MapEmbargo.allowsSingleCampLocation()
        case .eventOccurrence(let occurrence):
            return allowsEvent(locatedAtArt: occurrence.event.locatedAtArt?.isEmpty == false)
        case .event(let event):
            return allowsEvent(locatedAtArt: event.locatedAtArt?.isEmpty == false)
        case .none:
            // Built from raw coordinates with no object behind it; fall back to the type in
            // the id, and read an event with no payload as art-tier — the stricter guess.
            switch annotation.id.objectType {
            case .art: return MapEmbargo.allowsArtLocation()
            case .camp: return MapEmbargo.allowsSingleCampLocation()
            case .event: return MapEmbargo.allowsArtLocation()
            case .mutantVehicle: return true
            }
        }
    }

    /// Same split as `BRCEmbargo.canShowLocation(for:)`: an event at an art piece leaks the
    /// art's position, everything else leaks its host camp's.
    private static func allowsEvent(locatedAtArt: Bool) -> Bool {
        locatedAtArt ? MapEmbargo.allowsArtLocation() : MapEmbargo.allowsSingleCampLocation()
    }
}

public class YapViewAnnotationDataSource: NSObject {
    private let viewHandler: YapViewHandler
    public var showAllEvents: Bool = false
    
    init(viewHandler: YapViewHandler, showAllEvents: Bool = false) {
        self.viewHandler = viewHandler
        self.showAllEvents = showAllEvents
    }
}

public class YapCollectionAnnotationDataSource: NSObject {
    public let collection: String
    public var allowedClass = NSObject.self
    private let uiConnection: YapDatabaseConnection
    
    init(collection: String,
         uiConnection: YapDatabaseConnection = BRCDatabaseManager.shared.uiConnection) {
        self.uiConnection = uiConnection
        self.collection = collection
    }
}

public class MapRegionDataSource: NSObject, AnnotationDataSource {
    public var annotations: [MLNAnnotation] = []
    
    public func allAnnotations() -> [MLNAnnotation] {
        return annotations
    }
}

public class AggregateAnnotationDataSource: NSObject, AnnotationDataSource {
    let dataSources: [AnnotationDataSource]
    
    init(dataSources: [AnnotationDataSource]) {
        self.dataSources = dataSources
    }
    
    public func allAnnotations() -> [MLNAnnotation] {
        return dataSources.map { $0.allAnnotations() }.flatMap { $0 }
    }
}

extension YapViewAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MLNAnnotation] {
        var annotations: [MLNAnnotation] = []
        for section in 0..<viewHandler.numberOfSections {
            for row in 0..<viewHandler.numberOfItemsInSection(section) {
                let index = IndexPath(row: row, section: section)
                var annotation: DataObjectAnnotation?
                if let dataObject: BRCDataObject = viewHandler.object(at: index, readBlock: { (dataObject, t) in
                    annotation = dataObject.annotation(transaction: t)
                }),
                BRCEmbargo.canShowLocation(for: dataObject),
                    let annotation = annotation {
                    if let event = dataObject as? BRCEventObject {
                        if showAllEvents || event.shouldShowOnMap() {
                            annotations.append(annotation)
                        }
                    } else {
                        annotations.append(annotation)
                    }
                }
            }
        }
        return annotations
    }
}

extension YapCollectionAnnotationDataSource: AnnotationDataSource {
    public func allAnnotations() -> [MLNAnnotation] {
        var annotations: [MLNAnnotation] = []
        uiConnection.read({ transaction in
            transaction.iterateKeysAndObjects(inCollection: self.collection) { (key, nsObject: NSObject, stop) in
                guard nsObject.isKind(of: self.allowedClass) else {
                        return
                }
                if let annotation = nsObject as? MLNAnnotation {
                    annotations.append(annotation)
                }
            }
        })
        return annotations
    }
}

public extension BRCDataObject {
    func annotation(transaction: YapDatabaseReadTransaction) -> DataObjectAnnotation? {
        let metadata = self.metadata(with: transaction)
        return annotation(metadata: metadata)
    }
    
    /// The one annotation constructor that used to hand out a coordinate with no embargo
    /// check at all — `MapDetailViewController`'s pin comes through here. The tier is the
    /// single-object one (a camp unlocks in the week before gates), matching what the detail
    /// screen's address line is already allowed to say.
    func annotation(metadata: BRCObjectMetadata) -> DataObjectAnnotation? {
        guard BRCEmbargo.canShowLocation(for: self) else { return nil }
        return DataObjectAnnotation(object: self, metadata: metadata)
    }
}

/// This wrapper is required because MLNAnnotation has
/// different optionality requirements than BRCDataObject for `title`
public final class DataObjectAnnotation: NSObject {
    /// this value may be slightly changed to prevent data overlap
    public var coordinate: CLLocationCoordinate2D
    public let originalCoordinate: CLLocationCoordinate2D

    let object: BRCDataObject
    let metadata: BRCObjectMetadata
    @objc public init?(object: BRCDataObject, metadata: BRCObjectMetadata) {
        guard let location = object.location,
            CLLocationCoordinate2DIsValid(location.coordinate) else {
            return nil
        }
        self.coordinate = location.coordinate
        self.originalCoordinate = location.coordinate
        self.object = object
        self.metadata = metadata
    }
}

extension DataObjectAnnotation: MLNAnnotation {
    
    public var title: String? {
        var title = object.title
        if let event = object as? BRCEventObject {
            if let camp = event.campName {
                title += " @ \(camp)"
            } else if let art = event.artName {
                title += " @ \(art)"
            }
        }
        return title
    }
    
    public var subtitle: String? {
        var subtitle = ""
        if let location = object.playaLocation {
            subtitle += location
        }
        if let event = object as? BRCEventObject {
            if event.isHappeningRightNow(.present) {
                subtitle += " • \(event.startAndEndString)"
            } else {
                subtitle += " • \(event.startWeekdayString) \(event.startAndEndString)"
            }
        }
        if let userNotes = metadata.userNotes, !userNotes.isEmpty {
            subtitle += " - \(userNotes)"
        }
        return subtitle
    }
}


/// Protocol for iBurn-specific annotations
public protocol ImageAnnotation: MLNAnnotation {
    var markerImage: UIImage? { get }
}

extension DataObjectAnnotation: ImageAnnotation {
    public var markerImage: UIImage? {
        return object.brc_markerImage
    }
}

extension BRCMapPoint: ImageAnnotation {
    public var markerImage: UIImage? {
        return image
    }
}
