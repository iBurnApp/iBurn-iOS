//
//  YearSettings.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

@objc
public final class YearSettings: NSObject {
    
    // MARK: - Public
    
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
    
    /** Returns date if within range, or eventStart if out of range. */
    @objc public static func dayWithinFestival(_ date: Date) -> Date {
        guard (self.eventStart ... self.eventEnd).contains(date) else {
            return self.eventStart
        }
        return date
    }
    
    /// location of The Man
    public static var manCenterCoordinate: CLLocationCoordinate2D {
        return YearSettings.shared.manCenterCoordinate
    }

    // MARK: - Private
    
    private struct Keys {
        static let playaYear = "PlayaYear"
        static let eventStart = "EventStart"
        static let eventEnd = "EventEnd"
        static let manCenterLatitude = "ManCenterLatitude"
        static let manCenterLongitude = "ManCenterLongitude"
    }
    
    private static let path = Bundle(for: YearSettings.self).path(forResource: "YearSettings", ofType: "plist")!
    private let allSettings: [String: Any]
    
    private static let shared = YearSettings()
    
    /// e.g. "2018"
    private let playaYear: String
    private let eventStart: Date
    private let eventEnd: Date
    private let festivalDays: [Date]
    private let manCenterCoordinate: CLLocationCoordinate2D
    
    override init() {
        self.allSettings = NSDictionary(contentsOfFile: YearSettings.path)! as! [String: Any]
        let eventStart = allSettings["EventStart"] as! Date
        self.eventStart = eventStart
        self.eventEnd = allSettings["EventEnd"] as! Date
        self.playaYear = allSettings["PlayaYear"] as! String
        
        let numberOfDays = Calendar.current.dateComponents([.day], from: self.eventStart, to: self.eventEnd).day ?? 0
        self.festivalDays = (0..<numberOfDays).compactMap {
            var day = DateComponents()
            day.day = $0
            let date = Calendar.current.date(byAdding: day, to: eventStart)
            return date
        }
        let manCenterLatitude = allSettings[Keys.manCenterLatitude] as! Double
        let manCenterLongitude = allSettings[Keys.manCenterLongitude] as! Double
        self.manCenterCoordinate = CLLocationCoordinate2D(latitude: manCenterLatitude, longitude: manCenterLongitude)
    }
}
