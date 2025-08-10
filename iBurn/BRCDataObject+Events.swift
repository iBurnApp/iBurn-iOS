//
//  BRCDataObject+Events.swift
//  iBurn
//
//  Created by Claude on 1/9/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

extension BRCDataObject {
    
    /// Returns the count of events hosted at this art/camp
    @objc public func eventCount(with transaction: YapDatabaseReadTransaction) -> Int {
        guard self is BRCArtObject || self is BRCCampObject else {
            return 0
        }
        return events(with: transaction).count
    }
    
    /// Returns whether this art/camp has any events
    @objc public func hasEvents(with transaction: YapDatabaseReadTransaction) -> Bool {
        return eventCount(with: transaction) > 0
    }
    
    /// Returns upcoming events hosted at this art/camp
    @objc public func upcomingEvents(with transaction: YapDatabaseReadTransaction, from date: Date = Date.present) -> [BRCEventObject] {
        let allEvents = events(with: transaction)
        return allEvents.filter { !$0.hasEnded(date) }
            .sorted { $0.startDate.compare($1.startDate) == .orderedAscending }
    }
    
    /// Returns events happening now at this art/camp
    @objc public func currentEvents(with transaction: YapDatabaseReadTransaction, at date: Date = Date.present) -> [BRCEventObject] {
        let allEvents = events(with: transaction)
        return allEvents.filter { $0.isHappeningRightNow(date) }
    }
}

extension BRCEventObject {
    
    /// Returns a formatted string describing the event's host
    @objc public var formattedHostName: String? {
        if let campName = campName {
            return "🏕 \(campName)"
        } else if let artName = artName {
            return "🎨 \(artName)"
        } else if let otherLocation = otherLocation {
            return otherLocation
        }
        return nil
    }
    
    /// Returns whether this event is hosted at art (vs camp or other)
    @objc public var isHostedByArt: Bool {
        return hostedByArtUniqueID != nil
    }
    
    /// Returns whether this event is hosted at a camp
    @objc public var isHostedByCamp: Bool {
        return hostedByCampUniqueID != nil
    }
}

@objc extension BRCArtObject {
    
    /// Returns a formatted event count string for display
    public func formattedEventCount(with transaction: YapDatabaseReadTransaction) -> String? {
        let count = eventCount(with: transaction)
        guard count > 0 else { return nil }
        return "📅 \(count)"
    }
}

@objc extension BRCCampObject {
    
    /// Returns a formatted event count string for display
    public func formattedEventCount(with transaction: YapDatabaseReadTransaction) -> String? {
        let count = eventCount(with: transaction)
        guard count > 0 else { return nil }
        return "📅 \(count)"
    }
}