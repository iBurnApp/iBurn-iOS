import Foundation
import PlayaAPI

/// A single identifier type that can represent any PlayaDB object identifier while
/// preserving the underlying strongly-typed PlayaAPI IDs.
///
/// Useful for heterogeneous collections (e.g. map annotations, deep links, routing).
public enum AnyDataObjectID: Hashable, Sendable, Codable {
    case art(ArtID)
    case camp(CampID)
    case event(EventID)
    case mutantVehicle(MutantVehicleID)

    public var objectType: DataObjectType {
        switch self {
        case .art: return .art
        case .camp: return .camp
        case .event: return .event
        case .mutantVehicle: return .mutantVehicle
        }
    }

    /// The raw uid string used by PlayaDB tables.
    public var uid: String {
        switch self {
        case .art(let id): return id.value
        case .camp(let id): return id.value
        case .event(let id): return id.value
        case .mutantVehicle(let id): return id.value
        }
    }

    public init(objectType: DataObjectType, uid: String) {
        switch objectType {
        case .art:
            self = .art(ArtID(uid))
        case .camp:
            self = .camp(CampID(uid))
        case .event:
            self = .event(EventID(uid))
        case .mutantVehicle:
            self = .mutantVehicle(MutantVehicleID(uid))
        }
    }
}

public extension DataObject {
    /// Converts a concrete PlayaDB model into a single sum-type identifier.
    var anyID: AnyDataObjectID {
        AnyDataObjectID(objectType: objectType, uid: uid)
    }
}

