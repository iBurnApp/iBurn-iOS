//
//  BRCEvent+calendar.swift
//  iBurn
//
//  Created by Brice Pollock on 4/7/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
import OSLog
import EventKit

// Calendar Integration
extension BRCEvent {
    func refreshCalendarEvent(transaction: YapDatabaseReadWriteTransaction) {
        guard let metadata = BRCEventMetadata(transaction: transaction) else {
            return
        }
        if metadata.isFavorite {
            addCalendarEvent(for: metadata, transation: transaction)
        } else {
            removeCalendarEvent(for: metadata, transaction: transaction)
        }
    }
    
    /// Add a calendar event
    /// - Note: If an existing event, will not do anything
    func addCalendarEvent(for metadata: BRCEventMetadata, transaction: YapDatabaseReadWriteTransaction, calendarManager: CalendarManager = .shared) {
        if let eventID = metadata.calendarEventIdentifier, let existingEvent = calendarManager.eventStore?.event(withIdentifier: eventID) {
            Logger.calendarEvent.debug("Calendar event (\(eventID)) already exists for event: \(self)")
            return
        }
        let host = host(with: transaction)
        
    }
    
    func removeCalendarEvent(for metadata: BRCEventMetadata, transaction: YapDatabaseReadWriteTransaction, calendarManager: CalendarManager = .shared) {
        assert(!metadata.isFavorite)
        
        guard let store = calendarManager.eventStore else {
            return
        }
    
        // Remove from EventKit
        if let eventKitId = metadata.calendarEventIdentifier, let eventKitEvent = store.event(withIdentifier: eventKitId) {
            do {
                try store.remove(eventKitEvent, span: .thisEvent)
            } catch {
                Logger.calendarEvent.error("Failed to remove event \(eventKitEvent): \(error)")
            }
        }
        
        // Update persistence
        let newMetadata = metadata
        newMetadata.calendarEventIdentifier = nil
        self.replaceMetadata(metadata, transaction: transaction)
    }
    
    func makeCalendarEvent(event: BRCEvent, metadata: BRCEventMetadata, calendarManager: CalendarManager = .shared) {
        do {
            let calendarEvent = makeCalendarEvent(event: event, calendarManager: calendarManager)
            var newMetadata = metadata
            newMetadata.calendarEventIdentifier = calendarEvent.eventIdentifier            
            replaceMetadata(with: newMetadata, transaction: transaction)
        } catch {
            Logger.calendarEvent.error("Couldn't save calendar event due to error: \(error)")
        }
    }
    
    static func makeCalendarEvent(event: BRCEvent, calendarManager: CalendarManager = .shared) throws -> EKEvent {
        guard let eventStore = calendarManager.eventStore else {
            return
        }
        let calendar = eventStore.defaultCalendarForNewEvents
        var calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.calendar = calendar
        calendarEvent.title = title
        calendarEvent.location = locationString
        calendarEvent.timeZone = NSTimeZone.brc_burningManTimeZone]
        calendarEvent.startDate = startDate
        calendarEvent.endDate = endDate
        calendarEvent.allDay = isAllDay
        calendarEvent.URL = url
        calendarEvent.notes = detailDescription
        
        calendarEvent.addAlarm(EKAlarm(relativeOffset: -90*60))
        calendarEvent.addAlarm(EKAlarm(relativeOffset: -10*60))
        
        try eventStore.save(calendarEvent, span: .thisEvent, commit: true)
    }
    
    static func calendarEventLocation(host: BRCData) -> String? {
        var locationDescription = host.playaLocationDescription
        if let burnerLocation = host.burnerMapLocationDescription {
            locationDescription?.append("\(burnerLocation) - ")
        }
        if let name = host.name {
            locationDescription?.append(name)
        }
        return locationDescription
    }
}
