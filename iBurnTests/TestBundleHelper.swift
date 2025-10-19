//
//  TestBundleHelper.swift
//  iBurnTests
//
//  Created by Claude Code on 7/22/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation

@objc class TestBundleHelper: NSObject {
    /// Returns the test bundle itself
    @objc static func testBundle() -> Bundle {
        return Bundle(for: TestBundleHelper.self)
    }

    /// Loads a named .bundle resource from the test bundle
    /// - Parameter name: The bundle name without .bundle extension (e.g., "initial_data", "updated_data")
    /// - Returns: The loaded bundle, or nil if not found
    @objc static func bundle(named name: String) -> Bundle? {
        let testBundle = Bundle(for: TestBundleHelper.self)
        guard let bundleURL = testBundle.url(forResource: name, withExtension: "bundle") else {
            print("Failed to find bundle named '\(name).bundle' in test bundle")
            return nil
        }
        guard let bundle = Bundle(url: bundleURL) else {
            print("Failed to load bundle at URL: \(bundleURL)")
            return nil
        }
        return bundle
    }

    /// Returns URL to update.json file in the named bundle
    /// - Parameter bundleName: The bundle name without .bundle extension (e.g., "initial_data", "updated_data")
    /// - Returns: URL to update.json in the bundle, or nil if not found
    @objc static func updateDataURL(forBundle bundleName: String) -> URL? {
        guard let bundle = bundle(named: bundleName) else {
            return nil
        }
        return bundle.url(forResource: "update", withExtension: "json")
    }

    /// Legacy method - use bundle(named:) instead
    @available(*, deprecated, message: "Use bundle(named:) instead")
    @objc static func dataBundle() -> Bundle {
        return Bundle(for: TestBundleHelper.self)
    }
}