import Foundation
import CoreLocation

/// Protocol for all data objects in the PlayaDB system
public protocol DataObject {
    /// Unique identifier for this object
    var uid: String { get }
    
    /// Display name for this object
    var name: String { get }
    
    /// Year this object is associated with
    var year: Int { get }
    
    /// Description of this object
    var description: String? { get }
    
    /// Geographic location of this object
    var location: CLLocation? { get }
    
    /// Whether this object has location information
    var hasLocation: Bool { get }
    
    /// Type of this data object
    var objectType: DataObjectType { get }
}

/// Unambiguous spelling of `DataObject` for importers that shadow the name.
///
/// The iBurn app declares its own legacy `DataObject` class, and the usual escape hatch —
/// qualifying as `PlayaDB.DataObject` — does not work here because `PlayaDB` is both the
/// module name and a protocol inside it, so the qualified form resolves against the
/// protocol and fails. Client code that needs to name the existential uses
/// `any PlayaDataObject`.
public typealias PlayaDataObject = DataObject

/// Types of data objects supported by the system
public enum DataObjectType: String, CaseIterable, Codable {
    case art
    case camp
    case event
    case mutantVehicle

    /// Display name for the object type
    public var displayName: String {
        switch self {
        case .art: return "Art"
        case .camp: return "Camp"
        case .event: return "Event"
        case .mutantVehicle: return "Mutant Vehicles"
        }
    }
}

/// Helper extensions for DataObject
public extension DataObject {
    /// Whether this object has a description
    var hasDescription: Bool {
        description != nil && !description!.isEmpty
    }
}

/// Data object that represents a physical place with a playa address.
public protocol PlaceDataObject: DataObject {
    var address: String? { get }
}