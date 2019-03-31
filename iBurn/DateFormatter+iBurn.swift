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
}
