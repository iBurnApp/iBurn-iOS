//
//  PlayaObjectAnnotation.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import CoreLocation
import MapLibre
import PlayaDB
import UIKit

/// The fully-inflated PlayaDB object an annotation was built from, when one was available.
///
/// Screens driven purely by map annotations (e.g. the map's "Visible Pins" list) can render
/// rich rows and push detail views straight from this payload, with no extra database round
/// trips and no ambiguity about *which* occurrence put an event pin on the map.
enum PlayaAnnotationObject {
    case art(ArtObject)
    case camp(CampObject)
    case eventOccurrence(EventObjectOccurrence)
    /// Fallback for annotations built from a bare `EventObject` (no occurrence resolved).
    case event(EventObject)
}

/// Map annotation for PlayaDB objects (no YapDatabase / BRCDataObject involvement).
final class PlayaObjectAnnotation: NSObject, MLNAnnotation, ImageAnnotation {
    let id: AnyDataObjectID

    /// The object this annotation was built from, when it came from a convenience initializer.
    let object: PlayaAnnotationObject?

    @objc dynamic var coordinate: CLLocationCoordinate2D
    let originalCoordinate: CLLocationCoordinate2D
    private let titleText: String
    private let subtitleText: String?

    init(id: AnyDataObjectID,
         coordinate: CLLocationCoordinate2D,
         title: String,
         subtitle: String?,
         object: PlayaAnnotationObject? = nil) {
        self.id = id
        self.object = object
        self.coordinate = coordinate
        self.originalCoordinate = coordinate
        self.titleText = title
        self.subtitleText = subtitle
        super.init()
    }

    convenience init?(art: ArtObject) {
        guard let location = art.location, CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        self.init(
            id: art.anyID,
            coordinate: location.coordinate,
            title: art.name,
            subtitle: art.locationString ?? art.timeBasedAddress,
            object: .art(art)
        )
    }

    convenience init?(camp: CampObject) {
        guard let location = camp.location, CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        self.init(
            id: camp.anyID,
            coordinate: location.coordinate,
            title: camp.name,
            subtitle: camp.locationString ?? camp.intersection ?? camp.frontage,
            object: .camp(camp)
        )
    }

    convenience init?(event: EventObjectOccurrence) {
        guard let location = event.location, CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        self.init(
            id: event.event.anyID,
            coordinate: location.coordinate,
            title: event.name,
            subtitle: event.startAndEndString,
            object: .eventOccurrence(event)
        )
    }

    convenience init?(event: EventObject) {
        guard let location = event.location, CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        self.init(
            id: event.anyID,
            coordinate: location.coordinate,
            title: event.name,
            subtitle: event.primaryLocationString,
            object: .event(event)
        )
    }

    convenience init?(mutantVehicle: MutantVehicleObject) {
        // Mutant vehicles are mobile and have no fixed location
        return nil
    }

    var title: String? { titleText }
    var subtitle: String? { subtitleText }

    var markerImage: UIImage? {
        switch id.objectType {
        case .art:
            return UIImage(named: "BRCBluePin")
        case .camp:
            return UIImage(named: "BRCPurplePin")
        case .event:
            return UIImage(named: "BRCPurplePin")
        case .mutantVehicle:
            return UIImage(named: "BRCGreenPin")
        }
    }
}
