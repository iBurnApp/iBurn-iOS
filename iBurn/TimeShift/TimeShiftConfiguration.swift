//
//  TimeShiftConfiguration.swift
//  iBurn
//
//  Created by Claude Code on 8/3/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

/// Configuration for time-shift functionality, allowing users to view data as if they were at a different time and/or location
public struct TimeShiftConfiguration {
    public let date: Date
    public let location: CLLocation?
    public let isActive: Bool
    
    /// Creates a time shift configuration
    /// - Parameters:
    ///   - date: The date/time to shift to
    ///   - location: Optional location override
    ///   - isActive: Whether the time shift is currently active
    public init(date: Date, location: CLLocation? = nil, isActive: Bool) {
        self.date = date
        self.location = location
        self.isActive = isActive
    }
}