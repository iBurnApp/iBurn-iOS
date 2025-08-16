//
//  DetailCellType.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - DetailCell Wrapper

/// Wrapper struct for unique identification in SwiftUI
struct DetailCell: Identifiable {
    let id = UUID()
    let type: DetailCellType
    
    init(_ type: DetailCellType) {
        self.type = type
    }
}

// MARK: - DetailCellType Enum

/// Enum representing different types of detail cells
enum DetailCellType {
    case image(UIImage, aspectRatio: CGFloat)
    case mapView(BRCDataObject, metadata: BRCObjectMetadata?)
    case text(String, style: DetailTextStyle)
    case email(String, label: String?)
    case url(URL, title: String)
    case coordinates(CLLocationCoordinate2D, label: String)
    case schedule(NSAttributedString)
    case relationship(BRCDataObject, type: RelationshipType)
    case eventRelationship([BRCEventObject], hostName: String)
    case nextHostEvent(BRCEventObject, hostName: String)
    case allHostEvents(count: Int, hostName: String)
    case playaAddress(String, tappable: Bool)
    case distance(CLLocationDistance)
    case audio(BRCArtObject, isPlaying: Bool)
    case userNotes(String)
    case date(Date, format: String)
    case landmark(String)
    case eventType(BRCEventType)
    case visitStatus(BRCVisitStatus)
}

// MARK: - Supporting Types

/// Text styling options for detail cells
enum DetailTextStyle {
    case body
    case caption
    case title
    case subtitle
    case headline
}

/// Types of relationships between data objects
enum RelationshipType {
    case hostedBy(String) // "Hosted by Camp Name"
    case presentedBy(String) // "Presented by Artist"
    case relatedCamp
    case relatedArt
    case relatedEvent
}

// MARK: - DetailAction Enum

/// Actions that can be triggered from detail cells
enum DetailAction {
    case openEmail(String)
    case openURL(URL)
    case showMap(BRCDataObject)
    case navigateToObject(BRCDataObject)
    case showEventsList([BRCEventObject], hostName: String)
    case showNextEvent(BRCEventObject)
    case shareCoordinates(CLLocationCoordinate2D)
    case playAudio(BRCArtObject)
    case pauseAudio
    case editNotes(current: String, completion: (String) -> Void)
    case showEventEditor(BRCEventObject)
    case share([Any])
    case showShareScreen(BRCDataObject)
}

// MARK: - Error Types

/// Errors that can occur in detail operations
enum DetailError: Error, LocalizedError {
    case updateFailed
    case permissionDenied
    case networkError
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .updateFailed:
            return "Failed to update data"
        case .permissionDenied:
            return "Permission denied"
        case .networkError:
            return "Network error"
        case .invalidData:
            return "Invalid data"
        }
    }
}