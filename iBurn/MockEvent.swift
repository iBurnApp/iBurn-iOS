//
//  MockEvent.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
@testable import iBurn

struct MockEvent: BRCEvent {
    // BRCData
    var playaLocationDescription: String?
    var burnerMapLocationDescription: String?
    var burnerMapAddressDescription: String?
    var burnerMapShortAddressDescription: String?

    // BRCEvent
    let type: BRCEventType
    
    let isAllDay: Bool
    let start: Date
    let end: Date
    
    let duration: TimeInterval
    let durationUntilStart: TimeInterval
    let durationUntilEnd: TimeInterval
    let isHappeningNow: Bool
    let isEndingSoon: Bool
    let isStartingSoon: Bool
    let hasStarted: Bool
    let hasEnded: Bool
    
    let statusColor: UIColor
    let locationName: String?
    
    let camp: MockCamp?
    let art: MockArt?
    
    init(
        playaLocationDescription: String? = nil,
        burnerMapLocationDescription: String? = nil,
        burnerMapAddressDescription: String? = nil,
        burnerMapShortAddressDescription: String? = nil,
        type: BRCEventType = .ceremony,
        isAllDay: Bool = false,
        start: Date = Date(),
        end: Date = Date(),
        duration: TimeInterval = 0,
        durationUntilStart: TimeInterval = 0,
        durationUntilEnd: TimeInterval = 0,
        isHappeningNow: Bool = false,
        isEndingSoon: Bool = false,
        isStartingSoon: Bool = false,
        hasStarted: Bool = false,
        hasEnded: Bool = false,
        statusColor: UIColor = .green,
        locationName: String? = nil,
        camp: MockCamp? = nil,
        art: MockArt? = nil
    ) {
        self.playaLocationDescription = playaLocationDescription
        self.burnerMapLocationDescription = burnerMapLocationDescription
        self.burnerMapAddressDescription = burnerMapAddressDescription
        self.burnerMapShortAddressDescription = burnerMapShortAddressDescription
        self.type = type
        self.isAllDay = isAllDay
        self.start = start
        self.end = end
        self.duration = duration
        self.durationUntilStart = durationUntilStart
        self.durationUntilEnd = durationUntilEnd
        self.isHappeningNow = isHappeningNow
        self.isEndingSoon = isEndingSoon
        self.isStartingSoon = isStartingSoon
        self.hasStarted = hasStarted
        self.hasEnded = hasEnded
        self.statusColor = statusColor
        self.locationName = locationName
        self.camp = camp
        self.art = art
    }
    
    func camp(from transaction: YapDatabaseReadTransaction) -> BRCCamp? {
        camp
    }
        
    func art(from transaction: YapDatabaseReadTransaction) -> BRCArt? {
        art
    }
}
