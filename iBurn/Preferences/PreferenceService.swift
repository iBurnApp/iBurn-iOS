//
//  PreferenceService.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import Combine

/// Protocol defining the interface for preference storage and observation
protocol PreferenceService {
    /// Gets the current value for a preference
    /// - Parameter preference: The preference definition
    /// - Returns: The current value or default if not set
    func getValue<T>(_ preference: Preference<T>) -> T
    
    /// Sets a new value for a preference
    /// - Parameters:
    ///   - value: The new value to set
    ///   - preference: The preference definition
    func setValue<T>(_ value: T, for preference: Preference<T>)
    
    /// Creates a publisher that emits the current value and any future changes
    /// - Parameter preference: The preference to observe
    /// - Returns: A publisher that emits preference values
    func publisher<T>(for preference: Preference<T>) -> AnyPublisher<T, Never>
    
    /// Resets a preference to its default value
    /// - Parameter preference: The preference to reset
    func reset<T>(_ preference: Preference<T>)
    
    /// Checks if a preference has been explicitly set (vs using default)
    /// - Parameter preference: The preference to check
    /// - Returns: True if the preference has been set
    func hasValue<T>(_ preference: Preference<T>) -> Bool
}