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
    @Published var shouldZoomToCity: Bool = false
    
    // MARK: - Private Properties
    private let originalDate: Date
    private let originalLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    
    // Current real-world values
    public let currentRealDate = Date.present
    public let currentRealLocation: CLLocation?
    
    // MARK: - Completion Handlers
    var onCancel: (() -> Void)?
    var onApply: ((TimeShiftConfiguration) -> Void)?
    
    // MARK: - Computed Properties
    var isTimeShifted: Bool {
        return selectedDate != originalDate || (isLocationOverrideEnabled && selectedLocation != nil)
    }
    
    var isAtCurrentReality: Bool {
        let timeIsNow = abs(selectedDate.timeIntervalSince(Date.present)) < 60 // Within a minute
        let locationIsHere = !isLocationOverrideEnabled || selectedLocation == nil
        return timeIsNow && locationIsHere
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
        formatter.timeZone = .burningMan
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - Initialization
    public init(currentConfiguration: TimeShiftConfiguration? = nil,
         currentLocation: CLLocation? = nil) {
        
        self.currentRealLocation = currentLocation
        
        // Initialize from configuration or defaults
        if let config = currentConfiguration {
            self.originalDate = config.date
            self.originalLocation = config.location
            self.selectedDate = config.date
            self.selectedLocation = config.location
            self.isLocationOverrideEnabled = config.location != nil
        } else {
            self.originalDate = Date.present
            self.originalLocation = nil
            self.selectedDate = Date.present
            self.selectedLocation = nil
            self.isLocationOverrideEnabled = false
        }
        
        setupObservers()
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        Publishers.CombineLatest3($selectedDate, $selectedLocation, $isLocationOverrideEnabled)
            .sink { [weak self] date, location, locationEnabled in
                guard let self = self else { return }
                
                // Check if current state differs from saved configuration
                let dateChanged = date != self.originalDate
                let locationChanged = (locationEnabled != (self.originalLocation != nil)) ||
                                    (locationEnabled && location?.coordinate.latitude != self.originalLocation?.coordinate.latitude) ||
                                    (locationEnabled && location?.coordinate.longitude != self.originalLocation?.coordinate.longitude)
                
                self.hasUnsavedChanges = dateChanged || locationChanged
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
        let isReallyActive = !isAtCurrentReality
        let config = TimeShiftConfiguration(
            date: selectedDate,
            location: isLocationOverrideEnabled ? selectedLocation : nil,
            isActive: isReallyActive
        )
        onApply?(config)
    }
    
    func updateLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if !isLocationOverrideEnabled {
            isLocationOverrideEnabled = true
        }
    }
    
    func resetToNow() {
        selectedDate = Date.present
    }
    
    func resetToReality() {
        selectedDate = Date.present
        selectedLocation = nil
        isLocationOverrideEnabled = false
    }
    
    func clearLocation() {
        selectedLocation = nil
        isLocationOverrideEnabled = false
        shouldZoomToCity = true
    }
    
    func setToSunrise() {
        selectedDate = Self.next(hour: 7, after: selectedDate)
    }

    func setToNoon() {
        selectedDate = Self.next(hour: 12, after: selectedDate)
    }

    func setToSunset() {
        selectedDate = Self.next(hour: 19, after: selectedDate)
    }

    /// The next `hour`:00 on the playa strictly after `date`: today's if it's still ahead,
    /// otherwise tomorrow's. Black Rock City time (`Calendar.burningMan`) — "sunrise" means
    /// 7 AM in Black Rock City, not 7 AM wherever the phone happens to be set.
    static func next(hour: Int, after date: Date, calendar: Calendar = .burningMan) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        if let today = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart),
           today > date {
            return today
        }
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let tomorrow = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: nextDay)
        else { return date }
        return tomorrow
    }
}