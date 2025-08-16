//
//  BRCVisitStatus.swift
//  iBurn
//
//  Created by Chris Ballinger on 2025-08-16.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import SwiftUI

/// Represents the visit status of a data object (art, camp, event)
@objc public enum BRCVisitStatus: Int, CaseIterable {
    case unvisited = 0
    case visited = 1
    case wantToVisit = 2
    
    /// Display string for the status
    public var displayString: String {
        switch self {
        case .unvisited:
            return "Not Visited"
        case .visited:
            return "Visited"
        case .wantToVisit:
            return "Want to Visit"
        }
    }
    
    /// Short display string for compact UI
    public var shortDisplayString: String {
        switch self {
        case .unvisited:
            return "Not Visited"
        case .visited:
            return "Visited"
        case .wantToVisit:
            return "Want to Visit"
        }
    }
    
    /// SF Symbol icon name for the status
    public var iconName: String {
        switch self {
        case .unvisited:
            return "circle"
        case .visited:
            return "checkmark.circle.fill"
        case .wantToVisit:
            return "star.fill"
        }
    }
    
    /// Color associated with the status
    public var color: Color {
        switch self {
        case .unvisited:
            return .gray
        case .visited:
            return .green
        case .wantToVisit:
            return .yellow
        }
    }
    
    /// UIColor for UIKit compatibility
    public var uiColor: UIColor {
        switch self {
        case .unvisited:
            return .systemGray
        case .visited:
            return .systemGreen
        case .wantToVisit:
            return .systemYellow
        }
    }
}

// MARK: - Objective-C Compatibility

extension BRCVisitStatus {
    /// String value for Mantle serialization
    public var stringValue: String {
        switch self {
        case .unvisited:
            return "unvisited"
        case .visited:
            return "visited"
        case .wantToVisit:
            return "wantToVisit"
        }
    }
    
    /// Initialize from string value (for Mantle deserialization)
    public init?(stringValue: String) {
        switch stringValue {
        case "unvisited":
            self = .unvisited
        case "visited":
            self = .visited
        case "wantToVisit":
            self = .wantToVisit
        default:
            return nil
        }
    }
}