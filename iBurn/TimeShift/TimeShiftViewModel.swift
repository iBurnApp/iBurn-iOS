//
//  TimeShiftViewModel.swift
//  iBurn
//
//  Created by Claude Code on 8/3/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import Combine

public class TimeShiftViewModel: ObservableObject {
    // MARK: - Published State
    @Published var selectedDate: Date
    @Published var selectedLocation: CLLocation?
    @Published var isLocationOverrideEnabled: Bool
    @Published var hasUnsavedChanges: Bool = false
    
    // MARK: - Private Properties
    private let originalDate: Date
    private let originalLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Completion Handlers
    var onCancel: (() -> Void)?
    var onApply: ((TimeShiftConfiguration) -> Void)?
    
    // MARK: - Computed Properties
    var isTimeShifted: Bool {
        return selectedDate != originalDate || (isLocationOverrideEnabled && selectedLocation != nil)
    }
    
    var timeOffsetDescription: String? {
        guard selectedDate != originalDate else { return nil }
        
        let interval = selectedDate.timeIntervalSince(originalDate)
        let absInterval = abs(interval)
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        
        if let formatted = formatter.string(from: absInterval) {
            return interval >= 0 ? "+\(formatted)" : "-\(formatted)"
        }
        return nil
    }
    
    var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - Initialization
    public init(currentConfiguration: TimeShiftConfiguration? = nil,
         currentLocation: CLLocation? = nil) {
        
        // Initialize from configuration or defaults
        if let config = currentConfiguration {
            self.originalDate = config.date
            self.originalLocation = config.location
            self.selectedDate = config.date
            self.selectedLocation = config.location
            self.isLocationOverrideEnabled = config.location != nil
        } else {
            self.originalDate = Date.present
            self.originalLocation = currentLocation
            self.selectedDate = Date.present
            self.selectedLocation = currentLocation
            self.isLocationOverrideEnabled = false
        }
        
        setupObservers()
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        Publishers.CombineLatest3($selectedDate, $selectedLocation, $isLocationOverrideEnabled)
            .sink { [weak self] date, location, locationEnabled in
                guard let self = self else { return }
                self.hasUnsavedChanges = (date != self.originalDate) || 
                                         (locationEnabled && location != self.originalLocation)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func reset() {
        selectedDate = originalDate
        selectedLocation = originalLocation
        isLocationOverrideEnabled = false
        hasUnsavedChanges = false
    }
    
    func cancel() {
        onCancel?()
    }
    
    func apply() {
        let config = TimeShiftConfiguration(
            date: selectedDate,
            location: isLocationOverrideEnabled ? selectedLocation : nil,
            isActive: isTimeShifted
        )
        onApply?(config)
    }
    
    func updateLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        isLocationOverrideEnabled = true
    }
    
    func resetToNow() {
        selectedDate = Date.present
    }
    
    func addOneDay() {
        selectedDate = selectedDate.addingTimeInterval(86400) // +1 day
    }
    
    func setToSunset() {
        // Find next sunset (approximately 7:30 PM)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = 19
        components.minute = 30
        if let sunset = Calendar.current.date(from: components),
           sunset > selectedDate {
            selectedDate = sunset
        } else {
            // Next day's sunset
            components.day! += 1
            if let nextSunset = Calendar.current.date(from: components) {
                selectedDate = nextSunset
            }
        }
    }
}