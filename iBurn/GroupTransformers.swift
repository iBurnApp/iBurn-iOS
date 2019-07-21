//
//  GroupTransformers.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/21/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation

enum GroupTransformers {
    static let searchGroup: (String) -> String = {
        if $0.count == 1 {
            return $0
        }
        let components = $0.components(separatedBy: " ")
        guard let hourString = components.last,
            let dateString = components.first,
            let date = DateFormatter.eventGroupDateFormatter.date(from: dateString),
            var hour = Int(hourString) else {
                return $0
        }
        let day = DateFormatter.dayOfWeek.string(from: date)
        let dayLetter: String
        if let letter = day.first {
            dayLetter = "\(letter)"
        } else {
            dayLetter = ""
        }
        hour = hour % 12
        if hour == 0 {
            hour = 12
        }
        return "\(dayLetter)\(hour)"
    }
}
