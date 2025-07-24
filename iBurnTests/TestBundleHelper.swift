//
//  TestBundleHelper.swift
//  iBurnTests
//
//  Created by Claude Code on 7/22/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation

@objc class TestBundleHelper: NSObject {
    @objc static func dataBundle() -> Bundle {
        return Bundle(for: TestBundleHelper.self)
    }
}