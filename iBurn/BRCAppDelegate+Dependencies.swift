//
//  BRCAppDelegate+Dependencies.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

extension BRCAppDelegate {
    /// Lazy-loaded dependency container
    /// Created once on first access and reused throughout the app lifecycle
    private static var _dependencies: DependencyContainer?

    @MainActor
    var dependencies: DependencyContainer {
        get {
            if let existing = BRCAppDelegate._dependencies {
                return existing
            }

            do {
                let container = try DependencyContainer()
                BRCAppDelegate._dependencies = container
                return container
            } catch {
                fatalError("Failed to initialize DependencyContainer: \(error)")
            }
        }
    }
}
