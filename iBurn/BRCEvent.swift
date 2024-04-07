//
//  BRCEvent.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
import OSLog

protocol BRCEvent: BRCData {
    var type: BRCEventType { get }
    
    var isAllDay: Bool { get }
    var start: Date { get }
    var end: Date { get}
    
    var duration: TimeInterval { get }
    var durationUntilStart: TimeInterval { get }
    var durationUntilEnd: TimeInterval { get }
    var isHappeningNow: Bool { get }
    var isEndingSoon: Bool { get }
    var isStartingSoon: Bool { get }
    var hasStarted: Bool { get }
    var hasEnded: Bool { get }
    
    var statusColor: UIColor { get }
    var locationName: String? { get }
    
    func camp(from transaction: YapDatabaseReadTransaction) -> BRCCamp?
    func art(from transaction: YapDatabaseReadTransaction) -> BRCArt?
}

extension BRCEvent {
    var shortDay: String {
        let day = DateFormatter.dayOfWeek.string(from: start)
        return String(day.prefix(3))
    }
}

extension BRCEventObject: BRCEvent {
    /// Threshold close to end-time which means 'soon' (seconds)
    static let endSoonThreshold: TimeInterval = 15 * 60
    /// Threshold close to start-time which means 'soon' (seconds)
    static let startSoonThreshold: TimeInterval = 30 * 60
    
    var type: BRCEventType {
        eventType
    }
    
    var isAllDay: Bool {
        duration > 23 * 60 * 60
    }
    
    var start: Date {
        startDate
    }
    
    var end: Date {
        endDate
    }
    
    var duration: TimeInterval {
        timeIntervalForDuration()
    }
    
    var durationUntilStart: TimeInterval {
        start.timeIntervalSinceNow
    }
    
    var durationUntilEnd: TimeInterval {
        end.timeIntervalSinceNow
    }
    
    var isHappeningNow: Bool {
        hasStarted & !hasEnded
    }
    
    var isEndingSoon: Bool {
        !hasEnded && end.timeIntervalSinceNow < Self.endSoonThreshold
    }
    
    var isStartingSoon: Bool {
        !hasStarted && start.timeIntervalSinceNow < Self.endSoonThreshold
    }
    
    var hasStarted: Bool {
        start.timeIntervalSinceNow < 0
    }
    
    var hasEnded: Bool {
        end.timeIntervalSinceNow < 0
    }
    
    var statusColor: UIColor {
        let colors = BRCImageColors.colors(for: type)
        if isStartingSoon {
            return .brc_green
        } else if hasStarted {
            return colors.primaryColor
        } else if isEndingSoon {
            return .brc_orange
        } else if hasEnded {
            return .brc_red
        } else if isHappeningNow {
            return .brc_green
        } else {
            return colors.primaryColor
        }
    }
    
    var locationName: String? {
        otherLocation
    }
}

// Persistence
extension BRCEvent {
    func metadata(from transaction: YapDatabaseReadTransaction) -> BRCMetadata {
        guard let metadata = transaction.metadata(forKey: yapKey, inCollection: yapCollection) as? BRCEventMetadata else {
            return BRCMetadata()
        }
        return metadata
    }
    
    func camp(from transaction: YapDatabaseReadTransaction) -> BRCCamp? {
        guard let campID = hostedByCampID else {
            return nil
        }
        return transaction.object(forKey: campID, inCollection: BRCCampObject.yapCollection)
    }
    
    func art(from transaction: YapDatabaseReadTransaction) -> BRCArt? {
        guard let artID = hostedByArtID else {
            return nil
        }
        return transaction.object(forKey: artID, inCollection: BRCArtObject.yapCollection)
    }
}
