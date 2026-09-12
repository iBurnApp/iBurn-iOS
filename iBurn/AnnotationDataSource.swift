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
/// This is where a map can ask "may this pin be drawn?" without knowing who built it.
/// Annotations that carry no placement data (user map points, the Man, ordinary
/// `MLNAnnotation`s) are always allowed.
///
/// These are the *single-object* tiers: a pin already selected by the user. The bulk map
/// paths pick their own, stricter, tier — see `MapEmbargo`.
enum AnnotationEmbargo {
    static func allows(_ annotation: MLNAnnotation) -> Bool {
        if let playa = annotation as? PlayaObjectAnnotation {
            return allows(playa)
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

    /// An event at an art piece leaks the art's position, everything else leaks its host
    /// camp's.
    private static func allowsEvent(locatedAtArt: Bool) -> Bool {
        locatedAtArt ? MapEmbargo.allowsArtLocation() : MapEmbargo.allowsSingleCampLocation()
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

/// Protocol for iBurn-specific annotations
public protocol ImageAnnotation: MLNAnnotation {
    var markerImage: UIImage? { get }
}

extension BRCMapPoint: ImageAnnotation {
    public var markerImage: UIImage? {
        return image
    }
}
