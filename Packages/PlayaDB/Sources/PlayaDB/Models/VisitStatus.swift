import Foundation

/// Whether the user has visited (or wants to visit) an object.
/// Raw values match the iOS app's Yap-side `BRCVisitStatus` enum and the
/// `object_metadata.visit_status` column.
public enum VisitStatus: Int, Codable, Equatable, Sendable, CaseIterable {
    case unvisited = 0
    case visited = 1
    case wantToVisit = 2
}
