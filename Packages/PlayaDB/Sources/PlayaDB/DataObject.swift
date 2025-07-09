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

/// Types of data objects supported by the system
public enum DataObjectType: String, CaseIterable, Codable {
    case art
    case camp
    case event
    
    /// Display name for the object type
    public var displayName: String {
        switch self {
        case .art: return "Art"
        case .camp: return "Camp"
        case .event: return "Event"
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