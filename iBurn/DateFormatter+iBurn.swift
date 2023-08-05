//
//  DateFormatter+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

extension TimeZone {
    /// Gerlach time / PDT
    static let burningManTimeZone = TimeZone(abbreviation: "PDT")!
}

extension NSTimeZone {
    @objc public static var brc_burningManTimeZone: NSTimeZone {
        return TimeZone.burningManTimeZone as NSTimeZone
    }
}

extension DateFormatter {
    /** e.g. 2015-09-04 */
    static let eventGroupDateFormatter: DateFormatter = {
        var df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.burningManTimeZone
        return df
    }()
    
    /// e.g. "Monday"
    static let dayOfWeek: DateFormatter = {
        var df = DateFormatter()
        df.dateFormat = "EEEE"
        df.timeZone = TimeZone.burningManTimeZone
        return df
    }()
    
    /// e.g. 4:19 AM
    static let timeOnly: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mma"
        df.timeZone = TimeZone.burningManTimeZone
        return df
    }()
    
    /// e.g. Monday 8/29 4:19 AM
    static let annotationDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "E' 'M/d' 'h:mma"
        df.timeZone = TimeZone.burningManTimeZone
        return df
    }()
    
    /// e.g. 8/5/23, 11:16 AM
    static let shortDateAndTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        df.timeZone = TimeZone.burningManTimeZone
        return df
    }()
}

extension DateComponentsFormatter {
    static let shortRelativeTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [ .hour, .minute ]
        return formatter
    }()
}

@objc public final class DateFormatters: NSObject {
    /** e.g. 2015-09-04 */
    @objc public static var eventGroupDateFormatter: DateFormatter {
        return DateFormatter.eventGroupDateFormatter
    }
    
    /// e.g. "Monday"
    @objc public static var dayOfWeek: DateFormatter {
        return DateFormatter.dayOfWeek
    }
    
    /// e.g. 4:19 AM
    @objc public static var timeOnly: DateFormatter {
        return DateFormatter.timeOnly
    }
    
    /// e.g. 8/5/23, 11:16 AM
    @objc public static var shortDateAndTime: DateFormatter {
        return DateFormatter.shortDateAndTime
    }
    
    @objc public static func stringForTimeInterval(_ interval: TimeInterval) -> String? {
        let formatter = DateComponentsFormatter.shortRelativeTimeFormatter
        return formatter.string(from: interval)
    }
}
