//
//  DisplayableObject.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// Protocol for objects that can be displayed in list views
/// This protocol extracts the minimal set of properties needed by ObjectRowView
/// to avoid naming conflicts with legacy DataObject types.
protocol DisplayableObject {
    /// Display name for this object
    var name: String { get }

    /// Description of this object
    var description: String? { get }

    /// Unique identifier
    var uid: String { get }
}

// Extend PlayaDB types to conform to DisplayableObject
import PlayaDB

extension ArtObject: DisplayableObject {}
// Future: extension CampObject: DisplayableObject {}
// Future: extension EventObject: DisplayableObject {}
