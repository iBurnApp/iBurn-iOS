//
//  EventViewModel.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

struct EventLocation {
    var camp: BRCCamp?
    var art: BRCArt?
}

class EventViewModel: ObservableObject, DataViewModel {
    let timeDescription: String
    let statusColor: UIColor
    let eventTypeDescription: String
    @Published var hostName: String?
    @Published var locationDescription: String?
    
    private let event: BRCEvent
    private let embargo: BRCEmbargoInterface
    
    init?(data: BRCData, metadata: BRCMetadata, embargo: BRCEmbargoInterface = BRCEmbargo()) {
        guard let event = data as? BRCEvent else {
            return nil
        }
        self.event = event
        self.embargo = embargo
        timeDescription = Self.timeDescription(event: event)
        statusColor = event.statusColor
        eventTypeDescription = event.type.description
    }
    
    @MainActor
    func appear() async {
        let location = await event.locationInfo()
        hostName = location.camp?.name ?? location.art?.name ?? event.locationName
        
        let host = location.camp ?? location.art ?? event
        locationDescription = Self.locationDescription(for: host, embargo: embargo)
    }
    
    static func timeDescription(event: BRCEvent) -> String {
        if event.isAllDay {
            return "\(event.shortDay) (All Day)"
        } else if event.isStartingSoon {
            let eventDurationDescription = DateFormatters.stringForTimeInterval(event.duration)
            let timeToStart = event.durationUntilStart
            if timeToStart == 0 {
                return "now!"
            } else if let untilStart = DateFormatters.stringForTimeInterval(timeToStart) {
                var startDescription = "Starts \(untilStart)"
                if let eventDurationDescription {
                    startDescription.append(" (\(eventDurationDescription))")
                }
                return startDescription
            } else if let eventDurationDescription {
                return "Starts at \(eventDurationDescription)"
            } else {
                return defaultEventText(event: event)
            }
        } else if event.isHappeningNow {
            let timeToStart = event.durationUntilStart
            let timeUntilEnd = event.durationUntilEnd
            if timeUntilEnd == 0 {
                return "0 min"
            } else if let untilStart = DateFormatters.stringForTimeInterval(timeToStart) {
                var timeDescription = untilStart
                if let timeToEndDescription = DateFormatters.stringForTimeInterval( timeUntilEnd) {
                    timeDescription.append(" (\(timeToEndDescription) left)")
                }
                return timeDescription
            } else {
                return defaultEventText(event: event)
            }
        } else if event.hasEnded && event.hasStarted {
            return defaultEventText(event: event)
        } else {
            return defaultEventText(event: event)
        }
    }
    
    static func defaultEventText(event: BRCEvent) -> String {
        let startDescription = DateFormatter.timeOnly.string(from: event.start)
        var timeDescription = startDescription
        if let durationDescription = DateFormatters.stringForTimeInterval(event.duration) {
            timeDescription.append(" (\(durationDescription))")
        }
        return "\(event.shortDay) \(timeDescription)"
    }
}
