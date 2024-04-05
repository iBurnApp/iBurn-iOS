//
//  BRCEvent.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

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
    
    func locationInfo() async -> EventLocation
}

extension BRCEvent {
    var shortDay: String {
        let day = DateFormatter.dayOfWeek.string(from: start)
        return String(day.prefix(3))
    }
}

extension BRCEventObject: BRCEvent {
    var type: BRCEventType {
        eventType
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
        timeInterval(untilStart: Date())
    }
    
    var durationUntilEnd: TimeInterval {
        timeInterval(untilEnd: Date())
    }
    
    var isHappeningNow: Bool {
        isHappeningRightNow(Date())
    }
    
    var isEndingSoon: Bool {
        isEndingSoon(Date())
    }
    
    var isStartingSoon: Bool {
        isStartingSoon(Date())
    }
    
    var hasStarted: Bool {
        hasStarted(Date())
    }
    
    var hasEnded: Bool {
        hasEnded(Date())
    }
    
    var statusColor: UIColor {
        color(forEventStatus: Date())
    }
    
    var locationName: String? {
        otherLocation
    }
    
    func locationInfo() async -> EventLocation {
        await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.uiConnection.read { transaction in
                continuation.resume(
                    returning: EventLocation(
                        camp: hostedByCamp(with: transaction),
                        art: hostedByArt(with: transaction)
                    )
                )
            }
        }
    }
}
