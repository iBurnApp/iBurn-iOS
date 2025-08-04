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

// MARK: - Factory

/// Factory for creating calendar event edit controllers
enum EventEditControllerFactory {
    /// Creates a pre-configured event edit controller for the given event and host
    /// - Parameters:
    ///   - event: The event object to create a calendar entry for
    ///   - host: The host object (camp or art) that provides location and name
    /// - Returns: A configured EKEventEditViewController ready for presentation
    static func createEventEditController(for event: BRCEventObject, host: BRCDataObject?) -> EKEventEditViewController {
        let eventStore = EKEventStore()
        let calendarEvent = EKEvent(eventStore: eventStore)
        
        // Pre-populate with event data
        calendarEvent.title = event.title
        calendarEvent.startDate = event.startDate
        calendarEvent.endDate = event.endDate
        
        // Add location information (playa address + host name)
        calendarEvent.location = formatLocationString(event: event, host: host)
        
        // Add description (event + host information)
        calendarEvent.notes = formatNotesString(event: event, host: host)
        
        // Add URL if available
        if let url = event.url {
            calendarEvent.url = url
        }
        
        // Add reminder (1.5 hours before, matching existing behavior)
        let alarm = EKAlarm(relativeOffset: -90 * 60) // 90 minutes in seconds
        calendarEvent.addAlarm(alarm)
        let alarm2 = EKAlarm(relativeOffset: -10 * 60) // 10 minutes in seconds
        calendarEvent.addAlarm(alarm2)
        
        // Create and configure the edit controller
        let controller = EKEventEditViewController()
        controller.event = calendarEvent
        controller.eventStore = eventStore
        
        return controller
    }
    
    // MARK: - Private Helpers
    
    /// Formats location string to include both playa address and host name
    /// Uses same logic as legacy calendar system in BRCEventObject.m
    /// Respects embargo status - hides playa location when under embargo
    private static func formatLocationString(event: BRCEventObject, host: BRCDataObject?) -> String {
        var locationString = ""
        
        // Check if we should show location based on embargo status
        let canShowLocation = host.map { BRCEmbargo.canShowLocation(for: $0) } ?? true
        
        if canShowLocation {
            // Get playa location from host (camp/art) or fall back to event's otherLocation
            var playaLocation: String?
            if let host = host {
                playaLocation = host.playaLocation
                if playaLocation?.isEmpty ?? true {
                    playaLocation = host.burnerMapLocationString
                }
            }
            
            // If no host location, fall back to event's otherLocation
            if playaLocation?.isEmpty ?? true {
                playaLocation = event.otherLocation
            }
            
            // Build location string: "[Playa Address] - [Host Name]"
            if let playaLocation = playaLocation, !playaLocation.isEmpty {
                locationString += playaLocation
                if let hostTitle = host?.title, !hostTitle.isEmpty {
                    locationString += " - \(hostTitle)"
                }
            } else if let hostTitle = host?.title, !hostTitle.isEmpty {
                // If no playa location but we have a host, just use host name
                locationString = hostTitle
            }
        } else {
            // Under embargo - only show host name, no playa location
            if let hostTitle = host?.title, !hostTitle.isEmpty {
                locationString = hostTitle
            }
        }
        
        return locationString
    }
    
    /// Formats comprehensive notes string including event description, host description, and camp landmarks
    /// Uses same pattern as existing UI components that combine event + host information
    private static func formatNotesString(event: BRCEventObject, host: BRCDataObject?) -> String {
        var notesComponents: [String] = []
        
        // Start with event's own description
        if let eventDescription = event.detailDescription, !eventDescription.isEmpty {
            notesComponents.append(eventDescription)
        }
        
        // Add host information if available
        if let host = host {
            var hostSection = ""
            
            // Add host name and type
            let hostType = (host is BRCCampObject) ? "Camp" : "Art"
            hostSection += "\(host.title) (\(hostType))"
            
            // Add host description if available
            if let hostDescription = host.detailDescription, !hostDescription.isEmpty {
                hostSection += "\n\(hostDescription)"
            }
            
            // Add camp landmark if this is a camp and landmark exists
            if let camp = host as? BRCCampObject,
               let landmark = camp.landmark, !landmark.isEmpty {
                hostSection += "\n\nCamp Landmark: \(landmark)"
            }
            
            notesComponents.append(hostSection)
        }
        
        // Join components with double newlines for clear separation
        return notesComponents.joined(separator: "\n\n")
    }
}
