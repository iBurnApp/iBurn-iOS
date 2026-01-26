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

/// Map annotation for PlayaDB objects (no YapDatabase / BRCDataObject involvement).
final class PlayaObjectAnnotation: NSObject, MLNAnnotation, ImageAnnotation {
    let id: AnyDataObjectID

    @objc dynamic var coordinate: CLLocationCoordinate2D
    let originalCoordinate: CLLocationCoordinate2D
    private let titleText: String
    private let subtitleText: String?

    init(id: AnyDataObjectID, coordinate: CLLocationCoordinate2D, title: String, subtitle: String?) {
        self.id = id
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
            subtitle: art.locationString ?? art.timeBasedAddress
        )
    }

    convenience init?(camp: CampObject) {
        guard let location = camp.location, CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        self.init(
            id: camp.anyID,
            coordinate: location.coordinate,
            title: camp.name,
            subtitle: camp.locationString ?? camp.intersection ?? camp.frontage
        )
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
        }
    }
}
