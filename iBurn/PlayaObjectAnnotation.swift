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

    /// True when this pin came from a favourites query rather than the browse-everything one.
    ///
    /// Set by whoever built it, because "is a favourite" is a property of the *stream*, not of
    /// the object: `PlayaDBAnnotationDataSource` runs a separate `onlyFavorites` observation
    /// and both can emit the same camp. `CampPinVisibility` reads it to keep a starred camp's
    /// pin on the map when the style layer's label would otherwise replace it.
    var isFavorite: Bool = false

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
            subtitle: Self.calloutSubtitle(for: event),
            object: .eventOccurrence(event)
        )
    }

    /// A pin's callout has to say *which day* — the map shows favourites weeks ahead of the
    /// burn, and "9:00 AM - 11:00 AM" alone is unreadable when the answer could be any of
    /// eight days. Dropped only while the occurrence is actually running, when the day is
    /// implied and the times are all that's left to say. Same rule as the legacy
    /// `DataObjectAnnotation.subtitle`.
    static func calloutSubtitle(for event: EventObjectOccurrence,
                                now: Date = .present) -> String {
        if event.isHappeningRightNow(now) {
            return event.startAndEndString
        }
        return "\(event.startWeekdayString) \(event.startAndEndString)"
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

    /// Flags this annotation as coming from a favourites query and returns it, so the
    /// `onlyFavorites` observations can stay one-liners.
    func markedFavorite() -> PlayaObjectAnnotation {
        isFavorite = true
        return self
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
