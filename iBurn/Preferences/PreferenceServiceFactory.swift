//
//  PreferenceServiceFactory.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// Factory for accessing the shared PreferenceService instance
enum PreferenceServiceFactory {
    /// The shared service instance
    private static var _service: PreferenceService = PreferenceServiceImpl()
    
    /// Gets the shared PreferenceService instance
    static var shared: PreferenceService {
        return _service
    }
    
    /// Sets a custom service implementation (for testing)
    /// - Parameter service: The service to use
    static func setService(_ service: PreferenceService) {
        _service = service
    }
    
    /// Resets to the default service implementation
    static func resetToDefault() {
        _service = PreferenceServiceImpl()
    }
}

// MARK: - Objective-C Bridge

/// Objective-C compatible bridge to the preference service
@objc(BRCPreferenceService)
public class BRCPreferenceService: NSObject {
    /// Shared instance for Objective-C access
    @objc public static let shared = BRCPreferenceService()
    
    private let service: PreferenceServiceImpl
    
    private override init() {
        // We need direct access to impl for Obj-C methods
        self.service = PreferenceServiceFactory.shared as! PreferenceServiceImpl
        super.init()
    }
    
    @objc public func boolValue(forKey key: String) -> Bool {
        return service.boolValue(forKey: key)
    }
    
    @objc public func setBoolValue(_ value: Bool, forKey key: String) {
        service.setBoolValue(value, forKey: key)
    }
    
    @objc public func stringValue(forKey key: String) -> String? {
        return service.stringValue(forKey: key)
    }
    
    @objc public func setStringValue(_ value: String?, forKey key: String) {
        service.setStringValue(value, forKey: key)
    }
    
    @objc public func integerValue(forKey key: String) -> NSInteger {
        return service.integerValue(forKey: key)
    }
    
    @objc public func setIntegerValue(_ value: NSInteger, forKey key: String) {
        service.setIntegerValue(value, forKey: key)
    }
    
    @objc public func removeValue(forKey key: String) {
        service.removeValue(forKey: key)
    }
    
    @objc public func hasValue(forKey key: String) -> Bool {
        return service.hasValue(forKey: key)
    }
}