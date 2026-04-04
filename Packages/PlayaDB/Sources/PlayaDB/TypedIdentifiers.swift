import Foundation
import PlayaAPI

// Convenience typed identifiers for PlayaDB models.
//
// PlayaDB stores `uid` as a String for database/GRDB ergonomics, but the app often
// wants strongly-typed IDs (from PlayaAPI) when routing/navigation crosses layers.

extension ArtObject: Identifiable {
    public var id: ArtID { ArtID(uid) }
}

extension CampObject: Identifiable {
    public var id: CampID { CampID(uid) }
}

extension EventObject: Identifiable {
    public var id: EventID { EventID(uid) }
}

extension MutantVehicleObject: Identifiable {
    public var id: MutantVehicleID { MutantVehicleID(uid) }
}
