//
//  EventEditService.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import EventKit
import EventKitUI

// MARK: - Protocol

/// Service for creating calendar event editors without requiring permissions
protocol EventEditService {
    /// Creates a pre-configured event edit controller for the given event
    /// - Parameter event: The event object to create a calendar entry for
    /// - Returns: A configured EKEventEditViewController ready for presentation
    func createEventEditController(for event: BRCEventObject) -> EKEventEditViewController
}

// MARK: - Factory

/// Factory for creating EventEditService instances
enum EventEditServiceFactory {
    /// Creates an event edit service for production use
    static func makeService() -> EventEditService {
        return EventEditServiceImpl()
    }
}

// MARK: - Implementation

private class EventEditServiceImpl: EventEditService {
    
    func createEventEditController(for event: BRCEventObject) -> EKEventEditViewController {
        let eventStore = EKEventStore()
        let calendarEvent = EKEvent(eventStore: eventStore)
        
        // Pre-populate with event data
        calendarEvent.title = event.title
        calendarEvent.startDate = event.startDate
        calendarEvent.endDate = event.endDate
        
        // Add location information
        if let playaLocation = event.playaLocation, !playaLocation.isEmpty {
            calendarEvent.location = playaLocation
        }
        
        // Add description
        if let description = event.detailDescription, !description.isEmpty {
            calendarEvent.notes = description
        }
        
        // Add URL if available
        if let url = event.url {
            calendarEvent.url = url
        }
        
        // Add reminder (1.5 hours before, matching existing behavior)
        let alarm = EKAlarm(relativeOffset: -90 * 60) // 90 minutes in seconds
        calendarEvent.addAlarm(alarm)
        
        // Create and configure the edit controller
        let controller = EKEventEditViewController()
        controller.event = calendarEvent
        controller.eventStore = eventStore
        
        return controller
    }
}