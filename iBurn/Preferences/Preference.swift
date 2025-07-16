//
//  Preference.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// A type-safe preference definition for UserDefaults storage
struct Preference<T> {
    /// The UserDefaults key for this preference
    let key: String
    
    /// The default value if no value has been set
    let defaultValue: T
    
    /// Optional human-readable description for debug UI
    let description: String?
    
    /// Creates a new preference definition
    /// - Parameters:
    ///   - key: The UserDefaults key
    ///   - defaultValue: The default value if none is set
    ///   - description: Optional description for debug UI
    init(key: String, defaultValue: T, description: String? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.description = description
    }
}

// MARK: - Convenience Initializers

extension Preference where T == Bool {
    /// Creates a Bool preference with a default of false
    init(key: String, description: String? = nil) {
        self.init(key: key, defaultValue: false, description: description)
    }
}

extension Preference where T == String {
    /// Creates a String preference with a default empty string
    init(key: String, description: String? = nil) {
        self.init(key: key, defaultValue: "", description: description)
    }
}

extension Preference where T == Int {
    /// Creates an Int preference with a default of 0
    init(key: String, description: String? = nil) {
        self.init(key: key, defaultValue: 0, description: description)
    }
}