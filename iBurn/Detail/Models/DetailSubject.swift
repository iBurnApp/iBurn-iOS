//
//  DetailSubject.swift
//  iBurn
//
//  Created by Codex on 1/26/26.
//

import CoreLocation
import Foundation
import PlayaDB

/// Wrapper for the object being displayed in the SwiftUI detail screen.
///
/// During the PlayaDB migration, we need to support both:
/// - legacy YapDB-backed `BRCDataObject` instances
/// - new GRDB/PlayaDB-backed objects (`ArtObject`, `CampObject`, `EventObject`)
enum DetailSubject {
    case legacy(BRCDataObject)
    case art(ArtObject)
    case camp(CampObject)
    case event(EventObject)
}

extension DetailSubject {
    var title: String {
        switch self {
        case .legacy(let obj):
            return obj.title
        case .art(let art):
            return art.name
        case .camp(let camp):
            return camp.name
        case .event(let event):
            return event.name
        }
    }

    var uid: String {
        switch self {
        case .legacy(let obj):
            return obj.uniqueID
        case .art(let art):
            return art.uid
        case .camp(let camp):
            return camp.uid
        case .event(let event):
            return event.uid
        }
    }

    var location: CLLocation? {
        switch self {
        case .legacy(let obj):
            return obj.location
        case .art(let art):
            return art.location
        case .camp(let camp):
            return camp.location
        case .event(let event):
            return event.location
        }
    }

    /// Text used for the "OFFICIAL LOCATION" section.
    ///
    /// Note: For PlayaDB objects this should respect embargo rules at the call site.
    var locationString: String? {
        switch self {
        case .legacy(let obj):
            return obj.playaLocation
        case .art(let art):
            return art.locationString ?? art.timeBasedAddress
        case .camp(let camp):
            return camp.locationString ?? camp.intersection
        case .event(let event):
            return event.locationString
        }
    }
}

