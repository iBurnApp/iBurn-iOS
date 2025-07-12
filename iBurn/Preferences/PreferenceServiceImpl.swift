//
//  PreferenceServiceImpl.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import Combine

/// Default implementation of PreferenceService using UserDefaults
class PreferenceServiceImpl: NSObject, PreferenceService {
    private let userDefaults: UserDefaults
    private var publishers = [String: Any]()
    private let publisherQueue = DispatchQueue(label: "com.burningman.iburn.preferences", attributes: .concurrent)
    
    /// Initializes the service with a UserDefaults instance
    /// - Parameter userDefaults: The UserDefaults to use (defaults to .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        super.init()
    }
    
    // MARK: - PreferenceService
    
    func getValue<T>(_ preference: Preference<T>) -> T {
        return userDefaults.object(forKey: preference.key) as? T ?? preference.defaultValue
    }
    
    func setValue<T>(_ value: T, for preference: Preference<T>) {
        userDefaults.set(value, forKey: preference.key)
        
        // Notify subscribers on background queue
        publisherQueue.async(flags: .barrier) { [weak self] in
            if let publisher = self?.publishers[preference.key] as? PassthroughSubject<T, Never> {
                publisher.send(value)
            }
        }
    }
    
    func publisher<T>(for preference: Preference<T>) -> AnyPublisher<T, Never> {
        publisherQueue.sync {
            let publisher: PassthroughSubject<T, Never>
            if let existing = publishers[preference.key] as? PassthroughSubject<T, Never> {
                publisher = existing
            } else {
                publisher = PassthroughSubject<T, Never>()
                publisherQueue.async(flags: .barrier) { [weak self] in
                    self?.publishers[preference.key] = publisher
                }
            }
            
            return publisher
                .prepend(getValue(preference))
                .share() // Share to ensure multiple subscribers get same values
                .eraseToAnyPublisher()
        }
    }
    
    func reset<T>(_ preference: Preference<T>) {
        userDefaults.removeObject(forKey: preference.key)
        // Notify subscribers of the reset
        setValue(preference.defaultValue, for: preference)
    }
    
    func hasValue<T>(_ preference: Preference<T>) -> Bool {
        return userDefaults.object(forKey: preference.key) != nil
    }
}

// MARK: - Objective-C Compatibility

extension PreferenceServiceImpl {
    /// Gets a boolean value for the given key
    @objc func boolValue(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    /// Sets a boolean value for the given key
    @objc func setBoolValue(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
        
        // Notify any Swift observers
        publisherQueue.async(flags: .barrier) { [weak self] in
            if let publisher = self?.publishers[key] as? PassthroughSubject<Bool, Never> {
                publisher.send(value)
            }
        }
    }
    
    /// Gets a string value for the given key
    @objc func stringValue(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    /// Sets a string value for the given key
    @objc func setStringValue(_ value: String?, forKey key: String) {
        if let value = value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
        
        // Notify any Swift observers
        publisherQueue.async(flags: .barrier) { [weak self] in
            if let publisher = self?.publishers[key] as? PassthroughSubject<String?, Never> {
                publisher.send(value)
            }
        }
    }
    
    /// Gets an integer value for the given key
    @objc func integerValue(forKey key: String) -> NSInteger {
        return userDefaults.integer(forKey: key)
    }
    
    /// Sets an integer value for the given key
    @objc func setIntegerValue(_ value: NSInteger, forKey key: String) {
        userDefaults.set(value, forKey: key)
        
        // Notify any Swift observers
        publisherQueue.async(flags: .barrier) { [weak self] in
            if let publisher = self?.publishers[key] as? PassthroughSubject<Int, Never> {
                publisher.send(value)
            }
        }
    }
    
    /// Removes the value for the given key
    @objc func removeValue(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    /// Checks if a value exists for the given key
    @objc func hasValue(forKey key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
}