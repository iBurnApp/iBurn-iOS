//
//  YearSettings.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc
public final class YearSettings: NSObject {
    
    /// e.g. "2018"
    @objc public static var playaYear: String {
        return YearSettings.shared.playaYear
    }
    
    @objc public static var eventStart: Date {
        return YearSettings.shared.eventStart
    }
    
    @objc public static var eventEnd: Date {
        return YearSettings.shared.eventEnd
    }
    
    @objc public static var festivalDays: [Date] {
        return YearSettings.shared.festivalDays
    }
    
    static let shared = YearSettings()
    
    /// e.g. "2018"
    let playaYear: String
    let eventStart: Date
    let eventEnd: Date
    let festivalDays: [Date]
    
    override init() {
        let yearSettingsPlistPath = Bundle(for: YearSettings.self).path(forResource: "YearSettings", ofType: "plist")!
        let yearSettings = NSDictionary(contentsOfFile: yearSettingsPlistPath)! as! [String: AnyObject]
        let eventStart = yearSettings["EventStart"] as! Date
        self.eventStart = eventStart
        self.eventEnd = yearSettings["EventEnd"] as! Date
        self.playaYear = yearSettings["PlayaYear"] as! String
        
        let numberOfDays = Calendar.current.dateComponents([.day], from: self.eventStart, to: self.eventEnd).day ?? 0
        self.festivalDays = (0..<numberOfDays).compactMap {
            var day = DateComponents()
            day.day = $0
            let date = Calendar.current.date(byAdding: day, to: eventStart)
            return date
        }
    }
}
