//
//  PreferenceProperty.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import Combine

/// A property wrapper that provides SwiftUI integration for preferences
/// Similar to @AppStorage but with type-safe preference definitions
@propertyWrapper
struct PreferenceProperty<Value>: DynamicProperty {
    private let preference: Preference<Value>
    private let service: PreferenceService
    
    @ObservedObject private var observer: PreferenceObserver<Value>
    
    /// Creates a preference property for the given preference
    /// - Parameter preference: The preference definition
    init(_ preference: Preference<Value>) {
        self.preference = preference
        self.service = PreferenceServiceFactory.shared
        self.observer = PreferenceObserver(preference: preference, service: service)
    }
    
    /// The current value of the preference
    var wrappedValue: Value {
        get { observer.value }
        nonmutating set { 
            service.setValue(newValue, for: preference)
        }
    }
    
    /// A binding to the preference value
    var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
    
    /// A publisher that emits preference value changes
    /// Useful for observing changes in ViewModels
    var publisher: AnyPublisher<Value, Never> {
        service.publisher(for: preference)
    }
}

// MARK: - Internal Observer

/// Internal observer that triggers SwiftUI updates when preference values change
private class PreferenceObserver<T>: ObservableObject {
    @Published var value: T
    private var cancellable: AnyCancellable?
    
    init(preference: Preference<T>, service: PreferenceService) {
        // Get initial value
        self.value = service.getValue(preference)
        
        // Subscribe to changes
        self.cancellable = service.publisher(for: preference)
            .dropFirst() // Skip initial value since we already have it
            .receive(on: DispatchQueue.main) // Ensure UI updates on main thread
            .sink { [weak self] newValue in
                self?.value = newValue
            }
    }
}